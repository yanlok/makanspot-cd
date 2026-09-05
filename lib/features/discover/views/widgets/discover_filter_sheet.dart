import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';
import '../../controllers/discover_controller.dart';
import '../../controllers/discover_state.dart';

const List<String> discoverSupportedCuisines = [
  'Malay',
  'Chinese',
  'Indian',
  'Mamak',
  'Cafe',
  'Street Food',
  'Dessert & Bakery',
  'Western',
  'Japanese',
  'Korean',
  'Seafood',
  'Thai',
  'Fast Food',
  'Vegetarian',
  'Middle Eastern',
];

const List<String> discoverSupportedAreas = [
  'Kuala Lumpur',
  'Petaling Jaya',
  'Bangsar',
  'Subang Jaya',
  'Damansara',
  'Mont Kiara',
  'Ampang',
  'Cheras',
  'Puchong',
  'Kepong',
];

const List<String> discoverSortOptions = [
  'Popularity',
  'Distance',
  'Newest Listings',
  'Name (A-Z)',
];

Future<void> showDiscoverFilterSheet(
  BuildContext context, {
  required DiscoverController controller,
  DiscoverState? state,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _DiscoverFilterModal(
      controller: controller,
      initialState: state,
    ),
  );
}

class _DiscoverFilterModal extends StatefulWidget {
  const _DiscoverFilterModal({
    required this.controller,
    this.initialState,
  });

  final DiscoverController controller;
  final DiscoverState? initialState;

  @override
  State<_DiscoverFilterModal> createState() => _DiscoverFilterModalState();
}

class _DiscoverFilterModalState extends State<_DiscoverFilterModal> {
  late DiscoverState _state;
  void Function()? _removeListener;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState ?? widget.controller.currentState;
    _removeListener = widget.controller.addListener((nextState) {
      if (mounted) {
        setState(() {
          _state = nextState;
        });
      }
    }, fireImmediately: false);
  }

  @override
  void dispose() {
    _removeListener?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = _state;
    final controller = widget.controller;
    final activeCount = state.activeFilterCount;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
              child: Row(
                children: [
                  Text(
                    'Filters',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (activeCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$activeCount',
                        style: const TextStyle(
                          color: AppColors.surface,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (activeCount > 0)
                    TextButton(
                      key: const Key('discover-filter-reset'),
                      onPressed: controller.clearFilters,
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, size: 20),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.secondary),

            // Scrollable Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // Section 1: Sort By
                  _SectionHeader(title: 'Sort By', icon: LucideIcons.arrowUpDown),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: discoverSortOptions.map((option) {
                      final isSelected = state.sortBy == option;
                      return _FilterPill(
                        key: Key('sort-$option'),
                        label: option,
                        isSelected: isSelected,
                        onTap: () => controller.selectSort(option),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Section 2: Budget
                  _SectionHeader(title: 'Price Range', icon: LucideIcons.banknote),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _BudgetOptionCard(
                          label: r'$',
                          description: 'Under RM15',
                          isSelected: state.selectedBudgets.contains('Low'),
                          onTap: () => controller.toggleBudget('Low'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _BudgetOptionCard(
                          label: r'$$',
                          description: 'RM15 - RM40',
                          isSelected: state.selectedBudgets.contains('Medium'),
                          onTap: () => controller.toggleBudget('Medium'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _BudgetOptionCard(
                          label: r'$$$',
                          description: 'RM40+',
                          isSelected: state.selectedBudgets.contains('High'),
                          onTap: () => controller.toggleBudget('High'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 3: Area / City
                  _SectionHeader(title: 'Area / City', icon: LucideIcons.mapPin),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: discoverSupportedAreas.map((area) {
                      final isSelected = state.selectedAreas.contains(area);
                      return _FilterPill(
                        key: Key('area-$area'),
                        label: area,
                        isSelected: isSelected,
                        onTap: () => controller.toggleArea(area),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Section 4: Cuisine
                  _SectionHeader(title: 'Cuisine / Food Category', icon: LucideIcons.utensils),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: discoverSupportedCuisines.map((cuisine) {
                      final isSelected = state.selectedCuisines.contains(cuisine);
                      return _FilterPill(
                        key: Key('cuisine-$cuisine'),
                        label: cuisine,
                        isSelected: isSelected,
                        onTap: () => controller.toggleCuisine(cuisine),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Sticky Bottom Apply Bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.secondary)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    key: const Key('discover-filter-apply'),
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.control),
                      ),
                    ),
                    child: Text(
                      'Show ${state.restaurants.length} Restaurants',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.foreground,
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primary : AppColors.surface,
      shape: StadiumBorder(
        side: isSelected
            ? BorderSide.none
            : const BorderSide(color: AppColors.secondary),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                const Icon(
                  LucideIcons.check,
                  size: 14,
                  color: AppColors.surface,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.surface : AppColors.secondaryForeground,
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetOptionCard extends StatelessWidget {
  const _BudgetOptionCard({
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.secondary,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    const Icon(
                      LucideIcons.check,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.primary : AppColors.foreground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.mutedForeground,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
