import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/delivery.dart';
import '../../utils/rel_utils.dart';

/// A card widget that displays delivery information in a visually appealing format.
/// 
/// This widget shows key delivery details including:
/// - Delivery ID and current status
/// - Description of the delivery
/// - Value in ETH and receiver address
/// - Courier information (if assigned)
/// - Creation time and estimated delivery time
/// 
/// The card is tappable and can trigger a callback for detailed view.
class DeliveryCard extends StatelessWidget {
  /// The delivery object containing all the information to display
  final Delivery delivery;
  
  /// Optional callback triggered when the card is tapped
  final VoidCallback? onTap;

  /// Creates a new DeliveryCard widget.
  /// 
  /// [delivery] The delivery object to display (required)
  /// [onTap] Optional callback for tap interactions
  const DeliveryCard({
    super.key,
    required this.delivery,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Delivery #${delivery.id.substring(0, 8)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildStatusChip(delivery.status),
                ],
              ),
              const SizedBox(height: 12),
              
              // Description
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  delivery.description ?? 'No description',
                  style: const TextStyle(fontSize: 14),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Details row
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.attach_money,
                      '\$${delivery.fiatAmountUSD.toStringAsFixed(2)}',
                      Colors.green[700]!,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.social_distance,
                      '${delivery.distanceKm.toStringAsFixed(1)} km',
                      Colors.blue[700]!,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Driver info
              Row(
                children: [
                  Icon(Icons.local_shipping, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Driver: ${delivery.driverAddress.substring(0, 6)}...${delivery.driverAddress.substring(delivery.driverAddress.length - 4)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Time info
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Created: ${DateFormat('MMM dd, HH:mm').format(delivery.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              
              if (delivery.completedAt != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Completed: ${DateFormat('MMM dd, HH:mm').format(delivery.completedAt!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Builds an info item with an icon and text in a consistent format.
  /// 
  /// Used for displaying key-value pairs like value and receiver address.
  /// 
  /// [icon] The icon to display
  /// [text] The text content
  /// [color] The color for both icon and text
  Widget _buildInfoItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Builds a status chip with appropriate color, label, and icon for the delivery status.
  /// 
  /// Each status has a distinct visual representation:
  /// - Pending: Orange with hourglass icon
  /// - Accepted: Blue with check circle outline
  /// - In Transit: Purple with shipping icon
  /// - Delivered: Green with check circle
  /// - Cancelled: Red with cancel icon
  /// 
  /// [status] The delivery status to display
  Widget _buildStatusChip(DeliveryStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case DeliveryStatus.created:
        color = Colors.orange;
        label = 'Created';
        icon = Icons.hourglass_empty;
        break;
      case DeliveryStatus.inProgress:
        color = Colors.blue;
        label = 'In Progress';
        icon = Icons.local_shipping;
        break;
      case DeliveryStatus.completed:
        color = Colors.green;
        label = 'Completed';
        icon = Icons.check_circle;
        break;
      case DeliveryStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
