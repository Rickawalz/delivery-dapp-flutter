import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web3dart/web3dart.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/user_role.dart';
import '../../services/user/user_service.dart';

class RegistrationScreen extends StatefulWidget {
  final UserRole role;
  const RegistrationScreen({super.key, required this.role});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _secureStorage = const FlutterSecureStorage();
  final _passwordController = TextEditingController();
  String _username = '';
  String _password = '';
  String _email = '';
  String _fullName = '';
  String _phone = '';
  String _avatarUrl = '';
  String _address = '';
  String _bio = '';
  String _vehicleType = '';
  String _licenseNumber = '';
  String _preferredPayment = '';
  String _privateKey = '';
  bool _isLoading = false;
  String? _error;
  bool _showPrivateKey = false;

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
                      // Private Key Field (Optional)
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Private Key (Optional)',
                          prefixIcon: const Icon(Icons.vpn_key),
                          suffixIcon: IconButton(
                            icon: Icon(_showPrivateKey ? Icons.visibility : Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                _showPrivateKey = !_showPrivateKey;
                              });
                            },
                          ),
                          helperText: 'Keep this secret; stored locally in secure storage',
                        ),
                        obscureText: !_showPrivateKey,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            // Normalize and validate private key
                            final normalized = value.startsWith('0x') ? value : '0x$value';
                            final cleanKey = normalized.substring(2);
                            if (cleanKey.length != 64 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(cleanKey)) {
                              return 'Invalid private key format (must be 64 hex characters)';
                            }
                          }
                          return null;
                        },
                        onSaved: (value) => _privateKey = value ?? '',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
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
                          // Get the password field value from the controller
                          final passwordValue = _passwordController.text;
                          if (value != passwordValue) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
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

    try {
      final userService = context.read<UserService>();
      
      // Check if user already exists
      final exists = await userService.userExists(_username, widget.role);
      if (exists) {
        setState(() {
          _error = 'Username already exists for this role.';
          _isLoading = false;
        });
        return;
      }
      
      // Handle private key if provided
      String? walletAddress;
      if (_privateKey.isNotEmpty) {
        try {
          // Normalize private key
          final normalizedKey = _privateKey.startsWith('0x') ? _privateKey : '0x$_privateKey';
          
          // Create credentials and extract address
          final credentials = EthPrivateKey.fromHex(normalizedKey);
          final address = await credentials.extractAddress();
          walletAddress = address.hex;
          
          // Save private key to secure storage
          await _secureStorage.write(
            key: 'wallet:$_username:${widget.role.name}',
            value: normalizedKey,
          );
        } catch (e) {
          setState(() {
            _error = 'Invalid private key: ${e.toString()}';
            _isLoading = false;
          });
          return;
        }
      }
      
      // Create user in Firebase
      await userService.createUser(
        username: _username,
        password: _password,
        role: widget.role,
        email: _email,
        fullName: _fullName,
        phone: _phone,
        avatarUrl: _avatarUrl,
        address: _address,
        bio: _bio,
        walletAddress: walletAddress,
        vehicleType: _vehicleType,
        licenseNumber: _licenseNumber,
        preferredPayment: _preferredPayment,
      );

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        context.go('/login/${widget.role.name}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Please log in.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Registration failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
} 