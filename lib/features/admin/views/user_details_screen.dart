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

class UserDetailsScreen extends ConsumerStatefulWidget {
  const UserDetailsScreen({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends ConsumerState<UserDetailsScreen> {
  final _usernameController = TextEditingController();
  final _profileTitleController = TextEditingController();
  final _communityScoreController = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _profileTitleController.dispose();
    _communityScoreController.dispose();
    super.dispose();
  }

  void _seed(AdminUser user) {
    _usernameController.text = user.username;
    _profileTitleController.text = user.profileTitle;
    _communityScoreController.text = '${user.communityScore}';
    _seeded = true;
  }

  Future<void> _save() async {
    final error = await ref
        .read(userDetailsControllerProvider(widget.userId).notifier)
        .save(
          rawUsername: _usernameController.text,
          profileTitle: _profileTitleController.text,
          rawCommunityScore: _communityScoreController.text,
        );
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Changes Saved — User information updated.'),
      ),
    );
  }

  Future<void> _toggleStatus() async {
    final state = ref.read(userDetailsControllerProvider(widget.userId));
    final user = state.user;
    if (user == null) {
      return;
    }
    final activating = user.accountStatus == AdminAccountStatus.deactivated;
    final confirmed = await showAdminConfirmDialog(
      context,
      title: activating ? 'Activate Account?' : 'Deactivate Account?',
      message: activating
          ? '${user.username} will regain access to the account.'
          : '${user.username} will no longer be able to use the account '
                'until it is reactivated.',
      confirmLabel: activating ? 'Activate' : 'Deactivate',
      destructive: !activating,
    );
    if ((confirmed ?? false) && mounted) {
      final error = await ref
          .read(userDetailsControllerProvider(widget.userId).notifier)
          .toggleAccountStatus();
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      final nextStatus = activating
          ? AdminAccountStatus.active
          : AdminAccountStatus.deactivated;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${activating ? 'Account Activated' : 'Account Deactivated'} — '
            "${user.username}'s account is now "
            '${nextStatus == AdminAccountStatus.active ? 'active' : 'deactivated'}.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userDetailsControllerProvider(widget.userId));
    final user = state.user;
    if (!_seeded && user != null) {
      _seed(user);
    }
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('user-details-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AdminBackButton(label: 'Back to Users', onPressed: context.pop),
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
            _UserProfileCard(
              user: user!,
              usernameController: _usernameController,
              profileTitleController: _profileTitleController,
              communityScoreController: _communityScoreController,
            ),
            const SizedBox(height: 24),
            AdminPrimaryButton(
              label: 'Save Changes',
              loadingLabel: 'Saving...',
              isLoading: state.isSaving,
              icon: LucideIcons.save,
              buttonKey: const Key('admin-user-save'),
              onPressed: _save,
            ),
            const SizedBox(height: 12),
            AdminOutlineButton(
              label: user.accountStatus == AdminAccountStatus.active
                  ? 'Deactivate'
                  : 'Activate',
              icon: user.accountStatus == AdminAccountStatus.active
                  ? LucideIcons.userX
                  : LucideIcons.userCheck,
              borderColor: user.accountStatus == AdminAccountStatus.active
                  ? AppColors.destructive
                  : AppColors.success,
              foregroundColor: user.accountStatus == AdminAccountStatus.active
                  ? AppColors.destructive
                  : AppColors.success,
              buttonKey: const Key('admin-user-toggle-status'),
              onPressed: _toggleStatus,
            ),
          ],
        ],
      ),
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  const _UserProfileCard({
    required this.user,
    required this.usernameController,
    required this.profileTitleController,
    required this.communityScoreController,
  });

  final AdminUser user;
  final TextEditingController usernameController;
  final TextEditingController profileTitleController;
  final TextEditingController communityScoreController;

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AdminStatusBadge(
                      label: user.accountStatus == AdminAccountStatus.active
                          ? 'Active'
                          : 'Deactivated',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _field(
            label: 'Username',
            child: AdminInputField(
              controller: usernameController,
              hint: '',
              fieldKey: const Key('admin-user-username'),
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Email',
            child: SizedBox(
              height: 44,
              child: TextFormField(
                initialValue: user.email,
                enabled: false,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.secondary,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    borderSide: const BorderSide(color: AppColors.secondary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Profile Title',
            child: AdminInputField(
              controller: profileTitleController,
              hint: '',
              fieldKey: const Key('admin-user-profile-title'),
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Community Score',
            child: AdminInputField(
              controller: communityScoreController,
              hint: '',
              keyboardType: TextInputType.number,
              fieldKey: const Key('admin-user-community-score'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [AdminFieldLabel(label), const SizedBox(height: 8), child],
    );
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
              AdminSkeletonBox(height: 44, width: double.infinity),
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
