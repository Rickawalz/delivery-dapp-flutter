import 'package:flutter/foundation.dart';
import 'dart:js_util';
import 'package:web3dart/web3dart.dart';
import 'metamask_js.dart';
import '../../utils/allowed_networks.dart';


class WalletConnectionException implements Exception {
  final String message;
  WalletConnectionException(this.message);
  
  @override
  String toString() => 'WalletConnectionException: $message';
}

class WalletService extends ChangeNotifier {
  bool _isConnected = false;
  String? _walletAddress;
  int? _chainId;
  Credentials? _credentials;

  bool get isConnected => _isConnected;
  String? get walletAddress => _walletAddress;
  int? get chainId => _chainId;
  Credentials? get credentials => _credentials;
  bool get hasCredentials => _credentials != null;

  Future<void> connectWallet() async {
    try {
      final eth = ethereum;
      if (eth == null) {
        throw WalletConnectionException('MetaMask not found. Please install MetaMask extension.');
      }

      // Check if already connected
      if (_isConnected && _walletAddress != null) {
        return;
      }

      // Request account access
      final accounts = await promiseToFuture<List>(eth.request(
        RequestArguments(method: 'eth_requestAccounts'),
      ));

      if (accounts.isEmpty) {
        throw WalletConnectionException('No accounts found. Please unlock your MetaMask wallet.');
      }

      _walletAddress = accounts[0] as String;
      
      // Parse chain ID from MetaMask (hex string) to int
      final chainIdHex = eth.chainId;
      _chainId = _parseChainId(chainIdHex);
      
      // Validate the address format
      if (!_isValidEthereumAddress(_walletAddress!)) {
        throw WalletConnectionException('Invalid wallet address format.');
      }
      
      // Enforce Hardhat-only network
      if (!AllowedNetworks.isAllowed(_chainId)) {
        _isConnected = false;
        _walletAddress = null;
        _chainId = null;
        notifyListeners();
        
        // Try to switch to Hardhat network
        await _switchToHardhatNetwork();
        throw WalletConnectionException(
          'Only Hardhat network (31337) is allowed for research. '
          'Please switch to Hardhat network in MetaMask.'
        );
      }
      
      _isConnected = true;
      
      // For MetaMask connections, we don't need credentials since MetaMask handles signing
      // The ContractService will use MetaMask's eth_sendTransaction directly
      _credentials = null;
      
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      _walletAddress = null;
      _chainId = null;
      notifyListeners();
      
      if (e is WalletConnectionException) {
        rethrow;
      } else {
        throw WalletConnectionException('Failed to connect wallet: ${e.toString()}');
      }
    }
  }

  bool _isValidEthereumAddress(String address) {
    return address.startsWith('0x') && address.length == 42;
  }

  Future<void> connectWithPrivateKey(String privateKeyHex) async {
    try {
      // Normalize private key (add 0x prefix if missing)
      final normalizedKey = privateKeyHex.startsWith('0x') 
          ? privateKeyHex 
          : '0x$privateKeyHex';
      
      // Validate private key format
      if (!_isValidPrivateKey(normalizedKey)) {
        throw WalletConnectionException('Invalid private key format');
      }
      
      // Create credentials from private key
      _credentials = EthPrivateKey.fromHex(normalizedKey);
      
      // Extract address from credentials
      final address = await _credentials!.extractAddress();
      _walletAddress = address.hex;
      _isConnected = true;
      _chainId = 31337; // Hardhat network
      
      notifyListeners();
    } catch (e) {
      _credentials = null;
      _isConnected = false;
      _walletAddress = null;
      _chainId = null;
      notifyListeners();
      
      if (e is WalletConnectionException) {
        rethrow;
      } else {
        throw WalletConnectionException('Failed to connect with private key: ${e.toString()}');
      }
    }
  }

  bool _isValidPrivateKey(String key) {
    // Remove 0x prefix for validation
    final cleanKey = key.startsWith('0x') ? key.substring(2) : key;
    return cleanKey.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(cleanKey);
  }

  Future<void> disconnectWallet() async {
    // MetaMask does not support programmatic disconnect for security reasons.
    // We simply reset the state in the app.
    _isConnected = false;
    _walletAddress = null;
    _chainId = null;
    _credentials = null;
    notifyListeners();
  }

  Future<void> switchNetwork(int chainId) async {
    try {
      // TODO: Implement network switching
      _chainId = chainId;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Parse chain ID from hex string
  int? _parseChainId(String? chainIdHex) {
    if (chainIdHex == null) return null;
    if (chainIdHex.startsWith('0x')) {
      return int.parse(chainIdHex.substring(2), radix: 16);
    }
    return int.tryParse(chainIdHex);
  }
  
  /// Switch to Hardhat network in MetaMask
  Future<void> _switchToHardhatNetwork() async {
    try {
      final eth = ethereum;
      if (eth == null) return;
      
      // Try to switch to Hardhat network
      await promiseToFuture(eth.request(
        RequestArguments(
          method: 'wallet_switchEthereumChain',
          params: [{'chainId': AllowedNetworks.hardhatChainIdHex}],
        ),
      ));
    } catch (e) {
      // If switch fails, try to add the network
      try {
        final eth = ethereum;
        if (eth == null) return;
        await promiseToFuture(eth.request(
          RequestArguments(
            method: 'wallet_addEthereumChain',
            params: [
              {
                'chainId': AllowedNetworks.hardhatChainIdHex,
                'chainName': AllowedNetworks.hardhatNetworkName,
                'rpcUrls': [AllowedNetworks.preferredNetwork.rpcUrl],
                'nativeCurrency': {
                  'name': 'Ethereum',
                  'symbol': AllowedNetworks.preferredNetwork.currencySymbol,
                  'decimals': 18,
                },
              }
            ],
          ),
        ));
      } catch (addError) {
        debugPrint('Failed to add Hardhat network: $addError');
      }
    }
  }
} 