import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/features/auth/controllers/auth_controller.dart';

import '../controllers/profile_controller.dart';
import '../models/profile_models.dart';

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
          _ProfileHero(data: data, onBack: context.pop),
          const SizedBox(height: 16),
          _ProgressCard(score: data.profile.communityScore),
          const SizedBox(height: 18),
          _AccountSummarySection(state: state, controller: controller),
          if (data.earnedBadges.isNotEmpty) _BadgeSection(data: data),
          _ProfileMenu(onLogout: () => _confirmLogout(context, ref)),
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
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.data, required this.onBack});

  final ProfileData data;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final profile = data.profile;
    return ColoredBox(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                color: AppColors.surface,
                icon: const Icon(LucideIcons.chevronLeft),
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 16),
                ClipOval(
                  child: Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(4),
                    color: AppColors.surface,
                    child: ClipOval(
                      child: Image.asset(
                        profile.profileAsset,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
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
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ProfileLabelChip(
                      label: 'Role: ${_labelize(profile.role)}',
                    ),
                    const SizedBox(width: 8),
                    _ProfileLabelChip(
                      label: 'Status: ${_labelize(profile.accountStatus)}',
                    ),
                  ],
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
          ],
        ),
      ),
    );
  }
}

class _ProfileLabelChip extends StatelessWidget {
  const _ProfileLabelChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppColors.surface),
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Next: Makan Sifu',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '$score/300',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 300,
              minHeight: 8,
              backgroundColor: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeSection extends StatelessWidget {
  const _BadgeSection({required this.data});

  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Badges', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Row(
            children: data.earnedBadges
                .map(
                  (badge) => Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        right: badge == data.earnedBadges.last ? 0 : 8,
                      ),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: AppColors.secondary),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              LucideIcons.award,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            badge,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _AccountSummarySection extends StatelessWidget {
  const _AccountSummarySection({required this.state, required this.controller});

  final ProfileState state;
  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Registered Accounts',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Search and filter by name, email, role, and status.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('profile-account-search'),
            onChanged: controller.updateAccountSearch,
            decoration: const InputDecoration(
              prefixIcon: Icon(LucideIcons.search),
              hintText: 'Search name or email',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<AccountRoleFilter>(
                  key: const Key('profile-account-role-filter'),
                  isExpanded: true,
                  value: state.roleFilter,
                  items: const [
                    DropdownMenuItem(
                      value: AccountRoleFilter.all,
                      child: Text('All roles'),
                    ),
                    DropdownMenuItem(
                      value: AccountRoleFilter.user,
                      child: Text('User'),
                    ),
                    DropdownMenuItem(
                      value: AccountRoleFilter.admin,
                      child: Text('Admin'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      controller.selectRoleFilter(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<AccountStatusFilter>(
                  key: const Key('profile-account-status-filter'),
                  isExpanded: true,
                  value: state.statusFilter,
                  items: const [
                    DropdownMenuItem(
                      value: AccountStatusFilter.all,
                      child: Text('All statuses'),
                    ),
                    DropdownMenuItem(
                      value: AccountStatusFilter.active,
                      child: Text('Active'),
                    ),
                    DropdownMenuItem(
                      value: AccountStatusFilter.pending,
                      child: Text('Pending'),
                    ),
                    DropdownMenuItem(
                      value: AccountStatusFilter.deactivated,
                      child: Text('Deactivated'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      controller.selectStatusFilter(value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AccountSummaryContent(state: state, controller: controller),
        ],
      ),
    );
  }
}

class _AccountSummaryContent extends StatelessWidget {
  const _AccountSummaryContent({required this.state, required this.controller});

  final ProfileState state;
  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    if (state.accountListStatus == AccountListStatus.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.accountListStatus == AccountListStatus.error) {
      return _AccountSummaryState(
        icon: LucideIcons.triangleAlert,
        title: 'Unable to Load Accounts',
        message:
            state.accountErrorMessage ??
            'Something went wrong while retrieving account summaries.',
        actionLabel: 'Retry',
        onAction: controller.reloadAccountSummaries,
      );
    }
    if (state.accountListStatus == AccountListStatus.empty) {
      return const _AccountSummaryState(
        icon: LucideIcons.users,
        title: 'No Accounts Yet',
        message: 'No registered accounts are available right now.',
      );
    }
    if (state.accountListStatus == AccountListStatus.noResults) {
      return _AccountSummaryState(
        icon: LucideIcons.searchX,
        title: 'No Results',
        message: 'No accounts matched your current search and filters.',
        actionLabel: state.hasAccountFilters ? 'Clear Filters' : null,
        onAction: state.hasAccountFilters
            ? controller.clearAccountFilters
            : null,
      );
    }
    return Column(
      children: [
        for (final account in state.accountSummaries) ...[
          _AccountSummaryCard(account: account),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AccountSummaryState extends StatelessWidget {
  const _AccountSummaryState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.mutedForeground),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _AccountSummaryCard extends StatelessWidget {
  const _AccountSummaryCard({required this.account});

  final DemoRegisteredAccount account;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('profile-account-${account.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: Image.asset(
              account.photoUrl,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                color: AppColors.secondary,
                child: Text(
                  account.initial,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _StatusBadge(label: _labelize(account.status)),
                  ],
                ),
                Text(
                  account.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  account.bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _RoleBadge(label: _labelize(account.role)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppColors.secondaryForeground),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    Color background = AppColors.secondary;
    Color foreground = AppColors.mutedForeground;
    if (normalized == 'active') {
      background = AppColors.success.withValues(alpha: 0.15);
      foreground = AppColors.success;
    } else if (normalized == 'pending') {
      background = AppColors.accent.withValues(alpha: 0.15);
      foreground = AppColors.foreground;
    } else if (normalized == 'deactivated') {
      background = AppColors.destructive.withValues(alpha: 0.15);
      foreground = AppColors.destructive;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: foreground),
      ),
    );
  }
}

String _labelize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final items = [
      (LucideIcons.pencil, 'Edit Profile', '/profile/edit'),
      (LucideIcons.keyRound, 'Change Password', '/profile/change-password'),
      (LucideIcons.fileText, 'My Posts', '/my-posts'),
      (LucideIcons.map, 'Discovery Journey', '/journey'),
      (LucideIcons.award, 'Achievements & Progress', '/achievements'),
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
              onTap: () => context.go(item.$3),
            ),
            const SizedBox(height: 8),
          ],
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
