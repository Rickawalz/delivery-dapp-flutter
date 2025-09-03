import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/blockchain/wallet_service.dart';
import '../../services/delivery/delivery_service.dart';
import '../../models/delivery.dart';
import '../../widgets/common/wallet_connect_section.dart';
import '../../widgets/common/user_profile_section.dart';
import '../../models/user_role.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery DApp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              // TODO: Implement profile menu
            },
          ),
        ],
      ),
      body: Consumer2<WalletService, DeliveryService>(
        builder: (context, walletService, deliveryService, child) {
          return Column(
            children: [
              // User Profile Section
              UserProfileSection(username: 'customerTest', role: UserRole.customer),
              // Wallet Connect Section
              WalletConnectSection(),

              // Error Message
              if (deliveryService.error != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.red[100],
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          deliveryService.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => deliveryService.clearError(),
                      ),
                    ],
                  ),
                ),
              
              // Loading Indicator
              if (deliveryService.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),

              // Active Deliveries
              Expanded(
                child: deliveryService.deliveries.isEmpty && !deliveryService.isLoading
                    ? const Center(
                        child: Text('No deliveries found'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: deliveryService.deliveries.length,
                        itemBuilder: (context, index) {
                          final delivery = deliveryService.deliveries[index];
                          return DeliveryCard(delivery: delivery);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showCreateDeliveryDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateDeliveryDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String receiverAddress = '';
    String description = '';
    double deliveryValue = 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Delivery'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Receiver Address',
                  hintText: '0x...',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a receiver address';
                  }
                  if (!value.startsWith('0x') || value.length != 42) {
                    return 'Please enter a valid Ethereum address';
                  }
                  return null;
                },
                onSaved: (value) => receiverAddress = value!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter delivery description',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
                onSaved: (value) => description = value!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Value (ETH)',
                  hintText: '0.0',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a value';
                  }
                  final number = double.tryParse(value);
                  if (number == null || number <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
                onSaved: (value) {
                  if (value != null) {
                    deliveryValue = double.parse(value);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.pop(context);
                
                final delivery = await context.read<DeliveryService>().createDelivery(
                  receiverAddress: receiverAddress,
                  description: description,
                  value: deliveryValue,
                );

                if (delivery != null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Delivery created successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class DeliveryCard extends StatelessWidget {
  final Delivery delivery;

  const DeliveryCard({
    super.key,
    required this.delivery,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _buildStatusChip(delivery.status),
              ],
            ),
            const SizedBox(height: 8),
            Text('To: ${delivery.receiverAddress.substring(0, 6)}...${delivery.receiverAddress.substring(38)}'),
            const SizedBox(height: 4),
            Text('Value: ${delivery.value} ETH'),
            const SizedBox(height: 4),
            Text('Description: ${delivery.description}'),
            if (delivery.courierAddress != null) ...[
              const SizedBox(height: 4),
              Text('Courier: ${delivery.courierAddress!.substring(0, 6)}...${delivery.courierAddress!.substring(38)}'),
            ],
            if (delivery.estimatedDeliveryTime != null) ...[
              const SizedBox(height: 4),
              Text('Estimated: ${delivery.estimatedDeliveryTime!.toString().substring(0, 16)}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(DeliveryStatus status) {
    Color color;
    String label;

    switch (status) {
      case DeliveryStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        break;
      case DeliveryStatus.accepted:
        color = Colors.blue;
        label = 'Accepted';
        break;
      case DeliveryStatus.inTransit:
        color = Colors.purple;
        label = 'In Transit';
        break;
      case DeliveryStatus.delivered:
        color = Colors.green;
        label = 'Delivered';
        break;
      case DeliveryStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
        break;
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
    );
  }
} 