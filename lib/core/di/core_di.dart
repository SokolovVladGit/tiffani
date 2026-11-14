import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/logger_service.dart';
import 'injector.dart';

const _supabaseUrl = 'https://mnjxcoyvomgbdtwdhejq.supabase.co';
const _supabaseAnonKey = 'sb_publishable_oCSouJIquzZn4V478kpemg_Bzs2NXUR';

Future<void> initCoreDependencies() async {
  sl.registerLazySingleton<LoggerService>(() => LoggerService());

  final prefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => prefs);

  if (_supabaseUrl == 'YOUR_SUPABASE_URL' ||
      _supabaseAnonKey == 'YOUR_SUPABASE_ANON_KEY') {
    throw Exception(
      'Supabase credentials are not configured. '
      'Replace placeholder values in core_di.dart.',
    );
  }

  if (kDebugMode) {
    final host = Uri.parse(_supabaseUrl).host;
    debugPrint('TIFFANI startup host=$host environment=debug');
  }

  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  final client = Supabase.instance.client;
  if (kDebugMode) {
    final effectiveHost = Uri.parse(client.rest.url).host;
    debugPrint('TIFFANI effective host=$effectiveHost environment=debug');
  }
  sl.registerLazySingleton<SupabaseClient>(() => client);
}
