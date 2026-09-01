import 'package:flutter/material.dart';
import '../../models/delivery.dart';

/// A widget that displays delivery statistics in a summary format.
/// 
/// Shows counts for different delivery statuses:
/// - Pending deliveries (orange)
/// - In Progress deliveries (blue) 
/// - Completed deliveries (green)
/// 
/// The widget calculates these counts automatically from the provided delivery list.
class DeliveryStatsWidget extends StatelessWidget {
  /// List of deliveries to calculate statistics from
  final List<Delivery> deliveries;

  /// Creates a new DeliveryStatsWidget.
  /// 
  /// [deliveries] The list of deliveries to analyze (required)
  const DeliveryStatsWidget({
    super.key,
    required this.deliveries,
  });

  @override
  Widget build(BuildContext context) {
    final pendingCount = deliveries.where((d) => d.status == DeliveryStatus.created).length;
    final inProgressCount = deliveries.where((d) => d.status == DeliveryStatus.inProgress).length;
    final completedCount = deliveries.where((d) => d.status == DeliveryStatus.completed).length;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem('Pending', pendingCount, Colors.orange),
          ),
          Expanded(
            child: _buildStatItem('In Progress', inProgressCount, Colors.blue),
          ),
          Expanded(
            child: _buildStatItem('Completed', completedCount, Colors.green),
          ),
        ],
      ),
    );
  }

  /// Builds a single statistic item showing a count and label.
  /// 
  /// [label] The text label (e.g., "Pending", "In Progress")
  /// [count] The numeric count to display
  /// [color] The color for the count number
  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
