import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:makanspot/core/theme/app_theme.dart';

class MakanSearchBar extends StatefulWidget {
  const MakanSearchBar({required this.onSubmitted, super.key});

  final ValueChanged<String> onSubmitted;

  @override
  State<MakanSearchBar> createState() => _MakanSearchBarState();
}

class _MakanSearchBarState extends State<MakanSearchBar> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        key: const Key('home-search-field'),
        controller: _controller,
        textInputAction: TextInputAction.search,
        onSubmitted: widget.onSubmitted,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search restaurants, food, or areas',
          prefixIcon: const Icon(
            LucideIcons.search,
            size: 20,
            color: AppColors.mutedForeground,
          ),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: _controller.clear,
                  icon: const Icon(
                    LucideIcons.x,
                    size: 16,
                    color: AppColors.mutedForeground,
                  ),
                ),
        ),
      ),
    );
  }
}
