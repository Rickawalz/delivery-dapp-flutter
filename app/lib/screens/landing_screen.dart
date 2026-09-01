import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  int _logoTapCount = 0;
  bool _showAdminAccess = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[50]!,
              Colors.white,
              Colors.blue[100]!,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo with enhanced design
                  GestureDetector(
                    onTap: _handleLogoTap,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blue[400]!,
                            Colors.blue[600]!,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.local_shipping,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // App Name with enhanced styling
                  Text(
                    'Delivery DApp',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                          letterSpacing: 1.2,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Tagline with better styling
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      'Decentralized delivery tracking for the modern world',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Hidden Admin Access (appears after logo taps)
                  if (_showAdminAccess) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.deepPurple.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.admin_panel_settings, color: Colors.deepPurple.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Developer Access',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              context.go('/login/admin');
                            },
                            icon: const Icon(Icons.security),
                            label: const Text('Admin Login'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Enhanced role selection cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildRoleCard(
                          context,
                          title: 'Customer',
                          subtitle: 'Send packages',
                          icon: Icons.person,
                          color: Colors.blue,
                          onTap: () {
                            context.go('/login/customer');
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildRoleCard(
                          context,
                          title: 'Driver',
                          subtitle: 'Deliver packages',
                          icon: Icons.local_shipping,
                          color: Colors.green,
                          onTap: () {
                            context.go('/login/driver');
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Registration section
                  _buildRegistrationSection(context),
                  
                  const SizedBox(height: 48),
                  
                  // Features section
                  _buildFeaturesSection(context),
                  
                  const SizedBox(height: 32),
                  
                  // Learn more button
                  TextButton.icon(
                    onPressed: () {
                      // TODO: Open documentation/help
                    },
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Learn more about Delivery DApp'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color == Colors.blue ? Colors.blue[800] : Colors.green[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    final features = [
      {'icon': Icons.security, 'title': 'Secure', 'subtitle': 'Blockchain-based security'},
      {'icon': Icons.speed, 'title': 'Fast', 'subtitle': 'Real-time tracking'},
      {'icon': Icons.verified, 'title': 'Reliable', 'subtitle': 'Smart contract guarantees'},
    ];

    return Column(
      children: [
        Text(
          'Why Choose Delivery DApp?',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: features.map((feature) {
            return Expanded(
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      feature['icon'] as IconData,
                      color: Colors.blue[600],
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    feature['title'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    feature['subtitle'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRegistrationSection(BuildContext context) {
    return Column(
      children: [
        Text(
          'New to Delivery DApp?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  context.go('/register?role=customer');
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Register as Customer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  context.go('/register?role=driver');
                },
                icon: const Icon(Icons.local_shipping),
                label: const Text('Register as Driver'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleLogoTap() {
    setState(() {
      _logoTapCount++;
      
      // Show admin access after 5 taps
      if (_logoTapCount >= 5 && !_showAdminAccess) {
        _showAdminAccess = true;
        
        // Show a subtle hint
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Developer access unlocked'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.deepPurple,
          ),
        );
      }
      
      // Reset counter after 10 taps to allow re-unlocking
      if (_logoTapCount >= 10) {
        _logoTapCount = 0;
        _showAdminAccess = false;
      }
    });
  }
} 