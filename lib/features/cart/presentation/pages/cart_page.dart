import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/request_form_entity.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/cart_state.dart';
import '../widgets/cart_item_tile.dart';
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
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<CartCubit>()..loadCart(),
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
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Request sent successfully')),
              );
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
        return switch (state.status) {
          CartStatus.initial || CartStatus.loading => const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          CartStatus.failure => _FailureView(
            message: state.errorMessage ?? 'Failed to load cart',
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
      padding: const EdgeInsets.only(top: 4, bottom: 32),
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
          isSubmitting: state.isSubmitting,
          onSubmit: () {
            if (!formKey.currentState!.validate()) return;
            cubit.submitOrderRequest(
              RequestFormEntity(
                name: nameController.text,
                phone: phoneController.text,
                comment: commentController.text.isEmpty
                    ? null
                    : commentController.text,
              ),
            );
          },
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
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _RequestForm({
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.commentController,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
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
            const SizedBox(height: 12),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(hintText: 'Your name'),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: phoneController,
              decoration: const InputDecoration(hintText: 'Phone number'),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: commentController,
              decoration: const InputDecoration(hintText: 'Comment (optional)'),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
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
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.read<CartCubit>().loadCart(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
