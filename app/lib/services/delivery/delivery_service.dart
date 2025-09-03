import 'package:flutter/foundation.dart';
import '../../models/delivery.dart';
import '../blockchain/wallet_service.dart';
import '../blockchain/contract_service.dart';

class DeliveryService extends ChangeNotifier {
  final WalletService _walletService;
  final ContractService _contractService;
  List<Delivery> _deliveries = [];
  bool _isLoading = false;
  String? _error;

  DeliveryService(this._walletService) : _contractService = ContractService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _contractService.initialize();
    } catch (e) {
      _error = 'Failed to initialize contract service: ${e.toString()}';
      notifyListeners();
    }
  }

  List<Delivery> get deliveries => _deliveries;
  bool get isLoading => _isLoading;
  String? get error => _error;

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

      final deliveryIds = await _contractService.getCustomerDeliveries(_walletService.walletAddress!);
      final deliveries = <Delivery>[];

      for (final deliveryData in deliveryIds) {
        deliveries.add(Delivery(
          id: deliveryData['id'],
          senderAddress: deliveryData['customer'],
          receiverAddress: deliveryData['courier'],
          description: deliveryData['description'],
          value: double.parse(deliveryData['price'].toString()) / 1e18, // Convert from wei to ETH
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            int.parse(deliveryData['createdAt'].toString()) * 1000,
          ),
          status: _parseDeliveryStatus(deliveryData['status']),
          courierAddress: deliveryData['courier'],
        ));
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

  // Create a new delivery
  Future<Delivery?> createDelivery({
    required String receiverAddress,
    required String description,
    required double value,
  }) async {
    if (!_walletService.isConnected) {
      _error = 'Wallet not connected';
      notifyListeners();
      return null;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // TODO: Get pickup and delivery locations from user input
      const pickupLocation = 'Pickup Location';
      const deliveryLocation = 'Delivery Location';
      
      // Convert ETH to wei (1 ETH = 10^18 wei)
      final priceInWei = BigInt.from(value * 1e18);
      
      // Set deadline to 24 hours from now
      final deadline = BigInt.from(
        DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
      );

      final deliveryId = await _contractService.createDelivery(
        pickupAddress: pickupLocation,
        deliveryAddress: deliveryLocation,
        price: priceInWei,
        description: description,
      );

      final deliveryData = await _contractService.getDelivery(deliveryId);
      final delivery = Delivery(
        id: deliveryId,
        senderAddress: deliveryData['sender'],
        receiverAddress: deliveryData['receiver'],
        description: description,
        value: value,
        createdAt: DateTime.now(),
        status: DeliveryStatus.pending,
      );

      _deliveries.add(delivery);
      _isLoading = false;
      notifyListeners();
      return delivery;
    } catch (e) {
      _error = 'Failed to create delivery: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Accept a delivery (for couriers)
  Future<bool> acceptDelivery(String deliveryId) async {
    if (!_walletService.isConnected) {
      _error = 'Wallet not connected';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _contractService.acceptDelivery(deliveryId);
      
      // Update local delivery status
      final index = _deliveries.indexWhere((d) => d.id == deliveryId);
      if (index != -1) {
        _deliveries[index] = _deliveries[index].copyWith(
          status: DeliveryStatus.accepted,
          courierAddress: _walletService.walletAddress,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to accept delivery: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update delivery status
  Future<bool> updateDeliveryStatus(String deliveryId, DeliveryStatus newStatus) async {
    if (!_walletService.isConnected) {
      _error = 'Wallet not connected';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      switch (newStatus) {
        case DeliveryStatus.delivered:
          await _contractService.completeDelivery(deliveryId);
          break;
        case DeliveryStatus.cancelled:
          await _contractService.cancelDelivery(deliveryId);
          break;
        default:
          throw Exception('Invalid status update');
      }

      // Update local delivery status
      final index = _deliveries.indexWhere((d) => d.id == deliveryId);
      if (index != -1) {
        _deliveries[index] = _deliveries[index].copyWith(status: newStatus);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update delivery status: ${e.toString()}';
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

  DeliveryStatus _parseDeliveryStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return DeliveryStatus.pending;
      case 'inprogress':
        return DeliveryStatus.accepted;
      case 'completed':
        return DeliveryStatus.delivered;
      case 'cancelled':
        return DeliveryStatus.cancelled;
      default:
        return DeliveryStatus.pending;
    }
  }

  @override
  void dispose() {
    _contractService.dispose();
    super.dispose();
  }
} 