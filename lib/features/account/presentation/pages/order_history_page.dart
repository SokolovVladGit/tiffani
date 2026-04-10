import 'package:flutter/material.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../domain/entities/order_summary_entity.dart';
import '../../domain/repositories/account_repository.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  late Future<List<OrderSummaryEntity>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = sl<AccountRepository>().getOrderHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Center(child: AppBackButton()),
        title: const Text('История заказов'),
      ),
      body: FutureBuilder<List<OrderSummaryEntity>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return const _EmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _OrderCard(order: orders[index]),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDim,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 28,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text(
                'Заказов пока нет',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Оформленные заказы появятся здесь',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderSummaryEntity order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.cardSoft(radius: AppRadius.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDate(order.createdAt),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${order.totalItems} поз. · ${order.totalQuantity} шт.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                PriceFormatter.formatRub(order.totalPrice),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.$year, $hour:$minute';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final style = _badgeStyle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(6),
        border: style.outlined
            ? Border.all(color: AppColors.border, width: 1)
            : null,
      ),
      child: Text(
        _localizedStatus,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: style.foreground,
        ),
      ),
    );
  }

  String get _localizedStatus {
    switch (status) {
      case 'new':
        return 'Новый';
      case 'processing':
        return 'В обработке';
      case 'confirmed':
        return 'Подтверждён';
      case 'completed':
        return 'Завершён';
      case 'cancelled':
        return 'Отменён';
      default:
        return status;
    }
  }

  /// Monochrome badge tiers (darker fill = more finality).
  _BadgeStyle get _badgeStyle {
    switch (status) {
      case 'new':
        return _BadgeStyle(AppColors.surfaceDim, AppColors.textSecondary, outlined: true);
      case 'processing':
        return _BadgeStyle(AppColors.surfaceDim, AppColors.textSecondary);
      case 'confirmed':
        return _BadgeStyle(
          AppColors.textPrimary.withValues(alpha: 0.10),
          AppColors.textPrimary,
        );
      case 'completed':
        return _BadgeStyle(AppColors.textPrimary, AppColors.surface);
      case 'cancelled':
        return _BadgeStyle(AppColors.surfaceDim, AppColors.textTertiary);
      default:
        return _BadgeStyle(AppColors.surfaceDim, AppColors.textSecondary);
    }
  }
}

class _BadgeStyle {
  final Color background;
  final Color foreground;
  final bool outlined;
  const _BadgeStyle(this.background, this.foreground, {this.outlined = false});
}
