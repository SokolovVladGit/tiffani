import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/services/logger_service.dart';
import '../data/datasources/consultation_remote_data_source.dart';
import '../data/datasources/consultation_remote_data_source_impl.dart';
import '../data/repositories/consultation_repository_impl.dart';
import '../domain/repositories/consultation_repository.dart';
import '../domain/usecases/submit_consultation_use_case.dart';
import '../presentation/cubit/consultation_cubit.dart';

Future<void> initConsultationDependencies() async {
  sl.registerLazySingleton<ConsultationRemoteDataSource>(
    () => ConsultationRemoteDataSourceImpl(
      sl<SupabaseClient>(),
      sl<LoggerService>(),
    ),
  );

  sl.registerLazySingleton<ConsultationRepository>(
    () => ConsultationRepositoryImpl(sl<ConsultationRemoteDataSource>()),
  );

  sl.registerLazySingleton(
    () => SubmitConsultationUseCase(sl<ConsultationRepository>()),
  );

  sl.registerFactory(
    () => ConsultationCubit(
      sl<SubmitConsultationUseCase>(),
      sl<LoggerService>(),
    ),
  );
}
