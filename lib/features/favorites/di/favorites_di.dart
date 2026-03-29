import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/injector.dart';
import '../data/datasources/favorites_local_data_source.dart';
import '../data/datasources/favorites_local_data_source_impl.dart';
import '../data/repositories/favorites_repository_impl.dart';
import '../domain/repositories/favorites_repository.dart';
import '../domain/usecases/get_favorites.dart';
import '../domain/usecases/is_favorite.dart';
import '../domain/usecases/toggle_favorite.dart';
import '../../catalog/domain/repositories/catalog_repository.dart';
import '../presentation/cubit/favorites_cubit.dart';
import '../presentation/cubit/favorites_items_cubit.dart';

Future<void> initFavoritesDependencies() async {
  sl.registerLazySingleton<FavoritesLocalDataSource>(
    () => FavoritesLocalDataSourceImpl(sl<SharedPreferences>()),
  );

  sl.registerLazySingleton<FavoritesRepository>(
    () => FavoritesRepositoryImpl(sl<FavoritesLocalDataSource>()),
  );

  sl.registerLazySingleton(() => GetFavorites(sl()));
  sl.registerLazySingleton(() => ToggleFavorite(sl()));
  sl.registerLazySingleton(() => IsFavorite(sl()));

  sl.registerLazySingleton(
    () => FavoritesCubit(sl<GetFavorites>(), sl<ToggleFavorite>()),
  );

  sl.registerFactory(
    () => FavoritesItemsCubit(sl<CatalogRepository>()),
  );
}
