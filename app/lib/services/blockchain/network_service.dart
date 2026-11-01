import 'dart:js_util';
import 'package:flutter/foundation.dart';
import 'metamask_js.dart';
import 'contract_service.dart'; // Import to access HARDHAT_RPC_IP
import '../../constants/environment.dart';

/// Service for managing blockchain network connections
class NetworkService {
  // Use environment-aware configuration
  static String get networkName => Environment.networkName;
  static String get rpcUrl => Environment.isDevelopment 
      ? 'http://$devHardhatHost:8545'
      : Environment.productionRpc;      // Production: Sepolia
  static String get chainId => Environment.chainIdHex;
  static const String currencySymbol = 'ETH';
  static String get blockExplorer => Environment.isDevelopment 
      ? '' 
      : 'https://sepolia.etherscan.io';

  /// Add Hardhat network to MetaMask
  static Future<bool> addHardhatNetwork() async {
    try {
      final eth = ethereum;
      if (eth == null) {
        throw Exception('MetaMask not found');
      }

      await promiseToFuture(eth.request(
        RequestArguments(
          method: 'wallet_addEthereumChain',
          params: [
            {
              'chainId': chainId,
              'chainName': networkName,
              'rpcUrls': [rpcUrl],
              'nativeCurrency': {
                'name': 'Ethereum',
                'symbol': currencySymbol,
                'decimals': 18,
              },
              'blockExplorerUrls': blockExplorer.isEmpty 
                  ? null 
                  : [blockExplorer],
            }
          ],
        ),
      ));

      return true;
    } catch (e) {
      debugPrint('Error adding Hardhat network: $e');
      return false;
    }
  }

  /// Switch to Hardhat network
  static Future<bool> switchToHardhatNetwork() async {
    try {
      final eth = ethereum;
      if (eth == null) {
        throw Exception('MetaMask not found');
      }

      await promiseToFuture(eth.request(
        RequestArguments(
          method: 'wallet_switchEthereumChain',
          params: [
            {'chainId': chainId}
          ],
        ),
      ));

      return true;
    } catch (e) {
      debugPrint('Error switching to Hardhat network: $e');
      return false;
    }
  }

  /// Add and switch to Hardhat network in one call
  static Future<bool> setupHardhatNetwork() async {
    try {
      // First try to switch to the network
      final switchSuccess = await switchToHardhatNetwork();
      if (switchSuccess) {
        return true;
      }

      // If switch fails, try to add the network
      return await addHardhatNetwork();
    } catch (e) {
      debugPrint('Error setting up Hardhat network: $e');
      return false;
    }
  }

  /// Get current network chain ID
  static Future<String?> getCurrentChainId() async {
    try {
      final eth = ethereum;
      if (eth == null) return null;

      return await promiseToFuture<String>(eth.request(
        RequestArguments(method: 'eth_chainId'),
      ));
    } catch (e) {
      debugPrint('Error getting chain ID: $e');
      return null;
    }
  }

  /// Check if connected to Hardhat network
  static Future<bool> isConnectedToHardhat() async {
    final chainId = await getCurrentChainId();
    return chainId?.toLowerCase() == hardhatChainId.toLowerCase();
  }

  /// Get network information
  static Map<String, String> getHardhatNetworkInfo() {
    return {
      'name': hardhatNetworkName,
      'rpcUrl': hardhatRpcUrl,
      'chainId': hardhatChainId,
      'currencySymbol': hardhatCurrencySymbol,
      'blockExplorer': hardhatBlockExplorer,
    };
  }

  /// Get test account information for Hardhat
  static List<Map<String, String>> getHardhatTestAccounts() {
    return [
      {
        'address': '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
        'privateKey': '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
        'role': 'Customer',
        'description': 'Default Hardhat account #0',
      },
      {
        'address': '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
        'privateKey': '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d',
        'role': 'Driver',
        'description': 'Default Hardhat account #1',
      },
      {
        'address': '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
        'privateKey': '0x5de4111daeba5da4a170fd4365a0b2478c0c7b7e1e8e7a36b235832963d4b9b',
        'role': 'Customer',
        'description': 'Default Hardhat account #2',
      },
      {
        'address': '0x90F79bf6EB2c4f870365E785982E1f101E93b906',
        'privateKey': '0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6',
        'role': 'Driver',
        'description': 'Default Hardhat account #3',
      },
      {
        'address': '0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65',
        'privateKey': '0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8730739b127b5be02d96',
        'role': 'Customer',
        'description': 'Default Hardhat account #4',
      },
    ];
  }
}
