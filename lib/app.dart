import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class MakanSpotApp extends StatefulWidget {
  const MakanSpotApp({this.router, super.key});

  final GoRouter? router;

  @override
  State<MakanSpotApp> createState() => _MakanSpotAppState();
}

class _MakanSpotAppState extends State<MakanSpotApp> {
  late final GoRouter _router = widget.router ?? createAppRouter();

  @override
  void dispose() {
    if (widget.router == null) {
      _router.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MakanSpot',
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
