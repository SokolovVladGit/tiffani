import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/services/logger_service.dart';
import '../data/datasources/cart_local_data_source.dart';
import '../data/datasources/cart_local_data_source_impl.dart';
import '../data/datasources/cart_remote_data_source.dart';
import '../data/datasources/cart_remote_data_source_impl.dart';
import '../data/repositories/cart_repository_impl.dart';
import '../domain/repositories/cart_repository.dart';
import '../domain/usecases/add_to_cart_use_case.dart';
import '../domain/usecases/clear_cart_use_case.dart';
import '../domain/usecases/get_cart_item_count_use_case.dart';
import '../domain/usecases/get_cart_items_use_case.dart';
import '../domain/usecases/get_cart_summary_use_case.dart';
import '../domain/usecases/remove_from_cart_use_case.dart';
import '../domain/usecases/submit_order_request_use_case.dart';
import '../domain/usecases/update_cart_item_quantity_use_case.dart';
import '../presentation/cubit/cart_cubit.dart';

Future<void> initCartDependencies() async {
  sl.registerLazySingleton<CartLocalDataSource>(
    () => CartLocalDataSourceImpl(sl<SharedPreferences>()),
  );

  sl.registerLazySingleton<CartRemoteDataSource>(
    () => CartRemoteDataSourceImpl(sl<SupabaseClient>(), sl<LoggerService>()),
  );

  sl.registerLazySingleton<CartRepository>(
    () => CartRepositoryImpl(
      sl<CartLocalDataSource>(),
      sl<CartRemoteDataSource>(),
    ),
  );

  sl.registerLazySingleton(() => GetCartItemsUseCase(sl()));
  sl.registerLazySingleton(() => AddToCartUseCase(sl()));
  sl.registerLazySingleton(() => UpdateCartItemQuantityUseCase(sl()));
  sl.registerLazySingleton(() => RemoveFromCartUseCase(sl()));
  sl.registerLazySingleton(() => ClearCartUseCase(sl()));
  sl.registerLazySingleton(() => GetCartSummaryUseCase(sl()));
  sl.registerLazySingleton(() => GetCartItemCountUseCase(sl()));
  sl.registerLazySingleton(() => SubmitOrderRequestUseCase(sl()));

  sl.registerLazySingleton(
    () => CartCubit(
      sl<GetCartItemsUseCase>(),
      sl<AddToCartUseCase>(),
      sl<UpdateCartItemQuantityUseCase>(),
      sl<RemoveFromCartUseCase>(),
      sl<ClearCartUseCase>(),
      sl<GetCartSummaryUseCase>(),
      sl<SubmitOrderRequestUseCase>(),
    ),
  );
}
