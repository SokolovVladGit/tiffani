import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/services/logger_service.dart';
import '../data/datasources/stores_delivery_supabase_data_source.dart';
import '../data/datasources/stores_delivery_supabase_data_source_impl.dart';
import '../data/repositories/stores_delivery_repository_impl.dart';
import '../domain/repositories/stores_delivery_repository.dart';
import '../domain/usecases/get_delivery_rules_use_case.dart';
import '../domain/usecases/get_stores_use_case.dart';
import '../presentation/bloc/stores_delivery_bloc.dart';

Future<void> initStoresDeliveryDependencies() async {
  sl.registerLazySingleton<StoresDeliverySupabaseDataSource>(
    () => StoresDeliverySupabaseDataSourceImpl(
      sl<SupabaseClient>(),
      sl<LoggerService>(),
    ),
  );

  sl.registerLazySingleton<StoresDeliveryRepository>(
    () => StoresDeliveryRepositoryImpl(
      sl<StoresDeliverySupabaseDataSource>(),
    ),
  );

  sl.registerLazySingleton(() => GetStoresUseCase(sl()));
  sl.registerLazySingleton(() => GetDeliveryRulesUseCase(sl()));

  sl.registerFactory(
    () => StoresDeliveryBloc(
      sl<GetStoresUseCase>(),
      sl<GetDeliveryRulesUseCase>(),
    ),
  );
}
