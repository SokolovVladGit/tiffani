import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/info_block_entity.dart';
import '../cubit/info_cubit.dart';
import '../cubit/info_state.dart';
import '../widgets/info_block_renderer.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  late final InfoCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = sl<InfoCubit>()..load();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.surface,
          body: BlocBuilder<InfoCubit, InfoState>(
            builder: (context, state) {
              return switch (state.status) {
                InfoStatus.initial || InfoStatus.loading =>
                  const _LoadingView(),
                InfoStatus.error => _ErrorView(
                    message: state.errorMessage ?? 'Что-то пошло не так',
                    onRetry: () => _cubit.load(),
                  ),
                InfoStatus.loaded => _LoadedView(blocks: state.blocks),
              };
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _LoadedView extends StatefulWidget {
  final List<InfoBlockEntity> blocks;

  const _LoadedView({required this.blocks});

  @override
  State<_LoadedView> createState() => _LoadedViewState();
}

class _LoadedViewState extends State<_LoadedView> {
  final _scrollController = ScrollController();
  final _heroOffset = ValueNotifier<double>(0);
  final _revealedIndices = <int>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    _heroOffset.value = _scrollController.offset;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _heroOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.blocks.isEmpty) return const _EmptyView();

    InfoBlockEntity? galleryBlock;
    final displayBlocks = <InfoBlockEntity>[];
    for (final b in widget.blocks) {
      if (b.blockType == 'gallery') {
        galleryBlock = b;
      } else {
        displayBlocks.add(b);
      }
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xxxl * 2,
      ),
      itemCount: displayBlocks.length,
      itemBuilder: (_, index) {
        final block = displayBlocks[index];
        final topSpacing = _spacingBefore(block.blockType, index);
        final isHero = index == 0 && block.blockType == 'hero';

        if (isHero) {
          return ValueListenableBuilder<double>(
            valueListenable: _heroOffset,
            builder: (_, offset, __) => InfoBlockRenderer(
              block: block,
              scrollOffset: offset,
            ),
          );
        }

        final shouldAnimate = _revealedIndices.add(index);
        final isDelivery = block.blockType == 'delivery';

        return _FadeSlideIn(
          animate: shouldAnimate,
          delay: shouldAnimate
              ? Duration(milliseconds: (index * 60).clamp(0, 300))
              : Duration.zero,
          child: Column(
            children: [
              if (topSpacing > 0) SizedBox(height: topSpacing),
              InfoBlockRenderer(
                block: block,
                inlineGalleryBlock: isDelivery ? galleryBlock : null,
              ),
            ],
          ),
        );
      },
    );
  }

  double _spacingBefore(String blockType, int index) {
    if (index == 0) return 0;
    return switch (blockType) {
      'delivery' => AppSpacing.xxxl + AppSpacing.md,
      'stores' => AppSpacing.xxxl + AppSpacing.lg,
      'cta' => AppSpacing.xxxl + AppSpacing.xl,
      _ => AppSpacing.xxl,
    };
  }
}

// ---------------------------------------------------------------------------
// Soft fade + slide-up entrance. Runs once per mount, with optional delay.
// ---------------------------------------------------------------------------

class _FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final bool animate;

  const _FadeSlideIn({
    required this.child,
    this.delay = Duration.zero,
    this.animate = true,
  });

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    final curve = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);
    _slide = Tween<Offset>(
      begin: const Offset(0, 12),
      end: Offset.zero,
    ).animate(curve);

    if (!widget.animate) {
      _anim.value = 1;
      return;
    }

    if (widget.delay == Duration.zero) {
      _anim.forward();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _anim.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(offset: _slide.value, child: child),
      ),
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.seed),
    );
  }
}

// ---------------------------------------------------------------------------

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxxl),
        child: Text(
          'Информация пока недоступна',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

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
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
