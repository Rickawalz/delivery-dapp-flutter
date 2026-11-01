import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/customer/home_screen.dart';
import 'screens/driver/home_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/not_found_screen.dart';
import 'screens/analytics/analytics_dashboard.dart';
import 'screens/admin/admin_home_screen.dart';
import 'services/blockchain/wallet_service.dart';
import 'services/blockchain/walletconnect_service.dart';
import 'services/blockchain/network_info_service.dart';
import 'services/blockchain/contract_service.dart';
import 'services/blockchain/transaction_tracker.dart';
import 'services/delivery/delivery_service.dart';
import 'services/user/user_service.dart';
import 'models/user_role.dart';

Future<void> initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
    
    // Test database connection by adding a test document
    await _testDatabaseConnection();
    
    // Create admin user if it doesn't exist
    await _createAdminUser();
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
  }
}

Future<void> _testDatabaseConnection() async {
  try {
    final firestore = FirebaseFirestore.instance;
    
    // Add a test document to verify connection
    await firestore.collection('test').doc('connection').set({
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'connected',
      'platform': 'web',
    });
    
    print('✅ Database connection test successful');
    
    // Clean up test document
    await firestore.collection('test').doc('connection').delete();
    print('✅ Test document cleaned up');
  } catch (e) {
    print('❌ Database connection test failed: $e');
  }
}

Future<void> _createAdminUser() async {
  try {
    final userService = UserService();
    await userService.createAdminUser();
  } catch (e) {
    print('❌ Failed to create admin user: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadDevHardhatHost();
  
  // Initialize Firebase
  await initializeFirebase();
  

  // Enable clean URLs for web (no hash)
  setUrlStrategy(PathUrlStrategy());
  
  runApp(const MyApp());
}

// Router configuration
final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LandingScreen(),
    ),
    GoRoute(
      path: '/login/:role',
      builder: (context, state) {
        final roleStr = state.pathParameters['role'] ?? 'customer';
        final role = switch (roleStr) {
          'driver' => UserRole.driver,
          'admin' => UserRole.admin,
          _ => UserRole.customer,
        };
        return LoginScreen(role: role);
      },
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) {
        // Extract role from query parameters if available
        final roleStr = state.uri.queryParameters['role'] ?? 'customer';
        final role = roleStr == 'driver' ? UserRole.driver : UserRole.customer;
        return RegistrationScreen(role: role);
      },
    ),
    GoRoute(
      path: '/home/customer',
      builder: (context, state) => const CustomerHomeScreen(),
    ),
    GoRoute(
      path: '/home/driver',
      builder: (context, state) => const DriverHomeScreen(),
    ),
    GoRoute(
      path: '/home/admin',
      builder: (context, state) => const AdminHomeScreen(),
    ),
    GoRoute(
      path: '/analytics',
      builder: (context, state) => const AnalyticsDashboard(),
    ),
  ],
  errorBuilder: (context, state) => const NotFoundScreen(),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WalletService()),
        ChangeNotifierProvider(create: (_) => WalletConnectService()),
        ChangeNotifierProvider(
          create: (_) {
            final userService = UserService();
            userService.initializeUser(); // Restore user from storage on app start
            return userService;
          },
        ),
        ChangeNotifierProxyProvider<WalletConnectService, ContractService>(
          create: (context) => ContractService(
            walletConnectService: Provider.of<WalletConnectService>(context, listen: false),
          ),
          update: (context, walletConnectService, previous) =>
              previous ?? ContractService(walletConnectService: walletConnectService),
        ),
        ChangeNotifierProxyProvider<ContractService, NetworkInfoService>(
          create: (context) => NetworkInfoService(
            Provider.of<ContractService>(context, listen: false).client,
          ),
          update: (context, contractService, previous) =>
              NetworkInfoService(contractService.client),
        ),
        ChangeNotifierProxyProvider<ContractService, TransactionTracker>(
          create: (context) => TransactionTracker(
            Provider.of<ContractService>(context, listen: false).client,
          ),
          update: (context, contractService, previous) =>
              previous ?? TransactionTracker(contractService.client),
        ),
        ChangeNotifierProxyProvider3<WalletConnectService, TransactionTracker, ContractService, DeliveryService>(
          create: (context) => DeliveryService(
            Provider.of<WalletConnectService>(context, listen: false),
            Provider.of<TransactionTracker>(context, listen: false),
            Provider.of<ContractService>(context, listen: false),
          ),
          update: (context, walletConnectService, transactionTracker, contractService, previous) =>
              previous ?? DeliveryService(walletConnectService, transactionTracker, contractService),
        ),
      ],
      child: MaterialApp.router(
        title: 'Delivery DApp',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        routerConfig: _router,
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
