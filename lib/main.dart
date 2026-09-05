import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:makanspot/core/config/supabase_config.dart';
import 'package:makanspot/features/auth/controllers/auth_controller.dart';
import 'package:makanspot/features/auth/models/auth_session.dart';
import 'package:makanspot/features/auth/models/supabase_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to vertical / portrait only.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load(fileName: '.env');
  final mapAccessToken = dotenv.env['MAP_ACCESS_TOKEN'];
  if (mapAccessToken != null && mapAccessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapAccessToken);
  }

  AuthSession? initialSession;
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      publishableKey: SupabaseConfig.supabaseAnonKey,
    );
    try {
      initialSession = await SupabaseAuthRepository().restoreSession();
    } catch (_) {
      // Ignored: app falls back to standard restore flow if error occurs.
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        if (initialSession != null)
          initialSessionProvider.overrideWithValue(initialSession),
      ],
      child: const MakanSpotApp(),
    ),
  );
}
