import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'dart:js_util';
import 'package:crypto/crypto.dart';
import '../blockchain/metamask_js.dart';
import '../blockchain/transaction_tracker.dart';
import '../blockchain/walletconnect_service.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import '../../utils/allowed_networks.dart';

import '../../models/transaction_result.dart';
import '../../constants/environment.dart';

// Committed default for the Android emulator. In development, deploy-thesis.ts
// writes assets/config/dev_host.json and loadDevHardhatHost() prefers that host.
const String HARDHAT_RPC_IP = '10.0.2.2';
String devHardhatHost = HARDHAT_RPC_IP;

Future<void> loadDevHardhatHost() async {
  if (!Environment.isDevelopment) {
    return;
  }
  try {
    final raw = await rootBundle.loadString('assets/config/dev_host.json');
    final decoded = json.decode(raw);
    final host = decoded is Map ? decoded['host'] : null;
    if (host is String && host.isNotEmpty) {
      devHardhatHost = host;
    }
  } catch (_) {
    devHardhatHost = HARDHAT_RPC_IP;
  }
}

class GasEstimationException implements Exception {
  GasEstimationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ContractService extends ChangeNotifier {
  Web3Client _client;
  late DeployedContract _contract;
  late String _contractAddress;
  late String _rpcUrl;
  Credentials? _credentials;
  String? _walletAddress;
  bool _isInitialized = false;
  Map<String, String> _contractAddresses = {};
  TransactionTracker? _transactionTracker;

  Map<String, String> get contractAddresses => Map.unmodifiable(_contractAddresses);
  WalletConnectService? _walletConnectService;
  
  // Expose client for NetworkInfoService
  Web3Client get client => _client;
  
  /// Set WalletConnect service (for dependency injection)
  void setWalletConnectService(WalletConnectService walletConnectService) {
    _walletConnectService = walletConnectService;
  }
  
  /// Detect which wallet provider is available and connected
  Future<String> _detectWalletProvider() async {
    print('🔍 DEBUG: Detecting wallet provider...');
    
    // Check if WalletConnect is available and connected
    if (_walletConnectService != null && _walletConnectService!.isConnected) {
      print('  ✅ WalletConnect detected and connected');
      return 'walletconnect';
    }
    
    // Check if MetaMask is available
    final eth = ethereum;
    if (eth != null) {
      try {
        print('  🔍 Checking MetaMask availability...');
        // Try to get accounts from MetaMask
        final accounts = await promiseToFuture<List<dynamic>>(
          eth.request(RequestArguments(method: 'eth_accounts'))
        );
        if (accounts.isNotEmpty) {
          print('  ✅ MetaMask detected with accounts: ${accounts.length}');
          return 'metamask';
        }
      } catch (e) {
        print('  ❌ MetaMask check failed: $e');
      }
    }
    
    print('  ❌ No wallet provider available');
    throw Exception('No wallet provider available. Please connect MetaMask or use WalletConnect.');
  }
  
  /// Send transaction via WalletConnect
  Future<String> _sendTransactionViaWalletConnect(Map<String, dynamic> transactionData) async {
    print('📱 DEBUG: Sending transaction via WalletConnect...');
    
    if (_walletConnectService == null || !_walletConnectService!.isConnected) {
      throw Exception('WalletConnect not available or not connected');
    }

    final from = _walletConnectService!.walletAddress;
    if (from == null || from.isEmpty) {
      throw GasEstimationException('Cannot estimate gas because the wallet address is missing.');
    }
    final gas = await _gasLimitHex(transactionData, from);
    
    try {
      final chainId = _walletConnectService!.chainId!;
      // Add timeout to prevent hanging
      final result = await Future.any([
        Future(() async {
          // Check if session is ready
          print('  📋 Session details:');
          print('    - Topic: ${_walletConnectService!.currentSession!.topic}');
          print('    - Wallet address: $from');
          print('    - Chain ID: $chainId');
          
          // The wallet fills EIP-1559 fees. Only the estimated gas limit is set here.
          final result = await _walletConnectService!.web3App!.request(
            topic: _walletConnectService!.currentSession!.topic,
            chainId: 'eip155:$chainId',
            request: SessionRequestParams(
              method: 'eth_sendTransaction',
              params: [
                {
                  'from': from,
                  'to': transactionData['to'],
                  'data': transactionData['data'],
                  'value': transactionData['value'],
                  'gas': gas,
                }
              ],
            ),
          );
          
          return result.toString();
        }),
        Future.delayed(Duration(seconds: 60), () => throw Exception('WalletConnect transaction timeout after 60 seconds'))
      ]);
      
      print('✅ WalletConnect transaction successful');
      return result.toString();
    } on GasEstimationException {
      rethrow;
    } catch (e) {
      print('❌ WalletConnect transaction failed: $e');
      throw Exception('WalletConnect transaction failed: $e');
    }
  }

  /// Estimate gas for this exact call, then add 20 percent.
  /// A failed estimate means the call would revert, so nothing is sent.
  Future<String> _gasLimitHex(Map<String, dynamic> transactionData, String from) async {
    final to = transactionData['to'];
    final data = transactionData['data'];
    if (to is! String || to.isEmpty || data is! String || data.isEmpty) {
      throw GasEstimationException(
        'Cannot estimate gas because the transaction is missing its destination or calldata.',
      );
    }
    final valueRaw = transactionData['value'];
    final valueHex = valueRaw is String && valueRaw.isNotEmpty ? valueRaw : '0x0';

    final BigInt estimated;
    try {
      estimated = await _client.estimateGas(
        sender: EthereumAddress.fromHex(from),
        to: EthereumAddress.fromHex(to),
        data: _decodeHex(data),
        value: EtherAmount.inWei(_decodeHexInt(valueHex)),
      );
    } catch (e) {
      throw GasEstimationException(
        'This transaction would likely revert, so it was not sent. ${_revertReason(e)}',
      );
    }

    final withBuffer = estimated * BigInt.from(120) ~/ BigInt.from(100);
    if (Environment.isDevelopment) {
      print('Estimated gas: $estimated; sending $withBuffer after a 20% buffer');
    }
    return '0x${withBuffer.toRadixString(16)}';
  }

  String _revertReason(Object error) {
    final text = error.toString();
    final match = RegExp(
      r'execution reverted:?\s*([^"\n]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) {
      return match.group(1)!.trim();
    }
    return text;
  }

  Uint8List _decodeHex(String hexString) {
    var hex = hexString.startsWith('0x') || hexString.startsWith('0X')
        ? hexString.substring(2)
        : hexString;
    if (hex.isEmpty) return Uint8List(0);
    if (hex.length.isOdd) hex = '0$hex';
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  BigInt _decodeHexInt(String hexString) {
    final hex = hexString.startsWith('0x') || hexString.startsWith('0X')
        ? hexString.substring(2)
        : hexString;
    if (hex.isEmpty) return BigInt.zero;
    return BigInt.parse(hex, radix: 16);
  }
  
  /// Send transaction via MetaMask
  Future<String> _sendTransactionViaMetaMask(Map<String, dynamic> transactionData) async {
    print('🦊 DEBUG: Sending transaction via MetaMask...');
    
    final eth = ethereum;
    if (eth == null) {
      throw Exception('MetaMask not available');
    }

    final from = transactionData['from'] as String? ?? await _getCurrentAccount();
    if (from == null || from.isEmpty) {
      throw GasEstimationException('Cannot estimate gas because no account is connected.');
    }
    final gas = await _gasLimitHex(transactionData, from);
    
    try {
      // The wallet fills EIP-1559 fees. Only the estimated gas limit is set here.
      final completeTransaction = {
        'from': from,
        'to': transactionData['to'],
        'data': transactionData['data'],
        'value': transactionData['value'],
        'gas': gas,
      };
      
      final result = await promiseToFuture<String>(
        eth.request(RequestArguments(
          method: 'eth_sendTransaction',
          params: [completeTransaction],
        ))
      );
      
      print('✅ MetaMask transaction successful');
      return result;
    } on GasEstimationException {
      rethrow;
    } catch (e) {
      print('❌ MetaMask transaction failed: $e');
      throw Exception('MetaMask transaction failed: $e');
    }
  }
  
  /// Get current account from MetaMask
  Future<String?> _getCurrentAccount() async {
    try {
      final eth = ethereum;
      if (eth == null) return null;
      
      final accounts = await promiseToFuture<List<dynamic>>(
        eth.request(RequestArguments(method: 'eth_accounts'))
      );
      
      return accounts.isNotEmpty ? accounts.first.toString() : null;
    } catch (e) {
      print('Error getting current account: $e');
      return null;
    }
  }
  
  /// Check if current network is allowed before transactions
  Future<void> _checkNetworkAllowed() async {
    try {
      final chainId = await _client.getNetworkId();
      if (!AllowedNetworks.isAllowed(chainId)) {
        throw Exception(
          'Network not allowed. Current network: ${AllowedNetworks.nameFor(chainId)} (Chain ID: $chainId). '
          'Allowed: ${Environment.networkName} (Chain ID: ${Environment.chainId})'
        );
      }
    } catch (e) {
      throw Exception('Failed to verify network: $e');
    }
  }

  ContractService({WalletConnectService? walletConnectService}) 
      : _walletConnectService = walletConnectService,
        _client = Web3Client(
          Environment.isDevelopment 
              ? 'http://$devHardhatHost:8545'  // Development: dev_host.json or 10.0.2.2
              : Environment.productionRpc,      // Production: Sepolia
          Client(),
        );

  Future<void> initialize() async {
    print('🔍 DEBUG: ContractService.initialize() called');
    if (_isInitialized) {
      print('  ⏭️  Already initialized, skipping');
      return;
    }

    print('  - Loading RPC URL...');
    _rpcUrl = Environment.isDevelopment 
        ? 'http://$devHardhatHost:8545'  // Development: dev_host.json or 10.0.2.2
        : Environment.productionRpc;      // Production: Sepolia
    print('  - RPC URL: $_rpcUrl');
    print('  - Environment: ${Environment.isDevelopment ? "Development (Hardhat)" : "Production (Sepolia)"}');
    
    print('  - Loading contract config...');
    await _loadContractConfig();
    print('  - Contract address loaded: $_contractAddress');
    
    // Update Web3 client with correct RPC URL if different
    final expectedRpcUrl = Environment.isDevelopment 
        ? 'http://$devHardhatHost:8545' 
        : Environment.productionRpc;
    
    if (_rpcUrl != expectedRpcUrl) {
      _client.dispose();
      _client = Web3Client(_rpcUrl, Client());
    }
    
    print('  - Loading contract ABI...');
    final abi = await _loadContractAbi();
    print('  - ABI loaded, ${abi.length} entries');
    
    print('  - Creating contract instance...');
    _contract = DeployedContract(
      ContractAbi.fromJson(json.encode(abi), 'SimpleDeliverySystem'),
      EthereumAddress.fromHex(_contractAddress),
    );
    print('  - Contract instance created');

    // Credentials will be set by WalletService when user connects
    
    _isInitialized = true;
    print('✅ DEBUG: ContractService initialized successfully');
  }

  void setCredentials(Credentials credentials, String walletAddress) {
    _credentials = credentials;
    _walletAddress = walletAddress;
  }

  void setTransactionTracker(TransactionTracker tracker) {
    _transactionTracker = tracker;
  }

  /// Wait for transaction receipt with timeout (60 seconds = 30 attempts × 2s)
  Future<TransactionReceipt> _waitForTransactionReceipt(
    String txHash,
    {int maxAttempts = 30}
  ) async {
    print('⏳ Waiting for transaction receipt: $txHash');
    print('   Max wait time: ${maxAttempts * 2} seconds');
    
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 2));
      
      final receipt = await _client.getTransactionReceipt(txHash);
      if (receipt != null) {
        print('✅ Transaction mined in block ${receipt.blockNumber}');
        print('   Gas used: ${receipt.gasUsed}');
        print('   Status: ${receipt.status == true ? "Success" : "Reverted"}');
        
        if (receipt.status != true) {
          throw Exception('Transaction reverted');
        }
        
        return receipt;
      }
      
      if (i > 0 && i % 5 == 0) {
        print('   Still waiting... (${i * 2}s elapsed)');
      }
    }
    
