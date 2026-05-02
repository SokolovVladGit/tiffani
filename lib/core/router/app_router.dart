import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/pages/account_page.dart';
import '../../features/account/presentation/pages/auth_shell_page.dart';
import '../../features/app_shell/presentation/pages/app_shell_page.dart';
import '../../features/cart/presentation/cubit/cart_cubit.dart';
import '../../features/cart/presentation/pages/cart_page.dart';
import '../../features/cart/presentation/pages/checkout_page.dart';
import '../../features/cart/presentation/pages/request_success_page.dart';
import '../../features/catalog/domain/entities/catalog_item_entity.dart';
import '../../features/catalog/presentation/pages/brands_page.dart';
import '../../features/catalog/presentation/pages/catalog_details_page.dart';
import '../../features/catalog/presentation/pages/catalog_page.dart';
import '../../features/favorites/presentation/pages/favorites_page.dart';
import '../../features/glossary/presentation/pages/glossary_about_page.dart';
import '../../features/glossary/presentation/pages/glossary_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/info/presentation/pages/info_page.dart';
import '../di/injector.dart';
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
        ],
      ),
      GoRoute(
        path: RouteNames.cart,
        // Provide CartCubit ABOVE the page's State element so anything
        // using the State's own context (initState, postFrameCallback,
        // event handlers calling state.context.read<CartCubit>()) can
        // resolve the cubit. CartCubit is a registered singleton, so
        // Cart and Checkout share the exact same instance.
        builder: (context, state) => BlocProvider.value(
          value: sl<CartCubit>(),
          child: const CartPage(),
        ),
      ),
      GoRoute(
        path: RouteNames.glossary,
        name: RouteNames.glossary,
        builder: (context, state) => const GlossaryPage(),
      ),
      GoRoute(
        path: RouteNames.glossaryAbout,
        name: RouteNames.glossaryAbout,
        builder: (context, state) => const GlossaryAboutPage(),
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
        path: RouteNames.account,
        builder: (context, state) => const AccountPage(),
      ),
      GoRoute(
        path: RouteNames.orderHistory,
        builder: (context, state) =>
            const AccountPage(showOrderHistory: true),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const AuthShellPage(
          initialMode: AuthShellMode.login,
        ),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) => const AuthShellPage(
          initialMode: AuthShellMode.register,
        ),
      ),
      GoRoute(
        path: RouteNames.checkout,
        // See note on the Cart route above. CheckoutPage's State uses
        // its own `context` from initState's postFrameCallback to call
        // CartCubit.requestQuote, so the provider must sit ABOVE the
        // StatefulWidget element (not inside its build method).
        builder: (context, state) => BlocProvider.value(
          value: sl<CartCubit>(),
          child: const CheckoutPage(),
        ),
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
