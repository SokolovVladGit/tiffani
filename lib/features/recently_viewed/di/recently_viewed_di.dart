import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/injector.dart';
import '../data/datasources/recently_viewed_local_data_source.dart';
import '../data/datasources/recently_viewed_local_data_source_impl.dart';
import '../data/repositories/recently_viewed_repository_impl.dart';
import '../domain/repositories/recently_viewed_repository.dart';
import '../presentation/cubit/recently_viewed_cubit.dart';

Future<void> initRecentlyViewedDependencies() async {
  sl.registerLazySingleton<RecentlyViewedLocalDataSource>(
    () => RecentlyViewedLocalDataSourceImpl(sl<SharedPreferences>()),
  );

  sl.registerLazySingleton<RecentlyViewedRepository>(
    () => RecentlyViewedRepositoryImpl(sl<RecentlyViewedLocalDataSource>()),
  );

  sl.registerLazySingleton(
    () => RecentlyViewedCubit(sl<RecentlyViewedRepository>())..load(),
  );
}
