import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/blockchain/wallet_service.dart';
import '../../services/blockchain/walletconnect_service.dart';
import '../wallet/wallet_selector.dart';

class WalletConnectSection extends StatelessWidget {
  const WalletConnectSection({super.key});

  @override
  Widget build(BuildContext context) {
    final walletService = Provider.of<WalletService>(context);
    final walletConnectService = Provider.of<WalletConnectService>(context);
    
    // Check if any wallet is connected
    final isAnyWalletConnected = walletService.isConnected || walletConnectService.isConnected;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAnyWalletConnected ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isAnyWalletConnected ? Icons.check_circle : Icons.error,
                color: isAnyWalletConnected ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAnyWalletConnected ? 'Wallet Connected' : 'Wallet Not Connected',
                      style: TextStyle(
                        color: isAnyWalletConnected ? Colors.green[900] : Colors.red[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isAnyWalletConnected) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Connected via: ${walletService.isConnected ? "MetaMask" : "WalletConnect"}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      if (walletService.isConnected && walletService.walletAddress != null)
                        Text(
                          'Address: ${walletService.walletAddress!.substring(0, 6)}...${walletService.walletAddress!.substring(walletService.walletAddress!.length - 4)}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      if (walletConnectService.isConnected && walletConnectService.walletAddress != null)
                        Text(
                          'Address: ${walletConnectService.walletAddress!.substring(0, 6)}...${walletConnectService.walletAddress!.substring(walletConnectService.walletAddress!.length - 4)}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                    ],
                  ],
                ),
              ),
              // Add disconnect button when connected
              if (isAnyWalletConnected)
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  tooltip: 'Disconnect Wallet',
                  onPressed: () async {
                    // Show confirmation dialog
                    final shouldDisconnect = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Disconnect Wallet'),
                        content: const Text('Are you sure you want to disconnect your wallet?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Disconnect'),
                          ),
                        ],
                      ),
                    );

                    if (shouldDisconnect == true) {
                      // Disconnect active wallet
                      if (walletService.isConnected) {
                        await walletService.disconnectWallet();
                      }
                      if (walletConnectService.isConnected) {
                        await walletConnectService.disconnect();
                      }
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Wallet disconnected successfully'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          WalletSelector(
            walletService: walletService,
            walletConnectService: walletConnectService,
          ),
        ],
      ),
    );
  }
} 