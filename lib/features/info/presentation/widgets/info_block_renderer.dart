import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/hero_curve_clipper.dart';
import '../../../../core/widgets/tiffany_primary_button.dart';
import '../../../consultation/presentation/cubit/consultation_cubit.dart';
import '../../../consultation/presentation/cubit/consultation_state.dart';
import '../../domain/entities/info_block_entity.dart';
import 'blocks/blog_entry_block.dart';

class InfoBlockRenderer extends StatelessWidget {
  final InfoBlockEntity block;
  final double scrollOffset;
  final InfoBlockEntity? inlineGalleryBlock;

  const InfoBlockRenderer({
    super.key,
    required this.block,
    this.scrollOffset = 0,
    this.inlineGalleryBlock,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return switch (block.blockType) {
        'hero' => _HeroBlock(block: block, scrollOffset: scrollOffset),
        'delivery' => _DeliveryBlock(
            block: block,
            galleryBlock: inlineGalleryBlock,
          ),
        'stores' => _StoresBlock(block: block),
        'gallery' => _GalleryBlock(block: block),
        'blog_entry' => BlogEntryBlock(block: block),
        'cta' => _CtaBlock(block: block),
        _ => const SizedBox.shrink(),
      };
    } catch (e) {
      debugPrint('InfoBlockRenderer error [${block.blockType}]: $e');
      return const SizedBox.shrink();
    }
  }
}

// ============================================================
// Safe JSON helpers
// ============================================================

List<Map<String, dynamic>> _safeListOfMaps(dynamic value) {
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map((m) => Map<String, dynamic>.from(m))
      .toList();
}

List<String> _safeStringList(dynamic value) {
  if (value is! List) return [];
  return value.whereType<String>().toList();
}

Future<void> _launch(String url) async {
  try {
    await launchUrl(Uri.parse(url));
  } catch (e) {
    debugPrint('Could not launch $url: $e');
  }
}

// ============================================================
// HERO
// ============================================================

class _HeroBlock extends StatelessWidget {
  final InfoBlockEntity block;
  final double scrollOffset;
  const _HeroBlock({required this.block, this.scrollOffset = 0});

  static const _parallaxExtra = 30.0;
  static const _parallaxRange = 200.0;
  static const _parallaxFactor = 0.15;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final imageHeight = topPadding + 280;
    final parallaxShift =
        scrollOffset.clamp(0.0, _parallaxRange) * _parallaxFactor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (block.imageUrl != null && block.imageUrl!.isNotEmpty)
          ClipPath(
            clipper: const HeroCurveClipper(amplitude: 10),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    top: -_parallaxExtra + parallaxShift,
                    left: 0,
                    right: 0,
                    height: imageHeight + _parallaxExtra * 2,
                    child: CachedNetworkImage(
                      imageUrl: block.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.skeleton),
                      errorWidget: (_, __, ___) =>
                          Container(color: AppColors.skeleton),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.10),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                          stops: const [0.0, 0.2, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.xxl,
                    right: AppSpacing.xxl,
                    bottom: 36,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (block.title != null)
                          Text(
                            block.title!,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.15,
                              letterSpacing: -0.3,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                        if (block.subtitle != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            block.subtitle!,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.4,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              topPadding + AppSpacing.xxxl,
              AppSpacing.xxl,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (block.title != null)
                  Text(
                    block.title!,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.15,
                      letterSpacing: -0.3,
                    ),
                  ),
                if (block.subtitle != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    block.subtitle!,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ============================================================
// DELIVERY
// ============================================================

class _DeliveryBlock extends StatelessWidget {
  final InfoBlockEntity block;
  final InfoBlockEntity? galleryBlock;
  const _DeliveryBlock({required this.block, this.galleryBlock});

  @override
  Widget build(BuildContext context) {
    final regions = _safeListOfMaps(block.itemsJson?['regions']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (block.title != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _SectionTitle(text: block.title!),
          ),
        for (int i = 0; i < regions.length; i++) ...[
          if (i > 0) ...[
            if (i == 1 && galleryBlock != null) ...[
              const SizedBox(height: 30),
              _GalleryBlock(block: galleryBlock!),
              const SizedBox(height: 32),
            ] else
              const SizedBox(height: AppSpacing.xxl),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _RegionCard(region: regions[i]),
          ),
        ],
      ],
    );
  }
}

class _RegionCard extends StatelessWidget {
  final Map<String, dynamic> region;
  const _RegionCard({required this.region});

  @override
  Widget build(BuildContext context) {
    final name = region['region']?.toString() ?? '';
    final priceLines = _safeStringList(region['price_lines']);
    final freeNote = region['free_delivery_note']?.toString();
    final disclaimer = region['disclaimer']?.toString();
    final timingLines = _safeStringList(region['timing_lines']);
    final paymentNote = region['payment_note']?.toString();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 24,
            spreadRadius: -2,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 24,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.25,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (priceLines.isNotEmpty)
            _DeliveryGroup(
              label: 'Стоимость',
              children: [
                for (final line in priceLines)
                  Text(
                    line,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textDense,
                      height: 1.7,
                    ),
                  ),
              ],
            ),

          if (freeNote != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  freeNote,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444444),
                    height: 1.45,
                  ),
                ),
              ),
            ),

          if (timingLines.isNotEmpty)
            _DeliveryGroup(
              label: 'Сроки',
              children: [
                for (final line in timingLines)
                  Text(
                    line,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.7,
                    ),
                  ),
              ],
            ),

          if (disclaimer != null || paymentNote != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (disclaimer != null)
                    Text(
                      disclaimer,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (disclaimer != null && paymentNote != null)
                    const SizedBox(height: AppSpacing.sm),
                  if (paymentNote != null)
                    Text(
                      paymentNote,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        height: 1.6,
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _DeliveryGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _DeliveryGroup({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF777777),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            children[i],
          ],
        ],
      ),
    );
  }
}

