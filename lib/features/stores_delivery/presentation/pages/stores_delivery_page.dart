import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/stores_delivery_bloc.dart';
import '../bloc/stores_delivery_event.dart';
import '../bloc/stores_delivery_state.dart';
import '../widgets/delivery_rule_card.dart';
import '../widgets/store_card.dart';
import '../widgets/stores_delivery_skeleton.dart';

class StoresDeliveryPage extends StatefulWidget {
  const StoresDeliveryPage({super.key});

  @override
  State<StoresDeliveryPage> createState() => _StoresDeliveryPageState();
}

class _StoresDeliveryPageState extends State<StoresDeliveryPage> {
  late final StoresDeliveryBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = sl<StoresDeliveryBloc>()
      ..add(const StoresDeliveryStarted());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(title: const Text('Stores & Delivery')),
        body: const _Body(),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoresDeliveryBloc, StoresDeliveryState>(
      builder: (context, state) {
        return switch (state.status) {
          StoresDeliveryStatus.initial ||
          StoresDeliveryStatus.loading =>
            const StoresDeliverySkeleton(),
          StoresDeliveryStatus.failure => _FailureView(
            message: state.errorMessage ?? 'Something went wrong',
          ),
          StoresDeliveryStatus.success when !state.hasContent =>
            const _EmptyView(),
          StoresDeliveryStatus.success => _SuccessView(state: state),
        };
      },
    );
  }
}

class _SuccessView extends StatelessWidget {
  final StoresDeliveryState state;

  const _SuccessView({required this.state});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.deliveryRules.isNotEmpty) ...[
            const _SectionTitle(text: 'Delivery'),
            ...state.deliveryRules.map(
              (rule) => DeliveryRuleCard(rule: rule),
            ),
            const SizedBox(height: 16),
          ],
          if (state.stores.isNotEmpty) ...[
            const _SectionTitle(text: 'Stores'),
            ...state.stores.map(
              (store) => StoreCard(store: store),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'No store or delivery information yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
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
              style:
                  TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                context
                    .read<StoresDeliveryBloc>()
                    .add(const StoresDeliveryRefreshed());
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
