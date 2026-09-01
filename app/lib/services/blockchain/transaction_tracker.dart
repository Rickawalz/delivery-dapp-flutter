import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';
import '../firestore/analytics_service.dart';

/// Transaction tracking states
enum TransactionState {
  pending,
  submitted,
  mined,
  confirmed,
  failed,
}

/// Transaction tracking data
class TransactionData {
  final String txHash;
  final String action;
  final String providerType;
  final DateTime submittedAt;
  DateTime? minedAt;
  int? confirmations;
  BigInt? gasUsed;
  BigInt? effectiveGasPriceWei;
  BigInt? nativeFeeWei;
  TransactionState state;
  String? errorCode;
  String? errorMessage;

  TransactionData({
    required this.txHash,
    required this.action,
    required this.providerType,
    required this.submittedAt,
    this.minedAt,
    this.confirmations,
    this.gasUsed,
    this.effectiveGasPriceWei,
    this.nativeFeeWei,
    this.state = TransactionState.pending,
    this.errorCode,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'txHash': txHash,
      'action': action,
      'providerType': providerType,
      'submittedAt': submittedAt.toIso8601String(),
      'minedAt': minedAt?.toIso8601String(),
      'confirmations': confirmations,
      'gasUsed': gasUsed?.toString(),
      'effectiveGasPriceWei': effectiveGasPriceWei?.toString(),
      'nativeFeeWei': nativeFeeWei?.toString(),
      'state': state.toString(),
      'errorCode': errorCode,
      'errorMessage': errorMessage,
    };
  }
}

/// Service for tracking blockchain transactions
class TransactionTracker extends ChangeNotifier {
  final Map<String, TransactionData> _transactions = {};
  final Web3Client _client;
  Timer? _pollingTimer;

  TransactionTracker(this._client);

  /// Get all tracked transactions
  Map<String, TransactionData> get transactions => Map.unmodifiable(_transactions);

  /// Get transaction by hash
  TransactionData? getTransaction(String txHash) => _transactions[txHash];

  /// Check if transaction is still pending
  bool isPending(String txHash) {
    final tx = _transactions[txHash];
    if (tx == null) return false;
    return tx.state == TransactionState.pending || tx.state == TransactionState.submitted;
  }

  /// Manually trigger an immediate poll of all pending transactions
  Future<void> pollNow() async {
    await _pollTransactions();
  }

  /// Start tracking a transaction
  Future<void> trackTransaction({
    required String txHash,
    required String action,
    required String providerType,
  }) async {
    final transaction = TransactionData(
      txHash: txHash,
      action: action,
      providerType: providerType,
      submittedAt: DateTime.now(),
    );

    _transactions[txHash] = transaction;
    notifyListeners();

    // Save to Firestore
    await AnalyticsService.saveTransaction(
      txHash: txHash,
      action: action,
      providerType: providerType,
      submittedAt: transaction.submittedAt,
      status: 'submitted',
    );

    // Start polling for updates
    _startPolling();
  }

  /// Update transaction with receipt data
  Future<void> updateTransactionWithReceipt({
    required String txHash,
    required TransactionReceipt receipt,
  }) async {
    final transaction = _transactions[txHash];
    if (transaction == null) return;

    transaction.minedAt = DateTime.now();
    transaction.gasUsed = receipt.gasUsed;
    transaction.effectiveGasPriceWei = receipt.effectiveGasPrice?.getInWei;
    transaction.nativeFeeWei = receipt.gasUsed != null && receipt.effectiveGasPrice != null
        ? receipt.gasUsed! * receipt.effectiveGasPrice!.getInWei
        : null;
    transaction.state = receipt.status == '0x1' ? TransactionState.mined : TransactionState.failed;

    if (receipt.status != '0x1') {
      transaction.errorCode = 'REVERTED';
      transaction.errorMessage = 'Transaction reverted';
    }

    notifyListeners();

    // Update Firestore
    await AnalyticsService.saveTransaction(
      txHash: txHash,
      action: transaction.action,
      providerType: transaction.providerType,
      submittedAt: transaction.submittedAt,
      minedAt: transaction.minedAt,
      gasUsed: transaction.gasUsed,
      effectiveGasPriceWei: transaction.effectiveGasPriceWei,
      nativeFeeWei: transaction.nativeFeeWei,
      status: transaction.state == TransactionState.mined ? 'success' : 'reverted',
      errorCode: transaction.errorCode,
      errorMessage: transaction.errorMessage,
    );
  }