// ============================================================
// STORES
// ============================================================

class _StoresBlock extends StatelessWidget {
  final InfoBlockEntity block;
  const _StoresBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final stores = _safeListOfMaps(block.itemsJson?['stores']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.title != null) _SectionTitle(text: block.title!),
          if (block.subtitle != null) ...[
            Transform.translate(
              offset: const Offset(0, -AppSpacing.sm),
              child: Text(
                block.subtitle!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          for (int i = 0; i < stores.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            _StoreCard(store: stores[i]),
          ],
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  const _StoreCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final name = store['name']?.toString() ?? '';
    final city = store['city']?.toString() ?? '';
    final address = store['address']?.toString() ?? '';
    final phone = store['phone']?.toString() ?? '';
    final hours = store['working_hours']?.toString() ?? '';
    final imageUrl = store['image_url']?.toString();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      height: hasImage ? 260 : null,
      width: double.infinity,
      decoration: BoxDecoration(
        color: hasImage ? Colors.black : AppColors.storeSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: AppColors.skeleton),
                  errorWidget: (_, __, ___) =>
                      Container(color: AppColors.skeleton),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.75),
                      ],
                      stops: const [0.0, 0.25, 0.55, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.xl,
                  right: AppSpacing.xl,
                  bottom: AppSpacing.xxl,
                  child: _StoreOverlay(
                    name: name,
                    city: city,
                    address: address,
                    phone: phone,
                    hours: hours,
                  ),
                ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: _StoreOverlay(
                name: name,
                city: city,
                address: address,
                phone: phone,
                hours: hours,
                dark: true,
              ),
            ),
    );
  }
}

class _StoreOverlay extends StatelessWidget {
  final String name;
  final String city;
  final String address;
  final String phone;
  final String hours;
  final bool dark;

