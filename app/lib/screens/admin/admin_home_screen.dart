import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/user/user_service.dart';
import '../../services/blockchain/wallet_service.dart';
import '../../services/blockchain/network_info_service.dart';
import '../../services/blockchain/contract_service.dart';
import '../../models/user_role.dart';
import '../../widgets/common/wallet_connect_section.dart';
import '../../widgets/common/user_profile_section.dart';
import '../../widgets/common/network_status_widget.dart';
import '../../widgets/common/navigation_links.dart';
import '../../widgets/governance/decentralization_panel.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allDeliveries = [];
  List<Map<String, dynamic>> _allTransactions = [];
  Map<String, String> _contractAddresses = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userService = context.read<UserService>();
      
      // Fetch all users
      final users = await userService.getAllUsers();
      
      // Fetch all deliveries
      final deliveries = await AnalyticsService.getAllDeliveries();
      
      // Fetch all transactions
      final transactions = await AnalyticsService.getTransactions();

      final contractService = context.read<ContractService>();
      try {
        await contractService.initialize();
      } catch (e) {
        print('Contract config was not loaded: $e');
      }
      final loadedAddresses = contractService.contractAddresses;
      
      // Calculate statistics
      final customerCount = users.where((u) => u['role'] == 'customer').length;
      final driverCount = users.where((u) => u['role'] == 'driver').length;
      final adminCount = users.where((u) => u['role'] == 'admin').length;
      
      final completedDeliveries = deliveries.where((d) => d['status'] == 2).length;
      final activeDeliveries = deliveries.where((d) => d['status'] == 1).length;
      final pendingDeliveries = deliveries.where((d) => d['status'] == 0).length;
      
      final successfulTx = transactions.where((t) => t['status'] == 'success').length;
      final failedTx = transactions.where((t) => t['status'] == 'failed' || t['status'] == 'reverted').length;

      setState(() {
        _allUsers = users;
        _allDeliveries = deliveries;
        _allTransactions = transactions;
        _contractAddresses = loadedAddresses;
        _stats = {
          'totalUsers': users.length,
          'customerCount': customerCount,
          'driverCount': driverCount,
          'adminCount': adminCount,
          'totalDeliveries': deliveries.length,
          'completedDeliveries': completedDeliveries,
          'activeDeliveries': activeDeliveries,
          'pendingDeliveries': pendingDeliveries,
          'totalTransactions': transactions.length,
          'successfulTx': successfulTx,
          'failedTx': failedTx,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading admin data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Analytics Dashboard',
            onPressed: () {
              context.go('/analytics');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _loadAdminData,
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
          isScrollable: false,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 20)),
            Tab(text: 'Users', icon: Icon(Icons.people, size: 20)),
            Tab(text: 'Deliveries', icon: Icon(Icons.local_shipping, size: 20)),
            Tab(text: 'Blockchain', icon: Icon(Icons.storage, size: 20)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Navigation Links
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: NavigationLinks(currentPage: 'admin'),
            ),
            
            // Network Status Widget
            const NetworkStatusWidget(),
            
            // User Profile Section
            UserProfileSection(username: 'admin', role: UserRole.admin),
            
            // Wallet Connect Section
            WalletConnectSection(),

            const DecentralizationPanel(),

            // Tab Content
            SizedBox(
              height: 600, // Fixed height for tab content
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildUsersTab(),
                        _buildDeliveriesTab(),
                        _buildBlockchainTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          Card(
            elevation: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[600]!, Colors.purple[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                      SizedBox(width: 12),
                      Text(
                        'Administrator Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome to the Delivery DApp Admin Panel',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last updated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // User Statistics
          _buildSectionHeader('User Statistics', Icons.people),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Users',
                  '${_stats['totalUsers'] ?? 0}',
                  Icons.group,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Customers',
                  '${_stats['customerCount'] ?? 0}',
                  Icons.person,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Drivers',
                  '${_stats['driverCount'] ?? 0}',
                  Icons.local_shipping,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Admins',
                  '${_stats['adminCount'] ?? 0}',
                  Icons.admin_panel_settings,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Delivery Statistics
          _buildSectionHeader('Delivery Statistics', Icons.local_shipping),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total',
                  '${_stats['totalDeliveries'] ?? 0}',
                  Icons.all_inbox,
                  Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Completed',
                  '${_stats['completedDeliveries'] ?? 0}',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Active',
                  '${_stats['activeDeliveries'] ?? 0}',
                  Icons.local_shipping_outlined,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  '${_stats['pendingDeliveries'] ?? 0}',
                  Icons.pending,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Transaction Statistics
          _buildSectionHeader('Blockchain Statistics', Icons.data_usage),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total TX',
                  '${_stats['totalTransactions'] ?? 0}',
                  Icons.receipt_long,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Success',
                  '${_stats['successfulTx'] ?? 0}',
                  Icons.done_all,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Failed',
                  '${_stats['failedTx'] ?? 0}',
                  Icons.error,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Success Rate',
                  _stats['totalTransactions'] != null && _stats['totalTransactions'] > 0
                      ? '${((_stats['successfulTx'] ?? 0) / _stats['totalTransactions']! * 100).toStringAsFixed(1)}%'
                      : '0%',
                  Icons.trending_up,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quick Actions
          _buildSectionHeader('Quick Actions', Icons.flash_on),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildActionButton(
                'View Analytics',
                Icons.analytics,
                Colors.blue,
                () => context.go('/analytics'),
              ),
              _buildActionButton(
                'Manage Users',
                Icons.people_alt,
                Colors.green,
                () => _tabController.animateTo(1),
              ),
              _buildActionButton(
                'Monitor Deliveries',
                Icons.local_shipping,
                Colors.orange,
                () => _tabController.animateTo(2),
              ),
              _buildActionButton(
                'Blockchain Info',
                Icons.storage,
                Colors.purple,
                () => _tabController.animateTo(3),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        // User count summary
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.purple[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildUserCountChip('All', _allUsers.length, Colors.blue),
              _buildUserCountChip('Customers', _stats['customerCount'] ?? 0, Colors.green),
              _buildUserCountChip('Drivers', _stats['driverCount'] ?? 0, Colors.orange),
              _buildUserCountChip('Admins', _stats['adminCount'] ?? 0, Colors.purple),
            ],
          ),
        ),
        
        // Users list
        Expanded(
          child: _allUsers.isEmpty
              ? _buildEmptyState(
                  icon: Icons.people_outline,
                  title: 'No Users Found',
                  subtitle: 'No users have been registered yet',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _allUsers.length,
                  itemBuilder: (context, index) {
                    final user = _allUsers[index];
                    return _buildUserCard(user);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDeliveriesTab() {
    return Column(
      children: [
        // Delivery count summary
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildUserCountChip('All', _allDeliveries.length, Colors.indigo),
              _buildUserCountChip('Pending', _stats['pendingDeliveries'] ?? 0, Colors.orange),
              _buildUserCountChip('Active', _stats['activeDeliveries'] ?? 0, Colors.blue),
              _buildUserCountChip('Done', _stats['completedDeliveries'] ?? 0, Colors.green),
            ],
          ),
        ),
        
        // Deliveries list
        Expanded(
          child: _allDeliveries.isEmpty
              ? _buildEmptyState(
                  icon: Icons.local_shipping_outlined,
                  title: 'No Deliveries Found',
                  subtitle: 'No deliveries have been created yet',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _allDeliveries.length,
                  itemBuilder: (context, index) {
                    final delivery = _allDeliveries[index];
                    return _buildDeliveryCard(delivery);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBlockchainTab() {
    return Consumer<NetworkInfoService>(
      builder: (context, networkInfo, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Network Information', Icons.network_check),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoRow('Chain ID', networkInfo.rpcChainId?.toString() ?? 'Not connected'),
                      _buildInfoRow('Network', networkInfo.rpcNetworkName),
                      _buildInfoRow('Status', networkInfo.statusMessage),
                      _buildInfoRow('RPC URL', networkInfo.rpcUrl),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _buildSectionHeader('Contract Addresses', Icons.description),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _contractAddresses.isEmpty
                      ? const Text('No contract addresses loaded')
                      : Column(
                          children: _contractAddresses.entries
                              .map((entry) => _buildAddressRow(entry.key, entry.value))
                              .toList(),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              _buildSectionHeader('Recent Transactions', Icons.receipt_long),
              const SizedBox(height: 12),
              _allTransactions.isEmpty
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No transactions recorded yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: _allTransactions.take(10).map((tx) {
                        return _buildTransactionCard(tx);
                      }).toList(),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.purple[600], size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: (MediaQuery.of(context).size.width - 48) / 2,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCountChip(String label, int count, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          count.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = user['role'] as String?;
    final username = user['username'] as String?;
    final email = user['email'] as String?;
    final walletAddress = user['walletAddress'] as String?;
    final status = user['status'] as String? ?? 'active';
    
    Color roleColor;
    IconData roleIcon;
    
    switch (role) {
      case 'admin':
        roleColor = Colors.purple;
        roleIcon = Icons.admin_panel_settings;
        break;
      case 'driver':
        roleColor = Colors.orange;
        roleIcon = Icons.local_shipping;
        break;
      default:
        roleColor = Colors.green;
        roleIcon = Icons.person;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.2),
          child: Icon(roleIcon, color: roleColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                username ?? 'Unknown User',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                role?.toUpperCase() ?? 'UNKNOWN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: roleColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (email != null && email.isNotEmpty)
              Text('📧 $email', style: const TextStyle(fontSize: 12)),
            if (walletAddress != null && walletAddress.isNotEmpty)
              Text(
                '🔗 ${walletAddress.substring(0, 6)}...${walletAddress.substring(walletAddress.length - 4)}',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  status == 'active' ? Icons.check_circle : Icons.cancel,
                  size: 12,
                  color: status == 'active' ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: status == 'active' ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            _showUserOptions(context, user);
          },
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery) {
    final id = delivery['id'] as String?;
    final status = delivery['status'] as int? ?? 0;
    final customer = delivery['customer'] as String?;
    final courier = delivery['courier'] as String?;
    final amount = delivery['fiatAmountCents'] as int? ?? 0;
    
    String statusText;
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 0:
        statusText = 'Pending';
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 1:
        statusText = 'Active';
        statusColor = Colors.blue;
        statusIcon = Icons.local_shipping;
        break;
      case 2:
        statusText = 'Completed';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 3:
        statusText = 'Cancelled';
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusText = 'Unknown';
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Delivery #${id?.substring(0, 8) ?? 'Unknown'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              '💰 \$${(amount / 100).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            if (customer != null)
              Text(
                '👤 ${customer.substring(0, 6)}...${customer.substring(customer.length - 4)}',
                style: const TextStyle(fontSize: 11),
              ),
            if (courier != null)
              Text(
                '🚚 ${courier.substring(0, 6)}...${courier.substring(courier.length - 4)}',
                style: const TextStyle(fontSize: 11),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          _showDeliveryDetails(context, delivery);
        },
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final txHash = tx['txHash'] as String?;
    final status = tx['status'] as String?;
    final type = tx['type'] as String?;
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'success':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      default:
        statusColor = Colors.red;
        statusIcon = Icons.error;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(
          type?.toUpperCase() ?? 'TRANSACTION',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        subtitle: Text(
          '${txHash?.substring(0, 10) ?? 'Unknown'}...${txHash != null && txHash.length > 14 ? txHash.substring(txHash.length - 4) : ''}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Chip(
          label: Text(
            status?.toUpperCase() ?? 'UNKNOWN',
            style: TextStyle(fontSize: 9, color: statusColor),
          ),
          backgroundColor: statusColor.withOpacity(0.1),
          side: BorderSide(color: statusColor.withOpacity(0.3)),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(String label, String address) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${address.substring(0, 6)}...${address.substring(address.length - 4)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
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
              onTap: () {
                Navigator.pop(context);
                context.go('/');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUserOptions(BuildContext context, Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user['username'] ?? 'User Options',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _showUserDetails(context, user);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Suspend User'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement user suspension
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User suspension not yet implemented')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete User'),
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement user deletion with confirmation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User deletion not yet implemented')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetails(BuildContext context, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Details: ${user['username'] ?? 'Unknown'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Role', user['role']?.toString() ?? 'Unknown'),
              _buildDetailRow('Email', user['email']?.toString() ?? 'N/A'),
              _buildDetailRow('Full Name', user['fullName']?.toString() ?? 'N/A'),
              _buildDetailRow('Phone', user['phone']?.toString() ?? 'N/A'),
              _buildDetailRow('Status', user['status']?.toString() ?? 'N/A'),
              if (user['walletAddress'] != null)
                _buildDetailRow('Wallet', user['walletAddress'].toString()),
              if (user['vehicleType'] != null)
                _buildDetailRow('Vehicle', user['vehicleType'].toString()),
              if (user['licenseNumber'] != null)
                _buildDetailRow('License', user['licenseNumber'].toString()),
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

  void _showDeliveryDetails(BuildContext context, Map<String, dynamic> delivery) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delivery #${delivery['id']?.toString().substring(0, 8) ?? 'Unknown'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Status', _getStatusText(delivery['status'] as int? ?? 0)),
              _buildDetailRow('Amount', '\$${((delivery['fiatAmountCents'] as int? ?? 0) / 100).toStringAsFixed(2)}'),
              _buildDetailRow('Customer', delivery['customer']?.toString() ?? 'N/A'),
              _buildDetailRow('Driver', delivery['courier']?.toString() ?? 'N/A'),
              if (delivery['distanceMeters'] != null)
                _buildDetailRow('Distance', '${((delivery['distanceMeters'] as int) / 1000).toStringAsFixed(2)} km'),
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

  String _getStatusText(int status) {
    switch (status) {
      case 0:
        return 'Created/Pending';
      case 1:
        return 'In Progress';
      case 2:
        return 'Completed';
      case 3:
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }
}
