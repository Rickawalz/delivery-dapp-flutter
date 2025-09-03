import 'package:flutter_test/flutter_test.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:delivery_dapp/services/blockchain/blockchain_service.dart';
import 'package:delivery_dapp/constants/contract_addresses.dart';
import 'package:delivery_dapp/constants/abis.dart';

// Generate mocks
@GenerateMocks([Web3Client, Credentials])
import 'delivery_system_test.mocks.dart';

void main() {
  late BlockchainService blockchainService;
  late MockWeb3Client mockWeb3Client;
  late MockCredentials mockCredentials;
  
  setUp(() {
    mockWeb3Client = MockWeb3Client();
    mockCredentials = MockCredentials();
    
    // Create BlockchainService with mocked client
    blockchainService = BlockchainService(client: mockWeb3Client);
  });
  
  group('DeliverySystem Tests', () {
    const String testPrivateKey = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    const String testAddress = '0x1234567890123456789012345678901234567890';
    const String receiverAddress = '0x0987654321098765432109876543210987654321';
    
    test('createDelivery should call the delivery system contract', () async {
      // Setup
      final amount = BigInt.from(100);
      
      when(mockWeb3Client.sendTransaction(
        any,
        any,
      )).thenAnswer((_) async => '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
      
      // Execute
      await blockchainService.createDelivery(receiverAddress, amount);
      
      // Verify
      verify(mockWeb3Client.sendTransaction(
        any,
        argThat(
          predicate((Transaction tx) => 
            tx.to == EthereumAddress.fromHex(ContractAddresses.deliverySystem) &&
            tx.data != null
          ),
        ),
      )).called(1);
    });
    
    test('completeDelivery should call the delivery system contract', () async {
      // Setup
      const deliveryId = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      
      when(mockWeb3Client.sendTransaction(
        any,
        any,
      )).thenAnswer((_) async => '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
      
      // Execute
      await blockchainService.completeDelivery(deliveryId);
      
      // Verify
      verify(mockWeb3Client.sendTransaction(
        any,
        argThat(
          predicate((Transaction tx) => 
            tx.to == EthereumAddress.fromHex(ContractAddresses.deliverySystem) &&
            tx.data != null
          ),
        ),
      )).called(1);
    });
    
    test('getDelivery should return the correct delivery info', () async {
      // Setup
      const deliveryId = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      final expectedSender = testAddress;
      final expectedReceiver = receiverAddress;
      final expectedAmount = BigInt.from(100);
      final expectedCompleted = false;
      final expectedTimestamp = BigInt.from(1234567890);
      
      when(mockWeb3Client.call(
        contract: any,
        function: any,
        params: any,
      )).thenAnswer((_) async => [
        EthereumAddress.fromHex(expectedSender),
        EthereumAddress.fromHex(expectedReceiver),
        expectedAmount,
        expectedCompleted,
        expectedTimestamp
      ]);
      
      // Execute
      final result = await blockchainService.getDelivery(deliveryId);
      
      // Verify
      expect(result.sender, equals(expectedSender));
      expect(result.receiver, equals(expectedReceiver));
      expect(result.amount, equals(expectedAmount));
      expect(result.completed, equals(expectedCompleted));
      expect(result.timestamp, equals(expectedTimestamp));
      
      verify(mockWeb3Client.call(
        contract: any,
        function: any,
        params: [EthereumAddress.fromHex(deliveryId)],
      )).called(1);
    });
  });
} 