import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/data_scraper_controller.dart';
import '../models/data_scraper_models.dart';
import 'widgets/admin_page_header.dart';

/// Modernized Data Scraper screen — trigger and monitor the Instagram discovery pipeline.
class DataScraperScreen extends ConsumerStatefulWidget {
  const DataScraperScreen({super.key});

  @override
  ConsumerState<DataScraperScreen> createState() => _DataScraperScreenState();
}

class _DataScraperScreenState extends ConsumerState<DataScraperScreen> {
  int _selectedTabIndex = 0;
  static const int _pageSize = 10;
  int _visibleSourcesCount = _pageSize;
  int _visibleRunsCount = _pageSize;
  bool _isLoadingMore = false;

  void _triggerLazyLoad() {
    if (_isLoadingMore) return;
    final state = ref.read(dataScraperControllerProvider);
    if (_selectedTabIndex == 1) {
      final total = state.discoverySources.length;
      if (_visibleSourcesCount < total) {
        setState(() => _isLoadingMore = true);
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          setState(() {
            _visibleSourcesCount = (_visibleSourcesCount + _pageSize).clamp(
              0,
              total,
            );
            _isLoadingMore = false;
          });
        });
      }
    } else if (_selectedTabIndex == 2) {
      final total = state.recentRuns.length;
      if (_visibleRunsCount < total) {
        setState(() => _isLoadingMore = true);
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          setState(() {
            _visibleRunsCount = (_visibleRunsCount + _pageSize).clamp(0, total);
            _isLoadingMore = false;
          });
        });
      }
    }
  }

  void _loadMoreSources() {
    final total = ref
        .read(dataScraperControllerProvider)
        .discoverySources
        .length;
    if (_visibleSourcesCount < total) {
      setState(() {
        _visibleSourcesCount = (_visibleSourcesCount + _pageSize).clamp(
          0,
          total,
        );
      });
    }
  }

  void _loadMoreRuns() {
    final total = ref.read(dataScraperControllerProvider).recentRuns.length;
    if (_visibleRunsCount < total) {
      setState(() {
        _visibleRunsCount = (_visibleRunsCount + _pageSize).clamp(0, total);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dataScraperControllerProvider);
    final controller = ref.read(dataScraperControllerProvider.notifier);
    final isRunActive = state.autoRun?.isActive ?? false;

    return SafeArea(
      bottom: false,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification ||
              notification is ScrollEndNotification) {
            if (notification.metrics.extentAfter < 300) {
              _triggerLazyLoad();
            }
          }
          return false;
        },
        child: ListView(
          key: const Key('data-scraper-scroll'),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            // Header with live status badge
            AdminPageHeader(
              title: 'Data Scraper',
              subtitle: 'Instagram-native restaurant discovery pipeline',
              trailing: _StatusBadge(
                status: state.status,
                isAutoRunActive: isRunActive,
                isPaused: state.autoRun?.status == AutoRunStatus.paused,
              ),
            ),
            const SizedBox(height: 20),

            // Unified Hero Metrics Bento Grid
            _HeroMetricsGrid(
              totalRestaurants: state.totalRestaurants,
              totalPosts: state.totalPosts,
              totalCostUsd: state.totalCostUsd,
            ),
            const SizedBox(height: 20),

            // Modern Segmented Tab Navigation
            _ModernTabBar(
              selectedIndex: _selectedTabIndex,
              onTabSelected: (idx) => setState(() => _selectedTabIndex = idx),
              sourcesCount: state.discoverySources.length,
              runsCount: state.recentRuns.length,
              isRunActive: isRunActive,
            ),
            const SizedBox(height: 16),

            // Tab Content
            if (_selectedTabIndex == 0) ...[
              // Tab 1: Runner & Active Telemetry
              if (state.initMessage.isNotEmpty &&
                  state.status == PipelineStatus.idle)
                _LoadingBar(message: state.initMessage)
              else if (isRunActive)
                _AutoRunProgress(
                  autoRun: state.autoRun!,
                  onPause: controller.pauseAutoRun,
                  onResume: controller.resumeAutoRun,
                  onStop: controller.stopAutoRun,
                  activeHashtag: state.activeHashtag,
                  latestDiscoveredRestaurant: state.latestDiscoveredRestaurant,
                )
              else if (state.status == PipelineStatus.scanning ||
                  state.status == PipelineStatus.processing)
                _ScanProgress(state: state)
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

              // Results (either Auto Run summary OR Single Scan results, never both)
              if (state.status == PipelineStatus.complete && !isRunActive) ...[
                if (state.autoRun != null) ...[
                  const SizedBox(height: 16),
                  _AutoRunSummaryCard(autoRun: state.autoRun!),
                ] else if (state.result != null) ...[
                  const SizedBox(height: 16),
                  _ResultsCard(result: state.result!),
                ],
              ],
            ] else if (_selectedTabIndex == 1) ...[
              // Tab 2: Discovery Sources
              _DiscoverySourcesSection(
                sources: state.discoverySources,
                visibleCount: _visibleSourcesCount,
                isLoadingMore: _isLoadingMore && _selectedTabIndex == 1,
                onLoadMore: _loadMoreSources,
              ),
            ] else ...[
              // Tab 3: Run History
              _RecentRunsSection(
                runs: state.recentRuns,
                visibleCount: _visibleRunsCount,
                isLoadingMore: _isLoadingMore && _selectedTabIndex == 2,
                onLoadMore: _loadMoreRuns,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status Badge in Header
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
    required this.isAutoRunActive,
    required this.isPaused,
  });

  final PipelineStatus status;
  final bool isAutoRunActive;
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;

    if (isPaused) {
      label = 'Paused';
      color = AppColors.accent;
    } else if (isAutoRunActive) {
      label = 'Auto Running';
      color = AppColors.success;
    } else if (status == PipelineStatus.scanning ||
        status == PipelineStatus.processing) {
      label = 'Scanning';
      color = AppColors.primary;
    } else if (status == PipelineStatus.error) {
      label = 'Error';
      color = AppColors.destructive;
    } else {
      label = 'Server Ready';
      color = AppColors.mutedForeground;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Unified Hero Metrics Grid
// ---------------------------------------------------------------------------

class _HeroMetricsGrid extends StatelessWidget {
  const _HeroMetricsGrid({
    required this.totalRestaurants,
    required this.totalPosts,
    required this.totalCostUsd,
  });

  final int totalRestaurants;
  final int totalPosts;
  final double totalCostUsd;

  @override
  Widget build(BuildContext context) {
    final costPerRestaurant = totalRestaurants > 0
        ? totalCostUsd / totalRestaurants
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _HeroMetricItem(
            icon: LucideIcons.store,
            label: 'Restaurants',
            value: '$totalRestaurants',
            color: AppColors.success,
          ),
          Container(
            width: 1,
            height: 36,
            color: AppColors.secondary.withValues(alpha: 0.6),
          ),
          _HeroMetricItem(
            icon: LucideIcons.fileText,
            label: 'Posts Scraped',
            value: '$totalPosts',
            color: AppColors.primary,
          ),
          Container(
            width: 1,
            height: 36,
            color: AppColors.secondary.withValues(alpha: 0.6),
          ),
          _HeroMetricItem(
            icon: LucideIcons.trendingDown,
            label: totalRestaurants > 0 ? 'Cost/Rest.' : 'Total Spend',
            value: totalRestaurants > 0
                ? '\$${costPerRestaurant.toStringAsFixed(3)}'
                : '\$${totalCostUsd.toStringAsFixed(2)}',
            subtitle: totalRestaurants > 0
                ? 'Total: \$${totalCostUsd.toStringAsFixed(2)}'
                : null,
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _HeroMetricItem extends StatelessWidget {
  const _HeroMetricItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedForeground,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Modern Tab Bar
// ---------------------------------------------------------------------------

class _ModernTabBar extends StatelessWidget {
  const _ModernTabBar({
    required this.selectedIndex,
    required this.onTabSelected,
    required this.sourcesCount,
    required this.runsCount,
    required this.isRunActive,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final int sourcesCount;
  final int runsCount;
  final bool isRunActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Run Scraper',
            icon: LucideIcons.play,
            isSelected: selectedIndex == 0,
            hasPulse: isRunActive,
            onTap: () => onTabSelected(0),
          ),
          const SizedBox(width: 4),
          _TabButton(
            label: sourcesCount > 0 ? 'Sources ($sourcesCount)' : 'Sources',
            icon: LucideIcons.database,
            isSelected: selectedIndex == 1,
            hasPulse: false,
            onTap: () => onTabSelected(1),
          ),
          const SizedBox(width: 4),
          _TabButton(
            label: runsCount > 0 ? 'History ($runsCount)' : 'History',
            icon: LucideIcons.history,
            isSelected: selectedIndex == 2,
            hasPulse: false,
            onTap: () => onTabSelected(2),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.hasPulse,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final bool hasPulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.control - 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.control - 2),
              boxShadow: isSelected
                  ? const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasPulse) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                ] else ...[
                  Icon(
                    icon,
                    size: 13,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.mutedForeground,
                  ),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.foreground
                          : AppColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
        borderRadius: BorderRadius.circular(AppRadii.card),
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
              message.isEmpty ? 'Preparing pipeline...' : message,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
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
// Modern Auto Run Controls — Overflow-proof & Responsive
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Auto Run Pipeline',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      'Rotate queries and ingest restaurants',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Apify Native',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Results per query (Vertical stack — overflow-proof)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Results per hashtag',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Places batch',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _BatchOptionButton(
                    label: '20 places',
                    isSelected: _resultsPerQuery == 20,
                    onTap: () => setState(() => _resultsPerQuery = 20),
                  ),
                  const SizedBox(width: 8),
                  _BatchOptionButton(
                    label: '30 places',
                    isSelected: _resultsPerQuery == 30,
                    onTap: () => setState(() => _resultsPerQuery = 30),
                  ),
                  const SizedBox(width: 8),
                  _BatchOptionButton(
                    label: '40 places',
                    isSelected: _resultsPerQuery == 40,
                    onTap: () => setState(() => _resultsPerQuery = 40),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Two-column responsive card row for Max Queries & Budget Limit
          Row(
            children: [
              // Max queries stepper
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    border: Border.all(color: AppColors.secondary),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Max hashtag',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _StepperButton(
                            icon: LucideIcons.minus,
                            onPressed: _maxQueries > 1
                                ? () => setState(() => _maxQueries--)
                                : null,
                          ),
                          Expanded(
                            child: Text(
                              '$_maxQueries',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.foreground,
                              ),
                            ),
                          ),
                          _StepperButton(
                            icon: LucideIcons.plus,
                            onPressed: _maxQueries < 100
                                ? () => setState(() => _maxQueries++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Cost limit
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    border: Border.all(color: AppColors.secondary),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Budget limit (USD)',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 30,
                        child: TextFormField(
                          initialValue: _costLimitUsd.toStringAsFixed(1),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                          decoration: InputDecoration(
                            prefixText: '\$ ',
                            prefixStyle: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedForeground,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            fillColor: Colors.transparent,
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cost estimation banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.sparkles,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Est. cost: ~\$${estimatedCostPerQuery.toStringAsFixed(3)}/hashtag × $_maxQueries hashtags ≈ \$${estimatedTotalCost.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Start Auto Run Button
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
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Single Scan fallback button
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: widget.onStartScan,
              icon: const Icon(LucideIcons.scanLine, size: 15),
              label: const Text(
                'Run Single Scan (1 hashtag)',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.foreground,
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

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 14,
        onPressed: onPressed,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: AppColors.secondary),
          ),
        ),
      ),
    );
  }
}

class _BatchOptionButton extends StatelessWidget {
  const _BatchOptionButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.secondary,
            ),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.surface : AppColors.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auto Run Progress — Shown while active
// ---------------------------------------------------------------------------

class _AutoRunProgress extends StatefulWidget {
  const _AutoRunProgress({
    required this.autoRun,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    this.activeHashtag,
    this.latestDiscoveredRestaurant,
  });

  final AutoRunState autoRun;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onStop;
  final String? activeHashtag;
  final String? latestDiscoveredRestaurant;

  @override
  State<_AutoRunProgress> createState() => _AutoRunProgressState();
}

class _AutoRunProgressState extends State<_AutoRunProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _statusTickerTimer;
  int _statusCueIndex = 0;
  bool _pausePending = false;
  bool _resumePending = false;
  bool _stopPending = false;

  bool get _anyPending => _pausePending || _resumePending || _stopPending;

  static const _statusCues = [
    'AI analyzing Instagram feed for foodie hotspots...',
    'Evaluating post engagement and candidate mentions...',
    'Cross-referencing geolocation coordinates & profiles...',
    'Filtering high-resolution images & verified assets...',
    'Searching for hidden culinary gems across Malaysia...',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _statusTickerTimer = Timer.periodic(const Duration(milliseconds: 3200), (
      timer,
    ) {
      if (!mounted) return;
      setState(() {
        _statusCueIndex = (_statusCueIndex + 1) % _statusCues.length;
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusTickerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final autoRun = widget.autoRun;
    final isPaused = autoRun.status == AutoRunStatus.paused;
    final config = autoRun.config;
    final progressFraction = config.maxQueries > 0
        ? (autoRun.queriesCompleted / config.maxQueries).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: isPaused
              ? AppColors.accent.withValues(alpha: 0.5)
              : AppColors.primary.withValues(alpha: 0.5),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header status
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: isPaused
                    ? const Icon(
                        LucideIcons.pause,
                        size: 16,
                        color: AppColors.accent,
                      )
                    : const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPaused ? 'Auto Run Paused' : 'Auto Run Processing',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      'Autonomous multi-hashtag discovery in progress',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (isPaused ? AppColors.accent : AppColors.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${autoRun.queriesCompleted}/${config.maxQueries} hashtags',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isPaused ? AppColors.accent : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Linear progress
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressFraction,
              minHeight: 6,
              backgroundColor: AppColors.secondary.withValues(alpha: 0.5),
              color: isPaused ? AppColors.accent : AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),

          // Live AI Discovery Stream Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isPaused
                    ? AppColors.secondary
                    : AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPaused
                                ? AppColors.accent
                                : AppColors.success.withValues(
                                    alpha: _pulseAnimation.value,
                                  ),
                            boxShadow: isPaused
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppColors.success.withValues(
                                        alpha: 0.5 * _pulseAnimation.value,
                                      ),
                                      blurRadius: 6,
                                      spreadRadius: 2,
                                    ),
                                  ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AI DISCOVERY STREAM',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    if (widget.activeHashtag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          widget.activeHashtag!,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (widget.latestDiscoveredRestaurant != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.sparkles,
                          size: 14,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'New restaurant (${widget.latestDiscoveredRestaurant}) found! Searching for more...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Icon(
                        LucideIcons.bot,
                        size: 14,
                        color: AppColors.primary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            isPaused
                                ? 'Pipeline paused. Tap Resume to continue discovery.'
                                : _statusCues[_statusCueIndex],
                            key: ValueKey(
                              isPaused ? 'paused' : _statusCueIndex,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.foreground,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Live Metrics Tiles Grid
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _AutoRunMetricTile(
                icon: LucideIcons.utensilsCrossed,
                label: 'New restaurants',
                value: '${autoRun.newRestaurants}',
                color: AppColors.success,
              ),
              _AutoRunMetricTile(
                icon: LucideIcons.repeat,
                label: 'Existing matched',
                value: '${autoRun.existingMatched}',
                color: AppColors.primary,
              ),
              _AutoRunMetricTile(
                icon: LucideIcons.imageOff,
                label: 'Skipped (no img)',
                value: '${autoRun.skippedNoImage}',
                color: AppColors.accent,
              ),
              _AutoRunMetricTile(
                icon: LucideIcons.triangleAlert,
                label: 'Failed candidates',
                value: '${autoRun.failedCandidates}',
                color: AppColors.destructive,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Live Cost Tile
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.dollarSign,
                        size: 14,
                        color: AppColors.foreground,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Total Run Spend',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${autoRun.totalCostUsd.toStringAsFixed(3)}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Control buttons
          Row(
            children: [
              Expanded(
                child: isPaused
                    ? FilledButton.icon(
                        onPressed: _anyPending
                            ? null
                            : () async {
                                setState(() => _resumePending = true);
                                try {
                                  await widget.onResume();
                                } finally {
                                  if (mounted) {
                                    setState(() => _resumePending = false);
                                  }
                                }
                              },
                        icon: _resumePending
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.surface,
                                ),
                              )
                            : const Icon(LucideIcons.play, size: 15),
                        label: Text(
                          _resumePending ? 'Resuming...' : 'Resume',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _anyPending
                              ? AppColors.primary.withValues(alpha: 0.6)
                              : AppColors.primary,
                          foregroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadii.control,
                            ),
                          ),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: _anyPending
                            ? null
                            : () async {
                                setState(() => _pausePending = true);
                                try {
                                  await widget.onPause();
                                } finally {
                                  if (mounted) {
                                    setState(() => _pausePending = false);
                                  }
                                }
                              },
                        icon: _pausePending
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.foreground.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              )
                            : const Icon(LucideIcons.pause, size: 15),
                        label: Text(
                          _pausePending ? 'Pausing...' : 'Pause',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _anyPending
                              ? AppColors.foreground.withValues(alpha: 0.4)
                              : AppColors.foreground,
                          side: BorderSide(
                            color: _anyPending
                                ? AppColors.secondary.withValues(alpha: 0.3)
                                : AppColors.secondary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadii.control,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('stop-auto-run-button'),
                  onPressed: _anyPending
                      ? null
                      : () async {
                          setState(() => _stopPending = true);
                          try {
                            await widget.onStop();
                          } finally {
                            if (mounted) {
                              setState(() => _stopPending = false);
                            }
                          }
                        },
                  icon: _stopPending
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.destructive.withValues(alpha: 0.5),
                          ),
                        )
                      : const Icon(LucideIcons.circleStop, size: 15),
                  label: Text(
                    _stopPending ? 'Stopping...' : 'Stop',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _anyPending
                        ? AppColors.destructive.withValues(alpha: 0.4)
                        : AppColors.destructive,
                    side: BorderSide(
                      color: _anyPending
                          ? AppColors.destructive.withValues(alpha: 0.2)
                          : AppColors.destructive.withValues(alpha: 0.4),
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

class _AutoRunMetricTile extends StatelessWidget {
  const _AutoRunMetricTile({
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
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
// Auto Run Summary Card — Shown after finish
// ---------------------------------------------------------------------------

class _AutoRunSummaryCard extends StatelessWidget {
  const _AutoRunSummaryCard({required this.autoRun});

  final AutoRunState autoRun;

  @override
  Widget build(BuildContext context) {
    final isCompleted = autoRun.status == AutoRunStatus.completed;
    final isFailed = autoRun.status == AutoRunStatus.failed;
    final statusColor = isCompleted
        ? AppColors.success
        : isFailed
        ? AppColors.destructive
        : AppColors.accent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
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
                  isCompleted
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
                      'Auto Run ${autoRun.status.name.toUpperCase()}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    if (autoRun.stopReason != null)
                      Text(
                        autoRun.stopReason!,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ResultRow(
            label: 'Queries completed',
            value: '${autoRun.queriesCompleted}',
            color: AppColors.primary,
          ),
          const SizedBox(height: 6),
          _ResultRow(
            label: 'New restaurants created',
            value: '${autoRun.newRestaurants}',
            color: AppColors.success,
          ),
          const SizedBox(height: 6),
          _ResultRow(
            label: 'Existing restaurants matched',
            value: '${autoRun.existingMatched}',
            color: AppColors.primary,
          ),
          const SizedBox(height: 6),
          _ResultRow(
            label: 'Skipped (no permanent image)',
            value: '${autoRun.skippedNoImage}',
            color: AppColors.accent,
          ),
          const SizedBox(height: 6),
          _ResultRow(
            label: 'Failed candidates',
            value: '${autoRun.failedCandidates}',
            color: AppColors.destructive,
          ),
          const SizedBox(height: 6),
          _ResultRow(
            label: 'Total run spend',
            value: '\$${autoRun.totalCostUsd.toStringAsFixed(3)}',
            color: AppColors.foreground,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scan Progress — Single Scan Active
// ---------------------------------------------------------------------------

class _ScanProgress extends StatefulWidget {
  const _ScanProgress({required this.state});

  final PipelineState state;



  @override
  State<_ScanProgress> createState() => _ScanProgressState();
}

class _ScanProgressState extends State<_ScanProgress>
    with SingleTickerProviderStateMixin {
  late DateTime _startedAt;
  Timer? _tickerTimer;
  int _elapsedSeconds = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds = DateTime.now().difference(_startedAt).inSeconds;
      });
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatElapsed(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _getScrapeSubphaseMessage(int seconds) {
    if (seconds < 6) return 'Initializing Instagram Apify scraper...';
    if (seconds < 16) return 'Fetching latest Instagram posts & reels...';
    if (seconds < 28) {
      return 'Extracting captions, locations & food hashtags...';
    }

    if (seconds < 42) return 'Downloading post metadata & image assets...';
    return 'Finalizing Instagram extraction & preparing ingest...';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isScraping =
        state.currentStep == PipelineStep.scrape || state.currentStep == null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with active status and elapsed duration timer
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.stepMessage.isEmpty
                          ? 'Scanning hashtag...'
                          : state.stepMessage,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                    if (state.activeHashtag != null)
                      Text(
                        'Targeting ${state.activeHashtag}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.secondary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.timer,
                      size: 11,
                      color: AppColors.mutedForeground,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatElapsed(_elapsedSeconds),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Live Sub-phase Banner during initial scrape
          if (isScraping) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Icon(
                        LucideIcons.sparkles,
                        size: 14,
                        color: AppColors.primary.withValues(
                          alpha: _pulseAnimation.value,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getScrapeSubphaseMessage(_elapsedSeconds),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          _ProgressSteps(
            currentStep: state.currentStep,
            elapsedSeconds: _elapsedSeconds,
            scrapeSubphase: isScraping
                ? _getScrapeSubphaseMessage(_elapsedSeconds)
                : null,
            stepMessage: state.stepMessage,
          ),
        ],
      ),
    );
  }
}

class _ProgressSteps extends StatelessWidget {
  const _ProgressSteps({
    required this.currentStep,
    this.elapsedSeconds = 0,
    this.scrapeSubphase,
    this.stepMessage,
  });

  final PipelineStep? currentStep;
  final int elapsedSeconds;
  final String? scrapeSubphase;
  final String? stepMessage;

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

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 6),
          padding: EdgeInsets.symmetric(
            horizontal: isCurrent ? 8 : 4,
            vertical: isCurrent ? 6 : 4,
          ),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isCurrent
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            children: [
              _StepIcon(
                icon: icon,
                isComplete: isComplete,
                isCurrent: isCurrent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: isCurrent
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isComplete
                            ? AppColors.success
                            : isCurrent
                            ? AppColors.foreground
                            : AppColors.mutedForeground,
                      ),
                    ),
                    if (isCurrent)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          step == PipelineStep.scrape
                              ? (scrapeSubphase ??
                                  'In progress (${elapsedSeconds}s elapsed)')
                              : (stepMessage?.isNotEmpty == true
                                  ? stepMessage!
                                  : 'In progress...'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                  ],
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
                  width: 12,
                  height: 12,
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
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isComplete
            ? AppColors.success.withValues(alpha: 0.1)
            : isCurrent
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.secondary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 13, color: color),
    );
  }
}

// ---------------------------------------------------------------------------
// Results Card (Single scan completion)
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
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
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
              const Text(
                'Single Scan Completed',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ResultRow(
            label: 'Posts received',
            value: '${result.postsReceived}',
            color: AppColors.primary,
          ),
          const SizedBox(height: 6),
          _ResultRow(
            label: 'New restaurants created',
            value: '${result.newRestaurants}',
            color: AppColors.success,
          ),
          const SizedBox(height: 6),
          _ResultRow(
            label: 'Cost',
            value: '\$${result.costUsd.toStringAsFixed(3)}',
            color: AppColors.accent,
          ),
          if (result.newRestaurants > 0) ...[
            const SizedBox(height: 6),
            _ResultRow(
              label: 'Cost per new restaurant',
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
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        const SizedBox(width: 8),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.destructive.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.triangleAlert,
            size: 18,
            color: AppColors.destructive,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.destructive,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Discovery Sources Section
// ---------------------------------------------------------------------------

class _DiscoverySourcesSection extends StatelessWidget {
  const _DiscoverySourcesSection({
    required this.sources,
    required this.visibleCount,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final List<DiscoverySourceSummary> sources;
  final int visibleCount;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final count = visibleCount.clamp(0, sources.length);
    final visibleSources = sources.take(count).toList();
    final hasMore = count < sources.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Discovery Sources',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${sources.length} sources registered',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (sources.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.secondary),
            ),
            child: Column(
              children: [
                Icon(
                  LucideIcons.database,
                  size: 32,
                  color: AppColors.mutedForeground.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No discovery sources yet',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  'Run an Auto Run or single scan to ingest hashtags',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          )
        else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleSources.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _ModernSourceCard(source: visibleSources[index]),
          ),
          const SizedBox(height: 12),
          _PaginationFooter(
            currentCount: count,
            totalCount: sources.length,
            itemLabel: 'sources',
            hasMore: hasMore,
            isLoadingMore: isLoadingMore,
            onLoadMore: onLoadMore,
          ),
        ],
      ],
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({
    required this.currentCount,
    required this.totalCount,
    required this.itemLabel,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final int currentCount;
  final int totalCount;
  final String itemLabel;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (!hasMore) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.checkCheck,
              size: 14,
              color: AppColors.success,
            ),
            const SizedBox(width: 6),
            Text(
              'All $totalCount $itemLabel loaded',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Showing $currentCount of $totalCount $itemLabel',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isLoadingMore
                      ? 'Loading more $itemLabel...'
                      : 'Scroll down or tap to load more',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isLoadingMore)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else
            TextButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(LucideIcons.chevronDown, size: 14),
              label: const Text('Load more'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModernSourceCard extends StatelessWidget {
  const _ModernSourceCard({required this.source});

  final DiscoverySourceSummary source;

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
    final yieldPercent = (source.yieldRate * 100).clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  source.sourceValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              if (isAutomation) ...[
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
                    'AI GENERATED',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  source.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Area and type context
          Text(
            '${source.sourceType} · ${source.area ?? "All areas"}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 10),

          // Yield bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (source.yieldRate).clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: AppColors.secondary.withValues(alpha: 0.4),
                    color: source.yieldRate > 0.3
                        ? AppColors.success
                        : AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${yieldPercent.toStringAsFixed(1)}% yield',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: source.yieldRate > 0.3
                      ? AppColors.success
                      : AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Micro metrics chips
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _MiniBadge(
                label: '${source.newRestaurants} restaurants',
                color: source.newRestaurants > 0
                    ? AppColors.success
                    : AppColors.mutedForeground,
              ),
              _MiniBadge(
                label: '${source.postsScraped} posts',
                color: AppColors.primary,
              ),
              _MiniBadge(
                label: '${source.scrapeCount} scrapes',
                color: AppColors.mutedForeground,
              ),
            ],
          ),

          if (source.createdAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Added ${_formatDate(source.createdAt)}',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: Recent Runs Section
// ---------------------------------------------------------------------------

class _RecentRunsSection extends StatelessWidget {
  const _RecentRunsSection({
    required this.runs,
    required this.visibleCount,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final List<ScrapeRunSummary> runs;
  final int visibleCount;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final count = visibleCount.clamp(0, runs.length);
    final visibleRuns = runs.take(count).toList();
    final hasMore = count < runs.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Scrape Run History',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (runs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.secondary),
            ),
            child: Column(
              children: [
                Icon(
                  LucideIcons.history,
                  size: 32,
                  color: AppColors.mutedForeground.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No runs recorded yet',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  'Run an auto run or single scan to see history',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          )
        else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleRuns.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _ModernRunCard(run: visibleRuns[index]),
          ),
          const SizedBox(height: 12),
          _PaginationFooter(
            currentCount: count,
            totalCount: runs.length,
            itemLabel: 'runs',
            hasMore: hasMore,
            isLoadingMore: isLoadingMore,
            onLoadMore: onLoadMore,
          ),
        ],
      ],
    );
  }
}

class _ModernRunCard extends StatelessWidget {
  const _ModernRunCard({required this.run});

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
    final isCompleted = run.status == 'completed';
    final isFailed = run.status == 'failed';
    final statusColor = isCompleted
        ? AppColors.success
        : isFailed
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sourceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  run.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (sourceContext.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              sourceContext,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Results row
          Row(
            children: [
              _RunMetricPill(
                label: '${run.newRestaurants} new',
                isHighlight: run.newRestaurants > 0,
                highlightColor: AppColors.success,
              ),
              const SizedBox(width: 6),
              _RunMetricPill(
                label: '${run.postsReceived} received',
                isHighlight: false,
              ),
              const SizedBox(width: 6),
              _RunMetricPill(
                label: '${run.newPosts} new posts',
                isHighlight: false,
              ),
              const Spacer(),
              Text(
                '\$${run.costUsd.toStringAsFixed(3)}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Timestamp
          Text(
            _formatRunDate(run.startedAt ?? run.completedAt),
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _RunMetricPill extends StatelessWidget {
  const _RunMetricPill({
    required this.label,
    required this.isHighlight,
    this.highlightColor,
  });

  final String label;
  final bool isHighlight;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final color = isHighlight
        ? (highlightColor ?? AppColors.primary)
        : AppColors.mutedForeground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isHighlight
            ? color.withValues(alpha: 0.1)
            : AppColors.secondary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
          color: isHighlight ? color : AppColors.foreground,
        ),
      ),
    );
  }
}
