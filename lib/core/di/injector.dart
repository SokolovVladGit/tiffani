import 'package:get_it/get_it.dart';

import '../../features/cart/di/cart_di.dart';
import '../../features/catalog/di/catalog_di.dart';
import '../../features/favorites/di/favorites_di.dart';
import '../../features/home/di/home_di.dart';
import '../../features/stores_delivery/di/stores_delivery_di.dart';
import 'core_di.dart';

final sl = GetIt.instance;

Future<void> setupDependencies() async {
  await initCoreDependencies();
  await initCatalogDependencies();
  await initCartDependencies();
  await initHomeDependencies();
  await initStoresDeliveryDependencies();
  await initFavoritesDependencies();
}
