import 'package:web3dart/web3dart.dart';

/// Result of a blockchain transaction
class TransactionResult {
  final String txHash;
  final TransactionReceipt receipt;
  final DateTime submittedAt;
  final DateTime minedAt;
  
  TransactionResult({
    required this.txHash,
    required this.receipt,
    required this.submittedAt,
    required this.minedAt,
  });
  
  /// Calculate transaction latency in seconds
  double get latencySeconds {
    return minedAt.difference(submittedAt).inMilliseconds / 1000.0;
  }
  
  /// Get gas cost in wei
  BigInt get gasCostWei {
    return receipt.gasUsed! * receipt.effectiveGasPrice!.getInWei;
  }
  
  /// Check if transaction was successful
  bool get isSuccessful {
    return receipt.status == true;
  }
}

/// Result of creating a delivery, including transaction details
class DeliveryCreationResult {
  final String deliveryId;
  final TransactionResult transaction;
  
  DeliveryCreationResult({
    required this.deliveryId,
    required this.transaction,
  });
}

/// Result of completing a delivery
class DeliveryCompletionResult {
  final String deliveryId;
  final TransactionResult transaction;
  
  DeliveryCompletionResult({
    required this.deliveryId,
    required this.transaction,
  });
}

/// Result of cancelling a delivery
class DeliveryCancellationResult {
  final String deliveryId;
  final TransactionResult transaction;
  
  DeliveryCancellationResult({
    required this.deliveryId,
    required this.transaction,
  });
}

