import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/logger_service.dart';
import 'injector.dart';

const _supabaseUrl = 'https://ebannnxkjtvmhchwjwsz.supabase.co';
const _supabaseAnonKey = 'sb_publishable_Jd8UZIeltw3tBXR4dEWrPQ_1z9L5C4H';

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

  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
}
