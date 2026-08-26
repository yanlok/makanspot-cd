import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:makanspot/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final mapAccessToken = dotenv.env['MAP_ACCESS_TOKEN'];
  if (mapAccessToken != null && mapAccessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapAccessToken);
  }
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      publishableKey: SupabaseConfig.supabaseAnonKey,
    );
  }
  runApp(const ProviderScope(child: MakanSpotApp()));
}
