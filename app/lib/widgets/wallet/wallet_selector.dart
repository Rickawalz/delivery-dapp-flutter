import 'package:flutter/material.dart';
import '../../services/blockchain/wallet_service.dart';
import '../../services/blockchain/walletconnect_service.dart';
import '../common/walletconnect_qr_dialog.dart';

class WalletSelector extends StatelessWidget {
  final WalletService walletService;
  final WalletConnectService walletConnectService;

  const WalletSelector({
    super.key,
    required this.walletService,
    required this.walletConnectService,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connect Wallet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // MetaMask Option
            _buildWalletOption(
              context: context,
              title: 'MetaMask',
              subtitle: 'Connect using MetaMask browser extension',
              icon: Icons.account_balance_wallet,
              isConnected: walletService.isConnected,
              onTap: () async {
                if (walletService.isConnected) {
                  await walletService.disconnectWallet();
                } else {
                  try {
                    // Disconnect WalletConnect if connected
                    if (walletConnectService.isConnected) {
                      await walletConnectService.disconnect();
                    }
                    await walletService.connectWallet();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to connect MetaMask: ${e.toString()}'),
                          backgroundColor: Colors.red,
                          action: SnackBarAction(
                            label: 'Retry',
                            textColor: Colors.white,
                            onPressed: () async {
                              try {
                                await walletService.connectWallet();
                              } catch (retryError) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Retry failed: ${retryError.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      );
                    }
                  }
                }
              },
            ),
            
            const SizedBox(height: 12),
            
            // WalletConnect Option
            _buildWalletOption(
              context: context,
              title: 'WalletConnect',
              subtitle: 'Connect using mobile wallet apps',
              icon: Icons.qr_code_scanner,
              isConnected: walletConnectService.isConnected,
              onTap: () async {
                if (walletConnectService.isConnected) {
                  await walletConnectService.disconnect();
                } else {
                  try {
                    // Disconnect MetaMask if connected
                    if (walletService.isConnected) {
                      await walletService.disconnectWallet();
                    }
                    // Show QR dialog for WalletConnect
                    await _showWalletConnectDialog(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to connect WalletConnect: ${e.toString()}'),
                          backgroundColor: Colors.red,
                          action: SnackBarAction(
                            label: 'Retry',
                            textColor: Colors.white,
                            onPressed: () async {
                              try {
                                await _showWalletConnectDialog(context);
                              } catch (retryError) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Retry failed: ${retryError.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      );
                    }
                  }
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // Connection Status
            if (walletService.isConnected || walletConnectService.isConnected)
              _buildConnectionStatus(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isConnected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isConnected ? Colors.green : Colors.grey.shade300,
            width: isConnected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isConnected ? Colors.green.shade50 : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isConnected ? Colors.green : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isConnected ? Colors.green.shade800 : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isConnected)
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(BuildContext context) {
    final isMetaMaskConnected = walletService.isConnected;
    final walletName = isMetaMaskConnected ? 'MetaMask' : 'WalletConnect';
    final activeAddress = isMetaMaskConnected ? walletService.walletAddress : walletConnectService.walletAddress;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connected via $walletName',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                if (activeAddress != null)
                  Text(
                    'Address: ${activeAddress.substring(0, 6)}...${activeAddress.substring(activeAddress.length - 4)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show WalletConnect QR dialog
  Future<void> _showWalletConnectDialog(BuildContext context) async {
    try {
      // Generate pairing URI (non-blocking)
      final uri = await walletConnectService.generatePairingUri();
      
      if (context.mounted) {
        // Show QR dialog with the actual pairing URI
        await WalletConnectQRDialog.show(
          context: context,
          uri: uri,
          onCancel: () {
            Navigator.of(context).pop();
          },
        );
        
        // After dialog is shown, wait for connection in the background
        if (context.mounted) {
          // Wait for connection without blocking UI
          walletConnectService.waitForConnection().catchError((error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Connection failed: ${error.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          });
        }
      }
      
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('WalletConnect error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
