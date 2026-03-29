import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../favorites/presentation/cubit/favorites_cubit.dart';
import '../../../favorites/presentation/cubit/favorites_state.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../cubit/top_brands_cubit.dart';
import '../widgets/home_page_skeleton.dart';
import '../widgets/home_section.dart';
import '../widgets/top_brands_section.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeBloc _bloc;
  late final TopBrandsCubit _topBrandsCubit;

  @override
  void initState() {
    super.initState();
    _bloc = sl<HomeBloc>()..add(const HomeStarted());
    _topBrandsCubit = sl<TopBrandsCubit>()..load();
  }

  @override
  void dispose() {
    _bloc.close();
    _topBrandsCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _bloc),
        BlocProvider.value(value: _topBrandsCubit),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TIFFANI'),
          actions: [_FavoritesButton()],
        ),
        body: const _HomeBody(),
      ),
    );
  }
}

class _FavoritesButton extends StatelessWidget {
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
              count > 0 ? Icons.favorite : Icons.favorite_border,
            ),
          ),
        );
      },
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        return switch (state.status) {
          HomeStatus.initial || HomeStatus.loading =>
              const HomePageSkeleton(),
          HomeStatus.failure => _FailureView(
              message: state.errorMessage ?? 'Something went wrong'),
          HomeStatus.success => _SuccessView(state: state),
        };
      },
    );
  }
}

class _SuccessView extends StatelessWidget {
  final HomeState state;

  const _SuccessView({required this.state});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(),
          const TopBrandsSection(),
          if (state.newItems.isNotEmpty)
            HomeSection(title: 'New', items: state.newItems),
          if (state.saleItems.isNotEmpty)
            HomeSection(title: 'Sale', items: state.saleItems),
          if (state.hitItems.isNotEmpty)
            HomeSection(title: 'Hit', items: state.hitItems),
          if (!state.hasSections)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No featured products yet',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Beauty shopping',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Discover products and send a request to order.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final shell = StatefulNavigationShell.maybeOf(context);
                if (shell != null) {
                  shell.goBranch(1);
                } else {
                  context.go(RouteNames.catalog);
                }
              },
              child: const Text('Open catalog'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  final String message;

  const _FailureView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style:
                  TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                context.read<HomeBloc>().add(const HomeRefreshed());
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
