import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/admin_action_log_controller.dart';
import '../models/admin_models.dart';
import 'widgets/admin_empty_state.dart';
import 'widgets/admin_page_header.dart';
import 'widgets/admin_skeletons.dart';

class AdminActionLogScreen extends ConsumerWidget {
  const AdminActionLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminActionLogControllerProvider);
    final controller = ref.read(adminActionLogControllerProvider.notifier);
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('admin-action-log-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          const AdminPageHeader(
            title: 'Admin Action Log',
            subtitle: 'Review changes made to users and restaurants',
          ),
          const SizedBox(height: 20),
          if (state.status == AdminActionLogStatus.loading)
            const AdminListSkeleton(count: 4, cardHeight: 236)
          else if (state.status == AdminActionLogStatus.error)
            _ActionLogError(
              message: state.errorMessage!,
              onRetry: controller.load,
            )
          else if (state.status == AdminActionLogStatus.empty)
            const AdminEmptyState(
              icon: LucideIcons.scrollText,
              title: 'No actions recorded',
              message: 'Administrative actions will appear here.',
            )
          else
            for (final entry in state.entries) ...[
              _ActionLogCard(entry: entry),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _ActionLogError extends StatelessWidget {
  const _ActionLogError({required this.message, required this.onRetry});

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

class _ActionLogCard extends StatelessWidget {
  const _ActionLogCard({required this.entry});

  final AdminAuditLog entry;

  @override
  Widget build(BuildContext context) {
    final valueStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.foreground);
    final changedFields = entry.fieldChanges.entries
        .where((field) => field.value.from != field.value.to)
        .toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LogRow(
            label: 'Admin',
            value: entry.adminUsername,
            style: valueStyle,
          ),
          _LogRow(
            label: 'Action',
            value: _actionLabel(entry.action),
            style: valueStyle,
          ),
          _LogRow(
            label: entry.action == 'update_restaurant' ||
                    entry.action == 'remove_restaurant'
                ? 'Restaurant'
                : 'User',
            value: entry.targetUsername,
            style: valueStyle,
          ),
          for (final field in changedFields) ...[
            const SizedBox(height: 8),
            _LogRow(
              label: 'Field',
              value: _fieldLabel(field.key),
              style: valueStyle,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 64),
              child: Text(
                '${_displayValue(field.key, field.value.from)} → ${_displayValue(field.key, field.value.to)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: AppColors.secondary, height: 1),
          const SizedBox(height: 12),
          _LogRow(
            label: 'Date/Time',
            value: _formatDateTime(entry.createdAt),
            style: valueStyle,
          ),
        ],
      ),
    );
  }

  static String _actionLabel(String action) => switch (action) {
    'update_user' => 'Update User Account',
    'toggle_account_status' => 'Update Account Status',
    'update_restaurant' => 'Update Restaurant Information',
    'remove_restaurant' => 'Remove Restaurant',
    _ =>
      action
          .split('_')
          .map(
            (word) => word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1)}',
          )
          .join(' '),
  };

  static String _fieldLabel(String field) => switch (field) {
    'username' => 'Name',
    'email' => 'Email',
    'phone' => 'Phone',
    'role' => 'Role',
    'community_score' => 'Community Score',
    'is_active' => 'Account Status',
    'cuisine' => 'Cuisine',
    'address' => 'Address',
    'operating_hours' => 'Operating Hours',
    'contact' => 'Contact Number',
    'owner_name' => 'Owner Name',
    'rating' => 'Rating',
    'budget' => 'Budget',
    'description' => 'Description',
    'image_url' => 'Cover Image',
    'source_platform' => 'Source Platform',
    'verification_status' => 'Verification Status',
    'latitude' => 'Latitude',
    'longitude' => 'Longitude',
    'removal_reason' => 'Removal Reason',
    'additional_note' => 'Additional Note',
    'disposition' => 'Result',
    'deactivation_reason' => 'Deactivation Reason',
    _ => field,
  };

  static String _displayValue(String field, String value) {
    if (field == 'is_active') {
      return value == 'true' ? 'Active' : 'Deactivated';
    }
    return value;
  }

  static String _formatDateTime(DateTime value) {
    const months = [
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
    final local = value.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year} ${local.hour}:$minute';
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({
    required this.label,
    required this.value,
    required this.style,
  });

  final String label;
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '$label:',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
            ),
          ),
          Expanded(child: Text(value, style: style)),
        ],
      ),
    );
  }
}
