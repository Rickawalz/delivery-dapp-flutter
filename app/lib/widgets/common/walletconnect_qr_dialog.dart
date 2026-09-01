import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/blockchain/walletconnect_service.dart';

/// Dialog to display WalletConnect QR code for mobile wallet connection
class WalletConnectQRDialog extends StatefulWidget {
  final String uri;
  final VoidCallback? onCancel;

  const WalletConnectQRDialog({
    super.key,
    required this.uri,
    this.onCancel,
  });

  @override
  State<WalletConnectQRDialog> createState() => _WalletConnectQRDialogState();

  /// Show the QR dialog
  static Future<void> show({
    required BuildContext context,
    required String uri,
    VoidCallback? onCancel,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WalletConnectQRDialog(
        uri: uri,
        onCancel: onCancel,
      ),
    );
  }
}

class _WalletConnectQRDialogState extends State<WalletConnectQRDialog> {
  late WalletConnectService _walletConnectService;

  @override
  void initState() {
    super.initState();
    _walletConnectService = Provider.of<WalletConnectService>(context, listen: false);
    _walletConnectService.addListener(_onWalletConnectChanged);
  }

  @override
  void dispose() {
    _walletConnectService.removeListener(_onWalletConnectChanged);
    super.dispose();
  }

  void _onWalletConnectChanged() {
    // Auto-close dialog when wallet connects successfully
    if (_walletConnectService.isConnected && mounted) {
      // Add a small delay to ensure the connection is fully established
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.qr_code_scanner, color: Colors.blue),
          SizedBox(width: 8),
          Text('Connect Mobile Wallet'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scan this QR code with your mobile wallet to connect:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            // QR Code generated using qr_flutter package
            Container(
              width: 250,
              height: 250,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: QrImageView(
                data: widget.uri,
                version: QrVersions.auto,
                size: 200.0,
                gapless: false,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                errorStateBuilder: (context, error) {
                  return Container(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 48, color: Colors.red),
                        const SizedBox(height: 8),
                        Text(
                          'QR Code Error',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'URI too long or invalid',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // URI display for manual entry
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Or copy this URI manually:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    widget.uri,
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructions:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '1. Open MetaMask on your mobile device\n'
                    '2. Tap the menu (☰) and select "WalletConnect"\n'
                    '3. Scan the QR code above or tap "Connect via URI"\n'
                    '4. Approve the connection request\n'
                    '5. Make sure you\'re on Hardhat network (Chain ID: 31337)',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.uri));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('URI copied to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: const Text('Copy URI'),
        ),
        TextButton(
          onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
