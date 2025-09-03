import 'package:flutter_test/flutter_test.dart';
import 'package:web3dart/web3dart.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:delivery_dapp/services/delivery/delivery_service.dart';
import 'package:delivery_dapp/services/blockchain/wallet_service.dart';
import 'package:delivery_dapp/services/blockchain/contract_service.dart';
import 'package:delivery_dapp/models/delivery.dart';

// Generate mocks
@GenerateMocks([WalletService, ContractService])
import 'delivery_service_test.mocks.dart';

void main() {
  late DeliveryService deliveryService;
  late MockWalletService mockWalletService;
  late MockContractService mockContractService;
  
  setUp(() {
    mockWalletService = MockWalletService();
    mockContractService = MockContractService();
    
    // Setup wallet service mock
    when(mockWalletService.isConnected).thenReturn(true);
    when(mockWalletService.walletAddress).thenReturn('0x1234567890123456789012345678901234567890');
    
    // Create DeliveryService with mocked dependencies
    deliveryService = DeliveryService(mockWalletService);
  });
  
  group('DeliveryService Blockchain Tests', () {
    const String testAddress = '0x1234567890123456789012345678901234567890';
    const String receiverAddress = '0x0987654321098765432109876543210987654321';
    const String deliveryId = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    
    test('createDelivery should interact with blockchain', () async {
      // Setup
      const description = 'Test Delivery';
      const value = 1.0; // 1 ETH
      final priceInWei = BigInt.from(value * 1e18);
      
      when(mockContractService.createDelivery(
        pickupAddress: anyNamed('pickupAddress'),
        deliveryAddress: anyNamed('deliveryAddress'),
        price: anyNamed('price'),
        description: anyNamed('description'),
      )).thenAnswer((_) async => deliveryId);
      
      when(mockContractService.getDelivery(deliveryId)).thenAnswer((_) async => {
        'sender': testAddress,
        'receiver': receiverAddress,
        'description': description,
        'price': priceInWei.toString(),
        'status': 'pending',
      });
      
      // Execute
      final result = await deliveryService.createDelivery(
        receiverAddress: receiverAddress,
        description: description,
        value: value,
      );
      
      // Verify
      expect(result, isNotNull);
      expect(result!.id, equals(deliveryId));
      expect(result.senderAddress, equals(testAddress));
      expect(result.receiverAddress, equals(receiverAddress));
      expect(result.description, equals(description));
      expect(result.value, equals(value));
      expect(result.status, equals(DeliveryStatus.pending));
      
      verify(mockContractService.createDelivery(
        pickupAddress: anyNamed('pickupAddress'),
        deliveryAddress: anyNamed('deliveryAddress'),
        price: anyNamed('price'),
        description: anyNamed('description'),
      )).called(1);
    });
    
    test('updateDeliveryStatus should complete delivery on blockchain', () async {
      // Setup
      when(mockContractService.completeDelivery(deliveryId))
          .thenAnswer((_) async => {});
      
      // Execute
      final result = await deliveryService.updateDeliveryStatus(
        deliveryId,
        DeliveryStatus.delivered,
      );
      
      // Verify
      expect(result, isTrue);
      verify(mockContractService.completeDelivery(deliveryId)).called(1);
    });
    
    test('fetchUserDeliveries should get deliveries from blockchain', () async {
      // Setup
      final deliveryData = {
        'id': deliveryId,
        'customer': testAddress,
        'courier': receiverAddress,
        'description': 'Test Delivery',
        'price': (1.0 * 1e18).toString(),
        'createdAt': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
        'status': 'pending',
      };
      
      when(mockContractService.getCustomerDeliveries(testAddress))
          .thenAnswer((_) async => [deliveryData]);
      
      // Execute
      await deliveryService.fetchUserDeliveries();
      
      // Verify
      expect(deliveryService.deliveries.length, equals(1));
      expect(deliveryService.deliveries.first.id, equals(deliveryId));
      expect(deliveryService.deliveries.first.senderAddress, equals(testAddress));
      expect(deliveryService.deliveries.first.receiverAddress, equals(receiverAddress));
      expect(deliveryService.deliveries.first.status, equals(DeliveryStatus.pending));
      
      verify(mockContractService.getCustomerDeliveries(testAddress)).called(1);
    });
  });
} 