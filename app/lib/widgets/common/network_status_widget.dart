import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/blockchain/wallet_service.dart';
import '../../services/blockchain/walletconnect_service.dart';
import '../../services/blockchain/network_info_service.dart';
import '../../utils/allowed_networks.dart';

/// Widget that displays dynamic network and blockchain connection status
class NetworkStatusWidget extends StatelessWidget {
  const NetworkStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<WalletService, WalletConnectService, NetworkInfoService>(
      builder: (context, walletService, walletConnectService, networkInfoService, child) {
        final isWalletConnected = walletService.isConnected || walletConnectService.isConnected;
        final walletAddress = walletService.walletAddress ?? walletConnectService.walletAddress;
        final walletChainId = walletService.chainId ?? walletConnectService.chainId;
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getStatusColor(networkInfoService, isWalletConnected),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getStatusColor(networkInfoService, isWalletConnected).withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getStatusIcon(networkInfoService, isWalletConnected),
                    color: _getStatusColor(networkInfoService, isWalletConnected),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    networkInfoService.statusMessage,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(networkInfoService, isWalletConnected),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    onPressed: () => networkInfoService.refresh(),
                    tooltip: 'Refresh network status',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Network details
              _buildStatusItem('Chain ID', networkInfoService.rpcChainId?.toString() ?? 'Unknown'),
              _buildStatusItem('Network', networkInfoService.rpcNetworkName),
              _buildStatusItem('RPC URL', networkInfoService.rpcUrl),
              
              // Wallet details if connected
              if (isWalletConnected) ...[
                const Divider(height: 16),
                _buildStatusItem('Wallet', 'Connected', Colors.green),
                if (walletAddress != null)
                  _buildStatusItem(
                    'Address', 
                    '${walletAddress.substring(0, 6)}...${walletAddress.substring(walletAddress.length - 4)}',
                    Colors.blue,
                  ),
                if (walletChainId != null) ...[
                  _buildStatusItem('Wallet Chain ID', walletChainId.toString()),
                  if (walletChainId != networkInfoService.rpcChainId)
                    _buildStatusItem('⚠️ Mismatch', 'Wallet and RPC chain IDs differ', Colors.orange),
                ],
              ],
              
              // Error details
              if (networkInfoService.error != null) ...[
                const Divider(height: 16),
                _buildStatusItem('Error', networkInfoService.error!, Colors.red),
              ],
              
              // Network not allowed warning
              if (!networkInfoService.isRpcAllowed && networkInfoService.isRpcReachable) ...[
                const Divider(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Only Hardhat network (31337) is allowed for research',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusItem(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: color ?? Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(NetworkInfoService networkInfoService, bool isWalletConnected) {
    if (!networkInfoService.isRpcReachable) return Colors.red;
    if (!networkInfoService.isRpcAllowed) return Colors.orange;
    if (networkInfoService.isHardhat) return Colors.green;
    if (isWalletConnected) return Colors.blue;
    return Colors.grey;
  }

  IconData _getStatusIcon(NetworkInfoService networkInfoService, bool isWalletConnected) {
    if (!networkInfoService.isRpcReachable) return Icons.error;
    if (!networkInfoService.isRpcAllowed) return Icons.warning;
    if (networkInfoService.isHardhat) return Icons.check_circle;
    if (isWalletConnected) return Icons.link;
    return Icons.link_off;
  }
}

/// Compact network status indicator for app bars
class CompactNetworkStatus extends StatelessWidget {
  const CompactNetworkStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<WalletService, WalletConnectService, NetworkInfoService>(
      builder: (context, walletService, walletConnectService, networkInfoService, child) {
        final isWalletConnected = walletService.isConnected || walletConnectService.isConnected;
        final statusColor = _getStatusColor(networkInfoService, isWalletConnected);
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStatusIcon(networkInfoService, isWalletConnected),
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                _getStatusText(networkInfoService, isWalletConnected),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(NetworkInfoService networkInfoService, bool isWalletConnected) {
    if (!networkInfoService.isRpcReachable) return Colors.red;
    if (!networkInfoService.isRpcAllowed) return Colors.orange;
    if (networkInfoService.isHardhat) return Colors.green;
    if (isWalletConnected) return Colors.blue;
    return Colors.grey;
  }

  IconData _getStatusIcon(NetworkInfoService networkInfoService, bool isWalletConnected) {
    if (!networkInfoService.isRpcReachable) return Icons.error;
    if (!networkInfoService.isRpcAllowed) return Icons.warning;
    if (networkInfoService.isHardhat) return Icons.check_circle;
    if (isWalletConnected) return Icons.link;
    return Icons.link_off;
  }

  String _getStatusText(NetworkInfoService networkInfoService, bool isWalletConnected) {
    if (!networkInfoService.isRpcReachable) return 'RPC Error';
    if (!networkInfoService.isRpcAllowed) return 'Network Blocked';
    if (networkInfoService.isHardhat) return 'Hardhat';
    if (isWalletConnected) return 'Connected';
    return 'Disconnected';
  }
}