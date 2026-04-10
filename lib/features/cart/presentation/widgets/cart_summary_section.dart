import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/price_formatter.dart';

class CartSummarySection extends StatelessWidget {
  final int totalItems;
  final int totalQuantity;
  final double totalPrice;

  const CartSummarySection({
    super.key,
    required this.totalItems,
    required this.totalQuantity,
    required this.totalPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.cardSoft(),
      child: Column(
        children: [
          _row('Позиций', '$totalItems'),
          const SizedBox(height: AppSpacing.sm),
          _row('Количество', '$totalQuantity'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(),
          ),
          _row('Итого', PriceFormatter.formatRub(totalPrice), bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 15 : 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
