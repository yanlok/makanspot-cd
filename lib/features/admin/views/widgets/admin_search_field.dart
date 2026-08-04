import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

class AdminSearchField extends StatefulWidget {
  const AdminSearchField({
    required this.hint,
    required this.value,
    required this.onChanged,
    this.fieldKey,
    super.key,
  });

  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  final Key? fieldKey;

  @override
  State<AdminSearchField> createState() => _AdminSearchFieldState();
}

class _AdminSearchFieldState extends State<AdminSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant AdminSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        key: widget.fieldKey,
        onChanged: widget.onChanged,
        controller: _controller,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: const Icon(
            LucideIcons.search,
            size: 20,
            color: AppColors.mutedForeground,
          ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: _border(AppColors.secondary),
          enabledBorder: _border(AppColors.secondary),
          focusedBorder: _border(AppColors.primary, width: 2),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
