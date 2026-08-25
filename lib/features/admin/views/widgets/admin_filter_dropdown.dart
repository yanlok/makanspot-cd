import 'package:flutter/material.dart';

import 'package:makanspot/core/theme/app_theme.dart';

/// Compact status filter select used by the management screens.
class AdminFilterDropdown<T> extends StatelessWidget {
  const AdminFilterDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
    this.label,
    this.width = 132,
    super.key,
  });

  final T value;

  /// Ordered (label, value) options, mirroring the prototype's `<option>`s.
  final List<(String, T)> options;
  final ValueChanged<T> onChanged;
  final String? label;

  /// Fixed width; set to null to let the parent constrain it.
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.secondary),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          key: const Key('admin-filter-dropdown'),
          value: value,
          isExpanded: true,
          isDense: true,
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.control),
          hint: Text(label ?? ''),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.secondaryForeground,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: AppColors.mutedForeground,
          ),
          items: [
            for (final option in options)
              DropdownMenuItem<T>(
                value: option.$2,
                child: Text(option.$1, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (selected) {
            if (selected != null) {
              onChanged(selected);
            }
          },
        ),
      ),
    );
  }
}
