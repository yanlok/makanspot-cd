import 'package:flutter/material.dart';

import 'package:makanspot/core/theme/app_theme.dart';

/// Two-option segmented control matching the prototype's report tabs.
class AdminSegmentedTabs<T> extends StatelessWidget {
  const AdminSegmentedTabs({
    required this.tabs,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<(String, T)> tabs;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        children: [
          for (final tab in tabs) ...[
            Expanded(
              child: _TabItem(
                label: tab.$1,
                selected: tab.$2 == value,
                onTap: () => onChanged(tab.$2),
              ),
            ),
            if (tab != tabs.last) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        key: Key('admin-tab-$label'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x143B2921),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected
                  ? AppColors.foreground
                  : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
