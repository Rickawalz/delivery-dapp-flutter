import 'package:flutter/foundation.dart';
import '../../models/delivery.dart';
import '../../models/transaction_result.dart';
import '../blockchain/walletconnect_service.dart';
import '../blockchain/contract_service.dart';
import '../blockchain/transaction_tracker.dart';
import '../firestore/analytics_service.dart';

class DeliveryService extends ChangeNotifier {
  final WalletConnectService _walletService;
  final ContractService _contractService;
  final TransactionTracker _transactionTracker;
  List<Delivery> _deliveries = [];
  bool _isLoading = false;
  String? _error;
  String? _lastTransactionHash;

  DeliveryService(this._walletService, this._transactionTracker, ContractService? contractService) 
      : _contractService = contractService ?? ContractService() {
    _initialize();
    _walletService.addListener(_onWalletChanged);
    _contractService.setTransactionTracker(_transactionTracker);
  }

  Future<void> _initialize() async {
    try {
      await _contractService.initialize();
    } catch (e) {
      _error = 'Failed to initialize contract service: ${e.toString()}';
      notifyListeners();
    }
  }

  void _onWalletChanged() {
    if (_walletService.isConnected && _walletService.walletAddress != null) {
      // WalletConnectService doesn't use credentials like WalletService
      // The connection is handled through WalletConnect protocol
      print('✅ WalletConnect service initialized and connected');
      
      // Clear any existing wallet connection errors
      if (_error != null && _error!.contains('Wallet not connected')) {
        _error = null;
        notifyListeners();
      }
      
      // Auto-fetch deliveries when wallet connects
      print('🔄 DEBUG: Auto-fetching deliveries after wallet connection...');
      print('🔄 DEBUG: About to call fetchAvailableDeliveries()...');
      fetchAvailableDeliveries();
    }
  }

  List<Delivery> get deliveries => _deliveries;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get lastTransactionHash => _lastTransactionHash;

  /// Get transaction status by hash
  TransactionData? getTransactionStatus(String txHash) {
    return _transactionTracker.getTransaction(txHash);
  }

  /// Check if a transaction is still pending
  bool isTransactionPending(String txHash) {
    return _transactionTracker.isPending(txHash);
  }

