import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_failure_view.dart';
import '../cubit/brands_cubit.dart';
import '../widgets/brands_list_skeleton.dart';

class BrandsPage extends StatefulWidget {
  const BrandsPage({super.key});

  @override
  State<BrandsPage> createState() => _BrandsPageState();
}

class _BrandsPageState extends State<BrandsPage> {
  late final BrandsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = sl<BrandsCubit>()..loadBrands();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(title: const Text('Brands')),
        body: BlocBuilder<BrandsCubit, BrandsState>(
          builder: (context, state) {
            final Widget child;
            if (state.isLoading) {
              child = const BrandsListSkeleton();
            } else if (state.errorMessage != null) {
              child = AppFailureView(
                message: state.errorMessage!,
                onRetry: _cubit.loadBrands,
              );
            } else if (state.brands.isEmpty) {
              child = const Center(
                child: Text(
                  'No brands available',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            } else {
              child = _BrandsList(brands: state.brands);
            }
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

class _BrandsList extends StatelessWidget {
  final List<String> brands;

  const _BrandsList({required this.brands});

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByLetter(brands);
    final letters = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
      itemCount: letters.length,
      itemBuilder: (context, index) {
        final letter = letters[index];
        final items = grouped[letter]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Text(
                letter,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            for (final brand in items)
              ListTile(
                title: Text(
                  brand,
                  style: const TextStyle(fontSize: 15),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                onTap: () =>
                    context.push(RouteNames.brandCatalog, extra: brand),
              ),
          ],
        );
      },
    );
  }

  Map<String, List<String>> _groupByLetter(List<String> brands) {
    final map = <String, List<String>>{};
    for (final brand in brands) {
      if (brand.isEmpty) continue;
      final letter = brand[0].toUpperCase();
      (map[letter] ??= []).add(brand);
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Map.fromEntries(sorted);
  }
}
