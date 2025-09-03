import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/blockchain/wallet_service.dart';

class WalletConnectSection extends StatelessWidget {
  const WalletConnectSection({super.key});

  @override
  Widget build(BuildContext context) {
    final walletService = Provider.of<WalletService>(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: walletService.isConnected ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            walletService.isConnected ? Icons.check_circle : Icons.error,
            color: walletService.isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  walletService.isConnected ? 'Wallet Connected' : 'Wallet Not Connected',
                  style: TextStyle(
                    color: walletService.isConnected ? Colors.green[900] : Colors.red[900],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (walletService.isConnected && walletService.walletAddress != null)
                  Text(
                    'Address: ${walletService.walletAddress!.substring(0, 6)}...${walletService.walletAddress!.substring(walletService.walletAddress!.length - 4)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              if (walletService.isConnected) {
                walletService.disconnectWallet();
              } else {
                walletService.connectWallet();
              }
            },
            child: Text(walletService.isConnected ? 'Disconnect' : 'Connect Wallet'),
            style: ElevatedButton.styleFrom(
              backgroundColor: walletService.isConnected ? Colors.red : Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
} 