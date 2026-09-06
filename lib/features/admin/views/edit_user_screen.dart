import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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

class EditUserScreen extends ConsumerStatefulWidget {
  const EditUserScreen({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends ConsumerState<EditUserScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _accountIdController = TextEditingController();
  final _communityScoreController = TextEditingController();
  AdminUserRole _role = AdminUserRole.user;
  bool _seeded = false;
  String? _errorMessage;
  Set<UserAccountField> _invalidFields = const {};

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _accountIdController.dispose();
    _communityScoreController.dispose();
    super.dispose();
  }

  void _seed(AdminUser user, String accountId) {
    _usernameController.text = user.username;
    _emailController.text = user.email;
    _phoneController.text = user.phone;
    _accountIdController.text = accountId;
    _communityScoreController.text = '${user.communityScore}';
    _role = user.role;
    _seeded = true;
  }

  Future<void> _save() async {
    setState(() {
      _errorMessage = null;
      _invalidFields = const {};
    });
    final result = await ref
        .read(userDetailsControllerProvider(widget.userId).notifier)
        .save(
          rawUsername: _usernameController.text,
          rawEmail: _emailController.text,
          rawPhone: _phoneController.text,
          role: _role,
          rawCommunityScore: _communityScoreController.text,
        );
    if (!mounted) {
      return;
    }
    if (result.error != null) {
      setState(() {
        _errorMessage = result.error;
        _invalidFields = result.invalidFields;
      });
      return;
    }
    _accountIdController.text =
        ref.read(userDetailsControllerProvider(widget.userId)).accountId ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User account details updated successfully.'),
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
          ? 'Are you sure you want to activate this account?'
          : 'Are you sure you want to deactivate this account?',
      confirmLabel: activating ? 'Activate' : 'Deactivate',
      destructive: !activating,
    ) ==
        true;
    if (confirmed && mounted) {
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            activating
                ? 'User account activated successfully.'
                : 'User account deactivated successfully.',
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
      _seed(user, state.accountId ?? '');
    }
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('edit-user-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AdminBackButton(
            label: 'Back to Details',
            onPressed: () => context.go('/admin/users/${widget.userId}'),
          ),
          const SizedBox(height: 16),
          if (state.status == UserDetailsStatus.loading)
            const _EditUserSkeleton()
          else if (state.status == UserDetailsStatus.notFound)
            const Text(
              'User not found.',
              style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
            )
          else if (state.status == UserDetailsStatus.error)
            Text(state.errorMessage!, textAlign: TextAlign.center)
          else ...[
            _EditFormCard(
              user: user!,
              usernameController: _usernameController,
              emailController: _emailController,
              phoneController: _phoneController,
              accountIdController: _accountIdController,
              communityScoreController: _communityScoreController,
              role: _role,
              invalidFields: _invalidFields,
              onRoleChanged: (value) => setState(() => _role = value),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                key: const Key('edit-user-error'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.destructive,
                ),
              ),
            ],
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
              buttonKey: const Key('admin-user-toggle-status'),
              onPressed: _toggleStatus,
            ),
          ],
        ],
      ),
    );
  }
}

class _EditFormCard extends StatelessWidget {
  const _EditFormCard({
    required this.user,
    required this.usernameController,
    required this.emailController,
    required this.phoneController,
    required this.accountIdController,
    required this.communityScoreController,
    required this.role,
    required this.invalidFields,
    required this.onRoleChanged,
  });

  final AdminUser user;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController accountIdController;
  final TextEditingController communityScoreController;
  final AdminUserRole role;
  final Set<UserAccountField> invalidFields;
  final ValueChanged<AdminUserRole> onRoleChanged;

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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
            label: 'Name *',
            child: AdminInputField(
              controller: usernameController,
              hint: 'Enter full name',
              helperText: 'Cannot accept spaces. Letters and underscores only.',
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ_]'),
                ),
              ],
              fieldKey: const Key('admin-user-username'),
              hasError: invalidFields.contains(UserAccountField.username),
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Email *',
            child: AdminInputField(
              controller: emailController,
              hint: 'name@gmail.com',
              helperText: 'Enter a valid email address',
              keyboardType: TextInputType.emailAddress,
              fieldKey: const Key('admin-user-email'),
              hasError: invalidFields.contains(UserAccountField.email),
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Phone Number *',
            child: AdminInputField(
              controller: phoneController,
              hint: '012-3456789',
              helperText: 'Enter a valid phone number',
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
              ],
              fieldKey: const Key('admin-user-phone'),
              hasError: invalidFields.contains(UserAccountField.phone),
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Role',
            child: AdminSelectField<AdminUserRole>(
              value: role,
              options: const [
                ('User', AdminUserRole.user),
                ('Admin', AdminUserRole.admin),
                ('Manager', AdminUserRole.manager),
              ],
              onChanged: onRoleChanged,
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Account ID',
            child: AdminInputField(
              controller: accountIdController,
              hint: 'System generated',
              helperText: 'System generated and cannot be edited.',
              enabled: false,
              fieldKey: const Key('admin-user-account-id'),
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
              hasError: invalidFields.contains(UserAccountField.communityScore),
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

class _EditUserSkeleton extends StatelessWidget {
  const _EditUserSkeleton();

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
