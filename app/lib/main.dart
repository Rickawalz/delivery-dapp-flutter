import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/customer/home_screen.dart';
import 'screens/driver/home_screen.dart';
import 'services/blockchain/wallet_service.dart';
import 'services/delivery/delivery_service.dart';
import 'screens/landing_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

Future<void> ensurePreExistingUsers() async {
  final prefs = await SharedPreferences.getInstance();
  final users = prefs.getStringList('users') ?? [];
  final driverUser = {
    'username': 'driverTest',
    'password': '123456',
    'role': 'driver',
  };
  final customerUser = {
    'username': 'customerTest',
    'password': '78910',
    'role': 'customer',
  };
  bool driverExists = users.any((u) {
    final uMap = jsonDecode(u);
    return uMap['username'] == 'driverTest' && uMap['role'] == 'driver';
  });
  bool customerExists = users.any((u) {
    final uMap = jsonDecode(u);
    return uMap['username'] == 'customerTest' && uMap['role'] == 'customer';
  });
  if (!driverExists) {
    users.add(jsonEncode(driverUser));
  }
  if (!customerExists) {
    users.add(jsonEncode(customerUser));
  }
  await prefs.setStringList('users', users);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensurePreExistingUsers();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WalletService()),
        ChangeNotifierProxyProvider<WalletService, DeliveryService>(
          create: (context) => DeliveryService(
            Provider.of<WalletService>(context, listen: false),
          ),
          update: (context, walletService, previous) =>
              DeliveryService(walletService),
        ),
      ],
      child: MaterialApp(
        title: 'Delivery DApp',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: LandingScreen(),
      ),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Implement authentication logic
    return const CustomerHomeScreen(); // Temporary default to customer view
  }
} 