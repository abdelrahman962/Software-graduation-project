import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/owner_auth_provider.dart';
import '../../config/theme.dart';

class OwnerSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const OwnerSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<OwnerAuthProvider>(context);
    final user = authProvider.user;

    return Container(
      width: 280,
      color: AppTheme.cardColor,
      child: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
            child: Column(
              children: [
                const Icon(Icons.business, size: 48, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  'Lab Owner',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Navigation Sections
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNavSection(context, 'OVERVIEW', [
                    _buildNavItem(context, 'Dashboard', Icons.dashboard, 0),
                  ]),
                  _buildNavSection(context, 'MANAGEMENT', [
                    _buildNavItem(context, 'Staff', Icons.people, 1),
                    _buildNavItem(
                      context,
                      'Doctors',
                      Icons.medical_services,
                      2,
                    ),
                    _buildNavItem(context, 'Orders', Icons.assignment, 3),
                    _buildNavItem(context, 'Tests', Icons.science, 4),
                    _buildNavItem(context, 'Devices', Icons.devices, 5),
                    _buildNavItem(context, 'Inventory', Icons.inventory, 6),
                    _buildNavItem(context, 'Audit Logs', Icons.history, 7),
                  ]),
                  _buildNavSection(context, 'SYSTEM', [
                    _buildNavItem(context, 'My Profile', Icons.person, 8),
                    _buildNavItem(
                      context,
                      'Logout',
                      Icons.logout,
                      -1,
                      onTap: () => _logout(context),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavSection(
    BuildContext context,
    String title,
    List<Widget> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textLight,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...items,
      ],
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    String title,
    IconData icon,
    int index, {
    VoidCallback? onTap,
  }) {
    final isSelected = selectedIndex == index;

    return InkWell(
      onTap: onTap ?? () => onItemSelected(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryBlue : AppTheme.textLight,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.textDark,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.chevron_right, color: AppTheme.primaryBlue, size: 20),
          ],
        ),
      ),
    );
  }

  void _logout(BuildContext context) async {
    final authProvider = Provider.of<OwnerAuthProvider>(context, listen: false);
    await authProvider.logout();
    if (context.mounted) {
      // Small delay to ensure logout is complete before navigation
      await Future.delayed(const Duration(milliseconds: 50));
      if (context.mounted) {
        context.go('/');
      }
    }
  }
}
