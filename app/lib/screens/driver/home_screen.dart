import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/wallet_connect_section.dart';
import '../../widgets/common/network_status_widget.dart';
import '../../widgets/common/navigation_links.dart';
import '../../models/user_role.dart';
import '../../services/blockchain/wallet_service.dart';
import '../../services/blockchain/walletconnect_service.dart';
import '../../services/delivery/delivery_service.dart';
import '../../services/user/user_service.dart';
import '../../models/delivery.dart';
import 'package:intl/intl.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Note: fetchAvailableDeliveries() will be called automatically when wallet connects
    // via the _onWalletChanged method in DeliveryService
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userService = Provider.of<UserService>(context);
    final username = userService.currentUsername ?? 'Unknown';
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Driver Dashboard'),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    username,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<DeliveryService>().fetchAvailableDeliveries();
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              _showProfileMenu(context);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Available', icon: Icon(Icons.list)),
            Tab(text: 'My Jobs', icon: Icon(Icons.work)),
            Tab(text: 'Completed', icon: Icon(Icons.check_circle)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Navigation Links
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: NavigationLinks(currentPage: 'driver'),
            ),
            
            // Network Status Widget
            const NetworkStatusWidget(),
            
            // Wallet Connect Section
            WalletConnectSection(),

            // Tab Content
            SizedBox(
              height: 600, // Fixed height for tab content
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAvailableDeliveries(),
                  _buildMyJobs(),
                  _buildCompletedDeliveries(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableDeliveries() {
    return Consumer<DeliveryService>(
      builder: (context, deliveryService, child) {
        print('🔄 DEBUG: _buildAvailableDeliveries called');
        print('  - deliveryService.isLoading = ${deliveryService.isLoading}');
        
        if (deliveryService.isLoading) {
          print('  - Showing CircularProgressIndicator');
          return const Center(child: CircularProgressIndicator());
        }

        if (deliveryService.error != null) {
          return Center(child: Text('Error: ${deliveryService.error}'));
        }

        final availableDeliveries = deliveryService.deliveries
            .where((d) => d.status == DeliveryStatus.created || d.status == DeliveryStatus.inProgress)
            .toList();

        if (availableDeliveries.isEmpty) {
          return _buildEmptyState(
            icon: Icons.list_alt,
            title: 'No Available Deliveries',
            subtitle: 'Check back later for new delivery opportunities',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: availableDeliveries.length,
          itemBuilder: (context, index) {
            final delivery = availableDeliveries[index];
            return AvailableDeliveryCard(
              delivery: delivery,
              onAccept: () => _acceptDelivery(context, delivery),
            );
          },
        );
      },
    );
  }

  Widget _buildMyJobs() {
    return Consumer<DeliveryService>(
      builder: (context, deliveryService, child) {
        // For demo purposes, show some mock active jobs
        final activeJobs = _getMockActiveJobs();

        if (activeJobs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.work_outline,
            title: 'No Active Jobs',
            subtitle: 'Accept deliveries from the Available tab to get started',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeJobs.length,
          itemBuilder: (context, index) {
            final delivery = activeJobs[index];
            return ActiveJobCard(
              delivery: delivery,
              onUpdateStatus: (status) => _updateDeliveryStatus(context, delivery, status),
            );
          },
        );
      },
    );
  }

  Widget _buildCompletedDeliveries() {
    // For demo purposes, show some mock completed deliveries
    final completedDeliveries = _getMockCompletedDeliveries();

    if (completedDeliveries.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        title: 'No Completed Deliveries',
        subtitle: 'Complete your first delivery to see it here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completedDeliveries.length,
      itemBuilder: (context, index) {
        final delivery = completedDeliveries[index];
        return CompletedDeliveryCard(delivery: delivery);
      },
    );
  }


  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to profile page
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to settings
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.pop(context);
                
                // Disconnect wallet before logout
                final walletConnectService = Provider.of<WalletConnectService>(context, listen: false);
                if (walletConnectService.isConnected) {
                  await walletConnectService.disconnect();
                }
                
                final walletService = Provider.of<WalletService>(context, listen: false);
                if (walletService.isConnected) {
                  await walletService.disconnectWallet();
                }
                
                // Clear user from storage
                final userService = Provider.of<UserService>(context, listen: false);
                await userService.clearCurrentUser();
                
                // Navigate to home
                if (context.mounted) {
                  context.go('/');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _acceptDelivery(BuildContext context, Delivery delivery) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Delivery'),
        content: Text('Are you sure you want to accept this delivery?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement actual acceptance logic
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Delivery #${delivery.id.substring(0, 8)} accepted!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _updateDeliveryStatus(BuildContext context, Delivery delivery, DeliveryStatus status) {
    // TODO: Implement actual status update logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Delivery status updated to ${_getStatusText(status)}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  String _getStatusText(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.created:
        return 'Created';
      case DeliveryStatus.inProgress:
        return 'In Progress';
      case DeliveryStatus.completed:
        return 'Completed';
      case DeliveryStatus.cancelled:
        return 'Cancelled';
    }
  }

  // Mock data methods - in a real app, this would come from the blockchain
  List<Delivery> _getMockActiveJobs() {
    return [];
  }

  List<Delivery> _getMockCompletedDeliveries() {
    return [];
  }
}

class AvailableDeliveryCard extends StatelessWidget {
  final Delivery delivery;
  final VoidCallback onAccept;

  const AvailableDeliveryCard({
    super.key,
    required this.delivery,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Available',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
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
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Details
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
                    Icons.access_time,
                    DateFormat('MMM dd, HH:mm').format(delivery.createdAt),
                    Colors.blue[700]!,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Accept button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAccept,
                icon: const Icon(Icons.check_circle),
                label: const Text('Accept Delivery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
}

class ActiveJobCard extends StatelessWidget {
  final Delivery delivery;
  final Function(DeliveryStatus) onUpdateStatus;

  const ActiveJobCard({
    super.key,
    required this.delivery,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                delivery.description ?? 'No description',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Details
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
                    Icons.access_time,
                    DateFormat('MMM dd, HH:mm').format(delivery.createdAt),
                    Colors.blue[700]!,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onUpdateStatus(DeliveryStatus.inProgress),
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Start Delivery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[600],
                      side: BorderSide(color: Colors.blue[600]!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onUpdateStatus(DeliveryStatus.completed),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
}

class CompletedDeliveryCard extends StatelessWidget {
  final Delivery delivery;

  const CompletedDeliveryCard({
    super.key,
    required this.delivery,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                delivery.description ?? 'No description',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Details
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
                    Icons.check_circle,
                    delivery.completedAt != null 
                        ? DateFormat('MMM dd, HH:mm').format(delivery.completedAt!)
                        : 'Completed',
                    Colors.green[700]!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
} 