  // Get deliveries for the current user (as sender or receiver)
  Future<void> fetchUserDeliveries() async {
    if (!_walletService.isConnected) {
      _error = 'Wallet not connected';
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Try to fetch from Firestore first (faster), then fallback to blockchain
      List<Map<String, dynamic>> deliveryDataList = [];
      
      try {
        deliveryDataList = await AnalyticsService.getUserDeliveries(_walletService.walletAddress!);
        print('📊 Fetched ${deliveryDataList.length} deliveries from Firestore');
      } catch (e) {
        print('⚠️ Firestore fetch failed: $e');
        // TODO: Implement blockchain fallback for querying user deliveries
      }

      final deliveries = <Delivery>[];

      for (final deliveryData in deliveryDataList) {
        deliveries.add(Delivery.fromJson(deliveryData));
      }

      _deliveries = deliveries;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch deliveries: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create a new delivery with SimpleDeliverySystem parameters
  Future<Delivery?> createDelivery({
    required String driverAddress,
    required String description,
    required int distanceMeters,
    required double fiatAmountUSD,
  }) async {
    print('\n════════════════════════════════════════');
    print('🚀 DEBUG: createDelivery START');
    print('════════════════════════════════════════');
    print('📋 Input parameters:');
    print('  - Driver address: $driverAddress');
    print('  - Description: $description');
    print('  - Distance (meters): $distanceMeters');
    print('  - Fiat amount (USD): $fiatAmountUSD');
    
    print('\n🔐 Wallet check:');
    print('  - Connected: ${_walletService.isConnected}');
    print('  - Wallet address: ${_walletService.walletAddress}');
    print('  - Chain ID: ${_walletService.chainId}');
    
    if (!_walletService.isConnected) {
      print('❌ DEBUG: Wallet not connected, aborting');
      _error = 'Wallet not connected or no credentials available. Please connect your wallet first.';
      notifyListeners();
      return null;
    }

    print('\n💱 Converting parameters:');
    final fiatAmountCents = (fiatAmountUSD * 100).toInt();
    print('  - Fiat amount (cents): $fiatAmountCents');

    _isLoading = true;
    _error = null;
    notifyListeners();
    print('  - Loading state set to true');

    try {
      print('\n📞 DEBUG: Calling ContractService.createDelivery...');
      
      final result = await _contractService.createDelivery(
        driverAddress: driverAddress,
        distanceMeters: distanceMeters,
        fiatAmountCents: fiatAmountCents,
      );

      print('\n✅ DEBUG: Contract call successful!');
      print('  - Delivery ID: ${result.deliveryId}');
      print('  - Transaction hash: ${result.transaction.txHash}');
      print('  - Transaction latency: ${result.transaction.latencySeconds.toStringAsFixed(2)}s');
      print('  - Gas used: ${result.transaction.receipt.gasUsed}');
      
      // Store transaction hash for UI access
      _lastTransactionHash = result.transaction.txHash;

      print('\n📊 DEBUG: Fetching delivery data from contract...');
      final deliveryData = await _contractService.getDelivery(result.deliveryId);
      print('  - Delivery data retrieved: $deliveryData');
      
      print('\n🏗️  DEBUG: Creating Delivery object...');
      final delivery = Delivery(
        id: result.deliveryId,
        customerAddress: deliveryData['customer'],
        driverAddress: deliveryData['driver'],
        distanceMeters: deliveryData['distanceMeters'],
        fiatAmountCents: deliveryData['fiatAmountCents'],
        rating: deliveryData['rating'],
        status: DeliveryStatus.values[deliveryData['status']],
        createdAt: DateTime.fromMillisecondsSinceEpoch(deliveryData['createdAt'] * 1000),
        completedAt: deliveryData['completedAt'] > 0 
            ? DateTime.fromMillisecondsSinceEpoch(deliveryData['completedAt'] * 1000)
            : null,
        description: description,
      );
      print('  - Delivery object created');

      _deliveries.add(delivery);
      print('  - Added to local deliveries list');
      
      print('\n💾 DEBUG: Saving to Firestore...');
      await AnalyticsService.saveDelivery(
        deliveryId: result.deliveryId,
        customer: deliveryData['customer'],
        courier: deliveryData['driver'],
        pickupAddress: 'Location ${deliveryData['distanceMeters']}m away',
        deliveryAddress: 'Destination',
        priceWei: BigInt.from(deliveryData['fiatAmountCents']),
        description: description,
        status: 'inprogress',
        createdAt: DateTime.fromMillisecondsSinceEpoch(deliveryData['createdAt'] * 1000),
      );
      print('  - Saved to Firestore successfully');

      _isLoading = false;
      notifyListeners();
      
      print('\n════════════════════════════════════════');
      print('✅ DEBUG: createDelivery SUCCESS');
      print('════════════════════════════════════════\n');
      
      return delivery;
    } on GasEstimationException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      print('\n════════════════════════════════════════');
      print('❌ DEBUG: createDelivery FAILED');
      print('════════════════════════════════════════');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Stack trace:\n$stackTrace');
      print('════════════════════════════════════════\n');
      
      _error = 'Failed to create delivery: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Complete a delivery with rating
  Future<bool> completeDelivery(String deliveryId, int rating) async {
    print('\n🏁 DEBUG: completeDelivery called');
    print('  - Delivery ID: $deliveryId');
    print('  - Rating: $rating');
    
    if (!_walletService.isConnected ) {
      _error = 'Wallet not connected. Please connect your wallet first.';
      notifyListeners();
      return false;
    }

    // Validate rating
    if (rating < 1 || rating > 5) {
      _error = 'Rating must be between 1 and 5';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('📞 DEBUG: Calling ContractService.completeDelivery...');
      final result = await _contractService.completeDelivery(deliveryId, rating);
      print('✅ DEBUG: completeDelivery successful');
      print('  - Transaction hash: ${result.transaction.txHash}');
      print('  - Transaction latency: ${result.transaction.latencySeconds.toStringAsFixed(2)}s');
      
      // Store transaction hash
      _lastTransactionHash = result.transaction.txHash;
      
      // Update local delivery status
      final index = _deliveries.indexWhere((d) => d.id == deliveryId);
      if (index != -1) {
        _deliveries[index] = _deliveries[index].copyWith(
          status: DeliveryStatus.completed,
          rating: rating,
          completedAt: DateTime.now(),
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on GasEstimationException catch (e) {
      print('❌ DEBUG: completeDelivery was not sent: $e');
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('❌ DEBUG: completeDelivery failed: $e');
      _error = 'Failed to complete delivery: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Cancel a delivery with reason
  Future<bool> cancelDelivery(String deliveryId, String reason) async {
    print('\n🚫 DEBUG: cancelDelivery called');
    print('  - Delivery ID: $deliveryId');
    print('  - Reason: $reason');
    
    if (!_walletService.isConnected ) {
      _error = 'Wallet not connected. Please connect your wallet first.';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('📞 DEBUG: Calling ContractService.cancelDelivery...');
      final result = await _contractService.cancelDelivery(deliveryId, reason);
      print('✅ DEBUG: cancelDelivery successful');
      print('  - Transaction hash: ${result.transaction.txHash}');
      print('  - Transaction latency: ${result.transaction.latencySeconds.toStringAsFixed(2)}s');
      
      // Store transaction hash
      _lastTransactionHash = result.transaction.txHash;
      
      // Update local delivery status
      final index = _deliveries.indexWhere((d) => d.id == deliveryId);
      if (index != -1) {
        _deliveries[index] = _deliveries[index].copyWith(
          status: DeliveryStatus.cancelled,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ DEBUG: cancelDelivery failed: $e');
      _error = 'Failed to cancel delivery: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Fetch available deliveries for drivers
  Future<void> fetchAvailableDeliveries() async {
    print('🔍 DEBUG: fetchAvailableDeliveries called - VERSION 2.0');
    print('  - Wallet connected: ${_walletService.isConnected}');
    print('  - Wallet address: ${_walletService.walletAddress}');
    
    if (!_walletService.isConnected) {
      print('❌ DEBUG: Wallet not connected, aborting fetch');
      _error = 'Wallet not connected';
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      print('📞 DEBUG: Fetching available deliveries...');

      // Try to fetch from Firestore first (faster), then fallback to blockchain
      List<Map<String, dynamic>> deliveryDataList = [];
      
      try {
        // Get all deliveries from Firestore and filter for pending ones
        print('📡 DEBUG: Calling AnalyticsService.getAllDeliveries()...');
        
        // Add timeout to prevent hanging
        deliveryDataList = await AnalyticsService.getAllDeliveries().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('⏰ DEBUG: Firestore call timed out after 10 seconds');
            return <Map<String, dynamic>>[];
          },
        );
        
        print('📊 Fetched ${deliveryDataList.length} total deliveries from Firestore');
        
        // Filter for available deliveries (created status - available for drivers)
        deliveryDataList = deliveryDataList.where((delivery) {
          return delivery['status'] == 'inprogress' || delivery['status'] == 'created';
        }).toList();
        
        print('📋 Found ${deliveryDataList.length} available deliveries for drivers');
      } catch (e) {
        print('⚠️ Firestore fetch failed: $e');
        print('🔄 DEBUG: Continuing with empty list...');
        // Continue with empty list - no error, just no data
      }

      final deliveries = <Delivery>[];

      for (final deliveryData in deliveryDataList) {
        try {
          deliveries.add(Delivery.fromJson(deliveryData));
        } catch (e) {
          print('⚠️ Failed to parse delivery: $e');
          // Skip invalid deliveries
        }
      }

      _deliveries = deliveries;
      _isLoading = false;
      notifyListeners();
      
      print('✅ DEBUG: fetchAvailableDeliveries completed successfully');
      print('  - Found ${deliveries.length} available deliveries');
      print('  - Loading state set to false');
      print('  - _isLoading = $_isLoading');
      print('  - notifyListeners() called');
    } catch (e) {
      print('❌ DEBUG: fetchAvailableDeliveries failed: $e');
      _error = 'Failed to fetch available deliveries: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Accept a delivery (driver action)
  // Note: This is a placeholder - the actual smart contract doesn't have accept/pickup methods
  // The delivery goes directly from created -> inProgress -> completed
  Future<bool> acceptDelivery(String deliveryId) async {
    print('\n✅ DEBUG: acceptDelivery called (placeholder)');
    print('  - Delivery ID: $deliveryId');
    print('  - Note: This is a placeholder - smart contract doesn\'t have accept method');
    
    if (!_walletService.isConnected) {
      _error = 'Wallet not connected. Please connect your wallet first.';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Simulate acceptance by updating status to inProgress
      final index = _deliveries.indexWhere((d) => d.id == deliveryId);
      if (index != -1) {
        _deliveries[index] = _deliveries[index].copyWith(
          status: DeliveryStatus.inProgress,
        );
      }

      _isLoading = false;
      notifyListeners();
      print('✅ DEBUG: acceptDelivery completed (placeholder)');
      return true;
    } catch (e) {
      print('❌ DEBUG: acceptDelivery failed: $e');
      _error = 'Failed to accept delivery: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Pickup a delivery (driver action)
  // Note: This is a placeholder - the actual smart contract doesn't have pickup method
  Future<bool> pickupDelivery(String deliveryId) async {
    print('\n📦 DEBUG: pickupDelivery called (placeholder)');
    print('  - Delivery ID: $deliveryId');
    print('  - Note: This is a placeholder - smart contract doesn\'t have pickup method');
    
    if (!_walletService.isConnected) {
      _error = 'Wallet not connected. Please connect your wallet first.';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Simulate pickup by keeping status as inProgress
      // In the real implementation, this would be part of the completion process
      final index = _deliveries.indexWhere((d) => d.id == deliveryId);
      if (index != -1) {
        // Keep status as inProgress - pickup is just a UI state
        _deliveries[index] = _deliveries[index].copyWith(
          status: DeliveryStatus.inProgress,
        );
      }

      _isLoading = false;
      notifyListeners();
      print('✅ DEBUG: pickupDelivery completed (placeholder)');
      return true;
    } catch (e) {
      print('❌ DEBUG: pickupDelivery failed: $e');
      _error = 'Failed to pickup delivery: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Clear any error messages
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _walletService.removeListener(_onWalletChanged);
    _contractService.dispose();
    super.dispose();
  }
}
