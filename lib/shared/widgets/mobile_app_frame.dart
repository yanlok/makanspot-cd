import 'package:flutter/material.dart';

import 'package:makanspot/core/theme/app_theme.dart';

class MobileAppFrame extends StatelessWidget {
  const MobileAppFrame({
    required this.child,
    required this.bottomNavigationBar,
    super.key,
  });

  static const maxWidth = 448.0;

  final Widget child;
  final Widget bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Scaffold(
              body: child,
              bottomNavigationBar: bottomNavigationBar,
            ),
          ),
        ),
      ),
    );
  }
}
