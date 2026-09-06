import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/restaurant_details_controller.dart';
import '../models/admin_models.dart';
import 'widgets/admin_form_widgets.dart';
import 'widgets/admin_page_header.dart';
import 'widgets/admin_skeletons.dart';

class RestaurantInformationScreen extends ConsumerStatefulWidget {
  const RestaurantInformationScreen({required this.restaurantId, super.key});

  final String restaurantId;

  @override
  ConsumerState<RestaurantInformationScreen> createState() =>
      _RestaurantInformationScreenState();
}

class _RestaurantInformationScreenState
    extends ConsumerState<RestaurantInformationScreen> {
  Future<void> _removeRestaurant() async {
    final request = await _showRestaurantRemovalDialog(context);
    if (request == null || !mounted) return;

    final error = await ref
        .read(restaurantDetailsControllerProvider(widget.restaurantId).notifier)
        .remove(
          reason: request.reason,
          additionalNote: request.additionalNote,
        );
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('restaurant remove successfully.')),
    );
    context.go('/admin/restaurants');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      restaurantDetailsControllerProvider(widget.restaurantId),
    );
    final controller = ref.read(
      restaurantDetailsControllerProvider(widget.restaurantId).notifier,
    );
    final restaurant = state.restaurant;
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('restaurant-information-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AdminBackButton(
            label: 'Back to Restaurants',
            onPressed: () => context.go('/admin/restaurants'),
          ),
          const SizedBox(height: 16),
          const AdminPageHeader(
            title: 'Restaurant Information',
            subtitle: 'Restaurant details and verification status',
          ),
          const SizedBox(height: 20),
          if (state.status == RestaurantDetailsStatus.loading)
            const _RestaurantInformationSkeleton()
          else if (state.status == RestaurantDetailsStatus.notFound)
            const _RestaurantInformationMessage(
              icon: LucideIcons.circleX,
              message: 'Restaurant not found.',
            )
          else if (state.status == RestaurantDetailsStatus.error)
            _RestaurantInformationError(
              message: state.errorMessage!,
              onRetry: controller.load,
            )
          else if (restaurant != null) ...[
            _RestaurantInformationCard(restaurant: restaurant),
            const SizedBox(height: 24),
            AdminPrimaryButton(
              label: 'Edit Restaurant',
              icon: LucideIcons.pencil,
              buttonKey: const Key('admin-restaurant-edit'),
              onPressed: () =>
                  context.go('/admin/restaurants/${restaurant.id}/edit'),
            ),
            const SizedBox(height: 12),
            AdminOutlineButton(
              label: 'Remove Restaurant',
              icon: LucideIcons.trash2,
              borderColor: AppColors.destructive,
              foregroundColor: AppColors.destructive,
              buttonKey: const Key('admin-restaurant-remove'),
              onPressed: _removeRestaurant,
            ),
          ],
        ],
      ),
    );
  }
}

class _RestaurantRemovalRequest {
  const _RestaurantRemovalRequest({
    required this.reason,
    required this.additionalNote,
  });

  final RestaurantRemovalReason reason;
  final String? additionalNote;
}

