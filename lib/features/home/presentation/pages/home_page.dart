import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/catalog_filter_payload.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../favorites/presentation/cubit/favorites_cubit.dart';
import '../../../favorites/presentation/cubit/favorites_state.dart';
import '../../../articles/presentation/cubit/home_articles_cubit.dart';
import '../../../articles/presentation/widgets/home_recommendations_section.dart';
import '../../../recently_viewed/presentation/widgets/recently_viewed_section.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../cubit/top_brands_cubit.dart';
import '../home_strings.dart';
import '../widgets/home_page_skeleton.dart';
import '../widgets/home_section.dart';
import '../widgets/home_contacts_section.dart';
import '../widgets/top_brands_section.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeBloc _bloc;
  late final TopBrandsCubit _topBrandsCubit;
  late final HomeArticlesCubit _articlesCubit;

  @override
  void initState() {
    super.initState();
    _bloc = sl<HomeBloc>()..add(const HomeStarted());
    _topBrandsCubit = sl<TopBrandsCubit>()..load();
    _articlesCubit = sl<HomeArticlesCubit>()..load();
  }

  @override
  void dispose() {
    _bloc.close();
    _topBrandsCubit.close();
    _articlesCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _bloc),
        BlocProvider.value(value: _topBrandsCubit),
        BlocProvider.value(value: _articlesCubit),
      ],
      child: const Scaffold(
        body: _HomeBody(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — always renders hero; content below depends on bloc state
// ---------------------------------------------------------------------------

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    final heroHeight = MediaQuery.of(context).size.height * 0.37;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroSection(height: heroHeight),
            BlocBuilder<HomeBloc, HomeState>(
              builder: (context, state) {
                final child = switch (state.status) {
                  HomeStatus.initial || HomeStatus.loading =>
                    const HomeContentSkeleton(),
                  HomeStatus.failure => _FailureView(
                      message:
                          state.errorMessage ?? HomeStrings.genericError),
                  HomeStatus.success => _SuccessContent(state: state),
                };
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: child,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero section — full-bleed image with gradient, floating icons, bottom text
// ---------------------------------------------------------------------------

const _heroIconShadows = [
  Shadow(color: Color(0x40000000), blurRadius: 10),
];

class _HeroSection extends StatelessWidget {
  final double height;

  const _HeroSection({required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/home/main.jpg',
            fit: BoxFit.cover,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.65),
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => _navigateToCatalog(context),
                      icon: const Icon(
                        CupertinoIcons.search,
                        color: Colors.white,
                        size: 22,
                        shadows: _heroIconShadows,
                      ),
                    ),
                    const _FavoritesButton(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: AppSpacing.xxl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TIFFANI',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 4,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  HomeStrings.heroSubtitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _navigateToCatalog(BuildContext context) {
    final shell = StatefulNavigationShell.maybeOf(context);
    if (shell != null) {
      shell.goBranch(1);
    } else {
      context.go(RouteNames.catalog);
    }
  }
}

// ---------------------------------------------------------------------------
// Favorites button (white icon for hero overlay)
// ---------------------------------------------------------------------------

class _FavoritesButton extends StatelessWidget {
  const _FavoritesButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoritesCubit, FavoritesState>(
      bloc: sl<FavoritesCubit>(),
      buildWhen: (prev, curr) => prev.ids.length != curr.ids.length,
      builder: (context, state) {
        final count = state.ids.length;
        return IconButton(
          onPressed: () => context.push(RouteNames.favorites),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: Icon(
              count > 0
                  ? CupertinoIcons.heart_fill
                  : CupertinoIcons.heart,
              color: Colors.white,
              size: 22,
              shadows: _heroIconShadows,
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Success content — category chips + product sections + brands + recent
// ---------------------------------------------------------------------------

class _SuccessContent extends StatelessWidget {
  final HomeState state;

  const _SuccessContent({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSection(
          title: HomeStrings.newSection,
          items: state.newItems,
          actionText: HomeStrings.seeAll,
          onAction: () => context.push(
            RouteNames.filteredCatalog,
            extra: const CatalogFilterPayload(
              title: HomeStrings.newSection,
              mark: 'NEW',
            ),
          ),
        ),
        HomeSection(
          title: HomeStrings.bestsellersSection,
          items: state.hitItems,
          actionText: HomeStrings.seeAll,
          onAction: () => context.push(
            RouteNames.filteredCatalog,
            extra: const CatalogFilterPayload(
              title: HomeStrings.bestsellersSection,
              mark: 'ХИТ',
            ),
          ),
        ),
        HomeSection(
          title: HomeStrings.saleSection,
          items: state.saleItems,
          actionText: HomeStrings.seeAll,
          onAction: () => context.push(
            RouteNames.filteredCatalog,
            extra: const CatalogFilterPayload(
              title: HomeStrings.saleSection,
              saleOnly: true,
            ),
          ),
        ),
        const HomeRecommendationsSection(),
        const TopBrandsSection(),
        const RecentlyViewedSection(),
        const HomeContactsSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Failure view
// ---------------------------------------------------------------------------

class _FailureView extends StatelessWidget {
  final String message;

  const _FailureView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () {
                context.read<HomeBloc>().add(const HomeRefreshed());
              },
              child: const Text(HomeStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}
