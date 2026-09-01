import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/blockchain/wallet_service.dart';
import '../../services/blockchain/walletconnect_service.dart';
import '../../services/delivery/delivery_service.dart';
import '../../services/user/user_service.dart';
import '../../models/delivery.dart';
import '../../models/user_role.dart';
import '../../widgets/common/wallet_connect_section.dart';
import '../../widgets/delivery/delivery_card.dart';
import '../../widgets/delivery/create_delivery_dialog.dart';
import '../../widgets/delivery/delivery_stats_widget.dart';
import '../../widgets/common/firebase_status_widget.dart';
import '../../widgets/common/network_status_widget.dart';
import '../../widgets/common/navigation_links.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch deliveries when the screen is first loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryService>().fetchUserDeliveries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userService = Provider.of<UserService>(context);
    final username = userService.currentUsername ?? 'Unknown';
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('My Deliveries'),
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
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              context.go('/analytics');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<DeliveryService>().fetchUserDeliveries();
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              _showProfileMenu(context);
            },
          ),
        ],
      ),
      body: Consumer<DeliveryService>(
        builder: (context, deliveryService, child) {
          return SingleChildScrollView(
            child: Column(
              children: [
                // Navigation Links
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: NavigationLinks(currentPage: 'customer'),
                ),
                
                // Firebase Status Widget (for testing)
                const FirebaseStatusWidget(),
                
                        // Network Status Widget
                        const NetworkStatusWidget(),
                        
                        // Wallet Connect Section
                        WalletConnectSection(),

                
                // Loading Indicator
                if (deliveryService.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),

                // Delivery Statistics
                if (!deliveryService.isLoading && deliveryService.deliveries.isNotEmpty)
                  DeliveryStatsWidget(deliveries: deliveryService.deliveries),

                // Active Deliveries
                if (deliveryService.deliveries.isEmpty && !deliveryService.isLoading)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: _buildEmptyState(),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: deliveryService.deliveries.length,
                    itemBuilder: (context, index) {
                      final delivery = deliveryService.deliveries[index];
                      return DeliveryCard(
                        delivery: delivery,
                        onTap: () => _showDeliveryDetails(context, delivery),
                      );
                    },
                  ),
                
                // Add some bottom padding to prevent overflow
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateDeliveryDialog(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('New Delivery'),
        backgroundColor: Colors.blue[600],
      ),
    );
  }


  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No deliveries yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first delivery to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
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

  void _showDeliveryDetails(BuildContext context, Delivery delivery) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delivery #${delivery.id.substring(0, 8)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Status', _getStatusText(delivery.status)),
              _buildDetailRow('Description', delivery.description ?? 'No description'),
              _buildDetailRow('Amount', '\$${delivery.fiatAmountUSD.toStringAsFixed(2)}'),
              _buildDetailRow('Distance', '${delivery.distanceKm.toStringAsFixed(1)} km'),
              _buildDetailRow('Driver', '${delivery.driverAddress.substring(0, 6)}...${delivery.driverAddress.substring(delivery.driverAddress.length - 4)}'),
              _buildDetailRow('Created', DateFormat('MMM dd, yyyy HH:mm').format(delivery.createdAt)),
              if (delivery.completedAt != null)
                _buildDetailRow('Completed', DateFormat('MMM dd, yyyy HH:mm').format(delivery.completedAt!)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
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

  void _showCreateDeliveryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateDeliveryDialog(),
    );
  }
}

