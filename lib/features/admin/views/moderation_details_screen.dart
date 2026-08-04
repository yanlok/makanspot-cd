import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/moderation_details_controller.dart';
import '../models/admin_models.dart';
import 'widgets/admin_confirm_dialog.dart';
import 'widgets/admin_form_widgets.dart';
import 'widgets/admin_skeletons.dart';
import 'widgets/admin_status_badge.dart';

class ModerationDetailsScreen extends ConsumerStatefulWidget {
  const ModerationDetailsScreen({required this.reportId, super.key});

  final String reportId;

  @override
  ConsumerState<ModerationDetailsScreen> createState() =>
      _ModerationDetailsScreenState();
}

class _ModerationDetailsScreenState
    extends ConsumerState<ModerationDetailsScreen> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _removeContent() async {
    final error = await ref
        .read(moderationDetailsControllerProvider(widget.reportId).notifier)
        .removeContent();
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
        content: Text(
          'Content Removed — The content has been removed from public view.',
        ),
      ),
    );
  }

  Future<void> _dismiss() async {
    final error = await ref
        .read(moderationDetailsControllerProvider(widget.reportId).notifier)
        .dismiss();
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
        content: Text('Report Dismissed — The report has been dismissed.'),
      ),
    );
  }

  Future<void> _confirmRemove() async {
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Remove Content?',
      message:
          'This will remove the content from public view and mark this '
          'report as resolved.',
      confirmLabel: 'Remove Content',
      destructive: true,
    );
    if ((confirmed ?? false) && mounted) {
      await _removeContent();
    }
  }

  Future<void> _confirmDismiss() async {
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Dismiss Report?',
      message:
          'This will dismiss the report as invalid. No action will be taken '
          'against the content.',
      confirmLabel: 'Dismiss',
    );
    if ((confirmed ?? false) && mounted) {
      await _dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      moderationDetailsControllerProvider(widget.reportId),
    );
    final controller = ref.read(
      moderationDetailsControllerProvider(widget.reportId).notifier,
    );
    if (_reasonController.text != state.removalReason) {
      _reasonController.text = state.removalReason;
    }
    final report = state.report;
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('moderation-details-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AdminBackButton(label: 'Back to Moderation', onPressed: context.pop),
          const SizedBox(height: 16),
          if (state.status == ModerationDetailsStatus.loading)
            const _ModerationDetailsSkeleton()
          else if (state.status == ModerationDetailsStatus.notFound)
            const Text(
              'Report not found.',
              style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
            )
          else if (state.status == ModerationDetailsStatus.error)
            Text(state.errorMessage!, textAlign: TextAlign.center)
          else ...[
            _ReportHeader(report: report!),
            const SizedBox(height: 16),
            _ReportedContentCard(content: state.content),
            const SizedBox(height: 16),
            _ReportDetailsCard(report: report),
            if (!report.isResolved) ...[
              const SizedBox(height: 16),
              _ModerationActionCard(
                reasonController: _reasonController,
                isActing: state.isActing,
                onReasonChanged: controller.updateRemovalReason,
                onRemove: _confirmRemove,
                onDismiss: _confirmDismiss,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.report});

  final ModerationReport report;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.destructive.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: const Icon(
            LucideIcons.flag,
            size: 20,
            color: AppColors.destructive,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Moderation Review',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                report.contentType == ReportContentType.post
                    ? 'Reported Post'
                    : 'Reported Comment',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        AdminStatusBadge(label: _statusLabel(report.status)),
      ],
    );
  }

  static String _statusLabel(ReportStatus status) {
    return switch (status) {
      ReportStatus.pending => 'Pending',
      ReportStatus.removed => 'Removed',
      ReportStatus.dismissed => 'Dismissed',
    };
  }
}

class _ReportedContentCard extends StatelessWidget {
  const _ReportedContentCard({required this.content});

  final ReportedContent? content;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      title: 'Reported Content',
      child: content == null
          ? _MutedPanel(
              text:
                  'Content is no longer available. It may have been already removed.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        content!.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                    if (content!.restaurantName != null &&
                        content!.restaurantName!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        LucideIcons.utensils,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          content!.restaurantName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                _MutedPanel(text: content!.text),
                if (content!.mediaUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final url in content!.mediaUrls.take(3)) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const ColoredBox(
                                    color: AppColors.secondary,
                                    child: Icon(
                                      LucideIcons.image,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _ReportDetailsCard extends StatelessWidget {
  const _ReportDetailsCard({required this.report});

  final ModerationReport report;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      title: 'Report Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(label: 'Reason', value: report.reason),
          const SizedBox(height: 16),
          _DetailRow(label: 'Report Count', value: '${report.reportCount}'),
          if (report.additionalInfo != null &&
              report.additionalInfo!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DetailRow(label: 'Additional Info', value: report.additionalInfo!),
          ],
          if (report.removalReason != null &&
              report.removalReason!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DetailRow(label: 'Removal Reason', value: report.removalReason!),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _ModerationActionCard extends StatelessWidget {
  const _ModerationActionCard({
    required this.reasonController,
    required this.isActing,
    required this.onReasonChanged,
    required this.onRemove,
    required this.onDismiss,
  });

  final TextEditingController reasonController;
  final bool isActing;
  final ValueChanged<String> onReasonChanged;
  final VoidCallback onRemove;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      title: 'Moderation Action',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminFieldLabel('Removal Reason (required for removal)'),
          const SizedBox(height: 8),
          TextField(
            key: const Key('admin-removal-reason'),
            controller: reasonController,
            onChanged: onReasonChanged,
            minLines: 3,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Explain why this content is being removed...',
              filled: true,
              fillColor: AppColors.surface,
              hintStyle: const TextStyle(color: AppColors.mutedForeground),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.control),
                borderSide: const BorderSide(color: AppColors.secondary),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.control),
                borderSide: const BorderSide(color: AppColors.secondary),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.control),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AdminOutlineButton(
            label: 'Remove Content',
            icon: LucideIcons.trash2,
            borderColor: AppColors.destructive,
            foregroundColor: AppColors.destructive,
            buttonKey: const Key('admin-moderation-remove'),
            onPressed: isActing ? null : onRemove,
          ),
          const SizedBox(height: 12),
          AdminOutlineButton(
            label: 'Dismiss Report',
            icon: LucideIcons.checkCircle,
            buttonKey: const Key('admin-moderation-dismiss'),
            onPressed: isActing ? null : onDismiss,
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.title, required this.child});

  final String title;
  final Widget child;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MutedPanel extends StatelessWidget {
  const _MutedPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.foreground),
      ),
    );
  }
}

class _ModerationDetailsSkeleton extends StatelessWidget {
  const _ModerationDetailsSkeleton();

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminSkeletonBox(height: 24, width: 160, radius: 6),
              SizedBox(height: 12),
              AdminSkeletonBox(height: 128, width: double.infinity),
            ],
          ),
        ),
      ],
    );
  }
}
