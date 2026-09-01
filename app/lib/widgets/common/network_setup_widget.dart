import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/blockchain/network_service.dart';
import '../../services/blockchain/wallet_service.dart';
import '../../services/blockchain/contract_service.dart';

/// Widget for setting up Hardhat network connection
class NetworkSetupWidget extends StatefulWidget {
  const NetworkSetupWidget({super.key});

  @override
  State<NetworkSetupWidget> createState() => _NetworkSetupWidgetState();
}

class _NetworkSetupWidgetState extends State<NetworkSetupWidget> {
  bool _isSettingUp = false;
  String? _error;
  String? _currentChainId;

  @override
  void initState() {
    super.initState();
    _checkCurrentNetwork();
  }

  Future<void> _checkCurrentNetwork() async {
    final chainId = await NetworkService.getCurrentChainId();
    setState(() {
      _currentChainId = chainId;
    });
  }

  Future<void> _setupHardhatNetwork() async {
    setState(() {
      _isSettingUp = true;
      _error = null;
    });

    try {
      final success = await NetworkService.setupHardhatNetwork();
      if (success) {
        await _checkCurrentNetwork();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hardhat network configured successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _error = 'Failed to configure Hardhat network';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _isSettingUp = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnectedToHardhat = _currentChainId?.toLowerCase() == '0x7a69';
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings_ethernet,
                  color: isConnectedToHardhat ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Network Setup',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Current network status
            _buildNetworkStatus(),
            
            const SizedBox(height: 16),
            
            // Setup button
            if (!isConnectedToHardhat) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSettingUp ? null : _setupHardhatNetwork,
                  icon: _isSettingUp 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check),
                  label: Text(_isSettingUp ? 'Setting up...' : 'Setup Hardhat Network'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text(
                      'Connected to Hardhat Network',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Error message
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Test accounts info
            _buildTestAccountsInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkStatus() {
    final isConnectedToHardhat = _currentChainId?.toLowerCase() == '0x7a69';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isConnectedToHardhat 
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConnectedToHardhat 
              ? Colors.green.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isConnectedToHardhat ? Icons.check_circle : Icons.warning,
                color: isConnectedToHardhat ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isConnectedToHardhat 
                    ? 'Connected to Hardhat'
                    : 'Not connected to Hardhat',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isConnectedToHardhat ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildStatusRow('Chain ID', _currentChainId ?? 'Unknown'),
          _buildStatusRow('Network', isConnectedToHardhat ? 'Hardhat Local' : 'Other'),
          _buildStatusRow('RPC URL', 'http://$HARDHAT_RPC_IP:8545'),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestAccountsInfo() {
    return ExpansionTile(
      title: const Text(
        'Hardhat Test Accounts',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      children: [
        const Text(
          'Import these private keys into MetaMask to use test accounts:',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        ...NetworkService.getHardhatTestAccounts().take(3).map((account) => 
          _buildTestAccountItem(account),
        ),
        const SizedBox(height: 8),
        const Text(
          'Note: These accounts have 10,000 ETH each for testing.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTestAccountItem(Map<String, String> account) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                account['role']!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                '${account['address']!.substring(0, 6)}...${account['address']!.substring(38)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Private Key: ${account['privateKey']!.substring(0, 10)}...',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/// Compact network setup button for app bars
class CompactNetworkSetup extends StatelessWidget {
  const CompactNetworkSetup({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletService>(
      builder: (context, walletService, child) {
        if (!walletService.isConnected) {
          return const SizedBox.shrink();
        }

        return FutureBuilder<bool>(
          future: NetworkService.isConnectedToHardhat(),
          builder: (context, snapshot) {
            final isConnectedToHardhat = snapshot.data ?? false;
            
            if (isConnectedToHardhat) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Hardhat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return TextButton(
              onPressed: () => _showNetworkSetupDialog(context),
              child: const Text(
                'Setup Network',
                style: TextStyle(fontSize: 12),
              ),
            );
          },
        );
      },
    );
  }

  void _showNetworkSetupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setup Hardhat Network'),
        content: const Text(
          'This will add the Hardhat local network to your MetaMask wallet. '
          'Make sure your Hardhat node is running on port 8545.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await NetworkService.setupHardhatNetwork();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success 
                          ? 'Hardhat network configured successfully!'
                          : 'Failed to configure network',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Setup'),
          ),
        ],
      ),
    );
  }
}
