import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/user_management_controller.dart';
import '../models/admin_models.dart';
import 'widgets/admin_empty_state.dart';
import 'widgets/admin_filter_dropdown.dart';
import 'widgets/admin_page_header.dart';
import 'widgets/admin_search_field.dart';
import 'widgets/admin_skeletons.dart';
import 'widgets/admin_status_badge.dart';
import 'widgets/admin_user_avatar.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userManagementControllerProvider);
    final controller = ref.read(userManagementControllerProvider.notifier);
    return SafeArea(
      bottom: false,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification) {
            final metrics = notification.metrics;
            // Only paginate when the list actually scrolls; on a short list
            // maxScrollExtent is 0 and every scroll gesture would otherwise
            // trigger a page fetch.
            final atEnd =
                metrics.maxScrollExtent > 0 &&
                metrics.pixels >= metrics.maxScrollExtent - 40;
            if (atEnd) {
              controller.loadMore();
            }
          }
          return false;
        },
        child: ListView.builder(
          key: const Key('user-management-scroll'),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          itemCount: _itemCount(state),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildHeader(context, controller, state);
            }
            final userIndex = index - 1;
            if (userIndex < state.users.length) {
              final user = state.users[userIndex];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _UserCard(
                    user: user,
                    accountId: adminUserAccountId(user, state.users),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }

            return _buildFooter(controller, state);
          },
        ),
      ),
    );
  }

  int _itemCount(UserManagementState state) {
    final hasList = state.status != UserManagementStatus.loading;
    final footer = hasList ? 1 : 0;
    return 1 + (hasList ? state.users.length : 0) + footer;
  }

  Widget _buildHeader(
    BuildContext context,
    UserManagementController controller,
    UserManagementState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AdminPageHeader(
          title: 'User Management',
          subtitle: 'Manage user accounts and statuses',
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AdminSearchField(
                hint: 'Search users...',
                value: state.searchQuery,
                onChanged: controller.updateSearch,
                fieldKey: const Key('admin-user-search'),
              ),
            ),
            const SizedBox(width: 8),
            AdminFilterDropdown<UserStatusFilter>(
              value: state.statusFilter,
              options: const [
                ('All statuses', UserStatusFilter.all),
                ('Active', UserStatusFilter.active),
                ('Deactivated', UserStatusFilter.deactivated),
              ],
              onChanged: controller.selectStatusFilter,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AdminFilterDropdown<UserRoleFilter>(
                width: null,
                value: state.roleFilter,
                options: const [
                  ('All roles', UserRoleFilter.all),
                  ('Users', UserRoleFilter.user),
                  ('Admins', UserRoleFilter.admin),
                  ('Managers', UserRoleFilter.manager),
                ],
                onChanged: controller.selectRoleFilter,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (state.status == UserManagementStatus.loading)
          const AdminListSkeleton(count: 5, cardHeight: 112)
        else if (state.status == UserManagementStatus.empty)
          const AdminEmptyState(
            icon: LucideIcons.users,
            title: 'No accounts found.',
            message: 'Try a different search or filter.',
          ),
      ],
    );
  }

  Widget _buildFooter(
    UserManagementController controller,
    UserManagementState state,
  ) {
    if (state.status == UserManagementStatus.error) {
      return _UserManagementError(
        message:
            state.pageError ??
            'Unable to retrieve user accounts. Check your connection and try again.',
        onRetry: controller.loadFirstPage,
      );
    }

    if (state.status == UserManagementStatus.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.pageError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Could not load more users.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: controller.loadMore,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!state.hasMore && state.users.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'All users loaded.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.mutedForeground),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _UserManagementError extends StatelessWidget {
  const _UserManagementError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.triangleAlert,
              size: 44,
              color: AppColors.mutedForeground,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.accountId});

  final AdminUser user;
  final String accountId;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('admin-user-${user.id}'),
      onTap: () => context.go('/admin/users/${user.id}'),
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.secondary),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminUserAvatar(
              initial: user.initial,
              imageUrl: user.profilePictureUrl,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          user.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AdminStatusBadge(
                            label: _statusLabel(user.accountStatus),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: $accountId',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.mutedForeground,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.role == AdminUserRole.admin
                        ? '${user.email} · Administrator'
                        : user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.only(top: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.secondary),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: 'Community score ',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.mutedForeground),
                              children: [
                                TextSpan(
                                  text: '${user.communityScore}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.foreground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          'Manage',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(AdminAccountStatus status) {
    return status == AdminAccountStatus.active ? 'Active' : 'Deactivated';
  }
}
