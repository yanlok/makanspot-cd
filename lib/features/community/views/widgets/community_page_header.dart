import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

class CommunityPageHeader extends StatelessWidget {
  const CommunityPageHeader({
    required this.title,
    required this.onBack,
    this.bottom,
    super.key,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.secondary)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  key: Key('back-${title.toLowerCase().replaceAll(' ', '-')}'),
                  tooltip: 'Back',
                  onPressed: onBack,
                  icon: const Icon(LucideIcons.chevronLeft, size: 24),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            if (bottom != null) ...[const SizedBox(height: 4), bottom!],
          ],
        ),
      ),
    );
  }
}
