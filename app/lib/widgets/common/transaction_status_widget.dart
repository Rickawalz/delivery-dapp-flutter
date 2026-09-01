import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/blockchain/transaction_tracker.dart';

/// Reusable widget to display transaction status with real-time updates
class TransactionStatusWidget extends StatelessWidget {
  final String txHash;
  final bool showDetails;
  final VoidCallback? onComplete;

  const TransactionStatusWidget({
    Key? key,
    required this.txHash,
    this.showDetails = true,
    this.onComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionTracker>(
      builder: (context, tracker, child) {
        final tx = tracker.getTransaction(txHash);
        
        if (tx == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.grey),
                  SizedBox(width: 12),
                  Text('Transaction not found'),
                ],
              ),
            ),
          );
        }

        // Trigger callback when transaction completes
        if (tx.state == TransactionState.mined && onComplete != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onComplete!();
          });
        }

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status indicator
                _buildStatusRow(tx),
                
                if (showDetails) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  // Transaction hash
                  _buildTransactionHash(context, tx.txHash),
                  
                  const SizedBox(height: 12),
                  
                  // Action
                  _buildInfoRow('Action', _formatAction(tx.action)),
                  
                  const SizedBox(height: 8),
                  
                  // Provider
                  _buildInfoRow('Provider', tx.providerType),
                  
                  if (tx.minedAt != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Latency',
                      '${tx.minedAt!.difference(tx.submittedAt).inMilliseconds / 1000}s',
                    ),
                  ],
                  
                  if (tx.gasUsed != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow('Gas Used', tx.gasUsed.toString()),
                  ],
                  
                  if (tx.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tx.errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusRow(TransactionData tx) {
    IconData icon;
    Color color;
    String statusText;
    Widget? trailing;

    switch (tx.state) {
      case TransactionState.pending:
      case TransactionState.submitted:
        icon = Icons.hourglass_empty;
        color = Colors.orange;
        statusText = 'Waiting for confirmation...';
        trailing = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case TransactionState.mined:
        icon = Icons.check_circle;
        color = Colors.green;
        statusText = 'Transaction confirmed!';
        break;
      case TransactionState.confirmed:
        icon = Icons.verified;
        color = Colors.green;
        statusText = 'Transaction confirmed with ${tx.confirmations} confirmations';
        break;
      case TransactionState.failed:
        icon = Icons.error;
        color = Colors.red;
        statusText = 'Transaction failed';
        break;
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            statusText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildTransactionHash(BuildContext context, String hash) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Transaction Hash',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${hash.substring(0, 10)}...${hash.substring(hash.length - 8)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 20),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: hash));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Transaction hash copied to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          tooltip: 'Copy transaction hash',
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatAction(String action) {
    switch (action) {
      case 'createDelivery':
        return 'Create Delivery';
      case 'completeDelivery':
        return 'Complete Delivery';
      case 'cancelDelivery':
        return 'Cancel Delivery';
      default:
        return action;
    }
  }
}

/// Compact version of transaction status for inline display
class CompactTransactionStatus extends StatelessWidget {
  final String txHash;

  const CompactTransactionStatus({
    Key? key,
    required this.txHash,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionTracker>(
      builder: (context, tracker, child) {
        final tx = tracker.getTransaction(txHash);
        
        if (tx == null) {
          return const SizedBox.shrink();
        }

        IconData icon;
        Color color;
        String tooltip;

        switch (tx.state) {
          case TransactionState.pending:
          case TransactionState.submitted:
            icon = Icons.hourglass_empty;
            color = Colors.orange;
            tooltip = 'Pending confirmation';
            break;
          case TransactionState.mined:
          case TransactionState.confirmed:
            icon = Icons.check_circle;
            color = Colors.green;
            tooltip = 'Confirmed';
            break;
          case TransactionState.failed:
            icon = Icons.error;
            color = Colors.red;
            tooltip = 'Failed';
            break;
        }

        return Tooltip(
          message: tooltip,
          child: Icon(icon, color: color, size: 16),
        );
      },
    );
  }
}

