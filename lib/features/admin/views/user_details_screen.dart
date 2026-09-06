import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/user_details_controller.dart';
import '../models/admin_models.dart';
import 'widgets/admin_confirm_dialog.dart';
import 'widgets/admin_form_widgets.dart';
import 'widgets/admin_skeletons.dart';
import 'widgets/admin_status_badge.dart';
import 'widgets/admin_user_avatar.dart';

class UserDetailsScreen extends ConsumerWidget {
  const UserDetailsScreen({required this.userId, super.key});

  final String userId;

  Future<void> _toggleStatus(
    BuildContext context,
    WidgetRef ref,
    AdminUser user,
  ) async {
    final activating = user.accountStatus == AdminAccountStatus.deactivated;
    final confirmed = await showAdminConfirmDialog(
      context,
      title: activating ? 'Activate Account?' : 'Deactivate Account?',
      message: activating
          ? 'Are you sure you want to activate this account?'
          : 'Are you sure you want to deactivate this account?',
      confirmLabel: activating ? 'Activate' : 'Deactivate',
      destructive: !activating,
    ) ==
        true;
    if (!confirmed || !context.mounted) return;

    final error = await ref
        .read(userDetailsControllerProvider(userId).notifier)
        .toggleAccountStatus();
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          activating
              ? 'User account activated successfully.'
              : 'User account deactivated successfully.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userDetailsControllerProvider(userId));
    final user = state.user;
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('user-details-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AdminBackButton(
            label: 'Back to Users',
            onPressed: () => context.go('/admin/users'),
          ),
          const SizedBox(height: 16),
          if (state.status == UserDetailsStatus.loading)
            const _UserDetailsSkeleton()
          else if (state.status == UserDetailsStatus.notFound)
            const Text(
              'User not found.',
              style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
            )
          else if (state.status == UserDetailsStatus.error)
            Text(state.errorMessage!, textAlign: TextAlign.center)
          else ...[
            _UserProfileCard(user: user!, accountId: state.accountId ?? ''),
            const SizedBox(height: 24),
            AdminPrimaryButton(
              label: 'Edit Account',
              icon: LucideIcons.pencil,
              buttonKey: const Key('admin-user-edit'),
              onPressed: () => context.go('/admin/users/$userId/edit'),
            ),
            const SizedBox(height: 12),
            AdminOutlineButton(
              label: user.accountStatus == AdminAccountStatus.active
                  ? 'Deactivate Account'
                  : 'Activate Account',
              icon: user.accountStatus == AdminAccountStatus.active
                  ? LucideIcons.userX
                  : LucideIcons.userCheck,
              borderColor: user.accountStatus == AdminAccountStatus.active
                  ? AppColors.destructive
                  : AppColors.success,
              foregroundColor: user.accountStatus == AdminAccountStatus.active
                  ? AppColors.destructive
                  : AppColors.success,
              buttonKey: const Key('admin-user-details-toggle-status'),
              onPressed: () => _toggleStatus(context, ref, user),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  const _UserProfileCard({required this.user, required this.accountId});

  final AdminUser user;
  final String accountId;

  @override
  Widget build(BuildContext context) {
    final mutedStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground);
    final joined = user.joinedAt;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AdminUserAvatar(
                initial: user.initial,
                imageUrl: user.profilePictureUrl,
                size: 64,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(user.email, style: mutedStyle),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        AdminStatusBadge(
                          label: user.accountStatus == AdminAccountStatus.active
                              ? 'Active'
                              : 'Deactivated',
                        ),
                        const SizedBox(width: 8),
                        AdminStatusBadge(label: user.role.label),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _infoRow(
            context,
            'Phone',
            user.phone.isEmpty ? 'Not provided' : user.phone,
          ),
          _infoRow(context, 'Account ID', accountId),
          _infoRow(context, 'Community Score', '${user.communityScore}'),
          if (joined != null) _infoRow(context, 'Joined', _formatDate(joined)),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.foreground),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final months = const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

class _UserDetailsSkeleton extends StatelessWidget {
  const _UserDetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSkeletonBox(height: 32, width: 192, radius: 8),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.secondary),
          ),
          child: const Column(
            children: [
              AdminSkeletonBox(height: 64, width: double.infinity),
              SizedBox(height: 16),
              AdminSkeletonBox(height: 44, width: double.infinity),
              SizedBox(height: 16),
              AdminSkeletonBox(height: 44, width: double.infinity),
            ],
          ),
        ),
      ],
    );
  }
}
