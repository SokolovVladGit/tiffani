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
  static const _capsuleRadius = 32.0;
  static const _inactiveColor = Color(0xFF78736F);
  static const _activePillColor = Color(0xFFE6D7DF);
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

  static const _labels = <String>['Home', 'Catalog', 'Info', 'Cart'];

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
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF0E8E4), Color(0xFFECE3DE)],
                ),
                borderRadius: BorderRadius.circular(_capsuleRadius),
              ),
              clipBehavior: Clip.antiAlias,
              child: BlocSelector<CartCubit, CartState, int>(
                bloc: sl<CartCubit>(),
                selector: (state) => state.totalQuantity,
                builder: (context, cartCount) {
                  final selected = navigationShell.currentIndex;
                  return Row(
                    children: List.generate(4, (i) {
                      final active = i == selected;
                      final color =
                          active ? AppColors.seed : _inactiveColor;
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
                          onTap: () => navigationShell.goBranch(
                            i,
                            initialLocation: i == selected,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: active
                                      ? _activePillColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    _pillRadius,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  child: icon,
                                ),
                              ),
                              const SizedBox(height: 4),
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