  const _StoreOverlay({
    required this.name,
    required this.city,
    required this.address,
    required this.phone,
    required this.hours,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = dark ? AppColors.textPrimary : Colors.white;
    final secondary =
        dark ? AppColors.textSecondary : Colors.white.withValues(alpha: 0.85);
    final tertiary =
        dark ? AppColors.textTertiary : Colors.white.withValues(alpha: 0.7);

    final textShadows = dark
        ? null
        : <Shadow>[
            Shadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: primary,
            height: 1.3,
            shadows: textShadows,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '$city, $address',
          style: TextStyle(
            fontSize: 14,
            color: secondary,
            height: 1.5,
            shadows: textShadows,
          ),
        ),
        if (phone.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _launch('tel:${phone.replaceAll(' ', '')}');
            },
            behavior: HitTestBehavior.opaque,
            child: Text(
              phone,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: dark ? AppColors.action : Colors.white,
                height: 1.4,
                shadows: textShadows,
              ),
            ),
          ),
        ],
        if (hours.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            hours,
            style: TextStyle(
              fontSize: 13,
              color: tertiary,
              height: 1.4,
              shadows: textShadows,
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================
// GALLERY
// ============================================================

class _GalleryBlock extends StatefulWidget {
  final InfoBlockEntity block;
  const _GalleryBlock({required this.block});

  @override
  State<_GalleryBlock> createState() => _GalleryBlockState();
}

class _GalleryBlockState extends State<_GalleryBlock> {
  late final PageController _controller;
  Timer? _autoScrollTimer;
  int _activeDot = 0;
  bool _isAutoScrolling = false;

  List<Map<String, dynamic>> get _images =>
      _safeListOfMaps(widget.block.itemsJson?['images']);

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.88);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    final count = _images.length;
    if (count <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _isAutoScrolling = true;
      final next = (_activeDot + 1) % count;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  double _currentPage() {
    try {
      if (_controller.hasClients) return _controller.page ?? 0;
    } catch (_) {}
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    if (images.isEmpty) return const SizedBox.shrink();

    const cardHeight = 280.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: cardHeight,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) {
              if (!_isAutoScrolling) {
                HapticFeedback.selectionClick();
              }
              _isAutoScrolling = false;
              setState(() => _activeDot = i);
            },
            itemCount: images.length,
            itemBuilder: (_, index) {
              final url = images[index]['image_url']?.toString() ?? '';
              if (url.isEmpty) return const SizedBox.shrink();

              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final page = _currentPage();
                  final distance =
                      (index - page).abs().clamp(0.0, 1.0);
                  final scale = 1.0 - (distance * 0.06);
                  final opacity = 1.0 - (distance * 0.25);

                  return Transform.scale(
                    scale: scale,
                    child: Opacity(opacity: opacity, child: child),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppRadius.xxl),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.skeleton),
                          errorWidget: (_, __, ___) =>
                              Container(color: AppColors.skeleton),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 80,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black
                                      .withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                final active = i == _activeDot;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: active ? 16 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2.5),
                    color: active
                        ? AppColors.indicator.withValues(alpha: 0.65)
                        : AppColors.indicator
                            .withValues(alpha: 0.25),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// CTA
// ============================================================
//
// Wraps the block in its own [ConsultationCubit] so the submit flow
// is self-contained within the Info screen. The cubit is produced by
// [initConsultationDependencies] as a factory, so every mount gets a
// fresh instance.

class _CtaBlock extends StatelessWidget {
  final InfoBlockEntity block;
  const _CtaBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ConsultationCubit>(
      create: (_) => sl<ConsultationCubit>(),
      child: _CtaBlockBody(block: block),
    );
  }
}

class _CtaBlockBody extends StatefulWidget {
  final InfoBlockEntity block;

  const _CtaBlockBody({required this.block});

  @override
  State<_CtaBlockBody> createState() => _CtaBlockBodyState();
}

class _CtaBlockBodyState extends State<_CtaBlockBody> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Aligned with checkout_page phone validator.
  static final _phonePattern = RegExp(r'^[\d\s\+\-\(\)]{7,20}$');

  /// How long the inline success card stays visible before the form
  /// fades back in. Kept short so the user is not left staring at
  /// confirmation, but long enough that the transition feels intentional.
  static const Duration _successDisplayDuration = Duration(milliseconds: 3500);

  /// Pending auto-reset timer scheduled when entering the success state.
  /// Tracked on the state so it can be cancelled on dispose or on a
  /// subsequent state change.
  Timer? _successResetTimer;

  @override
  void dispose() {
    _successResetTimer?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? v, String message) {
    if (v == null || v.trim().isEmpty) return message;
    return null;
  }

  String? _nameValidator(String? v) =>
      _requiredValidator(v, 'Укажите имя');

  String? _phoneValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Укажите телефон';
    if (!_phonePattern.hasMatch(v.trim())) {
      return 'Некорректный номер телефона';
    }
    return null;
  }

  void _handleSubmit() {
    final cubit = context.read<ConsultationCubit>();
    if (cubit.state.isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.lightImpact();
    cubit.submit(
      name: _nameCtrl.text,
      phone: _phoneCtrl.text,
    );
  }

  void _handleSuccess(BuildContext context) {
    // Clear field text and any stale validator messages so that when the
    // form fades back in after the success view it is in a pristine state.
    _formKey.currentState?.reset();
    _nameCtrl.clear();
    _phoneCtrl.clear();
    FocusScope.of(context).unfocus();

    // Defensive: any previously queued reset is invalidated by a new
    // success transition. Without this, rapid successive submits could
    // collapse the success view too early.
    _successResetTimer?.cancel();
    _successResetTimer = Timer(_successDisplayDuration, () {
      if (!mounted) return;
      context.read<ConsultationCubit>().reset();
    });
  }

  /// Builds the default form column (kicker + title + subtitle + fields +
  /// submit button). Extracted so the success view can swap in/out cleanly
  /// inside an [AnimatedSwitcher] without re-declaring the layout twice.
  Widget _buildFormColumn(
    BuildContext context, {
    required String? kickerText,
    required String? title,
    required String? subtitle,
    required String buttonLabel,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (kickerText != null) ...[
          Text(
            kickerText.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.action.withValues(alpha: 0.50),
              letterSpacing: 1.6,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (title != null)
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.25,
              letterSpacing: -0.2,
            ),
          ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 26),
        _CtaField(
          controller: _nameCtrl,
          hint: 'Ваше имя',
          icon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.next,
          validator: _nameValidator,
        ),
        const SizedBox(height: 18),
        _CtaField(
          controller: _phoneCtrl,
          hint: 'Телефон',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          validator: _phoneValidator,
          onFieldSubmitted: (_) => _handleSubmit(),
        ),
        const SizedBox(height: 28),
        BlocBuilder<ConsultationCubit, ConsultationState>(
          buildWhen: (prev, curr) =>
              prev.isSubmitting != curr.isSubmitting,
          builder: (context, state) {
            return TiffanyPrimaryButton(
              label: buttonLabel,
              isLoading: state.isSubmitting,
              onPressed: state.isSubmitting ? null : _handleSubmit,
            );
          },
        ),
      ],
    );
  }

  /// Soft cross-fade with a barely-perceptible scale lift. Avoids any
  /// translate/slide motion so the card never feels like it's "jumping".
  Widget _ctaTransitionBuilder(Widget child, Animation<double> animation) {
    final scale = Tween<double>(begin: 0.985, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(scale: scale, child: child),
    );
  }

  void _handleFailure(BuildContext context, String? message) {
    // Backend / network failures only. Field-level validation errors are
    // surfaced inline by the Form validators above, never via SnackBar,
    // so we must not try to "interpret" the raw error as a field error.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось отправить заявку. Попробуйте ещё раз.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final buttonLabel =
        block.itemsJson?['button_label']?.toString() ?? 'Отправить';
    final kicker = block.itemsJson?['kicker']?.toString();
    final kickerText =
        kicker ?? (block.title != null ? 'КОНСУЛЬТАЦИЯ' : null);

    return BlocListener<ConsultationCubit, ConsultationState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.isSuccess) {
          // Do not reset the cubit here — the inline success view stays
          // visible while `state.isSuccess` is true and is dismissed by
          // the auto-reset timer scheduled below.
          _handleSuccess(context);
        } else if (state.isFailure) {
          // A new failure invalidates any pending success transition.
          _successResetTimer?.cancel();
          _successResetTimer = null;
          _handleFailure(context, state.errorMessage);
          context.read<ConsultationCubit>().reset();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl, AppSpacing.xxxl, AppSpacing.xxl, AppSpacing.xxl,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 24,
                spreadRadius: -2,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: BlocBuilder<ConsultationCubit, ConsultationState>(
              buildWhen: (prev, curr) => prev.isSuccess != curr.isSuccess,
              builder: (context, state) {
                // The success view replaces the form contents in place so the
                // CTA card stays in the same scroll position. AnimatedSize
                // smooths any height delta between the two layouts; the
                // AnimatedSwitcher cross-fades them with a soft scale.
                return AnimatedSize(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: _ctaTransitionBuilder,
                    child: state.isSuccess
                        ? _CtaSuccessView(
                            key: const ValueKey('cta-success'),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('cta-form'),
                            child: _buildFormColumn(
                              context,
                              kickerText: kickerText,
                              title: block.title,
                              subtitle: block.subtitle,
                              buttonLabel: buttonLabel,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CtaField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  const _CtaField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onFieldSubmitted: onFieldSubmitted,
      style: const TextStyle(
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 15,
          color: AppColors.inputHint,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Padding(
          padding:
              const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.md),
          child: Icon(icon, size: 20, color: AppColors.inputHint),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.action.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

/// Inline success state shown inside the CTA card after a consultation
/// request is accepted by the server. Designed to feel intentional and
/// quiet rather than celebratory: monochrome check inside a soft circular
/// well, short headline, supporting line. No saturated colors, no banner.
class _CtaSuccessView extends StatelessWidget {
  const _CtaSuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Approximates the visual mass of the form so the AnimatedSize
      // height delta during the cross-fade stays small.
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.creamSubtle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 28,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Заявка принята',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.25,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'Мы свяжемся с вами в ближайшее время.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SHARED
// ============================================================

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          height: 1.2,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