  /// Update transaction with error
  Future<void> updateTransactionWithError({
    required String txHash,
    required String errorCode,
    required String errorMessage,
  }) async {
    final transaction = _transactions[txHash];
    if (transaction == null) return;

    transaction.state = TransactionState.failed;
    transaction.errorCode = errorCode;
    transaction.errorMessage = errorMessage;

    notifyListeners();

    // Update Firestore
    await AnalyticsService.saveTransaction(
      txHash: txHash,
      action: transaction.action,
      providerType: transaction.providerType,
      submittedAt: transaction.submittedAt,
      status: 'failed',
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }

  /// Start polling for transaction updates
  void _startPolling() {
    if (_pollingTimer != null) return;

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _pollTransactions();
    });
  }

  /// Stop polling
  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Poll all pending transactions
  Future<void> _pollTransactions() async {
    final pendingTransactions = _transactions.values
        .where((tx) => tx.state == TransactionState.pending || tx.state == TransactionState.submitted)
        .toList();

    if (pendingTransactions.isEmpty) {
      _stopPolling();
      return;
    }

    for (final transaction in pendingTransactions) {
      try {
        final receipt = await _client.getTransactionReceipt(transaction.txHash);
        if (receipt != null) {
          await updateTransactionWithReceipt(
            txHash: transaction.txHash,
            receipt: receipt,
          );
        }
      } catch (e) {
        debugPrint('Error polling transaction ${transaction.txHash}: $e');
      }
    }
  }

  /// Get transaction latency in seconds
  double? getTransactionLatency(String txHash) {
    final transaction = _transactions[txHash];
    if (transaction?.minedAt == null) return null;
    
    return transaction!.minedAt!.difference(transaction.submittedAt).inMilliseconds / 1000.0;
  }

  /// Get transaction cost in native currency
  BigInt? getTransactionCost(String txHash) {
    final transaction = _transactions[txHash];
    return transaction?.nativeFeeWei;
  }

  /// Get transaction cost in REL (if applicable)
  BigInt? getTransactionCostRel(String txHash) {
    final transaction = _transactions[txHash];
    // This would need to be calculated based on token price
    // For now, return null as we don't have price oracle
    return null;
  }

  /// Get analytics data for all transactions
  Map<String, dynamic> getAnalyticsData() {
    final transactions = _transactions.values.toList();
    
    if (transactions.isEmpty) {
      return {
        'totalTransactions': 0,
        'successRate': 0.0,
        'averageLatency': 0.0,
        'totalGasUsed': 0,
        'totalCost': 0,
      };
    }

    final successfulTransactions = transactions.where((tx) => tx.state == TransactionState.mined).toList();
    final failedTransactions = transactions.where((tx) => tx.state == TransactionState.failed).toList();
    
    final latencies = successfulTransactions
        .map((tx) => getTransactionLatency(tx.txHash))
        .where((latency) => latency != null)
        .cast<double>()
        .toList();
    
    final totalGasUsed = successfulTransactions
        .map((tx) => tx.gasUsed ?? BigInt.zero)
        .fold(BigInt.zero, (sum, gas) => sum + gas);
    
    final totalCost = successfulTransactions
        .map((tx) => tx.nativeFeeWei ?? BigInt.zero)
        .fold(BigInt.zero, (sum, cost) => sum + cost);

    return {
      'totalTransactions': transactions.length,
      'successfulTransactions': successfulTransactions.length,
      'failedTransactions': failedTransactions.length,
      'successRate': successfulTransactions.length / transactions.length,
      'averageLatency': latencies.isEmpty ? 0.0 : latencies.reduce((a, b) => a + b) / latencies.length,
      'totalGasUsed': totalGasUsed.toString(),
      'totalCost': totalCost.toString(),
      'averageGasUsed': successfulTransactions.isEmpty ? 0 : totalGasUsed ~/ BigInt.from(successfulTransactions.length),
      'averageCost': successfulTransactions.isEmpty ? 0 : totalCost ~/ BigInt.from(successfulTransactions.length),
    };
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