    throw Exception('Transaction timeout after ${maxAttempts * 2} seconds. Transaction may still be pending.');
  }

  Future<void> _loadContractConfig() async {
    try {
      // Try to load localhost config first, then fallback to regular config
      String configString;
      try {
        configString = await rootBundle.loadString('assets/config/contracts.localhost.json');
      } catch (e) {
        configString = await rootBundle.loadString('assets/config/contracts.json');
      }
      
      final config = json.decode(configString);
      _storeContractAddresses(config);
      
      // Handle different config structures and contract names
      if (config.containsKey('contracts')) {
        // New format with nested contracts - try both possible names
        _contractAddress = config['contracts']['SimpleDeliverySystem'] ?? 
                         config['contracts']['DeliverySystem'];
      } else {
        // Old format with direct contract addresses - try both possible names
        _contractAddress = config['SimpleDeliverySystem'] ?? 
                          config['DeliverySystem'];
      }
      
      if (_contractAddress == null) {
        throw Exception('No valid contract address found in configuration');
      }
    } catch (e) {
      throw Exception('Failed to load contract configuration: $e');
    }
  }

  void _storeContractAddresses(dynamic config) {
    final source = config is Map && config['contracts'] is Map
        ? config['contracts'] as Map
        : config is Map
            ? config
            : <dynamic, dynamic>{};
    final next = <String, String>{};
    source.forEach((key, value) {
      if (value is String && value.startsWith('0x')) {
        next[key.toString()] = value;
      }
    });
    _contractAddresses = next;
  }

  Future<List<dynamic>> _loadContractAbi() async {
    try {
      // Load SimpleDeliverySystem ABI
      final abiString = await rootBundle.loadString('assets/abi/SimpleDeliverySystem.json');
      final abiData = json.decode(abiString);
      
      // Handle both array format and object format
      if (abiData is List) {
        return abiData;
      } else if (abiData is Map<String, dynamic> && abiData.containsKey('abi')) {
        return abiData['abi'] as List<dynamic>;
      } else {
        throw Exception('Unexpected ABI format: ${abiData.runtimeType}');
      }
    } catch (e) {
      throw Exception('Failed to load contract ABI: $e');
    }
  }

  /// Generate unique delivery ID (bytes32)
  String _generateDeliveryId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    final data = '$timestamp-$random-${_walletAddress ?? "unknown"}';
    final hash = sha256.convert(utf8.encode(data)).toString();
    return '0x$hash';
  }

  /// Convert hex string to bytes for bytes32 parameter
  Uint8List _hexToBytes(String hexString) {
    final hex = hexString.startsWith('0x') ? hexString.substring(2) : hexString;
    final bytes = Uint8List(32); // bytes32 is always 32 bytes
    final hexBytes = hex.length ~/ 2;
    for (int i = 0; i < hexBytes && i < 32; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  Future<DeliveryCreationResult> createDelivery({
    required String driverAddress,
    required int distanceMeters,
    required int fiatAmountCents,
  }) async {
    print('🔧 ContractService: Initializing...');
    if (!_isInitialized) await initialize();
    print('✅ ContractService: Initialized');

    // Check network before transaction
    await _checkNetworkAllowed();

    // Generate unique delivery ID
    final deliveryId = _generateDeliveryId();
    final deliveryIdBytes = _hexToBytes(deliveryId);

    print('\n🔍 DEBUG: Pre-transaction checks');
    print('  - Initialized: $_isInitialized');
    print('  - Contract address: $_contractAddress');
    print('  - Has credentials: ${_credentials != null}');
    print('  - Wallet address: $_walletAddress');
    print('  - Chain ID check passed');

    print('\n🔍 DEBUG: Transaction parameters');
    print('  - Delivery ID: $deliveryId');
    print('  - Driver address: $driverAddress');
    print('  - Distance meters: $distanceMeters');
    print('  - Fiat amount cents: $fiatAmountCents');
    print('  - Delivery ID bytes length: ${deliveryIdBytes.length}');

    try {
      print('\n🚀 DEBUG: Attempting to send transaction...');
      
      final submittedAt = DateTime.now();
      String txHash;
      
      // Detect which wallet provider to use
      final provider = await _detectWalletProvider();
      print('  🎯 Using wallet provider: $provider');
      
      // Prepare transaction data
      final function = _contract.function('createDelivery');
      final encodedData = function.encodeCall([
        deliveryIdBytes,
        EthereumAddress.fromHex(driverAddress),
        BigInt.from(distanceMeters),
        BigInt.from(fiatAmountCents),
      ]);
      
      // Convert Uint8List to hex string
      final hexData = '0x${encodedData.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('')}';
      
      final transactionData = {
        'to': _contractAddress,
        'data': hexData,
        'value': '0x0', // No ETH value for this transaction
        'deliveryId': '0x${deliveryIdBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('')}',
        'driverAddress': driverAddress,
        'distanceMeters': distanceMeters,
        'fiatAmountCents': fiatAmountCents,
      };
      
      // Send transaction using the detected provider
      if (provider == 'walletconnect') {
        try {
          txHash = await _sendTransactionViaWalletConnect(transactionData);
        } on GasEstimationException {
          rethrow;
        } catch (e) {
          print('⚠️ WalletConnect failed, trying MetaMask fallback...');
          // Try MetaMask as fallback
          final eth = ethereum;
          if (eth != null) {
            try {
              final accounts = await promiseToFuture<List<dynamic>>(
                eth.request(RequestArguments(method: 'eth_accounts'))
              );
              if (accounts.isNotEmpty) {
                print('🔄 Falling back to MetaMask...');
                txHash = await _sendTransactionViaMetaMask(transactionData);
              } else {
                rethrow; // Re-throw original WalletConnect error
              }
            } catch (fallbackError) {
              print('❌ MetaMask fallback also failed: $fallbackError');
              rethrow; // Re-throw original WalletConnect error
            }
          } else {
            rethrow; // Re-throw original WalletConnect error
          }
        }
      } else if (provider == 'metamask') {
        txHash = await _sendTransactionViaMetaMask(transactionData);
      } else {
        throw Exception('Unsupported wallet provider: $provider');
      }

      print('\n✅ DEBUG: Transaction submitted successfully!');
      print('  - Transaction hash: $txHash');
      print('  - Delivery ID: $deliveryId');
      
      // Track transaction if tracker is available
      if (_transactionTracker != null) {
        await _transactionTracker!.trackTransaction(
          txHash: txHash,
          action: 'createDelivery',
          providerType: _credentials != null ? 'private_key' : 'metamask',
        );
      }
      
      // Wait for transaction to be mined
      final receipt = await _waitForTransactionReceipt(txHash);
      final minedAt = DateTime.now();
      
      // Update transaction tracker with receipt
      if (_transactionTracker != null) {
        await _transactionTracker!.updateTransactionWithReceipt(
          txHash: txHash,
          receipt: receipt,
        );
      }
      
      final transactionResult = TransactionResult(
        txHash: txHash,
        receipt: receipt,
        submittedAt: submittedAt,
        minedAt: minedAt,
      );
      
      return DeliveryCreationResult(
        deliveryId: deliveryId,
        transaction: transactionResult,
      );
    } on GasEstimationException {
      rethrow;
    } catch (e, stackTrace) {
      print('\n❌ DEBUG: Transaction failed!');
      print('  - Error type: ${e.runtimeType}');
      print('  - Error message: $e');
      print('  - Stack trace: $stackTrace');
      throw Exception('Failed to create delivery: $e');
    }
  }

  Future<DeliveryCompletionResult> completeDelivery(String deliveryId, int rating) async {
    print('\n🔍 DEBUG: completeDelivery called');
    print('  - Delivery ID: $deliveryId');
    print('  - Rating: $rating');
    print('  - Has credentials: ${_credentials != null}');
    
    if (!_isInitialized) await initialize();
    
    // Check network before transaction
    await _checkNetworkAllowed();

    // Validate rating
    if (rating < 1 || rating > 5) {
      throw Exception('Rating must be between 1 and 5');
    }

    try {
      print('🚀 DEBUG: Sending completeDelivery transaction...');
      print('  The connected wallet must be the customer. During Bootstrap the founder may also complete.');

      final submittedAt = DateTime.now();
      final deliveryIdBytes = _hexToBytes(deliveryId);
      final provider = await _detectWalletProvider();
      final function = _contract.function('completeDelivery');
      final encodedData = function.encodeCall([
        deliveryIdBytes,
        BigInt.from(rating),
      ]);
      final hexData = '0x${encodedData.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('')}';
      final transactionData = {
        'to': _contractAddress,
        'data': hexData,
        'value': '0x0',
      };

      String txHash;
      if (provider == 'walletconnect') {
        try {
          txHash = await _sendTransactionViaWalletConnect(transactionData);
        } on GasEstimationException {
          rethrow;
        } catch (e) {
          final eth = ethereum;
          if (eth == null) rethrow;
          final accounts = await promiseToFuture<List<dynamic>>(
            eth.request(RequestArguments(method: 'eth_accounts'))
          );
          if (accounts.isEmpty) rethrow;
          txHash = await _sendTransactionViaMetaMask(transactionData);
        }
      } else if (provider == 'metamask') {
        txHash = await _sendTransactionViaMetaMask(transactionData);
      } else {
        throw Exception('Unsupported wallet provider: $provider');
      }

      print('✅ DEBUG: completeDelivery transaction submitted');
      print('  - Transaction hash: $txHash');
      
      // Track transaction if tracker is available
      if (_transactionTracker != null) {
        await _transactionTracker!.trackTransaction(
          txHash: txHash,
          action: 'completeDelivery',
          providerType: provider,
        );
      }
      
      // Wait for transaction to be mined
      final receipt = await _waitForTransactionReceipt(txHash);
      final minedAt = DateTime.now();
      
      // Update transaction tracker with receipt
      if (_transactionTracker != null) {
        await _transactionTracker!.updateTransactionWithReceipt(
          txHash: txHash,
          receipt: receipt,
        );
      }
      
      final transactionResult = TransactionResult(
        txHash: txHash,
        receipt: receipt,
        submittedAt: submittedAt,
        minedAt: minedAt,
      );
      
      return DeliveryCompletionResult(
        deliveryId: deliveryId,
        transaction: transactionResult,
      );
    } on GasEstimationException {
      rethrow;
    } catch (e, stackTrace) {
      print('❌ DEBUG: completeDelivery failed');
      print('  - Error: $e');
      print('  - Stack trace: $stackTrace');
      throw Exception('Failed to complete delivery: $e');
    }
  }

  Future<DeliveryCancellationResult> cancelDelivery(String deliveryId, String reason) async {
    print('\n🔍 DEBUG: cancelDelivery called');
    print('  - Delivery ID: $deliveryId');
    print('  - Reason: $reason');
    
    if (!_isInitialized) await initialize();
    
    // Check network before transaction
    await _checkNetworkAllowed();

    if (_credentials == null) {
      throw Exception('No wallet credentials available. Please connect your wallet first.');
    }

    try {
      print('🚀 DEBUG: Sending cancelDelivery transaction...');
      
      final submittedAt = DateTime.now();
      final deliveryIdBytes = _hexToBytes(deliveryId);
      
      final txHash = await _client.sendTransaction(
        _credentials!,
        Transaction.callContract(
          contract: _contract,
          function: _contract.function('cancelDelivery'),
          parameters: [
            deliveryIdBytes,
            reason,
          ],
        ),
        chainId: 31337,
      );

      print('✅ DEBUG: cancelDelivery transaction submitted');
      print('  - Transaction hash: $txHash');
      
      // Track transaction if tracker is available
      if (_transactionTracker != null) {
        await _transactionTracker!.trackTransaction(
          txHash: txHash,
          action: 'cancelDelivery',
          providerType: 'private_key',
        );
      }
      
      // Wait for transaction to be mined
      final receipt = await _waitForTransactionReceipt(txHash);
      final minedAt = DateTime.now();
      
      // Update transaction tracker with receipt
      if (_transactionTracker != null) {
        await _transactionTracker!.updateTransactionWithReceipt(
          txHash: txHash,
          receipt: receipt,
        );
      }
      
      final transactionResult = TransactionResult(
        txHash: txHash,
        receipt: receipt,
        submittedAt: submittedAt,
        minedAt: minedAt,
      );
      
      return DeliveryCancellationResult(
        deliveryId: deliveryId,
        transaction: transactionResult,
      );
    } catch (e, stackTrace) {
      print('❌ DEBUG: cancelDelivery failed');
      print('  - Error: $e');
      print('  - Stack trace: $stackTrace');
      throw Exception('Failed to cancel delivery: $e');
    }
  }

  Future<Map<String, dynamic>> getDelivery(String deliveryId) async {
    print('\n🔍 DEBUG: getDelivery called');
    print('  - Delivery ID: $deliveryId');
    
    if (!_isInitialized) await initialize();

    try {
      print('📞 DEBUG: Calling getDelivery on contract...');
      
      final deliveryIdBytes = _hexToBytes(deliveryId);
      
      final result = await _client.call(
        contract: _contract,
        function: _contract.function('getDelivery'),
        params: [deliveryIdBytes],
      );

      print('✅ DEBUG: getDelivery successful');
      print('  - Raw result: $result');

      // Contract returns Delivery struct with:
      // - address customer
      // - address driver
      // - uint32 distanceMeters
      // - uint32 fiatAmountCents
      // - uint8 rating
      // - Status status (enum: 0=Created, 1=InProgress, 2=Completed, 3=Cancelled)
      // - uint64 createdAt
      // - uint64 completedAt

      final delivery = result[0];
      
      final parsed = {
        'id': deliveryId,
        'customer': (delivery[0] as EthereumAddress).hex,
        'driver': (delivery[1] as EthereumAddress).hex,
        'distanceMeters': (delivery[2] as BigInt).toInt(),
        'fiatAmountCents': (delivery[3] as BigInt).toInt(),
        'rating': (delivery[4] as BigInt).toInt(),
        'status': (delivery[5] as BigInt).toInt(),
        'createdAt': (delivery[6] as BigInt).toInt(),
        'completedAt': (delivery[7] as BigInt).toInt(),
      };
      
      print('  - Parsed delivery: $parsed');
      return parsed;
    } catch (e, stackTrace) {
      print('❌ DEBUG: getDelivery failed');
      print('  - Error: $e');
      print('  - Stack trace: $stackTrace');
      throw Exception('Failed to get delivery: $e');
    }
  }

  void dispose() {
    _client.dispose();
  }
}
