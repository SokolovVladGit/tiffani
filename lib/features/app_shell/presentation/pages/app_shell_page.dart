import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../cart/presentation/cubit/cart_state.dart';

class AppShellPage extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShellPage({super.key, required this.navigationShell});

  static const _iconSize = 22.0;
  static const _barHeight = 64.0;
  static const _capsuleRadius = 26.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Container(
            height: _barHeight,
            decoration: BoxDecoration(
              color: AppColors.surfaceWarm,
              borderRadius: BorderRadius.circular(_capsuleRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 14,
                  offset: const Offset(0, -2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                labelTextStyle:
                    WidgetStateProperty.resolveWith((states) {
                  final isSelected =
                      states.contains(WidgetState.selected);
                  return TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppColors.seed
                        : const Color(0xFFBBBBC0),
                  );
                }),
              ),
              child: BlocSelector<CartCubit, CartState, int>(
                bloc: sl<CartCubit>(),
                selector: (state) => state.totalQuantity,
                builder: (context, cartCount) {
                  return NavigationBar(
                    selectedIndex: navigationShell.currentIndex,
                    onDestinationSelected: (index) =>
                        navigationShell.goBranch(
                      index,
                      initialLocation:
                          index == navigationShell.currentIndex,
                    ),
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    indicatorColor:
                        AppColors.seed.withValues(alpha: 0.09),
                    elevation: 0,
                    height: _barHeight,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: [
                      const NavigationDestination(
                        icon: Icon(CupertinoIcons.house,
                            size: _iconSize,
                            color: AppColors.textTertiary),
                        selectedIcon: Icon(CupertinoIcons.house_fill,
                            size: _iconSize, color: AppColors.seed),
                        label: 'Home',
                      ),
                      const NavigationDestination(
                        icon: Icon(CupertinoIcons.square_grid_2x2,
                            size: _iconSize,
                            color: AppColors.textTertiary),
                        selectedIcon: Icon(
                            CupertinoIcons.square_grid_2x2_fill,
                            size: _iconSize,
                            color: AppColors.seed),
                        label: 'Catalog',
                      ),
                      const NavigationDestination(
                        icon: Icon(CupertinoIcons.info_circle,
                            size: _iconSize,
                            color: AppColors.textTertiary),
                        selectedIcon: Icon(
                            CupertinoIcons.info_circle_fill,
                            size: _iconSize,
                            color: AppColors.seed),
                        label: 'Info',
                      ),
                      NavigationDestination(
                        icon: _CartBadgeIcon(
                          count: cartCount,
                          child: const Icon(CupertinoIcons.bag,
                              size: _iconSize,
                              color: AppColors.textTertiary),
                        ),
                        selectedIcon: _CartBadgeIcon(
                          count: cartCount,
                          child: const Icon(CupertinoIcons.bag_fill,
                              size: _iconSize, color: AppColors.seed),
                        ),
                        label: 'Cart',
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartBadgeIcon extends StatefulWidget {
  final int count;
  final Widget child;

  const _CartBadgeIcon({required this.count, required this.child});

  @override
  State<_CartBadgeIcon> createState() => _CartBadgeIconState();
}

class _CartBadgeIconState extends State<_CartBadgeIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_pulseCtrl);
  }

  @override
  void didUpdateWidget(_CartBadgeIcon old) {
    super.didUpdateWidget(old);
    if (widget.count > old.count) {
      _pulseCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  static const _badgeLabelStyle = TextStyle(
    color: Colors.white,
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Badge(
        isLabelVisible: widget.count > 0,
        backgroundColor: AppColors.seed,
        label: Text('${widget.count}', style: _badgeLabelStyle),
        child: widget.child,
      ),
    );
  }
}
