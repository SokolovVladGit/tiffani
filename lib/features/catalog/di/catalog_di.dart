import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/services/logger_service.dart';
import '../data/datasources/catalog_supabase_data_source.dart';
import '../data/datasources/catalog_supabase_data_source_impl.dart';
import '../data/repositories/catalog_repository_impl.dart';
import '../domain/repositories/catalog_repository.dart';
import '../domain/usecases/get_all_brands_use_case.dart';
import '../domain/usecases/get_catalog_item_by_variant_id_use_case.dart';
import '../domain/usecases/get_catalog_page_use_case.dart';
import '../domain/usecases/search_catalog_use_case.dart';
import '../presentation/bloc/catalog_bloc.dart';
import '../presentation/cubit/brands_cubit.dart';
import '../presentation/cubit/catalog_filter_cubit.dart';
import '../presentation/cubit/filter_cubit.dart';

Future<void> initCatalogDependencies() async {
  sl.registerLazySingleton<CatalogSupabaseDataSource>(
    () => CatalogSupabaseDataSourceImpl(
      sl<SupabaseClient>(),
      sl<LoggerService>(),
    ),
  );

  sl.registerLazySingleton<CatalogRepository>(
    () => CatalogRepositoryImpl(
      sl<CatalogSupabaseDataSource>(),
      sl<LoggerService>(),
    ),
  );

  sl.registerLazySingleton(() => GetCatalogPageUseCase(sl()));
  sl.registerLazySingleton(() => SearchCatalogUseCase(sl()));
  sl.registerLazySingleton(() => GetCatalogItemByVariantIdUseCase(sl()));
  sl.registerLazySingleton(() => GetAllBrandsUseCase(sl()));

  sl.registerFactory(
    () => CatalogBloc(sl<GetCatalogPageUseCase>(), sl<SearchCatalogUseCase>()),
  );
  sl.registerLazySingleton(
    () => CatalogFilterCubit(sl<CatalogRepository>()),
  );

  sl.registerFactory(() => FilterCubit());
  sl.registerFactory(() => BrandsCubit(sl<GetAllBrandsUseCase>()));
}
