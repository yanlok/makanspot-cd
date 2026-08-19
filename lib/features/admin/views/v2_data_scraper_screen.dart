import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/v2_data_scraper_controller.dart';
import '../models/v2_admin_models.dart';
import 'widgets/admin_page_header.dart';

/// V2 Data Scraper screen — trigger and monitor the v2 Instagram pipeline.
class V2DataScraperScreen extends ConsumerWidget {
  const V2DataScraperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(v2DataScraperControllerProvider);
    final controller = ref.read(v2DataScraperControllerProvider.notifier);

    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('v2-data-scraper-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          const AdminPageHeader(
            title: 'V2 Data Scraper',
            subtitle: 'Clean pipeline — Instagram-native restaurant discovery',
          ),
          const SizedBox(height: 24),

          // Stats overview
          _StatsOverview(
            totalRestaurants: state.totalRestaurants,
            totalPosts: state.totalPosts,
            totalCostUsd: state.totalCostUsd,
          ),
          const SizedBox(height: 16),

          // Scan controls or progress
          if (state.initMessage.isNotEmpty && state.status == V2PipelineStatus.idle)
            _LoadingBar(message: state.initMessage)
          else if (state.status == V2PipelineStatus.scanning ||
              state.status == V2PipelineStatus.processing)
            _ScanProgress(state: state)
          else
            _ScanControls(
              resultLimit: state.resultLimit,
              onLimitChanged: controller.setResultLimit,
              onPressed: controller.startScan,
            ),

          // Error state
          if (state.status == V2PipelineStatus.error) ...[
            const SizedBox(height: 16),
            _ErrorCard(message: state.error ?? 'Unknown error'),
          ],

          // Results
          if (state.status == V2PipelineStatus.complete && state.result != null) ...[
            const SizedBox(height: 16),
            _ResultsCard(result: state.result!),
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
            label: 'V2 Restaurants',
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
            style: TextStyle(
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
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
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
// Scan Controls (quantity slider + cost estimate + button)
// ---------------------------------------------------------------------------

class _ScanControls extends StatelessWidget {
  const _ScanControls({
    required this.resultLimit,
    required this.onLimitChanged,
    required this.onPressed,
  });

  final int resultLimit;
  final ValueChanged<int> onLimitChanged;
  final VoidCallback onPressed;

  static const _costPerResult = 0.003;

  @override
  Widget build(BuildContext context) {
    final estimatedCost = resultLimit * _costPerResult;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Results to fetch',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$resultLimit',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.secondary,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.1),
            ),
            child: Slider(
              value: resultLimit.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              onChanged: (v) => onLimitChanged(v.round()),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1',
                style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
              ),
              Text(
                '~\$${_costPerResult.toStringAsFixed(3)} × $resultLimit = \$${estimatedCost.toStringAsFixed(3)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedForeground,
                ),
              ),
              Text(
                '20',
                style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(LucideIcons.scan, size: 18),
              label: const Text(
                'Start V2 Scan',
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
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scan Progress
// ---------------------------------------------------------------------------

class _ScanProgress extends StatelessWidget {
  const _ScanProgress({required this.state});

  final V2PipelineState state;

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
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
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
        ],
      ),
    );
  }
}

class _ProgressSteps extends StatelessWidget {
  const _ProgressSteps({required this.currentStep});

  final V2PipelineStep? currentStep;

  @override
  Widget build(BuildContext context) {
    const steps = [
      (V2PipelineStep.scrape, 'Scraping', LucideIcons.download),
      (V2PipelineStep.ingest, 'Ingesting', LucideIcons.database),
      (V2PipelineStep.detect, 'Detecting', LucideIcons.brain),
      (V2PipelineStep.resolve, 'Resolving', LucideIcons.gitMerge),
      (V2PipelineStep.enrich, 'Enriching', LucideIcons.utensilsCrossed),
      (V2PipelineStep.metrics, 'Metrics', LucideIcons.barChart3),
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
              _StepIcon(icon: icon, isComplete: isComplete, isCurrent: isCurrent),
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
                const Icon(LucideIcons.check, size: 14, color: AppColors.success)
              else if (isCurrent)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
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

  final V2ScanResult result;

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
                child: const Icon(LucideIcons.checkCircle, size: 18, color: AppColors.success),
              ),
              const SizedBox(width: 12),
              Text('V2 Scan Complete', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          _ResultRow(label: 'Posts received', value: '${result.postsReceived}', color: AppColors.primary),
          const SizedBox(height: 8),
          _ResultRow(label: 'New restaurants', value: '${result.newRestaurants}', color: AppColors.success),
          const SizedBox(height: 8),
          _ResultRow(label: 'Cost', value: '\$${result.costUsd.toStringAsFixed(3)}', color: AppColors.accent),
          if (result.newRestaurants > 0) ...[
            const SizedBox(height: 8),
            _ResultRow(
              label: 'Cost per restaurant',
              value: '\$${(result.costUsd / result.newRestaurants).toStringAsFixed(3)}',
              color: AppColors.success,
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value, required this.color});

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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
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
  const _CostKpiCard({required this.totalCostUsd, required this.totalRestaurants});

  final double totalCostUsd;
  final int totalRestaurants;

  @override
  Widget build(BuildContext context) {
    final costPerRestaurant = totalRestaurants > 0 ? totalCostUsd / totalRestaurants : 0.0;

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
            child: const Icon(LucideIcons.trendingDown, size: 20, color: AppColors.success),
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
          const Icon(LucideIcons.triangleAlert, size: 20, color: AppColors.destructive),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.destructive)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Discovery Sources Section
// ---------------------------------------------------------------------------

class _DiscoverySourcesSection extends StatelessWidget {
  const _DiscoverySourcesSection({required this.sources});

  final List<V2DiscoverySourceSummary> sources;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Discovery Sources', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.secondary),
          ),
          child: Column(
            children: sources.take(10).map((source) {
              final isLast = source == sources.take(10).last;
              return _SourceRow(source: source, showDivider: !isLast);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.showDivider});

  final V2DiscoverySourceSummary source;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final statusColor = source.status == 'active'
        ? AppColors.success
        : source.status == 'cooldown'
            ? AppColors.accent
            : AppColors.mutedForeground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.secondary.withValues(alpha: 0.5))),
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.sourceValue,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  '${source.sourceType} · ${source.area ?? "—"}',
                  style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
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
                  color: source.newRestaurants > 0 ? AppColors.success : AppColors.mutedForeground,
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

  final List<V2ScrapeRunSummary> runs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Runs', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ...runs.take(5).map((run) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _RunCard(run: run),
        )),
      ],
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run});

  final V2ScrapeRunSummary run;

  @override
  Widget build(BuildContext context) {
    final statusColor = run.status == 'completed'
        ? AppColors.success
        : run.status == 'failed'
            ? AppColors.destructive
            : AppColors.accent;

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
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${run.newPosts} posts · ${run.newRestaurants} restaurants',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  '\$${run.costUsd.toStringAsFixed(3)} · ${run.status}',
                  style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
