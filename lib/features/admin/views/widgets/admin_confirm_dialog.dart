import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:makanspot/core/theme/app_theme.dart';

/// Bottom-aligned confirmation dialog matching the prototype's mobile sheet.
Future<bool?> showAdminConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.foreground.withValues(alpha: 0.4),
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Container(
            key: const Key('admin-confirm-dialog'),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.large),
              border: Border.all(color: AppColors.secondary),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    key: const Key('admin-confirm-action'),
                    onPressed: () => context.pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: destructive
                          ? AppColors.destructive
                          : AppColors.primary,
                      foregroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.control),
                      ),
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    key: const Key('admin-confirm-cancel'),
                    onPressed: () => context.pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.foreground,
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(color: AppColors.secondary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.control),
                      ),
                    ),
                    child: Text(cancelLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
