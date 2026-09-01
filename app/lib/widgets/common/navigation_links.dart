import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Navigation links widget for easy navigation between pages
class NavigationLinks extends StatelessWidget {
  final String currentPage; // 'customer', 'driver', or 'admin'

  const NavigationLinks({
    super.key,
    required this.currentPage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home, size: 20, color: Colors.blue),
            const SizedBox(width: 8),
            
            // Home Link
            _buildNavLink(
              context: context,
              label: 'Back to Home',
              icon: Icons.home_outlined,
              route: '/',
              isActive: currentPage == 'home',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavLink({
    required BuildContext context,
    required String label,
    required IconData icon,
    required String route,
    required bool isActive,
  }) {
    return InkWell(
      onTap: isActive ? null : () => context.go(route),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.blue.shade700 : Colors.grey.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.blue.shade700 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

