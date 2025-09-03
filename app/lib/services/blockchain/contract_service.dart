import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ContractService {
  Web3Client _client;
  late DeployedContract _contract;
  late String _contractAddress;
  late String _rpcUrl;
  late Credentials _credentials;
  bool _isInitialized = false;

  ContractService() : _client = Web3Client('http://localhost:8547', Client());

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load RPC URL from environment variables
    _rpcUrl = dotenv.env['RPC_URL'] ?? 'http://localhost:8547';
    
    // Load contract configuration
    await _loadContractConfig();
    
    // Update Web3 client with correct RPC URL if different
    if (_rpcUrl != 'http://localhost:8547') {
      _client.dispose();
      _client = Web3Client(_rpcUrl, Client());
    }
    
    // Load contract ABI
    final abi = await _loadContractAbi();
    
    // Initialize contract
    _contract = DeployedContract(
      ContractAbi.fromJson(json.encode(abi), 'DeliverySystem'),
      EthereumAddress.fromHex(_contractAddress),
    );

    // Initialize credentials (for testing, using a private key)
    _credentials = EthPrivateKey.fromHex('0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80');
    
    _isInitialized = true;
  }

  Future<void> _loadContractConfig() async {
    try {
      final configString = await rootBundle.loadString('assets/config/contracts.json');
      final config = json.decode(configString);
      _contractAddress = config['DeliverySystem']['address'];
    } catch (e) {
      throw Exception('Failed to load contract configuration: $e');
    }
  }

  Future<Map<String, dynamic>> _loadContractAbi() async {
    try {
      final abiString = await rootBundle.loadString('assets/abi/DeliverySystem.json');
      return json.decode(abiString);
    } catch (e) {
      throw Exception('Failed to load contract ABI: $e');
    }
  }

  Future<String> createDelivery({
    required String pickupAddress,
    required String deliveryAddress,
    required BigInt price,
    required String description,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final result = await _client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _contract,
          function: _contract.function('createDelivery'),
          parameters: [
            pickupAddress,
            deliveryAddress,
            price,
            description,
          ],
        ),
      );

      return result;
    } catch (e) {
      throw Exception('Failed to create delivery: $e');
    }
  }

  Future<String> acceptDelivery(String deliveryId) async {
    if (!_isInitialized) await initialize();

    try {
      final result = await _client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _contract,
          function: _contract.function('acceptDelivery'),
          parameters: [deliveryId],
        ),
      );

      return result;
    } catch (e) {
      throw Exception('Failed to accept delivery: $e');
    }
  }

  Future<String> completeDelivery(String deliveryId) async {
    if (!_isInitialized) await initialize();

    try {
      final result = await _client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _contract,
          function: _contract.function('completeDelivery'),
          parameters: [deliveryId],
        ),
      );

      return result;
    } catch (e) {
      throw Exception('Failed to complete delivery: $e');
    }
  }

  Future<String> cancelDelivery(String deliveryId) async {
    if (!_isInitialized) await initialize();

    try {
      final result = await _client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _contract,
          function: _contract.function('cancelDelivery'),
          parameters: [deliveryId],
        ),
      );

      return result;
    } catch (e) {
      throw Exception('Failed to cancel delivery: $e');
    }
  }

  Future<Map<String, dynamic>> getDelivery(String deliveryId) async {
    if (!_isInitialized) await initialize();

    try {
      final result = await _client.call(
        contract: _contract,
        function: _contract.function('getDelivery'),
        params: [deliveryId],
      );

      return {
        'id': result[0],
        'customer': result[1],
        'courier': result[2],
        'pickupAddress': result[3],
        'deliveryAddress': result[4],
        'price': result[5],
        'description': result[6],
        'status': result[7],
        'createdAt': result[8],
        'completedAt': result[9],
      };
    } catch (e) {
      throw Exception('Failed to get delivery: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCustomerDeliveries(String customerAddress) async {
    if (!_isInitialized) await initialize();

    try {
      final result = await _client.call(
        contract: _contract,
        function: _contract.function('getCustomerDeliveries'),
        params: [customerAddress],
      );

      return List<Map<String, dynamic>>.from(
        result[0].map((delivery) => {
          'id': delivery[0],
          'customer': delivery[1],
          'courier': delivery[2],
          'pickupAddress': delivery[3],
          'deliveryAddress': delivery[4],
          'price': delivery[5],
          'description': delivery[6],
          'status': delivery[7],
          'createdAt': delivery[8],
          'completedAt': delivery[9],
        }),
      );
    } catch (e) {
      throw Exception('Failed to get customer deliveries: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCourierDeliveries(String courierAddress) async {
    if (!_isInitialized) await initialize();

    try {
      final result = await _client.call(
        contract: _contract,
        function: _contract.function('getCourierDeliveries'),
        params: [courierAddress],
      );

      return List<Map<String, dynamic>>.from(
        result[0].map((delivery) => {
          'id': delivery[0],
          'customer': delivery[1],
          'courier': delivery[2],
          'pickupAddress': delivery[3],
          'deliveryAddress': delivery[4],
          'price': delivery[5],
          'description': delivery[6],
          'status': delivery[7],
          'createdAt': delivery[8],
          'completedAt': delivery[9],
        }),
      );
    } catch (e) {
      throw Exception('Failed to get courier deliveries: $e');
    }
  }

  void dispose() {
    _client.dispose();
  }
} 