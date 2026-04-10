import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/product_trust_helpers.dart';
import '../../../../core/widgets/app_image_placeholder.dart';
import '../../../../core/widgets/sticky_cta_bar.dart';
import '../../../../core/widgets/tiffany_primary_button.dart';
import '../../../cart/domain/entities/cart_item_from_catalog.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../recently_viewed/domain/entities/recently_viewed_item.dart';
import '../../../recently_viewed/presentation/cubit/recently_viewed_cubit.dart';
import '../../domain/entities/catalog_item_entity.dart';
import '../../domain/entities/product_image_entity.dart';
import '../cubit/product_images_cubit.dart';
import '../cubit/product_images_state.dart';
import '../cubit/similar_products_cubit.dart';
import '../widgets/similar_products_section.dart';

class CatalogDetailsPage extends StatefulWidget {
  final CatalogItemEntity item;
  final String? heroTag;

  const CatalogDetailsPage({super.key, required this.item, this.heroTag});

  @override
  State<CatalogDetailsPage> createState() => _CatalogDetailsPageState();
}

class _CatalogDetailsPageState extends State<CatalogDetailsPage> {
  late final SimilarProductsCubit _similarCubit;
  late final ProductImagesCubit _imagesCubit;
  bool _contentVisible = false;

  @override
  void initState() {
    super.initState();
    sl<RecentlyViewedCubit>().add(
      RecentlyViewedItem(
        id: widget.item.id,
        title: widget.item.title,
        imageUrl: widget.item.imageUrl,
        price: widget.item.price,
        oldPrice: widget.item.oldPrice,
        brand: widget.item.brand,
      ),
    );
    _similarCubit = sl<SimilarProductsCubit>()
      ..load(
        excludeId: widget.item.id,
        brand: widget.item.brand,
        category: widget.item.category,
      );
    _imagesCubit = sl<ProductImagesCubit>()..load(widget.item.productId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _contentVisible = true);
    });
  }

  @override
  void dispose() {
    _similarCubit.close();
    _imagesCubit.close();
    super.dispose();
  }

  CatalogItemEntity get item => widget.item;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _similarCubit),
        BlocProvider.value(value: _imagesCubit),
      ],
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            automaticallyImplyLeading: false,
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroSection(
                item: item,
                heroTag: widget.heroTag,
              ),
              AnimatedOpacity(
                opacity: _contentVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ContentSection(item: item),
                    const SimilarProductsSection(),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _AddToCartBar(item: item),
      ),
    );
  }
}

class _AddToCartBar extends StatefulWidget {
  final CatalogItemEntity item;

  const _AddToCartBar({required this.item});

  @override
  State<_AddToCartBar> createState() => _AddToCartBarState();
}

class _AddToCartBarState extends State<_AddToCartBar> {
  final _buttonKey = GlobalKey();
  bool _showSuccess = false;
  Timer? _successTimer;
  OverlayEntry? _ghostEntry;
  OverlayEntry? _dropEntry;

  @override
  void dispose() {
    _dropEntry?.remove();
    _dropEntry = null;
    _ghostEntry?.remove();
    _ghostEntry = null;
    _successTimer?.cancel();
    super.dispose();
  }

  void _handleAddToCart() {
    sl<CartCubit>().addItem(cartItemFromCatalog(widget.item));
    HapticFeedback.lightImpact();

    setState(() => _showSuccess = true);
    _successTimer?.cancel();
    _successTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showSuccess = false);
    });

    _spawnProductDrop();
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) _spawnGhostTrail();
    });
  }

  void _spawnProductDrop() {
    final imageUrl = widget.item.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return;

    _dropEntry?.remove();
    _dropEntry = null;

    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final screen = MediaQuery.of(context).size;
    final btnPos = box.localToGlobal(Offset.zero);

    final startCenter = Offset(screen.width / 2, screen.height * 0.27);
    final endCenter = Offset(screen.width / 2, btnPos.dy);
    final overlaySize = Size(screen.width * 0.55, screen.height * 0.26);

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ProductDrop(
        imageUrl: imageUrl,
        startCenter: startCenter,
        endCenter: endCenter,
        overlaySize: overlaySize,
        onComplete: () {
          entry.remove();
          if (_dropEntry == entry) _dropEntry = null;
        },
      ),
    );
    _dropEntry = entry;
    overlay.insert(entry);
  }

  void _spawnGhostTrail() {
    _ghostEntry?.remove();
    _ghostEntry = null;

    final box =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    final start = Offset(
      pos.dx + size.width * 0.55,
      pos.dy + size.height * 0.3,
    );

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _GhostTrail(
        start: start,
        onComplete: () {
          entry.remove();
          if (_ghostEntry == entry) _ghostEntry = null;
        },
      ),
    );
    _ghostEntry = entry;
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return StickyCtaBar(
      child: TiffanyPrimaryButton(
        key: _buttonKey,
        label: _showSuccess ? 'Добавлено' : 'Добавить в корзину',
        onPressed: _handleAddToCart,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _showSuccess
              ? const Icon(Icons.check_rounded, size: 18,
                  color: Colors.white, key: ValueKey('check'))
              : const Icon(Icons.add_shopping_cart, size: 18,
                  color: Colors.white, key: ValueKey('cart')),
        ),
      ),
    );
  }
}

