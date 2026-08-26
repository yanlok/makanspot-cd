import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import 'package:makanspot/shared/widgets/makan_network_image.dart';

import '../controllers/journey_controller.dart';
import '../models/journey_models.dart';
import 'widgets/journey_widgets.dart';

class VisitHistoryScreen extends ConsumerWidget {
  const VisitHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(journeyControllerProvider);
    final controller = ref.read(journeyControllerProvider.notifier);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          JourneyPageHeader(
            title: 'Visit History',
            onBack: context.pop,
            bottom: Column(
              children: [
                TextField(
                  key: const Key('visit-search'),
                  onChanged: controller.updateVisitSearch,
                  decoration: const InputDecoration(
                    hintText: 'Search your visits...',
                    prefixIcon: Icon(LucideIcons.search, size: 19),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _VisitFilterMenu<JourneyVisitPeriod>(
                        value: state.visitPeriod,
                        label: _periodLabel(state.visitPeriod),
                        items: const [
                          PopupMenuItem(
                            value: JourneyVisitPeriod.allTime,
                            child: Text('All time'),
                          ),
                          PopupMenuItem(
                            value: JourneyVisitPeriod.last30Days,
                            child: Text('Last 30 days'),
                          ),
                          PopupMenuItem(
                            value: JourneyVisitPeriod.last12Months,
                            child: Text('Last 12 months'),
                          ),
                          PopupMenuItem(
                            value: JourneyVisitPeriod.yearToDate,
                            child: Text('Year to date'),
                          ),
                        ],
                        onSelected: controller.updateVisitPeriod,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _VisitFilterMenu<JourneyActivityFilter>(
                        value: state.activityFilter,
                        label: state.activityFilter == JourneyActivityFilter.all
                            ? 'All activity'
                            : 'Reviews only',
                        items: const [
                          PopupMenuItem(
                            value: JourneyActivityFilter.all,
                            child: Text('All activity'),
                          ),
                          PopupMenuItem(
                            value: JourneyActivityFilter.reviews,
                            child: Text('Reviews only'),
                          ),
                        ],
                        onSelected: controller.updateActivityFilter,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _body(context, state, controller)),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    JourneyState state,
    JourneyController controller,
  ) {
    if (state.status == JourneyStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == JourneyStatus.error) {
      return JourneyErrorState(
        message: state.errorMessage!,
        onRetry: controller.load,
      );
    }
    if (state.filteredVisits.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.calendar,
                size: 44,
                color: AppColors.mutedForeground,
              ),
              SizedBox(height: 12),
              Text('No Visits Yet'),
              SizedBox(height: 6),
              Text(
                'Your visited restaurants will appear here after you write a review.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedForeground),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      key: const Key('visit-history-list'),
      padding: const EdgeInsets.all(16),
      itemCount: state.filteredVisits.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _VisitCard(visit: state.filteredVisits[index]),
    );
  }
}

class _VisitFilterMenu<T> extends StatelessWidget {
  const _VisitFilterMenu({
    required this.value,
    required this.label,
    required this.items,
    required this.onSelected,
  });

  final T value;
  final String label;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (_) => items,
      child: OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(LucideIcons.listFilter, size: 16),
        label: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

String _periodLabel(JourneyVisitPeriod period) {
  return switch (period) {
    JourneyVisitPeriod.allTime => 'All time',
    JourneyVisitPeriod.last30Days => 'Last 30 days',
    JourneyVisitPeriod.last12Months => 'Last 12 months',
    JourneyVisitPeriod.yearToDate => 'Year to date',
  };
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.visit});

  final JourneyVisit visit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('visit-${visit.id}'),
      onTap: () => context.push('/restaurant/${visit.restaurantId}'),
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.secondary),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.control),
              child: SizedBox.square(
                dimension: 64,
                child: MakanNetworkImage(
                  url: visit.restaurantImage,
                  semanticLabel: visit.restaurantName,
                  fallbackKey: Key('visit-fallback-${visit.id}'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visit.restaurantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  _MetaLine(icon: LucideIcons.mapPin, text: visit.cuisine),
                  const SizedBox(height: 4),
                  _MetaLine(
                    icon: LucideIcons.calendar,
                    text: _formatDate(visit.visitDate),
                  ),
                  if (visit.postId != null)
                    TextButton(
                      onPressed: () => context.push('/post/${visit.postId}'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 28),
                      ),
                      child: const Text('View Review →'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.mutedForeground),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
        ),
      ],
    );
  }
}
