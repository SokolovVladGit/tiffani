import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/tiffany_primary_button.dart';
import '../../../account/presentation/cubit/auth_cubit.dart';

class RequestSuccessPage extends StatelessWidget {
  const RequestSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isGuest = !sl<AuthCubit>().state.isAuthenticated;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.seed.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 36,
                    color: AppColors.seed,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const Text(
                  'Заявка отправлена',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Наш менеджер свяжется с вами\nдля подтверждения заказа.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl + AppSpacing.xs),
                TiffanyPrimaryButton(
                  label: 'Продолжить покупки',
                  onPressed: () => context.go(RouteNames.catalog),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.go(RouteNames.cart),
                    child: const Text('Перейти в корзину'),
                  ),
                ),
                if (isGuest) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  GestureDetector(
                    onTap: () => context.push(RouteNames.register),
                    child: const Text(
                      'Создать аккаунт',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
