import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/shared/widgets/demo_mode_switcher.dart';

import '../controllers/admin_auth_controller.dart';
import 'admin_login_screen.dart';
import 'widgets/admin_confirm_dialog.dart';

/// Administrator shell: header, bottom navigation, and auth gate.
class AdminShell extends ConsumerWidget {
  const AdminShell({required this.path, required this.child, super.key});

  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminAuthControllerProvider);
    if (!state.isAuthenticated) {
      return const AdminLoginScreen();
    }
    return ColoredBox(
      color: AppColors.background,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Scaffold(
              body: Column(
                children: [
                  _AdminHeader(onLogout: () => _confirmLogout(context, ref)),
                  Expanded(child: child),
                ],
              ),
              bottomNavigationBar: _AdminNavigation(
                currentPath: path,
                onDestinationSelected: (destination) {
                  context.go(destination);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showAdminConfirmDialog(
      context,
      title: 'Log out?',
      message: 'You will need to sign in again to access administration.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if ((shouldLogout ?? false) && context.mounted) {
      ref.read(adminAuthControllerProvider.notifier).logout();
      context.go('/admin/login');
    }
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.secondary)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: const Icon(
              LucideIcons.utensilsCrossed,
              size: 20,
              color: AppColors.surface,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MakanSpot',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  'Admin Console',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const DemoModeSwitcher(
            compact: true,
            keyPrefix: 'admin-header-switch',
          ),
          IconButton(
            key: const Key('admin-logout'),
            tooltip: 'Log out',
            onPressed: onLogout,
            style: IconButton.styleFrom(
              side: const BorderSide(color: AppColors.secondary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
            ),
            icon: const Icon(
              LucideIcons.logOut,
              size: 20,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminNavigation extends StatelessWidget {
  const _AdminNavigation({
    required this.currentPath,
    required this.onDestinationSelected,
  });

  final String currentPath;
  final ValueChanged<String> onDestinationSelected;

  static const _destinations = <_AdminDestination>[
    _AdminDestination('Dashboard', LucideIcons.layoutDashboard, '/admin'),
    _AdminDestination('Users', LucideIcons.users, '/admin/users'),
    _AdminDestination('Restaurants', LucideIcons.store, '/admin/restaurants'),
    _AdminDestination('Reports', LucideIcons.flag, '/admin/moderation'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.secondary)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final destination in _destinations)
                Expanded(
                  child: _NavigationItem(
                    destination: destination,
                    selected: _isActive(destination.path),
                    onTap: () => onDestinationSelected(destination.path),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isActive(String path) {
    if (path == '/admin') {
      return currentPath == '/admin';
    }
    return currentPath.startsWith(path);
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _AdminDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.mutedForeground;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        key: Key('admin-nav-${destination.label}'),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(destination.icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              destination.label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminDestination {
  const _AdminDestination(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}
