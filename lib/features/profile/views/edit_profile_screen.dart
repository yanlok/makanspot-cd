import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/profile_controller.dart';
import '../models/profile_models.dart';
import 'widgets/profile_avatar.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _picker = ImagePicker();
  bool _seeded = false;

  /// Bytes of a newly picked photo, shown as a preview before saving.
  Uint8List? _pickedBytes;

  /// The upload payload for the photo the user selected, when one is pending.
  ProfilePictureUpload? _photoUpload;

  /// True when the user chose to revert their avatar to the placeholder.
  bool _removePhoto = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editProfileControllerProvider);
    final controller = ref.read(editProfileControllerProvider.notifier);
    if (!_seeded && state.data != null) {
      _usernameController.text = state.data!.profile.username;
      _bioController.text = state.data!.profile.bio;
      _seeded = true;
    }
    ref.listen(editProfileControllerProvider, (previous, next) {
      if (next.status == ProfileStatus.saved) {
        context.go('/profile');
      }
    });
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _Header(onBack: context.pop),
          Expanded(child: _body(context, state, controller)),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    ProfileState state,
    EditProfileController controller,
  ) {
    if (state.status == ProfileStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == ProfileStatus.error && state.data == null) {
      return Center(child: Text(state.errorMessage!));
    }
    final profile = state.data!.profile;
    return ListView(
      key: const Key('edit-profile-scroll'),
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: _photoPicker(profile.profileAsset)),
        const SizedBox(height: 22),
        _LabelledField(
          label: 'Display Name',
          child: TextField(
            key: const Key('profile-display-name'),
            controller: _usernameController,
            decoration: const InputDecoration(hintText: 'Your display name'),
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 18),
        _LabelledField(
          label: 'Email',
          child: TextFormField(initialValue: profile.email, enabled: false),
        ),
        const SizedBox(height: 18),
        _LabelledField(
          label: 'Bio',
          child: TextField(
            key: const Key('profile-bio'),
            controller: _bioController,
            minLines: 4,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Tell the community about your food journey...',
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: context.pop,
                style: _buttonStyle(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('save-profile'),
                onPressed: state.status == ProfileStatus.saving
                    ? null
                    : () async {
                        final error = await controller.save(
                          username: _usernameController.text,
                          bio: _bioController.text,
                          currentProfileAsset: _removePhoto
                              ? defaultProfileAsset
                              : profile.profileAsset,
                          photoUpload: _photoUpload,
                        );
                        if (error != null && context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(error)));
                        }
                      },
                style: _buttonStyle(),
                child: Text(
                  state.status == ProfileStatus.saving
                      ? 'Saving...'
                      : 'Save Changes',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The avatar column: shows the picked photo, the current avatar, or the
  /// placeholder, plus a camera action that opens the photo picker.
  Widget _photoPicker(String currentProfileAsset) {
    final Widget avatar;
    if (_pickedBytes != null) {
      avatar = ClipOval(
        child: Container(
          width: 96,
          height: 96,
          padding: const EdgeInsets.all(4),
          color: AppColors.surface,
          child: ClipOval(
            child: Image.memory(_pickedBytes!, fit: BoxFit.cover),
          ),
        ),
      );
    } else {
      avatar = ProfileAvatar(
        profileAsset: _removePhoto ? defaultProfileAsset : currentProfileAsset,
      );
    }
    return Column(
      children: [
        Stack(
          children: [
            avatar,
            Positioned(
              bottom: 0,
              right: 0,
              child: IconButton.filled(
                key: const Key('edit-profile-photo'),
                tooltip: 'Change photo',
                onPressed: _showPhotoOptions,
                icon: const Icon(LucideIcons.camera, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Tap to change photo',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }

  Future<void> _showPhotoOptions() async {
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('photo-camera'),
              leading: const Icon(LucideIcons.camera),
              title: const Text('Take Photo'),
              onTap: () => context.pop(_PhotoAction.camera),
            ),
            ListTile(
              key: const Key('photo-gallery'),
              leading: const Icon(LucideIcons.images),
              title: const Text('Choose from Gallery'),
              onTap: () => context.pop(_PhotoAction.gallery),
            ),
            if (_pickedBytes != null || !_removePhoto)
              ListTile(
                key: const Key('photo-remove'),
                leading: const Icon(
                  LucideIcons.trash2,
                  color: AppColors.destructive,
                ),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: AppColors.destructive),
                ),
                onTap: () => context.pop(_PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (action == _PhotoAction.remove) {
      setState(() {
        _removePhoto = true;
        _pickedBytes = null;
        _photoUpload = null;
      });
      return;
    }
    if (action == null) {
      return;
    }
    await _pickPhoto(
      action == _PhotoAction.camera ? ImageSource.camera : ImageSource.gallery,
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (file == null) {
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _removePhoto = false;
        _photoUpload = ProfilePictureUpload(
          bytes: bytes,
          mimeType: _mimeFromName(file.name),
          fileName: file.name,
        );
        _pickedBytes = bytes;
      });
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not pick a photo.')));
      }
    }
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  ButtonStyle _buttonStyle() {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.secondary)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(LucideIcons.chevronLeft),
          ),
          Text('Edit Profile', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _LabelledField extends StatelessWidget {
  const _LabelledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

enum _PhotoAction { camera, gallery, remove }