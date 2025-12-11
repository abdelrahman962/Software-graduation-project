import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Row(
                children: [
                  Icon(
                    Icons.local_hospital,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'MedLab System',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            _DrawerNavLink(title: 'Home', icon: Icons.home, route: '/'),
            _DrawerNavLink(
              title: 'About',
              icon: Icons.info_outline,
              route: '/about',
            ),
            _DrawerNavLink(
              title: 'Services',
              icon: Icons.medical_services_outlined,
              route: '/services',
            ),
            _DrawerNavLink(
              title: 'Contact',
              icon: Icons.contact_mail_outlined,
              route: '/contact',
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.goNamed('merged-login');
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Login'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerNavLink extends StatelessWidget {
  final String title;
  final IconData icon;
  final String route;
  const _DrawerNavLink({
    required this.title,
    required this.icon,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = GoRouterState.of(context).uri.path == route;
    return ListTile(
      leading: Icon(
        icon,
        color: isActive
            ? Theme.of(context).colorScheme.primary
            : Colors.grey[700],
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[800],
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        Navigator.of(context).pop();
        context.go(route);
      },
    );
  }
}
