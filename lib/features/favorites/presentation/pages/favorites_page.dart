import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../catalog/presentation/widgets/catalog_card.dart';
import '../cubit/favorites_cubit.dart';
import '../cubit/favorites_items_cubit.dart';
import '../cubit/favorites_items_state.dart';
import '../cubit/favorites_state.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late final FavoritesItemsCubit _itemsCubit;

  @override
  void initState() {
    super.initState();
    _itemsCubit = sl<FavoritesItemsCubit>();
    _itemsCubit.load(sl<FavoritesCubit>().state.ids.toList());
  }

  @override
  void dispose() {
    _itemsCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FavoritesCubit, FavoritesState>(
      bloc: sl<FavoritesCubit>(),
      listenWhen: (prev, curr) => prev.ids != curr.ids,
      listener: (context, state) {
        final displayedIds =
            _itemsCubit.state.items.map((e) => e.id).toSet();
        final newIds = state.ids;
        final removed = displayedIds.difference(newIds);
        final added = newIds.difference(displayedIds);

        if (removed.isNotEmpty) {
          for (final id in removed) {
            _itemsCubit.removeLocally(id);
          }
        }
        if (added.isNotEmpty) {
          _itemsCubit.load(newIds.toList());
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Favorites')),
        body: BlocBuilder<FavoritesItemsCubit, FavoritesItemsState>(
          bloc: _itemsCubit,
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.items.isEmpty) {
              return _EmptyView();
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.items.length,
              itemBuilder: (context, index) {
                final item = state.items[index];
                return CatalogCard(
                  item: item,
                  onTap: () => context.push(
                    RouteNames.catalogDetails,
                    extra: item,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'No favorites yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
