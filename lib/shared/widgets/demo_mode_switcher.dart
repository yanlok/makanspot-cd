import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/router/app_router.dart';
import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/features/admin/controllers/admin_auth_controller.dart';

/// TEMPORARY prototype navigation aid: two small pills that jump between the
/// customer app and the admin console. The Admin pill opens the admin login
/// (which signs in with the admin account), the User pill returns to the
/// customer home. Remove once the app has a real entry flow.
class DemoModeSwitcher extends ConsumerWidget {
  const DemoModeSwitcher({
    this.compact = false,
    this.keyPrefix = 'demo-switch',
    super.key,
  });

  /// When true, renders icon-only pills sized for the admin shell header.
  final bool compact;

  /// Prefix for the pill keys, so multiple instances can coexist.
  final String keyPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(adminAuthControllerProvider.notifier);
    final padding = EdgeInsets.only(
      top: compact ? 0 : 8,
      right: compact ? 0 : 8,
    );
    return SafeArea(
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModePill(
              key: Key('$keyPrefix-user'),
              label: 'User',
              tooltip: 'Go to the customer app',
              icon: LucideIcons.user,
              compact: compact,
              onTap: () {
                auth.exitDemoSession();
                context.go(AppRoutes.home);
              },
            ),
            const SizedBox(width: 8),
            _ModePill(
              key: Key('$keyPrefix-admin'),
              label: 'Admin',
              tooltip: 'Go to the admin login',
              icon: LucideIcons.shield,
              compact: compact,
              onTap: () {
                auth.exitDemoSession();
                context.go(AppRoutes.adminLogin);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.compact,
    required this.onTap,
    super.key,
  });

  final String label;
  final String tooltip;
  final IconData icon;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (compact) {
      content = SizedBox.square(
        dimension: 36,
        child: Icon(icon, size: 16, color: AppColors.foreground),
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
      );
    }
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: content,
          ),
        ),
      ),
    );
  }
}
