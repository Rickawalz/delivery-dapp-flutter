import 'package:flutter_test/flutter_test.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:delivery_dapp/services/blockchain/wallet_service.dart';

// Generate mocks
@GenerateMocks([Web3Client, Credentials])
import 'wallet_service_test.mocks.dart';

void main() {
  late WalletService walletService;
  late MockWeb3Client mockWeb3Client;
  late MockCredentials mockCredentials;
  
  setUp(() {
    mockWeb3Client = MockWeb3Client();
    mockCredentials = MockCredentials();
    
    // Create a real WalletService instance but with mocked dependencies
    walletService = WalletService();
    // Replace the real client with our mock
    walletService._client = mockWeb3Client;
  });
  
  group('WalletService Tests', () {
    const String testPrivateKey = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    const String testAddress = '0x1234567890123456789012345678901234567890';
    
    test('connect should initialize credentials and address', () async {
      // Setup
      when(mockCredentials.extractAddress()).thenAnswer((_) async => testAddress);
      
      // Execute
      await walletService.connect(testPrivateKey);
      
      // Verify
      expect(walletService._address, equals(testAddress));
      expect(walletService.isConnected, isTrue);
    });
    
    test('disconnect should reset the service state', () async {
      // Setup
      await walletService.connect(testPrivateKey);
      
      // Execute
      await walletService.disconnect();
      
      // Verify
      expect(walletService.isConnected, isFalse);
      expect(walletService.address, isNull);
      verify(mockWeb3Client.dispose()).called(1);
    });
    
    test('getAddress should return the correct address', () async {
      // Setup
      await walletService.connect(testPrivateKey);
      
      // Execute
      final address = walletService.address;
      
      // Verify
      expect(address, equals(testAddress));
    });
    
    test('isConnected should return the correct connection state', () async {
      // Initial state
      expect(walletService.isConnected, isFalse);
      
      // After connecting
      await walletService.connect(testPrivateKey);
      expect(walletService.isConnected, isTrue);
      
      // After disconnecting
      await walletService.disconnect();
      expect(walletService.isConnected, isFalse);
    });
  });
} 