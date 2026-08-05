import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/moderation_controller.dart';
import '../controllers/moderation_details_controller.dart';
import '../models/admin_models.dart';
import 'widgets/admin_confirm_dialog.dart';
import 'widgets/admin_form_widgets.dart';
import 'widgets/admin_skeletons.dart';
import 'widgets/admin_status_badge.dart';

class ModerationDetailsScreen extends ConsumerStatefulWidget {
  const ModerationDetailsScreen({required this.contentId, super.key});

  final String contentId;

  @override
  ConsumerState<ModerationDetailsScreen> createState() =>
      _ModerationDetailsScreenState();
}

class _ModerationDetailsScreenState
    extends ConsumerState<ModerationDetailsScreen> {
  Future<void> _removeContent() async {
    final error = await ref
        .read(moderationDetailsControllerProvider(widget.contentId).notifier)
        .removeContent();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Remove content successfully.')),
    );
    // Refresh the moderation list so the report no longer shows as pending.
    ref.invalidate(moderationControllerProvider);
    if (mounted) context.go('/admin/moderation');
  }

  Future<void> _dismiss() async {
    final error = await ref
        .read(moderationDetailsControllerProvider(widget.contentId).notifier)
        .dismiss();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Dismiss reports successfully.')),
    );
    // Refresh the moderation list so the dismissed report disappears.
    ref.invalidate(moderationControllerProvider);
    if (mounted) context.go('/admin/moderation');
  }

  Future<void> _confirmRemove() async {
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Remove Content?',
      message:
          'This will hide the content from public view. The content owner '
          'will not be able to see it.',
      confirmLabel: 'Remove Content',
      destructive: true,
    );
    if ((confirmed ?? false) && mounted) await _removeContent();
  }

  Future<void> _confirmDismiss() async {
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Dismiss Reports?',
      message:
          'This will clear all reports for this content. The content will '
          'remain visible.',
      confirmLabel: 'Dismiss',
    );
    if ((confirmed ?? false) && mounted) await _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      moderationDetailsControllerProvider(widget.contentId),
    );
    final group = state.group;
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('moderation-details-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Transform.translate(
            offset: const Offset(-80, 0),
            child: AdminBackButton(
              label: 'Back to Moderation',
              onPressed: () => context.go('/admin/moderation'),
            ),
          ),
          const SizedBox(height: 16),
          if (state.status == ModerationDetailsStatus.loading)
            const _Skeleton()
          else if (state.status == ModerationDetailsStatus.notFound)
            const Text(
              'Report not found.',
              style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
            )
          else if (state.status == ModerationDetailsStatus.error)
            Text(state.errorMessage!, textAlign: TextAlign.center)
          else ...[
            _ReportHeader(group: group!),
            const SizedBox(height: 16),
            _ContentCard(content: state.content),
            const SizedBox(height: 16),
            _ReportsListCard(reports: group.reports),
            if (group.isPending) ...[
              const SizedBox(height: 16),
              _ActionCard(
                isActing: state.isActing,
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
  const _ReportHeader({required this.group});

  final ReportedContentGroup group;

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
                group.contentType == ReportContentType.post
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
        AdminStatusBadge(label: group.isRemoved ? 'Removed' : 'Pending'),
      ],
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.content});

  final ReportedContent? content;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Reported Content',
      child: content == null
          ? _Muted(
              text:
                  'Content is no longer available. It may have been '
                  'already removed.',
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
                _Muted(text: content!.text),
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

class _ReportsListCard extends StatelessWidget {
  const _ReportsListCard({required this.reports});

  final List<ModerationReport> reports;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Reports (${reports.length})',
      child: Column(
        children: [
          for (var i = 0; i < reports.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
            ],
            _ReportRow(report: reports[i]),
          ],
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report});

  final ModerationReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  report.reporterName.isNotEmpty
                      ? report.reporterName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.reporterName.isEmpty
                        ? 'Anonymous'
                        : report.reporterName,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.foreground,
                    ),
                  ),
                  Text(
                    _formatDate(report.createdDate),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          report.reason.isEmpty ? 'Not provided' : report.reason,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (report.additionalInfo != null &&
            report.additionalInfo!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            report.additionalInfo!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
          ),
        ],
      ],
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.isActing,
    required this.onRemove,
    required this.onDismiss,
  });

  final bool isActing;
  final VoidCallback onRemove;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Moderation Action',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            label: 'Dismiss Reports',
            icon: LucideIcons.checkCircle,
            buttonKey: const Key('admin-moderation-dismiss'),
            onPressed: isActing ? null : onDismiss,
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

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

class _Muted extends StatelessWidget {
  const _Muted({required this.text});

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

class _Skeleton extends StatelessWidget {
  const _Skeleton();

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
