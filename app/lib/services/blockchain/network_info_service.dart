import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';
import '../../utils/allowed_networks.dart';
import 'contract_service.dart'; // Import to access HARDHAT_RPC_IP
import '../../constants/environment.dart';

/// Service for managing network information and status
/// Provides real-time network detection and validation
class NetworkInfoService extends ChangeNotifier {
  final Web3Client _web3Client;
  Timer? _refreshTimer;
  
  // Network state - use environment-aware default
  String _rpcUrl = Environment.isDevelopment 
      ? 'http://$HARDHAT_RPC_IP:8545'  // Development: dynamic IP
      : Environment.productionRpc;      // Production: Sepolia
  int? _rpcChainId;
  String _rpcNetworkName = 'Unknown';
  bool _isRpcReachable = false;
  bool _isRpcAllowed = false;
  DateTime? _lastUpdated;
  String? _error;
  
  // Getters
  String get rpcUrl => _rpcUrl;
  int? get rpcChainId => _rpcChainId;
  String get rpcNetworkName => _rpcNetworkName;
  bool get isRpcReachable => _isRpcReachable;
  bool get isRpcAllowed => _isRpcAllowed;
  DateTime? get lastUpdated => _lastUpdated;
  String? get error => _error;
  
  NetworkInfoService(this._web3Client) {
    _startPeriodicRefresh();
  }
  
  /// Start periodic network status refresh
  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      refresh();
    });
  }
  
  /// Update RPC URL and refresh network info
  void updateRpcUrl(String newRpcUrl) {
    if (_rpcUrl != newRpcUrl) {
      _rpcUrl = newRpcUrl;
      refresh();
    }
  }
  
  /// Refresh network information from RPC
  Future<void> refresh() async {
    try {
      _error = null;
      
      // Get chain ID from RPC
      final chainId = await _getChainIdFromRpc();
      
      if (chainId != null) {
        _rpcChainId = chainId;
        _rpcNetworkName = AllowedNetworks.nameFor(chainId);
        _isRpcReachable = true;
        _isRpcAllowed = AllowedNetworks.isAllowed(chainId);
      } else {
        _isRpcReachable = false;
        _isRpcAllowed = false;
        _error = 'RPC unreachable';
      }
      
      _lastUpdated = DateTime.now();
      notifyListeners();
      
    } catch (e) {
      _isRpcReachable = false;
      _isRpcAllowed = false;
      _error = 'Network error: $e';
      _lastUpdated = DateTime.now();
      notifyListeners();
    }
  }
  
  /// Get chain ID from RPC using eth_chainId
  Future<int?> _getChainIdFromRpc() async {
    try {
      // Use getNetworkId which is the standard method
      final networkId = await _web3Client.getNetworkId();
      return networkId;
      
    } catch (e) {
      debugPrint('Error getting chain ID from RPC: $e');
      return null;
    }
  }
  
  /// Get network info for current RPC
  NetworkInfo? get currentNetworkInfo {
    if (_rpcChainId == null) return null;
    return AllowedNetworks.infoFor(_rpcChainId);
  }
  
  /// Check if current network is Hardhat
  bool get isHardhat => _rpcChainId == AllowedNetworks.hardhatChainId;
  
  /// Get status message for UI
  String get statusMessage {
    if (!_isRpcReachable) {
      return 'RPC unreachable';
    }
    if (!_isRpcAllowed) {
      return 'Network not allowed';
    }
    if (isHardhat) {
      return 'Connected to Hardhat';
    }
    return 'Connected to $_rpcNetworkName';
  }
  
  /// Get status color for UI
  String get statusColor {
    if (!_isRpcReachable) return 'red';
    if (!_isRpcAllowed) return 'orange';
    if (isHardhat) return 'green';
    return 'blue';
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
