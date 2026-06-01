import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/admin_catalog_cubit.dart';
import '../cubit/admin_catalog_state.dart';
import '../../data/repositories/admin_catalog_repository_impl.dart';
import 'admin_catalog_product_card.dart';
import 'admin_native_product_edit_sheet.dart';

/// Admin catalog visibility management (product list + app_is_visible toggle).
class AdminCatalogPanel extends StatelessWidget {
  const AdminCatalogPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AdminCatalogCubit>()..loadInitial(),
      child: const _AdminCatalogView(),
    );
  }
}

class _AdminCatalogView extends StatefulWidget {
  const _AdminCatalogView();

  @override
  State<_AdminCatalogView> createState() => _AdminCatalogViewState();
}

class _AdminCatalogViewState extends State<_AdminCatalogView> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      context.read<AdminCatalogCubit>().search(value);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<AdminCatalogCubit>().search('');
  }

  Future<void> _onCreateProduct(BuildContext context) async {
    final cubit = context.read<AdminCatalogCubit>();
    final saved = await AdminNativeProductEditSheet.showCreate(
      context,
      cubit: cubit,
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Товар создан')));
    }
  }

  Future<void> _onEditProduct(BuildContext context, String productId) async {
    final cubit = context.read<AdminCatalogCubit>();
    try {
      final form = await cubit.loadNativeProductForEdit(productId);
      if (!context.mounted) return;
      final saved = await AdminNativeProductEditSheet.showEdit(
        context,
        cubit: cubit,
        initial: form,
      );
      if (saved == true && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Сохранено')));
      }
    } catch (e) {
      if (!context.mounted) return;
      final msg = e is AdminCatalogException
          ? e.message
          : 'Не удалось загрузить товар';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onSubmitted: context.read<AdminCatalogCubit>().search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Поиск: название, бренд, категория, UID',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: state.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: 'Очистить поиск',
                          onPressed: _clearSearch,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(40, 40),
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceDim,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Показано до 50 товаров · видимость в приложении',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Semantics(
                      button: true,
                      label: 'Добавить товар',
                      child: OutlinedButton.icon(
                        onPressed: state.isSavingNativeProduct
                            ? null
                            : () => _onCreateProduct(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Добавить товар'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(child: _buildBody(context, state)),
          ],
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AdminCatalogState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator.adaptive(),
      );
    }

    if (state.status == AdminCatalogStatus.error && state.products.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _ErrorBlock(
            message: state.errorMessage ?? 'Не удалось загрузить каталог',
            onRetry: () => context.read<AdminCatalogCubit>().loadInitial(),
          ),
        ],
      );
    }

    if (state.isEmptyLoaded) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _EmptyBlock(
            hasSearch: state.searchQuery.trim().isNotEmpty,
            onClearSearch: _clearSearch,
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<AdminCatalogCubit>().refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        itemCount: state.products.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final product = state.products[index];
          final mutating = state.mutatingIds.contains(product.id);
          final editLoading = state.loadingEditProductId == product.id;
          return AdminCatalogProductCard(
            product: product,
            isMutating: mutating,
            isEditLoading: editLoading,
            onEdit: product.isTildaImported
                ? null
                : () => _onEditProduct(context, product.id),
            onVisibilityChanged: (visible) {
              context.read<AdminCatalogCubit>().setVisibility(
                    product.id,
                    visible,
                    onError: (msg) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(content: Text(msg)));
                    },
                  );
            },
          );
        },
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onClearSearch;

  const _EmptyBlock({
    required this.hasSearch,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 32,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            hasSearch ? 'Ничего не найдено' : 'Товары не найдены',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (hasSearch) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: onClearSearch,
              child: const Text('Сбросить поиск'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBlock({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            size: 28,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
