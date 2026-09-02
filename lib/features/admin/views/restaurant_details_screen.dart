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

const _categories = <String>[
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

const _priceRanges = <String>['\$', '\$\$', '\$\$\$', '\$\$\$\$'];

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
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _instagramController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  final Set<String> _selectedCategories = {};
  String _priceRange = _priceRanges.first;
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
    _phoneController.dispose();
    _websiteController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _instagramController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _seed(AdminRestaurant restaurant) {
    _nameController.text = restaurant.name;
    _selectedCategories
      ..clear()
      ..addAll(restaurant.categories.where(_categories.contains));
    _addressController.text = restaurant.address ?? '';
    _cityController.text = restaurant.city ?? '';
    _stateController.text = restaurant.state ?? '';
    _phoneController.text = restaurant.phone ?? '';
    _websiteController.text = restaurant.website ?? '';
    _instagramController.text = restaurant.instagramUsername ?? '';
    _priceRange = _priceRanges.contains(restaurant.priceRange)
        ? restaurant.priceRange!
        : _priceRanges.first;
    _descriptionController.text = restaurant.description ?? '';
    _imageUrl = restaurant.imageUrl;
    _latitudeController.text = restaurant.latitude?.toString() ?? '';
    _longitudeController.text = restaurant.longitude?.toString() ?? '';
    _seeded = true;
  }

  AdminRestaurantDraft _draft() {
    return AdminRestaurantDraft(
      name: _nameController.text,
      categories: _selectedCategories.toList(),
      address: _addressController.text,
      city: _cityController.text,
      state: _stateController.text,
      phone: _phoneController.text,
      website: _websiteController.text,
      instagramUsername: _instagramController.text,
      priceRange: _priceRange,
      description: _descriptionController.text,
      imageUrl: _imageUrl,
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
    if (widget.restaurantId != 'new') {
      context.go('/admin/restaurants/${widget.restaurantId}');
    }
  }

  Future<void> _remove() async {
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Remove Restaurant?',
      message:
          'This will hide "${_nameController.text.trim()}" from the public '
          'app and move it to Deleted. An administrator can restore it later.',
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
            'Restaurant Removed — ${_nameController.text.trim()} is now hidden from the public app.',
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
          AdminBackButton(
            label: widget.restaurantId == 'new'
                ? 'Back to Restaurants'
                : 'Back to Restaurant Information',
            onPressed: () => context.go(
              widget.restaurantId == 'new'
                  ? '/admin/restaurants'
                  : '/admin/restaurants/${widget.restaurantId}',
            ),
          ),
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
              imageUrl: _imageUrl,
            ),
            const SizedBox(height: 24),
            if (!isCreate) ...[
              _RestaurantInformationCard(restaurant: restaurant),
              const SizedBox(height: 24),
            ],
            _FormCard(
              nameController: _nameController,
              addressController: _addressController,
              cityController: _cityController,
              stateController: _stateController,
              phoneController: _phoneController,
              websiteController: _websiteController,
              instagramController: _instagramController,
              descriptionController: _descriptionController,
              latitudeController: _latitudeController,
              longitudeController: _longitudeController,
              selectedCategories: _selectedCategories,
              priceRange: _priceRange,
              imageUrl: _imageUrl,
              uploading: _uploading,
              onCategoryToggled: (category) => setState(() {
                if (_selectedCategories.contains(category)) {
                  _selectedCategories.remove(category);
                } else {
                  _selectedCategories.add(category);
                }
              }),
              onPriceRangeChanged: (value) =>
                  setState(() => _priceRange = value),
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

class _RestaurantInformationCard extends StatelessWidget {
  const _RestaurantInformationCard({required this.restaurant});

  final AdminRestaurant restaurant;

  static String _formatBusinessHours(Map<String, dynamic>? hours) {
    if (hours == null || hours.isEmpty) return '';
    final entries = hours.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    return entries;
  }

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
            'Restaurant Information',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _infoRow(context, 'Restaurant Name', restaurant.name),
          _infoRow(
            context,
            'Location',
            (restaurant.address ?? '').isEmpty
                ? 'Not provided'
                : restaurant.address!,
          ),
          _infoRow(
            context,
            'Business Hours',
            _formatBusinessHours(restaurant.businessHours).isEmpty
                ? 'Not provided'
                : _formatBusinessHours(restaurant.businessHours),
          ),
          _infoRow(
            context,
            'Instagram',
            (restaurant.instagramUsername ?? '').isEmpty
                ? 'Not provided'
                : restaurant.instagramUsername!,
          ),
          _infoRow(
            context,
            'Phone',
            (restaurant.phone ?? '').isEmpty
                ? 'Not provided'
                : restaurant.phone!,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    String label,
    String value, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsHeader extends StatelessWidget {
  const _DetailsHeader({
    required this.isCreate,
    required this.name,
    required this.imageUrl,
  });

  final bool isCreate;
  final String name;
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
    required this.cityController,
    required this.stateController,
    required this.phoneController,
    required this.websiteController,
    required this.instagramController,
    required this.descriptionController,
    required this.latitudeController,
    required this.longitudeController,
    required this.selectedCategories,
    required this.priceRange,
    required this.imageUrl,
    required this.uploading,
    required this.onCategoryToggled,
    required this.onPriceRangeChanged,
    required this.onUpload,
  });

  final TextEditingController nameController;
  final TextEditingController addressController;
  final TextEditingController cityController;
  final TextEditingController stateController;
  final TextEditingController phoneController;
  final TextEditingController websiteController;
  final TextEditingController instagramController;
  final TextEditingController descriptionController;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final Set<String> selectedCategories;
  final String priceRange;
  final String imageUrl;
  final bool uploading;
  final ValueChanged<String> onCategoryToggled;
  final ValueChanged<String> onPriceRangeChanged;
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
            label: 'Categories',
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final category in _categories)
                  FilterChip(
                    key: Key('admin-category-${category.toLowerCase()}'),
                    label: Text(category),
                    selected: selectedCategories.contains(category),
                    onSelected: (_) => onCategoryToggled(category),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primary,
                    side: BorderSide(
                      color: selectedCategories.contains(category)
                          ? AppColors.primary
                          : AppColors.secondary,
                    ),
                    labelStyle: TextStyle(
                      color: selectedCategories.contains(category)
                          ? AppColors.primary
                          : AppColors.foreground,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
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
            label: 'City',
            child: AdminInputField(
              controller: cityController,
              hint: 'e.g. Kuala Lumpur',
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'State',
            child: AdminInputField(
              controller: stateController,
              hint: 'e.g. Selangor',
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Phone',
            child: AdminInputField(
              controller: phoneController,
              hint: 'Phone number',
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Website',
            child: AdminInputField(
              controller: websiteController,
              hint: 'e.g. https://example.com',
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Instagram Username',
            child: AdminInputField(
              controller: instagramController,
              hint: 'e.g. myrestaurant',
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Price Range',
            child: AdminSelectField<String>(
              value: priceRange,
              options: [for (final p in _priceRanges) (p, p)],
              onChanged: onPriceRangeChanged,
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
