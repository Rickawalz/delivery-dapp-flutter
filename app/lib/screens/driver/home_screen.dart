import 'package:flutter/material.dart';
import '../../widgets/common/wallet_connect_section.dart';
import '../../widgets/common/user_profile_section.dart';
import '../../models/user_role.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
      ),
      body: Column(
        children: [
          // User Profile Section
          UserProfileSection(username: 'driverTest', role: UserRole.driver),
          WalletConnectSection(),
          const Expanded(
            child: Center(
              child: Text(
                'Driver dashboard coming soon!',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 