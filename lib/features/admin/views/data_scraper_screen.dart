import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/data_scraper_controller.dart';
import '../models/data_scraper_models.dart';
import 'widgets/admin_page_header.dart';

/// Data Scraper screen — trigger and monitor the Instagram pipeline.
class DataScraperScreen extends ConsumerWidget {
  const DataScraperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dataScraperControllerProvider);
    final controller = ref.read(dataScraperControllerProvider.notifier);

    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('data-scraper-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          const AdminPageHeader(
            title: 'Data Scraper',
            subtitle: 'Instagram-native restaurant discovery pipeline',
          ),
          const SizedBox(height: 24),

          // Stats overview
          _StatsOverview(
            totalRestaurants: state.totalRestaurants,
            totalPosts: state.totalPosts,
            totalCostUsd: state.totalCostUsd,
          ),
          const SizedBox(height: 16),

          // Auto Run controls or progress or manual scan
          if (state.initMessage.isNotEmpty &&
              state.status == PipelineStatus.idle)
            _LoadingBar(message: state.initMessage)
          else if (state.autoRun != null && state.autoRun!.isActive)
            _AutoRunProgress(
              autoRun: state.autoRun!,
              onPause: controller.pauseAutoRun,
              onResume: controller.resumeAutoRun,
              onStop: controller.stopAutoRun,
            )
          else if (state.status == PipelineStatus.scanning ||
              state.status == PipelineStatus.processing)
            _ScanProgress(state: state, onCancel: controller.cancelScan)
          else
            _AutoRunControls(
              onStartAutoRun: controller.startAutoRun,
              onStartScan: controller.startScan,
            ),

          // Error state
          if (state.status == PipelineStatus.error) ...[
            const SizedBox(height: 16),
            _ErrorCard(message: state.error ?? 'Unknown error'),
          ],

          // Results (single scan only)
          if (state.status == PipelineStatus.complete &&
              state.result != null &&
              (state.autoRun == null || !state.autoRun!.isActive)) ...[
            const SizedBox(height: 16),
            _ResultsCard(result: state.result!),
          ],

          // Auto Run summary (when finished)
          if (state.autoRun != null && !state.autoRun!.isActive) ...[
            const SizedBox(height: 16),
            _AutoRunSummaryCard(autoRun: state.autoRun!),
          ],

          // Cost KPI
          if (state.totalCostUsd > 0 && state.totalRestaurants > 0) ...[
            const SizedBox(height: 16),
            _CostKpiCard(
              totalCostUsd: state.totalCostUsd,
              totalRestaurants: state.totalRestaurants,
            ),
          ],

          // Discovery sources
          if (state.discoverySources.isNotEmpty) ...[
            const SizedBox(height: 24),
            _DiscoverySourcesSection(sources: state.discoverySources),
          ],

          // Recent runs
          if (state.recentRuns.isNotEmpty) ...[
            const SizedBox(height: 24),
            _RecentRunsSection(runs: state.recentRuns),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats Overview
// ---------------------------------------------------------------------------

class _StatsOverview extends StatelessWidget {
  const _StatsOverview({
    required this.totalRestaurants,
    required this.totalPosts,
    required this.totalCostUsd,
  });

  final int totalRestaurants;
  final int totalPosts;
  final double totalCostUsd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Row(
        children: [
          _StatItem(
            icon: LucideIcons.store,
            label: 'Restaurants',
            value: '$totalRestaurants',
            color: AppColors.success,
          ),
          const SizedBox(width: 16),
          _StatItem(
            icon: LucideIcons.fileText,
            label: 'Posts',
            value: '$totalPosts',
            color: AppColors.primary,
          ),
          const SizedBox(width: 16),
          _StatItem(
            icon: LucideIcons.dollarSign,
            label: 'Total Cost',
            value: '\$${totalCostUsd.toStringAsFixed(2)}',
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.mutedForeground,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading Bar
// ---------------------------------------------------------------------------

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message.isEmpty ? 'Preparing...' : message,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auto Run Controls — configuration before starting
// ---------------------------------------------------------------------------

class _AutoRunControls extends StatefulWidget {
  const _AutoRunControls({
    required this.onStartAutoRun,
    required this.onStartScan,
  });

  final void Function({
    int resultsPerQuery,
    int maxQueries,
    double costLimitUsd,
  })
  onStartAutoRun;
  final VoidCallback onStartScan;

  @override
  State<_AutoRunControls> createState() => _AutoRunControlsState();
}

class _AutoRunControlsState extends State<_AutoRunControls> {
  int _resultsPerQuery = 30;
  int _maxQueries = 10;
  double _costLimitUsd = 5.0;

  static const _costPerResult = 0.003;

  @override
  Widget build(BuildContext context) {
    final estimatedCostPerQuery = _resultsPerQuery * _costPerResult;
    final estimatedTotalCost = estimatedCostPerQuery * _maxQueries;

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
          const Text(
            'Auto Run',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Process multiple queries automatically',
            style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 16),

          // Results per query
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Results per query',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 20, label: Text('20')),
                  ButtonSegment(value: 30, label: Text('30')),
                  ButtonSegment(value: 40, label: Text('40')),
                ],
                selected: {_resultsPerQuery},
                onSelectionChanged: (values) {
                  setState(() => _resultsPerQuery = values.first);
                },
                style: SegmentedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Max queries
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Max queries',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
              SizedBox(
                width: 80,
                height: 36,
                child: TextFormField(
                  initialValue: '$_maxQueries',
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.secondary),
                    ),
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n >= 1 && n <= 100) {
                      setState(() => _maxQueries = n);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cost limit
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cost limit (USD)',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
              SizedBox(
                width: 80,
                height: 36,
                child: TextFormField(
                  initialValue: _costLimitUsd.toStringAsFixed(1),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.secondary),
                    ),
                  ),
                  onChanged: (v) {
                    final n = double.tryParse(v);
                    if (n != null && n >= 0.1 && n <= 100) {
                      setState(() => _costLimitUsd = n);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Cost estimate
          Text(
            '~\$${estimatedCostPerQuery.toStringAsFixed(3)} × $_maxQueries queries ≈ '
            '\$${estimatedTotalCost.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 16),

          // Start Auto Run button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () => widget.onStartAutoRun(
                resultsPerQuery: _resultsPerQuery,
                maxQueries: _maxQueries,
                costLimitUsd: _costLimitUsd,
              ),
              icon: const Icon(LucideIcons.play, size: 18),
              label: const Text(
                'Start Auto Run',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Single scan fallback
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: widget.onStartScan,
              icon: const Icon(LucideIcons.scan, size: 16),
              label: const Text(
                'Single Scan',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.mutedForeground,
                side: BorderSide(color: AppColors.secondary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auto Run Progress — shown while an auto-run is active
// ---------------------------------------------------------------------------

class _AutoRunProgress extends StatelessWidget {
  const _AutoRunProgress({
    required this.autoRun,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final AutoRunState autoRun;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final isPaused = autoRun.status == AutoRunStatus.paused;
    final config = autoRun.config;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isPaused ? AppColors.accent : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isPaused ? 'Auto Run Paused' : 'Auto Run In Progress',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isPaused ? AppColors.accent : AppColors.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${autoRun.queriesCompleted}/${config.maxQueries}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isPaused ? AppColors.accent : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          LinearProgressIndicator(
            value: config.maxQueries > 0
                ? autoRun.queriesCompleted / config.maxQueries
                : 0,
            backgroundColor: AppColors.secondary,
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),

          // Stats grid
          _AutoRunStatRow(
            icon: LucideIcons.utensilsCrossed,
            label: 'New restaurants',
            value: '${autoRun.newRestaurants}',
            color: AppColors.success,
          ),
          _AutoRunStatRow(
            icon: LucideIcons.repeat,
            label: 'Existing matched',
            value: '${autoRun.existingMatched}',
            color: AppColors.primary,
          ),
          _AutoRunStatRow(
            icon: LucideIcons.imageOff,
            label: 'Skipped (no image)',
            value: '${autoRun.skippedNoImage}',
            color: AppColors.accent,
          ),
          _AutoRunStatRow(
            icon: LucideIcons.triangleAlert,
            label: 'Failed candidates',
            value: '${autoRun.failedCandidates}',
            color: AppColors.destructive,
          ),
          _AutoRunStatRow(
            icon: LucideIcons.dollarSign,
            label: 'Total cost',
            value: '\$${autoRun.totalCostUsd.toStringAsFixed(3)}',
            color: AppColors.foreground,
          ),

          const SizedBox(height: 16),

          // Controls
          Row(
            children: [
              Expanded(
                child: isPaused
                    ? FilledButton.icon(
                        onPressed: onResume,
                        icon: const Icon(LucideIcons.play, size: 16),
                        label: const Text(
                          'Resume',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadii.control,
                            ),
                          ),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: onPause,
                        icon: const Icon(LucideIcons.pause, size: 16),
                        label: const Text(
                          'Pause',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.foreground,
                          side: BorderSide(color: AppColors.secondary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadii.control,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('stop-auto-run-button'),
                  onPressed: onStop,
                  icon: const Icon(LucideIcons.circleStop, size: 16),
                  label: const Text(
                    'Stop',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.destructive,
                    side: BorderSide(
                      color: AppColors.destructive.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AutoRunStatRow extends StatelessWidget {
  const _AutoRunStatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.mutedForeground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auto Run Summary Card — shown after auto-run finishes
// ---------------------------------------------------------------------------

class _AutoRunSummaryCard extends StatelessWidget {
  const _AutoRunSummaryCard({required this.autoRun});

  final AutoRunState autoRun;

  @override
  Widget build(BuildContext context) {
    final statusColor = autoRun.status == AutoRunStatus.completed
        ? AppColors.success
        : autoRun.status == AutoRunStatus.failed
        ? AppColors.destructive
        : AppColors.accent;

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
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  autoRun.status == AutoRunStatus.completed
                      ? LucideIcons.checkCircle
                      : LucideIcons.circleStop,
                  size: 18,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto Run ${autoRun.status.name}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (autoRun.stopReason != null)
                      Text(
                        autoRun.stopReason!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ResultRow(
            label: 'Queries completed',
            value: '${autoRun.queriesCompleted}',
            color: AppColors.primary,
          ),
          const SizedBox(height: 8),
          _ResultRow(
            label: 'New restaurants',
            value: '${autoRun.newRestaurants}',
            color: AppColors.success,
          ),
          const SizedBox(height: 8),
          _ResultRow(
            label: 'Existing matched',
            value: '${autoRun.existingMatched}',
            color: AppColors.primary,
          ),
          const SizedBox(height: 8),
          _ResultRow(
            label: 'Skipped (no image)',
            value: '${autoRun.skippedNoImage}',
            color: AppColors.accent,
          ),
          const SizedBox(height: 8),
          _ResultRow(
            label: 'Failed candidates',
            value: '${autoRun.failedCandidates}',
            color: AppColors.destructive,
          ),
          const SizedBox(height: 8),
          _ResultRow(
            label: 'Total cost',
            value: '\$${autoRun.totalCostUsd.toStringAsFixed(3)}',
            color: AppColors.foreground,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scan Progress
// ---------------------------------------------------------------------------

class _ScanProgress extends StatelessWidget {
  const _ScanProgress({required this.state, required this.onCancel});

  final PipelineState state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.stepMessage,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProgressSteps(currentStep: state.currentStep),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('cancel-pipeline-button'),
              onPressed: onCancel,
              icon: const Icon(LucideIcons.circleStop, size: 16),
              label: const Text('Stop scan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSteps extends StatelessWidget {
  const _ProgressSteps({required this.currentStep});

  final PipelineStep? currentStep;

  @override
  Widget build(BuildContext context) {
    const steps = [
      (PipelineStep.scrape, 'Scraping', LucideIcons.download),
      (PipelineStep.ingest, 'Ingesting', LucideIcons.database),
      (PipelineStep.detect, 'Detecting', LucideIcons.brain),
      (PipelineStep.resolve, 'Resolving', LucideIcons.gitMerge),
      (PipelineStep.enrich, 'Enriching', LucideIcons.utensilsCrossed),
      (PipelineStep.metrics, 'Metrics', LucideIcons.barChart3),
    ];

    final currentIndex = currentStep != null
        ? steps.indexWhere((s) => s.$1 == currentStep)
        : -1;

    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final (step, label, icon) = entry.value;
        final isComplete = index < currentIndex;
        final isCurrent = index == currentIndex;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              _StepIcon(
                icon: icon,
                isComplete: isComplete,
                isCurrent: isCurrent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                    color: isComplete
                        ? AppColors.success
                        : isCurrent
                        ? AppColors.foreground
                        : AppColors.mutedForeground,
                  ),
                ),
              ),
              if (isComplete)
                const Icon(
                  LucideIcons.check,
                  size: 14,
                  color: AppColors.success,
                )
              else if (isCurrent)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({
    required this.icon,
    required this.isComplete,
    required this.isCurrent,
  });

  final IconData icon;
  final bool isComplete;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final color = isComplete
        ? AppColors.success
        : isCurrent
        ? AppColors.primary
        : AppColors.mutedForeground;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isComplete
            ? AppColors.success.withValues(alpha: 0.1)
            : isCurrent
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.secondary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }
}

// ---------------------------------------------------------------------------
// Results Card
// ---------------------------------------------------------------------------

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({required this.result});

  final ScanResult result;

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
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.checkCircle,
                  size: 18,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Scan Complete',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ResultRow(
            label: 'Posts received',
            value: '${result.postsReceived}',
            color: AppColors.primary,
          ),
          const SizedBox(height: 8),
          _ResultRow(
            label: 'New restaurants',
            value: '${result.newRestaurants}',
            color: AppColors.success,
          ),
          const SizedBox(height: 8),
          _ResultRow(
            label: 'Cost',
            value: '\$${result.costUsd.toStringAsFixed(3)}',
            color: AppColors.accent,
          ),
          if (result.newRestaurants > 0) ...[
            const SizedBox(height: 8),
            _ResultRow(
              label: 'Cost per restaurant',
              value:
                  '\$${(result.costUsd / result.newRestaurants).toStringAsFixed(3)}',
              color: AppColors.success,
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cost KPI Card
// ---------------------------------------------------------------------------

class _CostKpiCard extends StatelessWidget {
  const _CostKpiCard({
    required this.totalCostUsd,
    required this.totalRestaurants,
  });

  final double totalCostUsd;
  final int totalRestaurants;

  @override
  Widget build(BuildContext context) {
    final costPerRestaurant = totalRestaurants > 0
        ? totalCostUsd / totalRestaurants
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              LucideIcons.trendingDown,
              size: 20,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\$${costPerRestaurant.toStringAsFixed(3)}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  'Cost per new restaurant',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error Card
// ---------------------------------------------------------------------------

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.destructive.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.triangleAlert,
            size: 20,
            color: AppColors.destructive,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.destructive,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Discovery Sources Section
// ---------------------------------------------------------------------------

class _DiscoverySourcesSection extends StatefulWidget {
  const _DiscoverySourcesSection({required this.sources});

  final List<DiscoverySourceSummary> sources;

  @override
  State<_DiscoverySourcesSection> createState() =>
      _DiscoverySourcesSectionState();
}

class _DiscoverySourcesSectionState extends State<_DiscoverySourcesSection> {
  static const _pageSize = 5;
  int _visibleCount = _pageSize;

  @override
  void didUpdateWidget(covariant _DiscoverySourcesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sources != widget.sources) {
      _visibleCount = _pageSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = widget.sources;
    final visibleCount = _visibleCount.clamp(0, sources.length);
    final visibleSources = sources.take(visibleCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Discovery Sources',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.secondary),
          ),
          child: sources.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No discovery sources yet.'),
                )
              : Column(
                  children: visibleSources.asMap().entries.map((entry) {
                    return _SourceRow(
                      source: entry.value,
                      showDivider: entry.key < visibleSources.length - 1,
                    );
                  }).toList(),
                ),
        ),
        if (sources.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Showing $visibleCount of ${sources.length} sources',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
              const Spacer(),
              if (visibleCount < sources.length)
                TextButton(
                  onPressed: () => setState(() {
                    _visibleCount = (_visibleCount + _pageSize).clamp(
                      0,
                      sources.length,
                    );
                  }),
                  child: const Text('Show 5 more'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.showDivider});

  final DiscoverySourceSummary source;
  final bool showDivider;

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
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
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = source.status == 'active'
        ? AppColors.success
        : source.status == 'cooldown'
        ? AppColors.accent
        : AppColors.mutedForeground;

    final isAutomation = source.sourceType == 'automation';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.secondary.withValues(alpha: 0.5),
                ),
              ),
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        source.sourceValue,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                    if (isAutomation)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'AI',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  '${source.sourceType} · ${source.area ?? "No area"}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      '${source.postsScraped} posts',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    Text(
                      '${source.restaurantCandidates} candidates',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    Text(
                      '${source.scrapeCount} scrapes',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                if (source.createdAt != null)
                  Text(
                    'added ${_formatDate(source.createdAt)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${source.newRestaurants} restaurants',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: source.newRestaurants > 0
                      ? AppColors.success
                      : AppColors.mutedForeground,
                ),
              ),
              Text(
                '${(source.yieldRate * 100).toStringAsFixed(1)}% yield',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.mutedForeground,
                ),
              ),
              Text(
                source.status,
                style: TextStyle(fontSize: 11, color: statusColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent Runs Section
// ---------------------------------------------------------------------------

class _RecentRunsSection extends StatelessWidget {
  const _RecentRunsSection({required this.runs});

  final List<ScrapeRunSummary> runs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Runs', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ...runs
            .take(5)
            .map(
              (run) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RunCard(run: run),
              ),
            ),
      ],
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run});

  final ScrapeRunSummary run;

  String _formatRunDate(DateTime? dt) {
    if (dt == null) return '—';
    final malaysiaTime = dt.toUtc().add(const Duration(hours: 8));
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
    final day = malaysiaTime.day;
    final month = months[malaysiaTime.month - 1];
    final hour = malaysiaTime.hour % 12 == 0 ? 12 : malaysiaTime.hour % 12;
    final minute = malaysiaTime.minute.toString().padLeft(2, '0');
    final period = malaysiaTime.hour < 12 ? 'AM' : 'PM';
    return '$day $month ${malaysiaTime.year}, $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = run.status == 'completed'
        ? AppColors.success
        : run.status == 'failed'
        ? AppColors.destructive
        : AppColors.accent;
    final sourceLabel = run.sourceValue?.trim().isNotEmpty == true
        ? run.sourceValue!
        : run.sourceId != null
        ? 'Legacy source #${run.sourceId}'
        : 'Legacy run (source unavailable)';
    final sourceContext = [
      if (run.sourceType?.isNotEmpty == true) run.sourceType!,
      if (run.sourceArea?.isNotEmpty == true) run.sourceArea!,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sourceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                if (sourceContext.isNotEmpty)
                  Text(
                    sourceContext,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                Text(
                  '${run.postsReceived} received · ${run.newPosts} new · '
                  '${run.newRestaurants} restaurants',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  '\$${run.costUsd.toStringAsFixed(3)} · ${run.status}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
                Text(
                  _formatRunDate(run.startedAt ?? run.completedAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
