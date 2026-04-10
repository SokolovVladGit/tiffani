import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_failure_view.dart';
import '../../../../core/widgets/sticky_cta_bar.dart';
import '../../../../core/widgets/tiffany_primary_button.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/cart_state.dart';
import '../widgets/cart_item_tile.dart';
import '../widgets/cart_list_skeleton.dart';
import '../widgets/cart_summary_section.dart';
import '../widgets/empty_cart_view.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  @override
  void initState() {
    super.initState();
    sl<CartCubit>().loadCart();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<CartCubit>(),
      child: Scaffold(
        appBar: AppBar(
          leading: const Center(child: AppBackButton()),
          title: const Text('Корзина'),
          actions: [
            BlocBuilder<CartCubit, CartState>(
              buildWhen: (prev, curr) =>
                  prev.status != curr.status || prev.isEmpty != curr.isEmpty,
              builder: (context, state) {
                if (state.status != CartStatus.success || state.isEmpty) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'Очистить корзину',
                  onPressed: () => context.read<CartCubit>().clearAllItems(),
                );
              },
            ),
          ],
        ),
        body: const _CartBody(),
        bottomNavigationBar: BlocBuilder<CartCubit, CartState>(
          buildWhen: (prev, curr) =>
              prev.status != curr.status || prev.isEmpty != curr.isEmpty,
          builder: (context, state) {
            if (state.status != CartStatus.success || state.isEmpty) {
              return const SizedBox.shrink();
            }
            return StickyCtaBar(
              child: TiffanyPrimaryButton(
                label: 'Оформить заявку',
                onPressed: () => context.push(RouteNames.checkout),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CartBody extends StatelessWidget {
  const _CartBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        final child = switch (state.status) {
          CartStatus.initial || CartStatus.loading =>
            const CartListSkeleton(),
          CartStatus.failure => AppFailureView(
            message: state.errorMessage ?? 'Не удалось загрузить корзину',
            onRetry: () => context.read<CartCubit>().loadCart(),
          ),
          CartStatus.success when state.isEmpty => const EmptyCartView(),
          CartStatus.success => _CartContent(state: state),
        };
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: child,
        );
      },
    );
  }
}

class _CartContent extends StatelessWidget {
  final CartState state;

  const _CartContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CartCubit>();
    return ListView(
      padding: const EdgeInsets.only(
        top: AppSpacing.xs,
        bottom: AppSpacing.lg,
      ),
      children: [
        ...state.items.map(
          (item) => CartItemTile(
            item: item,
            onIncrement: () => cubit.incrementQuantity(item.id),
            onDecrement: () => cubit.decrementQuantity(item.id),
            onRemove: () => cubit.removeItem(item.id),
          ),
        ),
        CartSummarySection(
          totalItems: state.totalItems,
          totalQuantity: state.totalQuantity,
          totalPrice: state.totalPrice,
        ),
      ],
    );
  }
}
