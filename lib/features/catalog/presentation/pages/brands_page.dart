import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/brands_cubit.dart';

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
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.errorMessage != null) {
              return _ErrorView(
                message: state.errorMessage!,
                onRetry: _cubit.loadBrands,
              );
            }
            if (state.brands.isEmpty) {
              return const Center(
                child: Text(
                  'No brands available',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }
            return _BrandsList(brands: state.brands);
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
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: letters.length,
      itemBuilder: (context, index) {
        final letter = letters[index];
        final items = grouped[letter]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
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

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

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
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
