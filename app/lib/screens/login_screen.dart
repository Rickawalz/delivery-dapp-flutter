import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../../models/user_role.dart';
import '../../services/blockchain/wallet_service.dart';
import '../../services/user/user_service.dart';

class LoginScreen extends StatefulWidget {
  final UserRole role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _secureStorage = const FlutterSecureStorage();
  String _username = '';
  String _password = '';
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    String roleText = widget.role == UserRole.customer
        ? 'Customer'
        : widget.role == UserRole.driver
            ? 'Driver'
            : 'Administrator';
    return Scaffold(
      appBar: AppBar(
        title: Text('Login as $roleText'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  widget.role == UserRole.customer
                      ? Icons.person
                      : widget.role == UserRole.driver
                          ? Icons.local_shipping
                          : Icons.admin_panel_settings,
                  size: 64,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                Text(
                  'Login as $roleText',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                // Username/Password Login
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: widget.role == UserRole.customer
                            ? 'customerTest'
                            : widget.role == UserRole.driver
                                ? 'driverTest'
                                : 'admin',
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your username';
                          }
                          return null;
                        },
                        onSaved: (value) => _username = value ?? '',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: widget.role == UserRole.customer
                            ? '78910'
                            : widget.role == UserRole.driver
                                ? '123456'
                                : 'admin123',
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                        onSaved: (value) => _password = value ?? '',
                      ),
                      const SizedBox(height: 24),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(_error!, style: const TextStyle(color: Colors.red)),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Login'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          context.go('/register?role=${widget.role.name}');
                        },
                        child: const Text('Don\'t have an account? Register'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userService = context.read<UserService>();
      final user = await userService.getUser(_username, widget.role);
      
      if (user != null && user['password'] == _password) {
        // Update last login
        await userService.updateLastLogin(user['id']);
        
        // Set current user in UserService
        userService.setCurrentUser(_username, widget.role);
        
        // Auto-connect wallet if private key exists
        await _autoConnectWallet();
        
        if (widget.role == UserRole.customer) {
          context.go('/home/customer');
        } else if (widget.role == UserRole.driver) {
          context.go('/home/driver');
        } else {
          context.go('/home/admin');
        }
        return;
      }
    } catch (e) {
      print('Login error: $e');
    }
    
    setState(() {
      _error = 'Invalid username or password';
      _isLoading = false;
    });
  }

  Future<void> _autoConnectWallet() async {
    try {
      // Check if user has a private key stored
      final privateKeyKey = 'wallet:$_username:${widget.role.name}';
      final privateKey = await _secureStorage.read(key: privateKeyKey);
      
      if (privateKey != null && privateKey.isNotEmpty) {
        // Get WalletService from context and connect with private key
        final walletService = Provider.of<WalletService>(context, listen: false);
        await walletService.connectWithPrivateKey(privateKey);
        print('✅ Wallet auto-connected for user: $_username');
      } else {
        print('ℹ️ No private key found for user: $_username');
      }
    } catch (e) {
      print('❌ Failed to auto-connect wallet: $e');
      // Don't show error to user, just log it
      // User can still use the app without wallet connection
    }
  }
} 