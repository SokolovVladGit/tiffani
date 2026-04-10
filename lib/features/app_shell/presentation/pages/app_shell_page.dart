import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../cart/presentation/cubit/cart_state.dart';

class AppShellPage extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShellPage({super.key, required this.navigationShell});

  static const _iconSize = 22.0;
  static const _barHeight = 64.0;
  static const _capsuleRadius = 32.0;
  static const _pillRadius = 14.0;

  static const _icons = <IconData>[
    CupertinoIcons.house,
    CupertinoIcons.square_grid_2x2,
    CupertinoIcons.info_circle,
    CupertinoIcons.bag,
  ];

  static const _activeIcons = <IconData>[
    CupertinoIcons.house_fill,
    CupertinoIcons.square_grid_2x2_fill,
    CupertinoIcons.info_circle_fill,
    CupertinoIcons.bag_fill,
  ];

  static const _labels = <String>['Главная', 'Каталог', 'Инфо', 'Корзина'];

  /// Number of actual shell branches (Home, Catalog, Info).
  /// The 4th nav item (Cart) is a push-navigation action, not a branch.
  static const _branchCount = 3;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          navigationShell,
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: bottomInset + AppSpacing.sm,
            child: Container(
              height: _barHeight,
              decoration: BoxDecoration(
                gradient: AppGradients.navBar,
                borderRadius: BorderRadius.circular(_capsuleRadius),
                border: Border.all(
                  color: AppColors.navBorder,
                  width: 0.5,
                ),
                boxShadow: AppShadows.navBar,
              ),
              clipBehavior: Clip.antiAlias,
              child: BlocSelector<CartCubit, CartState, int>(
                bloc: sl<CartCubit>(),
                selector: (state) => state.totalQuantity,
                builder: (context, cartCount) {
                  final selected = navigationShell.currentIndex;
                  return Row(
                    children: List.generate(4, (i) {
                      final isBranch = i < _branchCount;
                      final active = isBranch && i == selected;
                      final color =
                          active ? AppColors.textPrimary : AppColors.navInactive;
                      final iconData =
                          active ? _activeIcons[i] : _icons[i];

                      Widget icon = Icon(
                        iconData,
                        size: _iconSize,
                        color: color,
                      );
                      if (i == 3) {
                        icon = _CartBadgeIcon(
                          count: cartCount,
                          child: icon,
                        );
                      }

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (isBranch) {
                              navigationShell.goBranch(
                                i,
                                initialLocation: i == selected,
                              );
                            } else {
                              context.push(RouteNames.cart);
                            }
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.navActivePill
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    _pillRadius,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 5,
                                  ),
                                  child: icon,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _labels[i],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ),
        ],
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

  static const _badgeLabelStyle = AppTextStyles.badgeLabel;

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
