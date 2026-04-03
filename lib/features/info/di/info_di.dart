import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/services/logger_service.dart';
import '../data/datasources/info_supabase_data_source.dart';
import '../data/datasources/info_supabase_data_source_impl.dart';
import '../data/repositories/info_repository_impl.dart';
import '../domain/repositories/info_repository.dart';
import '../presentation/cubit/info_cubit.dart';

Future<void> initInfoDependencies() async {
  sl.registerLazySingleton<InfoSupabaseDataSource>(
    () => InfoSupabaseDataSourceImpl(
      sl<SupabaseClient>(),
      sl<LoggerService>(),
    ),
  );

  sl.registerLazySingleton<InfoRepository>(
    () => InfoRepositoryImpl(
      sl<InfoSupabaseDataSource>(),
      sl<LoggerService>(),
    ),
  );

  sl.registerFactory(
    () => InfoCubit(sl<InfoRepository>()),
  );
}