class _GhostTrail extends StatefulWidget {
  final Offset start;
  final VoidCallback onComplete;

  const _GhostTrail({required this.start, required this.onComplete});

  @override
  State<_GhostTrail> createState() => _GhostTrailState();
}

class _GhostTrailState extends State<_GhostTrail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() => setState(() {}));
    _ctrl.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeOut.transform(_ctrl.value);
    return Positioned(
      left: widget.start.dx + 40 * t - 12,
      top: widget.start.dy + 20 * t - 5,
      child: IgnorePointer(
        child: Opacity(
          opacity: (1.0 - t * 1.3).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 1.0 - 0.5 * t,
            child: Container(
              width: 24,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.seed.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductDrop extends StatefulWidget {
  final String imageUrl;
  final Offset startCenter;
  final Offset endCenter;
  final Size overlaySize;
  final VoidCallback onComplete;

  const _ProductDrop({
    required this.imageUrl,
    required this.startCenter,
    required this.endCenter,
    required this.overlaySize,
    required this.onComplete,
  });

  @override
  State<_ProductDrop> createState() => _ProductDropState();
}

class _ProductDropState extends State<_ProductDrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..addListener(() => setState(() {}));
    _ctrl.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeOut.transform(_ctrl.value);

    final w = widget.overlaySize.width;
    final h = widget.overlaySize.height;
    final cx = widget.startCenter.dx +
        (widget.endCenter.dx - widget.startCenter.dx) * t;
    final cy = widget.startCenter.dy +
        (widget.endCenter.dy - widget.startCenter.dy) * t;

    final scale = 1.0 - 0.12 * t;
    final fadeT = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
    final opacity = 0.75 * (1.0 - fadeT);

    return Positioned(
      left: cx - w / 2,
      top: cy - h / 2,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: w,
              height: h,
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatefulWidget {
  final CatalogItemEntity item;
  final String? heroTag;

  const _HeroSection({required this.item, this.heroTag});

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top;
    final screenHeight = mq.size.height;

    final imageTop = topPad + AppSpacing.xs + 36 + AppSpacing.sm;
    final imageHeight = screenHeight * 0.30;
    final totalHeight = imageTop + imageHeight + AppRadius.xxl;

    return BlocBuilder<ProductImagesCubit, ProductImagesState>(
      builder: (context, imagesState) {
        final images = imagesState.images;
        final safeIndex =
            _selectedIndex < images.length ? _selectedIndex : 0;

        String? displayUrl;
        if (images.isNotEmpty) {
          displayUrl = images[safeIndex].url;
        }
        displayUrl ??= widget.item.imageUrl;

        final useHero = widget.heroTag != null && safeIndex == 0;

        Widget imageWidget = AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(displayUrl ?? ''),
            child: _buildMainImage(displayUrl, imageHeight),
          ),
        );

        if (useHero) {
          imageWidget = Hero(
            tag: widget.heroTag!,
            child: Material(
              type: MaterialType.transparency,
              child: imageWidget,
            ),
          );
        }

        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: totalHeight,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: AppColors.surface),
                  ),
                  Positioned(
                    top: imageTop,
                    left: 0,
                    right: 0,
                    height: imageHeight,
                    child: imageWidget,
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const AppBackButton(),
                          _HeroIconButton(
                            child: FavoriteButton(
                                id: widget.item.id, iconSize: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (images.length > 1)
              _ThumbnailStrip(
                images: images,
                selectedIndex: safeIndex,
                onSelected: (index) {
                  if (index != _selectedIndex) {
                    setState(() => _selectedIndex = index);
                  }
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildMainImage(String? url, double imageHeight) {
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        height: imageHeight,
        fit: BoxFit.contain,
        placeholder: (_, _) => SizedBox(
          width: double.infinity,
          height: imageHeight,
        ),
        errorWidget: (_, _, _) => AppImagePlaceholder(
          width: double.infinity,
          height: imageHeight,
          iconSize: 48,
        ),
      );
    }
    return AppImagePlaceholder(
      width: double.infinity,
      height: imageHeight,
      iconSize: 48,
    );
  }
}

class _ThumbnailStrip extends StatelessWidget {
  final List<ProductImageEntity> images;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _ThumbnailStrip({
    required this.images,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const double _size = 48;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.md,
      ),
      child: SizedBox(
        height: _size + 4,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          itemCount: images.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (context, index) {
            final isSelected = index == selectedIndex;
            return GestureDetector(
              onTap: () => onSelected(index),
              child: AnimatedScale(
                scale: isSelected ? 1.04 : 1.0,
                duration: const Duration(milliseconds: 180),
                child: AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.65,
                  duration: const Duration(milliseconds: 180),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.seed.withValues(alpha: 0.4)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppRadius.sm - 1),
                    child: CachedNetworkImage(
                      imageUrl: images[index].url,
                      width: _size,
                      height: _size,
                      fit: BoxFit.contain,
                      placeholder: (_, _) => const SizedBox.shrink(),
                      errorWidget: (_, _, _) => AppImagePlaceholder(
                        width: _size,
                        height: _size,
                      ),
                    ),
                  ),
                ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  final Widget? child;

  const _HeroIconButton({this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }
}

class _ContentSection extends StatelessWidget {
  final CatalogItemEntity item;

  const _ContentSection({required this.item});

  static final _countryLineRegex =
      RegExp(r'Страна[- ]производитель\s*:\s*(.+)', caseSensitive: false);

  /// Extracts "Страна-производитель: ..." from [text], returning the
  /// cleaned text and the extracted country (if any).
  static ({String? text, String? country}) _extractCountry(String? text) {
    if (text == null) return (text: null, country: null);
    final match = _countryLineRegex.firstMatch(text);
    if (match == null) return (text: text, country: null);

    final country = match.group(1)!.trim();
    final cleaned = text
        .replaceFirst(_countryLineRegex, '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return (
      text: cleaned.isEmpty ? null : cleaned,
      country: country.isEmpty ? null : country,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stock = availabilityText(
      quantity: item.quantity,
      itemId: item.id,
      detailed: true,
    );
    final stockColor = availabilityColor(stock);

    final rawShort = _stripHtml(item.shortDescription);
    final rawFull = _stripHtml(item.fullDescription);

    final shortResult = _extractCountry(rawShort);
    final fullResult = _extractCountry(rawFull);

    final shortDesc = shortResult.text;
    final fullDesc = fullResult.text;
    final country = shortResult.country ?? fullResult.country;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xxxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.35,
              letterSpacing: -0.2,
            ),
          ),
          if (item.brand != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              item.brand!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                letterSpacing: 0.1,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _buildPrice(),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.circle, size: 6, color: stockColor),
              const SizedBox(width: AppSpacing.xs),
              Text(
                stock,
                style: TextStyle(fontSize: 13, color: stockColor),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 14,
                color: AppColors.textTertiary,
              ),
              SizedBox(width: AppSpacing.xs),
              Text(
                'Самовывоз сегодня или доставка 1–2 дня',
                style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
              ),
            ],
          ),
          if (item.edition != null || item.modification != null) ...[
            const SizedBox(height: AppSpacing.xl),
            _buildChips(),
          ],
          if (shortDesc != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            const _SectionTitle(text: 'Описание'),
            const SizedBox(height: AppSpacing.sm),
            _BodyText(text: shortDesc),
          ],
          if (fullDesc != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            const _SectionTitle(text: 'Подробнее'),
            const SizedBox(height: AppSpacing.sm),
            _BodyText(text: fullDesc),
          ],
          if (country != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            const _SectionTitle(text: 'Характеристики'),
            const SizedBox(height: AppSpacing.sm),
            _SpecRow(label: 'Страна-производитель', value: country),
          ],
        ],
      ),
    );
  }

  static final _htmlTagRegex = RegExp(r'<[^>]*>');

  static String? _stripHtml(String? raw) {
    if (raw == null) return null;
    var text = raw
        .replaceAll(_htmlTagRegex, '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return text.isEmpty ? null : text;
  }

  Widget _buildPrice() {
    final formatted = PriceFormatter.formatRub(item.price);
    if (formatted.isEmpty) return const SizedBox.shrink();

    final showOld =
        item.oldPrice != null &&
        item.price != null &&
        item.oldPrice! > item.price!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          formatted,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        if (showOld) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            PriceFormatter.formatRub(item.oldPrice),
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.priceOld,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.priceOld,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChips() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (item.edition != null && item.edition!.isNotEmpty)
          _InfoChip(label: item.edition!),
        if (item.modification != null && item.modification!.isNotEmpty)
          _InfoChip(label: item.modification!),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;

  const _BodyText({required this.text});

  static const _style = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
    height: 1.6,
  );

  @override
  Widget build(BuildContext context) {
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    if (paragraphs.length <= 1) {
      return Text(text, style: _style);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          Text(paragraphs[i].trim(), style: _style),
        ],
      ],
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;

  const _SpecRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:  ',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
