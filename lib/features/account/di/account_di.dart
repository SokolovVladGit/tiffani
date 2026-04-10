import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/services/logger_service.dart';
import '../data/repositories/account_repository_impl.dart';
import '../domain/repositories/account_repository.dart';
import '../presentation/cubit/auth_cubit.dart';

Future<void> initAccountDependencies() async {
  sl.registerLazySingleton<AccountRepository>(
    () => AccountRepositoryImpl(sl<SupabaseClient>(), sl<LoggerService>()),
  );

  sl.registerLazySingleton(() => AuthCubit(sl<AccountRepository>()));
}
