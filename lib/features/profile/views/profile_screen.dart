import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/features/auth/controllers/auth_controller.dart';

import '../controllers/profile_controller.dart';
import '../models/profile_models.dart';
import 'widgets/profile_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);
    if (state.status == ProfileStatus.loading) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    if (state.status == ProfileStatus.error) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.triangleAlert,
                  size: 44,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(height: 12),
                Text(state.errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: controller.load,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final data = state.data!;
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('profile-scroll'),
        children: [
          _ProfileHero(data: data),
          const SizedBox(height: 16),
          _ProfileMenu(
            onLogout: () => _confirmLogout(context, ref),
            onDeleteAccount: () => _confirmDeleteAccount(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out?'),
        content: const Text(
          "You'll need to sign in again to access your profile and posts.",
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if ((shouldLogout ?? false) && context.mounted) {
      ref.read(authControllerProvider.notifier).logout();
      // The router redirect sends the signed-out user to the login screen.
    }
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This action is permanent and cannot be undone. All your data, '
          'posts, and reviews will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            onPressed: () => context.pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if ((shouldDelete ?? false) && context.mounted) {
      final error = await ref
          .read(authControllerProvider.notifier)
          .deleteAccount();
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
      // On success the router redirect sends the user to the login screen.
    }
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.data});

  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    final profile = data.profile;
    return ColoredBox(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          children: [
            const SizedBox(height: 16),
            ProfileAvatar(profileAsset: profile.profileAsset),
            const SizedBox(height: 10),
            Text(
              profile.username,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppColors.surface),
            ),
            Text(
              profile.email,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.surface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                profile.profileTitle,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppColors.surface),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Stat(value: profile.communityScore, label: 'Score'),
                const SizedBox(width: 24),
                _Stat(value: data.visits, label: 'Visits'),
                const SizedBox(width: 24),
                _Stat(value: data.reviews, label: 'Reviews'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.surface,
            fontSize: 24,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.surface.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.onLogout, required this.onDeleteAccount});

  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final items = [
      (LucideIcons.pencil, 'Edit Profile', '/profile/edit'),
      (LucideIcons.keyRound, 'Change Password', '/profile/change-password'),
      (LucideIcons.fileText, 'My Posts', '/my-posts'),
      (LucideIcons.map, 'Discovery Journey', '/journey'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        children: [
          for (final item in items) ...[
            _MenuTile(
              key: Key('profile-menu-${item.$3}'),
              icon: item.$1,
              label: item.$2,
              onTap: () => context.push(item.$3),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          _MenuTile(
            key: const Key('profile-delete-account'),
            icon: LucideIcons.trash2,
            label: 'Delete Account',
            destructive: true,
            onTap: onDeleteAccount,
          ),
          const SizedBox(height: 8),
          _MenuTile(
            key: const Key('profile-logout'),
            icon: LucideIcons.logOut,
            label: 'Logout',
            destructive: true,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.destructive : AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: destructive
                ? AppColors.destructive.withValues(alpha: 0.25)
                : AppColors.secondary,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: destructive ? AppColors.destructive : null,
                ),
              ),
            ),
            if (!destructive)
              const Icon(
                LucideIcons.chevronRight,
                size: 20,
                color: AppColors.mutedForeground,
              ),
          ],
        ),
      ),
    );
  }
}
