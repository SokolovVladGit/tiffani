import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/services/logger_service.dart';
import '../data/datasources/articles_supabase_data_source.dart';
import '../data/datasources/articles_supabase_data_source_impl.dart';
import '../data/repositories/articles_repository_impl.dart';
import '../domain/repositories/articles_repository.dart';
import '../presentation/cubit/article_details_cubit.dart';
import '../presentation/cubit/home_articles_cubit.dart';

Future<void> initArticlesDependencies() async {
  sl.registerLazySingleton<ArticlesSupabaseDataSource>(
    () => ArticlesSupabaseDataSourceImpl(
      sl<SupabaseClient>(),
      sl<LoggerService>(),
    ),
  );

  sl.registerLazySingleton<ArticlesRepository>(
    () => ArticlesRepositoryImpl(
      sl<ArticlesSupabaseDataSource>(),
      sl<LoggerService>(),
    ),
  );

  sl.registerFactory(
    () => HomeArticlesCubit(sl<ArticlesRepository>()),
  );

  sl.registerFactory(
    () => ArticleDetailsCubit(sl<ArticlesRepository>()),
  );
}
