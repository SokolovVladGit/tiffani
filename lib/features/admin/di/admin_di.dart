import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/services/logger_service.dart';
import '../data/repositories/admin_access_repository_impl.dart';
import '../data/repositories/admin_discounts_repository_impl.dart';
import '../domain/repositories/admin_access_repository.dart';
import '../domain/repositories/admin_discounts_repository.dart';
import '../presentation/cubit/admin_discounts_cubit.dart';

Future<void> initAdminDependencies() async {
  sl.registerLazySingleton<AdminAccessRepository>(
    () => AdminAccessRepositoryImpl(sl<SupabaseClient>(), sl<LoggerService>()),
  );

  sl.registerLazySingleton<AdminDiscountsRepository>(
    () =>
        AdminDiscountsRepositoryImpl(sl<SupabaseClient>(), sl<LoggerService>()),
  );

  // Factory: a fresh cubit per panel mount avoids cross-session state leakage
  // between admin/customer transitions.
  sl.registerFactory(() => AdminDiscountsCubit(sl<AdminDiscountsRepository>()));
}
