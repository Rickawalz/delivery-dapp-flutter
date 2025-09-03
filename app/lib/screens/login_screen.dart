import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'customer/home_screen.dart';
import 'registration_screen.dart';
import '../../models/user_role.dart';

class LoginScreen extends StatefulWidget {
  final UserRole role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String _username = '';
  String _password = '';
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    String roleText = widget.role == UserRole.customer ? 'Customer' : 'Driver';
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
                  widget.role == UserRole.customer ? Icons.person : Icons.local_shipping,
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RegistrationScreen(role: widget.role),
                            ),
                          );
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
    final prefs = await SharedPreferences.getInstance();
    final users = prefs.getStringList('users') ?? [];
    final userIndex = users.indexWhere((u) {
      final uMap = jsonDecode(u);
      return uMap['username'] == _username && uMap['role'] == widget.role.name;
    });
    if (userIndex != -1) {
      final userMap = jsonDecode(users[userIndex]);
      if (userMap['password'] == _password) {
        // Update lastLogin
        userMap['lastLogin'] = DateTime.now().toIso8601String();
        users[userIndex] = jsonEncode(userMap);
        await prefs.setStringList('users', users);
        // Success: Navigate to dashboard
        if (widget.role == UserRole.customer) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const CustomerHomeScreen()),
            (route) => false,
          );
        } else {
          // Placeholder for driver dashboard
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Driver dashboard coming soon!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }
    setState(() {
      _error = 'Invalid username or password';
      _isLoading = false;
    });
  }
} 