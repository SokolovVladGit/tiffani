import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/services/logger_service.dart';
import '../data/datasources/home_supabase_data_source.dart';
import '../data/datasources/home_supabase_data_source_impl.dart';
import '../data/repositories/home_repository_impl.dart';
import '../domain/repositories/home_repository.dart';
import '../../catalog/domain/usecases/get_all_brands_use_case.dart';
import '../domain/usecases/get_home_hit_items_use_case.dart';
import '../domain/usecases/get_home_new_items_use_case.dart';
import '../domain/usecases/get_home_sale_items_use_case.dart';
import '../presentation/bloc/home_bloc.dart';
import '../presentation/cubit/top_brands_cubit.dart';

Future<void> initHomeDependencies() async {
  sl.registerLazySingleton<HomeSupabaseDataSource>(
    () => HomeSupabaseDataSourceImpl(sl<SupabaseClient>(), sl<LoggerService>()),
  );

  sl.registerLazySingleton<HomeRepository>(
    () => HomeRepositoryImpl(sl<HomeSupabaseDataSource>()),
  );

  sl.registerLazySingleton(() => GetHomeNewItemsUseCase(sl()));
  sl.registerLazySingleton(() => GetHomeSaleItemsUseCase(sl()));
  sl.registerLazySingleton(() => GetHomeHitItemsUseCase(sl()));

  sl.registerFactory(
    () => HomeBloc(
      sl<GetHomeNewItemsUseCase>(),
      sl<GetHomeSaleItemsUseCase>(),
      sl<GetHomeHitItemsUseCase>(),
    ),
  );

  sl.registerFactory(() => TopBrandsCubit(sl<GetAllBrandsUseCase>()));
}
