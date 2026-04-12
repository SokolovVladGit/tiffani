import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/tiffany_primary_button.dart';

class RequestSuccessPage extends StatefulWidget {
  const RequestSuccessPage({super.key});

  @override
  State<RequestSuccessPage> createState() => _RequestSuccessPageState();
}

class _RequestSuccessPageState extends State<RequestSuccessPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _circleScale;
  late final Animation<double> _checkOpacity;
  late final Animation<double> _checkScale;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _contentOpacity;

  Timer? _redirectTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _circleScale = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
    );

    _glowOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0.18), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.18, end: 0.08), weight: 60),
    ]).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.0, 0.7),
    ));

    _checkOpacity = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.35, 0.65, curve: Curves.easeIn),
    );

    _checkScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.35, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _contentOpacity = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.55, 1.0, curve: Curves.easeIn),
    );

    _animCtrl.forward();

    _redirectTimer = Timer(const Duration(seconds: 2), _goHome);
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  void _goHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _redirectTimer?.cancel();
    context.go(RouteNames.catalog);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (context, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAnimation(),
                    const SizedBox(height: AppSpacing.xxxl),
                    Opacity(
                      opacity: _contentOpacity.value,
                      child: _buildContent(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimation() {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft glow ring.
          Opacity(
            opacity: _glowOpacity.value,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.seed,
                  width: 1.5,
                ),
              ),
            ),
          ),
          // Main circle.
          Transform.scale(
            scale: _circleScale.value,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.seed,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.seed.withValues(alpha: 0.15),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          // Check mark.
          Opacity(
            opacity: _checkOpacity.value,
            child: Transform.scale(
              scale: _checkScale.value,
              child: const Icon(
                Icons.check_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Заказ успешно оформлен',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'Наш менеджер скоро свяжется с вами\nдля подтверждения',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          '📩 Детали заказа уже переданы менеджеру',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textTertiary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl + AppSpacing.sm),
        TiffanyPrimaryButton(
          label: 'Продолжить покупки',
          onPressed: _goHome,
        ),
      ],
    );
  }
}
