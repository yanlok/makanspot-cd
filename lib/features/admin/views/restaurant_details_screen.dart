import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/restaurant_details_controller.dart';
import '../models/admin_models.dart';
import 'widgets/admin_confirm_dialog.dart';
import 'widgets/admin_form_widgets.dart';
import 'widgets/admin_skeletons.dart';
import 'widgets/admin_status_badge.dart';

const _cuisines = <String>[
  'Malay',
  'Chinese',
  'Indian',
  'Nyonya',
  'Western',
  'Japanese',
  'Korean',
  'Street Food',
  'Desserts',
  'Mamak',
];

const _budgets = <String>['Low', 'Medium', 'High'];

class RestaurantDetailsScreen extends ConsumerStatefulWidget {
  const RestaurantDetailsScreen({required this.restaurantId, super.key});

  final String restaurantId;

  @override
  ConsumerState<RestaurantDetailsScreen> createState() =>
      _RestaurantDetailsScreenState();
}

class _RestaurantDetailsScreenState
    extends ConsumerState<RestaurantDetailsScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _hoursController = TextEditingController();
  final _contactController = TextEditingController();
  final _ratingController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sourceController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  String _cuisine = _cuisines.first;
  String _budget = _budgets.first;
  bool _isVerified = false;
  String _imageUrl = '';
  bool _uploading = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _addressController.dispose();
    _hoursController.dispose();
    _contactController.dispose();
    _ratingController.dispose();
    _descriptionController.dispose();
    _sourceController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _seed(AdminRestaurant restaurant) {
    _nameController.text = restaurant.name;
    _cuisine = _cuisines.contains(restaurant.cuisine)
        ? restaurant.cuisine
        : _cuisines.first;
    _addressController.text = restaurant.address;
    _hoursController.text = restaurant.operatingHours;
    _contactController.text = restaurant.contact;
    _ratingController.text = restaurant.rating?.toString() ?? '';
    _budget = _budgets.contains(restaurant.budget)
        ? restaurant.budget
        : _budgets.first;
    _descriptionController.text = restaurant.description;
    _imageUrl = restaurant.imageUrl;
    _sourceController.text = restaurant.sourcePlatform;
    _isVerified = restaurant.isVerified;
    _latitudeController.text = restaurant.latitude?.toString() ?? '';
    _longitudeController.text = restaurant.longitude?.toString() ?? '';
    _seeded = true;
  }

  AdminRestaurantDraft _draft() {
    return AdminRestaurantDraft(
      name: _nameController.text,
      cuisine: _cuisine,
      address: _addressController.text,
      operatingHours: _hoursController.text,
      contact: _contactController.text,
      budget: _budget,
      description: _descriptionController.text,
      imageUrl: _imageUrl,
      sourcePlatform: _sourceController.text,
      isVerified: _isVerified,
      rating: double.tryParse(_ratingController.text.trim()),
      latitude: double.tryParse(_latitudeController.text.trim()),
      longitude: double.tryParse(_longitudeController.text.trim()),
    );
  }

  Future<void> _save() async {
    final result = await ref
        .read(restaurantDetailsControllerProvider(widget.restaurantId).notifier)
        .save(_draft());
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (result.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    final createdId = result.createdId;
    if (createdId != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Restaurant Created — ${_nameController.text.trim()} has been added.',
          ),
        ),
      );
      context.go('/admin/restaurants/$createdId');
      return;
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Changes Saved — Restaurant information updated.'),
      ),
    );
  }

  Future<void> _remove() async {
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Remove Restaurant?',
      message:
          'This will permanently remove "${_nameController.text.trim()}" '
          'from MakanSpot. This action cannot be undone.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if ((confirmed ?? false) && mounted) {
      final error = await ref
          .read(
            restaurantDetailsControllerProvider(widget.restaurantId).notifier,
          )
          .remove();
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Restaurant Removed — ${_nameController.text.trim()} has been removed.',
          ),
        ),
      );
      context.go('/admin/restaurants');
    }
  }

  Future<void> _uploadImage() async {
    setState(() => _uploading = true);
    final url = await ref
        .read(restaurantDetailsControllerProvider(widget.restaurantId).notifier)
        .uploadImage();
    if (!mounted) {
      return;
    }
    if (url == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Upload Failed')));
    } else {
      setState(() => _imageUrl = url);
    }
    setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      restaurantDetailsControllerProvider(widget.restaurantId),
    );
    final restaurant = state.restaurant;
    if (!_seeded && restaurant != null) {
      _seed(restaurant);
    }
    final isCreate = restaurant == null;
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('restaurant-details-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AdminBackButton(label: 'Back to Restaurants', onPressed: context.pop),
          const SizedBox(height: 16),
          if (state.status == RestaurantDetailsStatus.loading)
            const _RestaurantDetailsSkeleton()
          else if (state.status == RestaurantDetailsStatus.notFound)
            const Text(
              'Restaurant not found.',
              style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
            )
          else if (state.status == RestaurantDetailsStatus.error)
            Text(state.errorMessage!, textAlign: TextAlign.center)
          else ...[
            _DetailsHeader(
              isCreate: isCreate,
              name: _nameController.text,
              isVerified: _isVerified,
              imageUrl: _imageUrl,
            ),
            const SizedBox(height: 24),
            _FormCard(
              nameController: _nameController,
              addressController: _addressController,
              hoursController: _hoursController,
              contactController: _contactController,
              ratingController: _ratingController,
              descriptionController: _descriptionController,
              sourceController: _sourceController,
              latitudeController: _latitudeController,
              longitudeController: _longitudeController,
              cuisine: _cuisine,
              budget: _budget,
              isVerified: _isVerified,
              imageUrl: _imageUrl,
              uploading: _uploading,
              onCuisineChanged: (value) => setState(() => _cuisine = value),
              onBudgetChanged: (value) => setState(() => _budget = value),
              onVerifiedChanged: () =>
                  setState(() => _isVerified = !_isVerified),
              onUpload: _uploadImage,
            ),
            const SizedBox(height: 24),
            AdminPrimaryButton(
              label: isCreate ? 'Create Restaurant' : 'Save Changes',
              loadingLabel: 'Saving...',
              isLoading: state.isSaving,
              icon: LucideIcons.save,
              buttonKey: const Key('admin-restaurant-save'),
              onPressed: _nameController.text.trim().isEmpty ? null : _save,
            ),
            if (!isCreate) ...[
              const SizedBox(height: 12),
              AdminOutlineButton(
                label: 'Remove Restaurant',
                icon: LucideIcons.trash2,
                borderColor: AppColors.destructive,
                foregroundColor: AppColors.destructive,
                buttonKey: const Key('admin-restaurant-remove'),
                onPressed: _remove,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DetailsHeader extends StatelessWidget {
  const _DetailsHeader({
    required this.isCreate,
    required this.name,
    required this.isVerified,
    required this.imageUrl,
  });

  final bool isCreate;
  final String name;
  final bool isVerified;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: Container(
            width: 48,
            height: 48,
            color: AppColors.secondary,
            child: imageUrl.isEmpty
                ? const Icon(
                    LucideIcons.utensilsCrossed,
                    size: 24,
                    color: AppColors.mutedForeground,
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      LucideIcons.utensilsCrossed,
                      size: 24,
                      color: AppColors.mutedForeground,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCreate
                    ? 'Add Restaurant'
                    : (name.isEmpty ? 'Restaurant' : name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (!isCreate) ...[
                const SizedBox(height: 4),
                AdminStatusBadge(label: isVerified ? 'Verified' : 'Pending'),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.nameController,
    required this.addressController,
    required this.hoursController,
    required this.contactController,
    required this.ratingController,
    required this.descriptionController,
    required this.sourceController,
    required this.latitudeController,
    required this.longitudeController,
    required this.cuisine,
    required this.budget,
    required this.isVerified,
    required this.imageUrl,
    required this.uploading,
    required this.onCuisineChanged,
    required this.onBudgetChanged,
    required this.onVerifiedChanged,
    required this.onUpload,
  });

  final TextEditingController nameController;
  final TextEditingController addressController;
  final TextEditingController hoursController;
  final TextEditingController contactController;
  final TextEditingController ratingController;
  final TextEditingController descriptionController;
  final TextEditingController sourceController;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final String cuisine;
  final String budget;
  final bool isVerified;
  final String imageUrl;
  final bool uploading;
  final ValueChanged<String> onCuisineChanged;
  final ValueChanged<String> onBudgetChanged;
  final VoidCallback onVerifiedChanged;
  final VoidCallback onUpload;

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
          _CoverRow(
            imageUrl: imageUrl,
            uploading: uploading,
            onUpload: onUpload,
          ),
          const SizedBox(height: 20),
          _field(
            label: 'Name *',
            child: AdminInputField(
              controller: nameController,
              hint: 'Restaurant name',
              fieldKey: const Key('admin-restaurant-name'),
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Cuisine',
            child: AdminSelectField<String>(
              value: cuisine,
              options: [for (final c in _cuisines) (c, c)],
              onChanged: onCuisineChanged,
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Address',
            child: AdminInputField(
              controller: addressController,
              hint: 'Full address',
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Operating Hours',
            child: AdminInputField(
              controller: hoursController,
              hint: 'e.g. 8am - 11pm',
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Contact',
            child: AdminInputField(
              controller: contactController,
              hint: 'Phone number',
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Rating',
            child: AdminInputField(
              controller: ratingController,
              hint: '0.0',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Budget',
            child: AdminSelectField<String>(
              value: budget,
              options: [for (final b in _budgets) (b, b)],
              onChanged: onBudgetChanged,
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Verified',
            child: AdminOutlineButton(
              label: isVerified ? 'Verified' : 'Unverified',
              borderColor: isVerified ? AppColors.success : AppColors.secondary,
              foregroundColor: isVerified
                  ? AppColors.success
                  : AppColors.mutedForeground,
              backgroundColor: isVerified
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.surface,
              buttonKey: const Key('admin-restaurant-verified'),
              onPressed: onVerifiedChanged,
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Latitude',
            child: AdminInputField(
              controller: latitudeController,
              hint: '3.1390',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Longitude',
            child: AdminInputField(
              controller: longitudeController,
              hint: '101.6869',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Description',
            child: TextField(
              key: const Key('admin-restaurant-description'),
              controller: descriptionController,
              minLines: 4,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Restaurant description',
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
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Source Platform',
            child: AdminInputField(
              controller: sourceController,
              hint: 'e.g. Google Maps, Manual',
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [AdminFieldLabel(label), const SizedBox(height: 8), child],
    );
  }
}

class _CoverRow extends StatelessWidget {
  const _CoverRow({
    required this.imageUrl,
    required this.uploading,
    required this.onUpload,
  });

  final String imageUrl;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.control),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  border: Border.all(color: AppColors.secondary),
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: imageUrl.isEmpty
                    ? const Icon(
                        LucideIcons.utensilsCrossed,
                        size: 32,
                        color: AppColors.mutedForeground,
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              LucideIcons.utensilsCrossed,
                              size: 32,
                              color: AppColors.mutedForeground,
                            ),
                      ),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: InkWell(
                key: const Key('admin-restaurant-upload'),
                onTap: uploading ? null : onUpload,
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: uploading
                        ? const SizedBox.square(
                            dimension: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.surface,
                            ),
                          )
                        : const Icon(
                            LucideIcons.camera,
                            size: 14,
                            color: AppColors.surface,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Text(
            'Restaurant cover image',
            style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
          ),
        ),
      ],
    );
  }
}

class _RestaurantDetailsSkeleton extends StatelessWidget {
  const _RestaurantDetailsSkeleton();

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
            children: [
              AdminSkeletonBox(height: 44, width: double.infinity),
              SizedBox(height: 16),
              AdminSkeletonBox(height: 44, width: double.infinity),
              SizedBox(height: 16),
              AdminSkeletonBox(height: 44, width: double.infinity),
              SizedBox(height: 16),
              AdminSkeletonBox(height: 44, width: double.infinity),
              SizedBox(height: 16),
              AdminSkeletonBox(height: 44, width: double.infinity),
              SizedBox(height: 16),
              AdminSkeletonBox(height: 44, width: double.infinity),
            ],
          ),
        ),
      ],
    );
  }
}
