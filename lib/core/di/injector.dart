import 'package:get_it/get_it.dart';

import '../../features/account/di/account_di.dart';
import '../../features/articles/di/articles_di.dart';
import '../../features/cart/di/cart_di.dart';
import '../../features/catalog/di/catalog_di.dart';
import '../../features/consultation/di/consultation_di.dart';
import '../../features/favorites/di/favorites_di.dart';
import '../../features/home/di/home_di.dart';
import '../../features/recently_viewed/di/recently_viewed_di.dart';
import '../../features/info/di/info_di.dart';
import 'core_di.dart';

final sl = GetIt.instance;

Future<void> setupDependencies() async {
  await initCoreDependencies();
  await initAccountDependencies();
  await initCatalogDependencies();
  await initCartDependencies();
  await initHomeDependencies();
  await initArticlesDependencies();
  await initInfoDependencies();
  await initConsultationDependencies();
  await initFavoritesDependencies();
  await initRecentlyViewedDependencies();
}
