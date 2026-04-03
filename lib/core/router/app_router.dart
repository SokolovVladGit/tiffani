import 'package:go_router/go_router.dart';

import '../../features/app_shell/presentation/pages/app_shell_page.dart';
import '../../features/cart/presentation/pages/cart_page.dart';
import '../../features/cart/presentation/pages/request_success_page.dart';
import '../../features/catalog/domain/entities/catalog_item_entity.dart';
import '../../features/catalog/presentation/pages/brands_page.dart';
import '../../features/catalog/presentation/pages/catalog_details_page.dart';
import '../../features/catalog/presentation/pages/catalog_page.dart';
import '../../features/favorites/presentation/pages/favorites_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/info/presentation/pages/info_page.dart';
import 'catalog_filter_payload.dart';
import 'product_details_payload.dart';
import 'route_names.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: RouteNames.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShellPage(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.home,
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.catalog,
                builder: (context, state) => const CatalogPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.info,
                builder: (context, state) => const InfoPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.cart,
                builder: (context, state) => const CartPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.catalogDetails,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is ProductDetailsPayload) {
            return CatalogDetailsPage(
              item: extra.item,
              heroTag: extra.heroTag,
            );
          }
          return CatalogDetailsPage(item: extra! as CatalogItemEntity);
        },
      ),
      GoRoute(
        path: RouteNames.favorites,
        builder: (context, state) => const FavoritesPage(),
      ),
      GoRoute(
        path: RouteNames.brands,
        builder: (context, state) => const BrandsPage(),
      ),
      GoRoute(
        path: RouteNames.brandCatalog,
        builder: (context, state) {
          final brand = state.extra! as String;
          return CatalogPage(initialBrand: brand);
        },
      ),
      GoRoute(
        path: RouteNames.requestSuccess,
        builder: (context, state) => const RequestSuccessPage(),
      ),
      GoRoute(
        path: RouteNames.filteredCatalog,
        builder: (context, state) {
          final payload = state.extra! as CatalogFilterPayload;
          return CatalogPage(
            title: payload.title,
            initialBrand: payload.brand,
            initialCategory: payload.category,
            initialMark: payload.mark,
            initialSaleOnly: payload.saleOnly,
          );
        },
      ),
    ],
  );
}
