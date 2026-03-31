import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_failure_view.dart';
import '../../domain/entities/request_form_entity.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    sl<CartCubit>().loadCart();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _handleSubmit(CartCubit cubit) {
    if (!_formKey.currentState!.validate()) return;
    cubit.submitOrderRequest(
      RequestFormEntity(
        name: _nameController.text,
        phone: _phoneController.text,
        comment: _commentController.text.isEmpty
            ? null
            : _commentController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<CartCubit>(),
      child: BlocListener<CartCubit, CartState>(
        listenWhen: (prev, curr) =>
            prev.submissionSuccess != curr.submissionSuccess ||
            (prev.isSubmitting &&
                !curr.isSubmitting &&
                curr.errorMessage != null),
        listener: (context, state) {
          if (state.submissionSuccess) {
            _nameController.clear();
            _phoneController.clear();
            _commentController.clear();
            context.go(RouteNames.requestSuccess);
          } else if (!state.isSubmitting && state.errorMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ?? 'Failed to send request'),
                ),
              );
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Cart'),
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
                    onPressed: () => context.read<CartCubit>().clearAllItems(),
                  );
                },
              ),
            ],
          ),
          body: _CartBody(
            formKey: _formKey,
            nameController: _nameController,
            phoneController: _phoneController,
            commentController: _commentController,
          ),
          bottomNavigationBar: BlocBuilder<CartCubit, CartState>(
            buildWhen: (prev, curr) =>
                prev.status != curr.status ||
                prev.isEmpty != curr.isEmpty ||
                prev.isSubmitting != curr.isSubmitting,
            builder: (context, state) {
              if (state.status != CartStatus.success || state.isEmpty) {
                return const SizedBox.shrink();
              }
              return _StickyBottomBar(
                isSubmitting: state.isSubmitting,
                onSubmit: () => _handleSubmit(context.read<CartCubit>()),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CartBody extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController commentController;

  const _CartBody({
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.commentController,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        final child = switch (state.status) {
          CartStatus.initial || CartStatus.loading =>
            const CartListSkeleton(),
          CartStatus.failure => AppFailureView(
            message: state.errorMessage ?? 'Failed to load cart',
            onRetry: () => context.read<CartCubit>().loadCart(),
          ),
          CartStatus.success when state.isEmpty => const EmptyCartView(),
          CartStatus.success => _CartContent(
            state: state,
            formKey: formKey,
            nameController: nameController,
            phoneController: phoneController,
            commentController: commentController,
          ),
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
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController commentController;

  const _CartContent({
    required this.state,
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.commentController,
  });

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
        _RequestForm(
          formKey: formKey,
          nameController: nameController,
          phoneController: phoneController,
          commentController: commentController,
        ),
      ],
    );
  }
}

class _RequestForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController commentController;

  const _RequestForm({
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.commentController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.cardSoft(radius: AppRadius.lg),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request details',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(hintText: 'Your name'),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: phoneController,
              decoration: const InputDecoration(hintText: 'Phone number'),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: commentController,
              decoration: const InputDecoration(hintText: 'Comment (optional)'),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyBottomBar extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _StickyBottomBar({
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Submit a request and our manager will contact you to confirm the order.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : onSubmit,
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

