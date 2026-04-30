import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/catalog_filter_payload.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/hero_curve_clipper.dart';
import '../../../favorites/presentation/cubit/favorites_cubit.dart';
import '../../../favorites/presentation/cubit/favorites_state.dart';
import '../../../articles/presentation/cubit/home_articles_cubit.dart';
import '../../../articles/presentation/widgets/home_recommendations_section.dart';
import '../../../recently_viewed/presentation/widgets/recently_viewed_section.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../cubit/top_brands_cubit.dart';
import '../home_metrics.dart';
import '../home_strings.dart';
import '../widgets/home_page_skeleton.dart';
import '../widgets/home_section.dart';
import '../widgets/home_contacts_section.dart';
import '../widgets/top_brands_section.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeBloc _bloc;
  late final TopBrandsCubit _topBrandsCubit;
  late final HomeArticlesCubit _articlesCubit;

  @override
  void initState() {
    super.initState();
    _bloc = sl<HomeBloc>()..add(const HomeStarted());
    _topBrandsCubit = sl<TopBrandsCubit>()..load();
    _articlesCubit = sl<HomeArticlesCubit>()..load();
  }

  @override
  void dispose() {
    _bloc.close();
    _topBrandsCubit.close();
    _articlesCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _bloc),
        BlocProvider.value(value: _topBrandsCubit),
        BlocProvider.value(value: _articlesCubit),
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/home/bg.jpg',
                fit: BoxFit.cover,
              ),
            ),
            const Positioned.fill(child: ColoredBox(color: Color(0x38FFFFFF))),
            const _HomeBody(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — always renders hero; content below depends on bloc state
// ---------------------------------------------------------------------------

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    final heroHeight = MediaQuery.of(context).size.height * 0.37;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroSection(height: heroHeight),
            const _HeroCurveContinuationStrip(),
            BlocBuilder<HomeBloc, HomeState>(
              builder: (context, state) {
                final child = switch (state.status) {
                  HomeStatus.initial ||
                  HomeStatus.loading => const HomeContentSkeleton(),
                  HomeStatus.failure => _FailureView(
                    message: state.errorMessage ?? HomeStrings.genericError,
                  ),
                  HomeStatus.success => _SuccessContent(state: state),
                };
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: child,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Curved continuation under Hero (same veil as page; matches hero bottom arc)
// ---------------------------------------------------------------------------

const double _kHeroContinuationOverlap = 14;

class _HeroCurveContinuationStrip extends StatelessWidget {
  const _HeroCurveContinuationStrip();

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -_kHeroContinuationOverlap),
      child: ClipPath(
        clipper: const HeroContinuationClipper(
          amplitude: 14,
          overlap: _kHeroContinuationOverlap,
        ),
        clipBehavior: Clip.antiAlias,
        child: const ColoredBox(
          color: Color(0x38FFFFFF),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Center(child: _GiftBenefitRibbon()),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Premium tappable benefit ribbon under the hero
// ---------------------------------------------------------------------------

class _GiftBenefitRibbon extends StatefulWidget {
  const _GiftBenefitRibbon();

  @override
  State<_GiftBenefitRibbon> createState() => _GiftBenefitRibbonState();
}

class _GiftBenefitRibbonState extends State<_GiftBenefitRibbon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOut));
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entrance.forward();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    _GiftBenefitSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Listener(
          onPointerDown: (_) => setState(() => _pressed = true),
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.985 : 1.0,
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _onTap,
                borderRadius: BorderRadius.circular(999),
                splashColor: AppColors.textPrimary.withValues(alpha: 0.04),
                highlightColor: AppColors.textPrimary.withValues(alpha: 0.02),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.textPrimary.withValues(alpha: 0.08),
                      width: 0.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 22,
                        spreadRadius: -4,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const _GiftIconMicroMotion(),
                      const SizedBox(width: 11),
                      Text(
                        'Подарок к каждому заказу',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.0,
                          letterSpacing: 0.6,
                          color: AppColors.textPrimary.withValues(alpha: 0.88),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 1,
                        height: 12,
                        color: AppColors.textPrimary.withValues(alpha: 0.10),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.textSecondary.withValues(alpha: 0.55),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet — short, premium explanation of the gift benefit
// ---------------------------------------------------------------------------

class _GiftBenefitSheet {
  const _GiftBenefitSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      isScrollControlled: false,
      builder: (_) => const _GiftBenefitSheetContent(),
    );
  }
}

class _GiftBenefitSheetContent extends StatelessWidget {
  const _GiftBenefitSheetContent();

  static const _bullets = <String>[
    'Каждый заказ дополняем подарком от Тиффани.',
    'Наполнение может отличаться от заказа к заказу.',
    'Состав подарка зависит от наличия и суммы заказа.',
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.xl),
          topRight: Radius.circular(AppRadius.xl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm + 2,
        AppSpacing.xl,
        AppSpacing.xl + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 1,
                color: AppColors.textPrimary.withValues(alpha: 0.32),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'TIFFANI',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary.withValues(alpha: 0.85),
                  letterSpacing: 1.8,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Подарок к заказу',
            style: AppTextStyles.sectionTitle.copyWith(
              fontSize: 19,
              letterSpacing: -0.3,
              height: 1.1,
              color: AppColors.textPrimary.withValues(alpha: 0.96),
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            'Маленький жест внимания — добавляем подарок '
            'к каждому заказу как продолжение нашего ухода о вас.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary.withValues(alpha: 0.88),
              letterSpacing: 0.05,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: AppSpacing.lg + 2),
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg - 2,
              AppSpacing.md,
              AppSpacing.lg - 2,
              AppSpacing.md + 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceWarm,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.05),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _bullets.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm + 2),
                  _SheetBullet(text: _bullets[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg + 2),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text(
                'ПОНЯТНО',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetBullet extends StatelessWidget {
  final String text;

  const _SheetBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.55,
              color: AppColors.textPrimary.withValues(alpha: 0.82),
              letterSpacing: 0.05,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

/// Rotational sway (primary) + light vertical settle on the gift asset only;
/// ~4s calm pause between ~1.3s motion passes.
class _GiftIconMicroMotion extends StatefulWidget {
  const _GiftIconMicroMotion();

  @override
  State<_GiftIconMicroMotion> createState() => _GiftIconMicroMotionState();
}

class _GiftIconMicroMotionState extends State<_GiftIconMicroMotion>
    with SingleTickerProviderStateMixin {
  static const Duration _motionDuration = Duration(milliseconds: 1300);
  static const Duration _idleBetweenRuns = Duration(milliseconds: 4000);

  late final AnimationController _c;
  late final Animation<double> _sway;
  late final Animation<double> _liftY;
  late final Animation<double> _iconOpacity;
  Timer? _idleTimer;

  void _onStatus(AnimationStatus s) {
    if (s != AnimationStatus.completed || !mounted) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleBetweenRuns, () {
      if (mounted) _c.forward(from: 0);
    });
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _motionDuration)
      ..addStatusListener(_onStatus);

    _sway = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: -0.04,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 36,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -0.04,
          end: 0.025,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 38,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.025,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 26,
      ),
    ]).animate(_c);

    _liftY = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 10),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: -1.0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 34,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -1.0,
          end: 0.35,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 38,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.35,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 18,
      ),
    ]).animate(_c);

    _iconOpacity = Tween<double>(
      begin: 0.93,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _c.removeStatusListener(_onStatus);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Opacity(
            opacity: _iconOpacity.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, _liftY.value),
              child: Transform.rotate(
                angle: _sway.value,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0xFFB9AD9F),
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    'assets/icons/gift.png',
                    width: 16,
                    height: 16,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero section — full-bleed image with gradient, floating icons, bottom text
// ---------------------------------------------------------------------------

const _heroIconShadows = [Shadow(color: Color(0x40000000), blurRadius: 10)];

class _HeroSection extends StatelessWidget {
  final double height;

  const _HeroSection({required this.height});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const HeroCurveClipper(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/home/main.jpg', fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.42),
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.sm,
                    0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () => _navigateToCatalog(context),
                        icon: const Icon(
                          CupertinoIcons.search,
                          color: Colors.white,
                          size: 22,
                          shadows: _heroIconShadows,
                        ),
                      ),
                      const _FavoritesButton(),
                      IconButton(
                        onPressed: () => context.push(RouteNames.account),
                        icon: const Icon(
                          CupertinoIcons.person_crop_circle,
                          color: Colors.white,
                          size: 22,
                          shadows: _heroIconShadows,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              bottom: AppSpacing.xxl + 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('TIFFANI', style: AppTextStyles.hero),
                  const SizedBox(height: 10),
                  Text(
                    HomeStrings.heroSubtitle,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.82),
                      letterSpacing: 0.6,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _navigateToCatalog(BuildContext context) {
    final shell = StatefulNavigationShell.maybeOf(context);
    if (shell != null) {
      shell.goBranch(1);
    } else {
      context.go(RouteNames.catalog);
    }
  }
}

// ---------------------------------------------------------------------------
// Favorites button (white icon for hero overlay)
// ---------------------------------------------------------------------------

class _FavoritesButton extends StatelessWidget {
  const _FavoritesButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoritesCubit, FavoritesState>(
      bloc: sl<FavoritesCubit>(),
      buildWhen: (prev, curr) => prev.ids.length != curr.ids.length,
      builder: (context, state) {
        final count = state.ids.length;
        return IconButton(
          onPressed: () => context.push(RouteNames.favorites),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: Icon(
              count > 0 ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
              color: Colors.white,
              size: 22,
              shadows: _heroIconShadows,
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Success content — category chips + product sections + brands + recent
// ---------------------------------------------------------------------------

class _SuccessContent extends StatelessWidget {
  final HomeState state;

  const _SuccessContent({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSection(
          title: HomeStrings.newSection,
          sectionKey: 'new',
          items: state.newItems,
          isFirst: true,
          actionText: HomeStrings.seeAll,
          onAction: () => context.push(
            RouteNames.filteredCatalog,
            extra: const CatalogFilterPayload(
              title: HomeStrings.newSection,
              mark: 'NEW',
            ),
          ),
        ),
        HomeSection(
          title: HomeStrings.bestsellersSection,
          sectionKey: 'hits',
          items: state.hitItems,
          actionText: HomeStrings.seeAll,
          onAction: () => context.push(
            RouteNames.filteredCatalog,
            extra: const CatalogFilterPayload(
              title: HomeStrings.bestsellersSection,
              mark: 'ХИТ',
            ),
          ),
        ),
        HomeSection(
          title: HomeStrings.saleSection,
          sectionKey: 'sale',
          items: state.saleItems,
          actionText: HomeStrings.seeAll,
          onAction: () => context.push(
            RouteNames.filteredCatalog,
            extra: const CatalogFilterPayload(
              title: HomeStrings.saleSection,
              saleOnly: true,
            ),
          ),
        ),
        const HomeRecommendationsSection(),
        const TopBrandsSection(),
        const RecentlyViewedSection(),
        const SizedBox(height: HomeMetrics.contactsTop),
        const HomeContactsSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Failure view
// ---------------------------------------------------------------------------

class _FailureView extends StatelessWidget {
  final String message;

  const _FailureView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () {
                context.read<HomeBloc>().add(const HomeRefreshed());
              },
              child: const Text(HomeStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}