Future<_RestaurantRemovalRequest?> _showRestaurantRemovalDialog(
  BuildContext context,
) async {
  final noteController = TextEditingController();
  RestaurantRemovalReason? selectedReason;
  var showReasonError = false;
  var showNoteError = false;

  try {
    return await showModalBottomSheet<_RestaurantRemovalRequest>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.foreground.withValues(alpha: 0.4),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Container(
                key: const Key('admin-restaurant-removal-dialog'),
                margin: const EdgeInsets.all(16),
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
                    Text(
                      'Remove Restaurant?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'please provide a reason for removing the restaurant',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const AdminFieldLabel('Removal reason *'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<RestaurantRemovalReason>(
                      key: const Key('admin-restaurant-removal-reason'),
                      value: selectedReason,
                      isExpanded: true,
                      hint: const Text('Choose a reason'),
                      items: RestaurantRemovalReason.values
                          .map(
                            (reason) => DropdownMenuItem(
                              value: reason,
                              child: Text(reason.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (reason) => setSheetState(() {
                        selectedReason = reason;
                        showReasonError = false;
                        if (reason != RestaurantRemovalReason.other) {
                          showNoteError = false;
                        }
                      }),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (showReasonError) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Choose a removal reason.',
                        style: TextStyle(color: AppColors.destructive),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const AdminFieldLabel('Additional note — optional'),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('admin-restaurant-removal-note'),
                      controller: noteController,
                      maxLines: 3,
                      onChanged: (_) {
                        if (showNoteError) {
                          setSheetState(() => showNoteError = false);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: selectedReason == RestaurantRemovalReason.other
                            ? 'Required when Other is selected'
                            : 'Add details if helpful',
                        errorText: showNoteError
                            ? 'An additional note is required for Other.'
                            : null,
                        filled: true,
                        fillColor: AppColors.surface,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        key: const Key('admin-restaurant-removal-confirm'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.destructive,
                          foregroundColor: AppColors.surface,
                        ),
                        onPressed: () {
                          final requiresNote =
                              selectedReason == RestaurantRemovalReason.other;
                          final note = noteController.text.trim();
                          if (selectedReason == null ||
                              (requiresNote && note.isEmpty)) {
                            setSheetState(() {
                              showReasonError = selectedReason == null;
                              showNoteError = requiresNote && note.isEmpty;
                            });
                            return;
                          }
                          Navigator.of(sheetContext).pop(
                            _RestaurantRemovalRequest(
                              reason: selectedReason!,
                              additionalNote: note.isEmpty ? null : note,
                            ),
                          );
                        },
                        child: const Text('Remove Restaurant'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  } finally {
    noteController.dispose();
  }
}

class _RestaurantInformationCard extends StatelessWidget {
  const _RestaurantInformationCard({required this.restaurant});

  final AdminRestaurant restaurant;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RestaurantImage(imageUrl: restaurant.imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      restaurant.categoriesDisplay,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _InformationSectionTitle('Restaurant Information'),
          _InformationRow(
            icon: LucideIcons.hash,
            label: 'Restaurant ID',
            value: restaurant.id,
          ),
          _InformationRow(
            icon: LucideIcons.store,
            label: 'Restaurant Name',
            value: restaurant.name,
          ),
          _InformationRow(
            icon: LucideIcons.mapPin,
            label: 'Address',
            value: _orNotProvided(restaurant.address),
          ),
          _InformationRow(
            icon: LucideIcons.clock3,
            label: 'Business Hours',
            value: _formatBusinessHours(restaurant.businessHours),
          ),
          const SizedBox(height: 12),
          const _InformationSectionTitle('Owner Information'),
          _InformationRow(
            icon: LucideIcons.userRound,
            label: 'Instagram',
            value: _orNotProvided(restaurant.instagramUsername),
          ),
          _InformationRow(
            icon: LucideIcons.phone,
            label: 'Phone',
            value: _orNotProvided(restaurant.phone),
            last: true,
          ),
        ],
      ),
    );
  }

  static String _orNotProvided(String? value) =>
      (value == null || value.isEmpty) ? 'Not provided' : value;

  static String _formatBusinessHours(Map<String, dynamic>? hours) {
    if (hours == null || hours.isEmpty) return 'Not provided';
    return hours.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }
}

class _InformationSectionTitle extends StatelessWidget {
  const _InformationSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _RestaurantImage extends StatelessWidget {
  const _RestaurantImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 72,
      height: 72,
      color: AppColors.secondary,
      child: const Icon(
        LucideIcons.utensilsCrossed,
        color: AppColors.mutedForeground,
      ),
    );
    if (imageUrl.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: fallback,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.secondary)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.mutedForeground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantInformationMessage extends StatelessWidget {
  const _RestaurantInformationMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _RestaurantInformationError extends StatelessWidget {
  const _RestaurantInformationError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
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
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _RestaurantInformationSkeleton extends StatelessWidget {
  const _RestaurantInformationSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.secondary),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSkeletonBox(height: 72, width: double.infinity, radius: 12),
          SizedBox(height: 20),
          AdminSkeletonBox(height: 48, width: double.infinity, radius: 8),
          SizedBox(height: 12),
          AdminSkeletonBox(height: 48, width: double.infinity, radius: 8),
          SizedBox(height: 12),
          AdminSkeletonBox(height: 48, width: double.infinity, radius: 8),
        ],
      ),
    );
  }
}
