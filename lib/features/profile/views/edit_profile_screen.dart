import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

import '../controllers/profile_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _seeded = false;

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
        Center(
          child: Column(
            children: [
              Stack(
                children: [
                  ClipOval(
                    child: Container(
                      width: 96,
                      height: 96,
                      padding: const EdgeInsets.all(4),
                      color: AppColors.surface,
                      child: ClipOval(
                        child: Image.asset(
                          profile.profileAsset,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: IconButton.filled(
                      key: const Key('edit-profile-photo'),
                      tooltip: 'Change photo',
                      onPressed: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Fixture photo selected'),
                            ),
                          ),
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
          ),
        ),
        const SizedBox(height: 22),
        _LabelledField(
          label: 'Display Name',
          child: TextField(
            key: const Key('profile-display-name'),
            controller: _usernameController,
            decoration: const InputDecoration(hintText: 'Your display name'),
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
