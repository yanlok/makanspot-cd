import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

class MakanBottomNavigation extends StatelessWidget {
  const MakanBottomNavigation({
    required this.currentIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _destinations = <_NavigationDestination>[
    _NavigationDestination('Home', LucideIcons.house),
    _NavigationDestination('Discover', LucideIcons.compass),
    _NavigationDestination('Community', LucideIcons.users),
    _NavigationDestination('Journey', LucideIcons.map),
    _NavigationDestination('Profile', LucideIcons.user),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.secondary)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F3B2921),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_destinations.length, (index) {
              final destination = _destinations[index];
              final isSelected = index == currentIndex;
              final color = isSelected
                  ? AppColors.primary
                  : AppColors.mutedForeground;
              return Expanded(
                child: Semantics(
                  selected: isSelected,
                  button: true,
                  label: destination.label,
                  child: InkWell(
                    key: Key('bottom-nav-${destination.label}'),
                    onTap: () => onDestinationSelected(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(destination.icon, size: 20, color: color),
                        const SizedBox(height: 2),
                        Text(
                          destination.label,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ).copyWith(color: color),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavigationDestination {
  const _NavigationDestination(this.label, this.icon);

  final String label;
  final IconData icon;
}
