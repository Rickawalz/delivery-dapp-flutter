import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'login_screen.dart';
import '../../models/user_role.dart';

class RegistrationScreen extends StatefulWidget {
  final UserRole role;
  const RegistrationScreen({super.key, required this.role});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  String _username = '';
  String _password = '';
  String _confirmPassword = '';
  String _email = '';
  String _fullName = '';
  String _phone = '';
  String _avatarUrl = '';
  String _address = '';
  String _bio = '';
  String _vehicleType = '';
  String _licenseNumber = '';
  String _preferredPayment = '';
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    String roleText = widget.role == UserRole.customer ? 'Customer' : 'Driver';
    return Scaffold(
      appBar: AppBar(
        title: Text('Register as $roleText'),
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
                  'Register as $roleText',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
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
                            return 'Please enter a username';
                          }
                          return null;
                        },
                        onSaved: (value) => _username = value ?? '',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.badge),
                        ),
                        onSaved: (value) => _fullName = value ?? '',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                        onSaved: (value) => _email = value ?? '',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        onSaved: (value) => _phone = value ?? '',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Profile Picture URL',
                          prefixIcon: Icon(Icons.image),
                        ),
                        onSaved: (value) => _avatarUrl = value ?? '',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          prefixIcon: Icon(Icons.home),
                        ),
                        onSaved: (value) => _address = value ?? '',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Bio',
                          prefixIcon: Icon(Icons.info_outline),
                        ),
                        onSaved: (value) => _bio = value ?? '',
                      ),
                      if (widget.role == UserRole.driver) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Vehicle Type',
                            prefixIcon: Icon(Icons.directions_car),
                          ),
                          onSaved: (value) => _vehicleType = value ?? '',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'License Number',
                            prefixIcon: Icon(Icons.confirmation_number),
                          ),
                          onSaved: (value) => _licenseNumber = value ?? '',
                        ),
                      ],
                      if (widget.role == UserRole.customer) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Preferred Payment',
                            prefixIcon: Icon(Icons.payment),
                          ),
                          onSaved: (value) => _preferredPayment = value ?? '',
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                        onSaved: (value) => _password = value ?? '',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _password) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                        onSaved: (value) => _confirmPassword = value ?? '',
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
                          onPressed: _isLoading ? null : _handleRegister,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Register'),
                        ),
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

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final prefs = await SharedPreferences.getInstance();
    final users = prefs.getStringList('users') ?? [];
    // Check if user already exists
    final exists = users.any((u) {
      final uMap = jsonDecode(u);
      return uMap['username'] == _username && uMap['role'] == widget.role.name;
    });
    if (exists) {
      setState(() {
        _error = 'Username already exists for this role.';
        _isLoading = false;
      });
      return;
    }
    final now = DateTime.now().toIso8601String();
    final userMap = {
      'username': _username,
      'password': _password,
      'role': widget.role.name,
      'email': _email,
      'fullName': _fullName,
      'phone': _phone,
      'avatarUrl': _avatarUrl,
      'address': _address,
      'bio': _bio,
      'createdAt': now,
      'lastLogin': '',
      'status': 'active',
      if (widget.role == UserRole.driver) ...{
        'vehicleType': _vehicleType,
        'licenseNumber': _licenseNumber,
      },
      if (widget.role == UserRole.customer) ...{
        'preferredPayment': _preferredPayment,
      },
    };
    users.add(jsonEncode(userMap));
    await prefs.setStringList('users', users);
    setState(() {
      _isLoading = false;
    });
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful! Please log in.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
} 