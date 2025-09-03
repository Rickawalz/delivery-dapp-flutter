import 'package:flutter_test/flutter_test.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:delivery_dapp/services/blockchain/blockchain_service.dart';
import 'package:delivery_dapp/constants/contract_addresses.dart';
import 'package:delivery_dapp/constants/contract_abis.dart';

// Generate mocks
@GenerateMocks([Web3Client, Credentials])
import 'blockchain_service_test.mocks.dart';

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
  
  group('BlockchainService Tests', () {
    const String testPrivateKey = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    final testAddress = EthereumAddress.fromHex('0x1234567890123456789012345678901234567890');
    
    test('connect should initialize credentials and address', () async {
      // Setup
      when(mockCredentials.extractAddress()).thenAnswer((_) async => testAddress);
      
      // Execute
      await blockchainService.connect(testPrivateKey);
      
      // Verify
      expect(blockchainService.address, equals(testAddress.hex));
      expect(blockchainService.credentials, isA<EthPrivateKey>());
      expect(blockchainService.client, equals(mockWeb3Client));
    });
    
    test('stake should call the staking contract', () async {
      // Setup
      final amount = BigInt.from(100);
      
      when(mockWeb3Client.sendTransaction(
        any,
        any,
      )).thenAnswer((_) async => '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
      
      // Execute
      await blockchainService.stake(amount);
      
      // Verify
      verify(mockWeb3Client.sendTransaction(
        any,
        argThat(
          predicate((Transaction tx) => 
            tx.to == EthereumAddress.fromHex(ContractAddresses.stakingManager) &&
            tx.data != null
          ),
        ),
      )).called(1);
    });
    
    test('unstake should call the staking contract', () async {
      // Setup
      when(mockWeb3Client.sendTransaction(
        any,
        any,
      )).thenAnswer((_) async => '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
      
      // Execute
      await blockchainService.unstake();
      
      // Verify
      verify(mockWeb3Client.sendTransaction(
        any,
        argThat(
          predicate((Transaction tx) => 
            tx.to == EthereumAddress.fromHex(ContractAddresses.stakingManager) &&
            tx.data != null
          ),
        ),
      )).called(1);
    });
    
    test('getStakedAmount should return the correct amount', () async {
      // Setup
      final expectedAmount = BigInt.from(100);
      final account = EthereumAddress.fromHex('0x1234567890123456789012345678901234567890');
      
      when(mockWeb3Client.call(
        contract: any,
        function: any,
        params: any,
      )).thenAnswer((_) async => [expectedAmount]);
      
      // Execute
      final result = await blockchainService.getStakedAmount(account.hex);
      
      // Verify
      expect(result, equals(expectedAmount));
      verify(mockWeb3Client.call(
        contract: any,
        function: any,
        params: any,
      )).called(1);
    });
    
    test('submitRating should call the rating contract', () async {
      // Setup
      const user = '0x1234567890123456789012345678901234567890';
      const rating = 5;
      
      when(mockWeb3Client.sendTransaction(
        any,
        any,
      )).thenAnswer((_) async => '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
      
      // Execute
      await blockchainService.submitRating(user, rating);
      
      // Verify
      verify(mockWeb3Client.sendTransaction(
        any,
        argThat(
          predicate((Transaction tx) => 
            tx.to == EthereumAddress.fromHex(ContractAddresses.ratingSystem) &&
            tx.data != null
          ),
        ),
      )).called(1);
    });
    
    test('getRating should return the correct rating', () async {
      // Setup
      const user = '0x1234567890123456789012345678901234567890';
      const expectedRating = 5;
      
      when(mockWeb3Client.call(
        contract: any,
        function: any,
        params: any,
      )).thenAnswer((_) async => [BigInt.from(expectedRating)]);
      
      // Execute
      final result = await blockchainService.getRating(user);
      
      // Verify
      expect(result, equals(expectedRating));
      verify(mockWeb3Client.call(
        contract: any,
        function: any,
        params: [EthereumAddress.fromHex(user)],
      )).called(1);
    });
    
    test('transfer should call the token contract', () async {
      // Setup
      const to = '0x1234567890123456789012345678901234567890';
      final amount = BigInt.from(100);
      
      when(mockWeb3Client.sendTransaction(
        any,
        any,
      )).thenAnswer((_) async => '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
      
      // Execute
      await blockchainService.transfer(to, amount);
      
      // Verify
      verify(mockWeb3Client.sendTransaction(
        any,
        argThat(
          predicate((Transaction tx) => 
            tx.to == EthereumAddress.fromHex(ContractAddresses.deliveryToken) &&
            tx.data != null
          ),
        ),
      )).called(1);
    });
    
    test('getBalance should return the correct balance', () async {
      // Setup
      const account = '0x1234567890123456789012345678901234567890';
      final expectedBalance = BigInt.from(1000);
      
      when(mockWeb3Client.call(
        contract: any,
        function: any,
        params: any,
      )).thenAnswer((_) async => [expectedBalance]);
      
      // Execute
      final result = await blockchainService.getBalance(account);
      
      // Verify
      expect(result, equals(expectedBalance));
      verify(mockWeb3Client.call(
        contract: any,
        function: any,
        params: [EthereumAddress.fromHex(account)],
      )).called(1);
    });
  });
} 