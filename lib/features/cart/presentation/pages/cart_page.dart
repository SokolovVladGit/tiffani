import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_failure_view.dart';
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
    // CartCubit is provided by the GoRoute builder above this widget so
    // both this build context and the State's own context can resolve it.
    return Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
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
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/home/bg.jpg',
                fit: BoxFit.cover,
              ),
            ),
            const Positioned.fill(
              child: ColoredBox(color: Color(0x38FFFFFF)),
            ),
            const SafeArea(child: _CartBody()),
            BlocBuilder<CartCubit, CartState>(
              buildWhen: (prev, curr) =>
                  prev.status != curr.status || prev.isEmpty != curr.isEmpty,
              builder: (context, state) {
                if (state.status != CartStatus.success || state.isEmpty) {
                  return const SizedBox.shrink();
                }
                final bottomInset = MediaQuery.of(context).padding.bottom;
                return Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16 + bottomInset,
                  child: TiffanyPrimaryButton(
                    label: 'Оформить заявку',
                    onPressed: () => context.push(RouteNames.checkout),
                  ),
                );
              },
            ),
          ],
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ListView(
      padding: EdgeInsets.only(
        top: AppSpacing.xs,
        bottom: 80 + bottomInset,
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
