import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../../models/user_role.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo Placeholder
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.local_shipping, size: 60, color: Colors.blue),
                  ),
                ),
                const SizedBox(height: 24),
                // App Name
                Text(
                  'Delivery DApp',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Tagline/Description
                Text(
                  'A decentralized delivery tracking application for web and mobile.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Role Selection
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(role: UserRole.customer),
                            ),
                          );
                        },
                        child: const Text('Continue as Customer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(role: UserRole.driver),
                            ),
                          );
                        },
                        child: const Text('Continue as Driver'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Optional: Link to docs/help
                TextButton(
                  onPressed: () {
                    // TODO: Open documentation/help
                  },
                  child: const Text('Learn more / Documentation'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 