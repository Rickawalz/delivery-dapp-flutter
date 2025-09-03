import 'package:flutter/foundation.dart';
import 'dart:js_util';
import 'metamask_js.dart';

class WalletService extends ChangeNotifier {
  bool _isConnected = false;
  String? _walletAddress;
  String? _chainId;

  bool get isConnected => _isConnected;
  String? get walletAddress => _walletAddress;
  String? get chainId => _chainId;

  Future<void> connectWallet() async {
    try {
      final eth = ethereum;
      if (eth == null) throw Exception('MetaMask not found');

      // Request account access
      final accounts = await promiseToFuture<List>(eth.request(
        RequestArguments(method: 'eth_requestAccounts'),
      ));

      _walletAddress = accounts.isNotEmpty ? accounts[0] as String : null;
      _chainId = eth.chainId;
      _isConnected = _walletAddress != null;
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      _walletAddress = null;
      _chainId = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> disconnectWallet() async {
    // MetaMask does not support programmatic disconnect for security reasons.
    // We simply reset the state in the app.
    _isConnected = false;
    _walletAddress = null;
    _chainId = null;
    notifyListeners();
  }

  Future<void> switchNetwork(String chainId) async {
    try {
      // TODO: Implement network switching
      _chainId = chainId;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
} 