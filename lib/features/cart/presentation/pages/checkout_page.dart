import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/tiffany_primary_button.dart';
import '../../../account/presentation/cubit/auth_cubit.dart';
import '../../../account/presentation/cubit/auth_state.dart';
import '../../config/discount_pricing_config.dart';
import '../../data/dto/order_quote_dto.dart';
import '../../domain/entities/fulfillment_option.dart';
import '../../domain/entities/payment_option.dart';
import '../../domain/entities/pickup_store.dart';
import '../../domain/entities/request_form_entity.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/cart_state.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();
  final _loyaltyCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  FulfillmentOption _fulfillment = FulfillmentOption.values.first;
  PickupStore? _selectedStore;
  PaymentOption _payment = PaymentOption.values.first;
  bool _consent = false;

  /// Trimmed + lower-cased promo code used in the most recent
  /// `quote_order_v1` call. Drives the "Промокод изменён" stale hint and
  /// keeps button copy consistent — `null` means no apply has been triggered
  /// yet (initial automatic-only quote on open does not count, see
  /// [_runQuote]).
  String? _lastQuotedPromo;

  @override
  void initState() {
    super.initState();
    _tryPrefill();
    if (DiscountPricingConfig.useDiscountPricingV1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _runQuote(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _promoCtrl.dispose();
    _loyaltyCtrl.dispose();
    _addressCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _tryPrefill() {
    final auth = sl<AuthCubit>().state;
    if (!auth.isAuthenticated) return;
    _prefillFromAuth(auth);
  }

  void _prefillFromAuth(AuthCubitState auth) {
    if (_nameCtrl.text.isEmpty && auth.profile?.name != null) {
      _nameCtrl.text = auth.profile!.name!;
    }
    if (_phoneCtrl.text.isEmpty && auth.profile?.phone != null) {
      _phoneCtrl.text = auth.profile!.phone!;
    }
    if (_emailCtrl.text.isEmpty && auth.email != null) {
      _emailCtrl.text = auth.email!;
    }
    if (_loyaltyCtrl.text.isEmpty && auth.profile?.loyaltyCard != null) {
      _loyaltyCtrl.text = auth.profile!.loyaltyCard!;
    }
  }

  /// Builds the form entity from current controller/option state. Used by
  /// both the quote and the submit paths so they always agree.
  RequestFormEntity _buildForm() {
    return RequestFormEntity(
      name: _nameCtrl.text,
      phone: _phoneCtrl.text,
      email: _emailCtrl.text.isEmpty ? null : _emailCtrl.text,
      promoCode: _promoCtrl.text.isEmpty ? null : _promoCtrl.text,
      loyaltyCard: _loyaltyCtrl.text.isEmpty ? null : _loyaltyCtrl.text,
      comment: _commentCtrl.text.isEmpty ? null : _commentCtrl.text,
      consentGiven: _consent,
      fulfillment: _fulfillment,
      pickupStore: _fulfillment.isPickup ? _selectedStore : null,
      deliveryAddress: _fulfillment.isDelivery
          ? (_addressCtrl.text.isEmpty ? null : _addressCtrl.text)
          : null,
      payment: _payment,
    );
  }

  /// Triggers a fresh `quote_order_v1` call using the current form. Safe to
  /// call before the form passes validation: the quote endpoint only cares
  /// about items + promo + fulfillment fee.
  ///
  /// `silent` skips the keyboard dismiss (used for non-tap triggers like
  /// fulfillment changes and the implicit on-open quote).
  void _runQuote({bool silent = false}) {
    if (!DiscountPricingConfig.useDiscountPricingV1) return;
    final cubit = context.read<CartCubit>();
    if (cubit.state.items.isEmpty) return;
    setState(() => _lastQuotedPromo = _normalizePromo(_promoCtrl.text));
    cubit.requestQuote(_buildForm());
    if (!silent) {
      FocusScope.of(context).unfocus();
    }
  }

  /// Promo code comparison key. Promo codes are case-insensitive on the
  /// backend (server uppercases them in `submit_order_v3`), so we normalise
  /// here too. Empty string represents "no promo".
  static String _normalizePromo(String raw) => raw.trim().toLowerCase();

  void _handleSubmit(CartCubit cubit) {
    if (!_formKey.currentState!.validate()) return;

    if (_fulfillment.isPickup && _selectedStore == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Выберите магазин для самовывоза')),
        );
      return;
    }

    if (!_consent) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Необходимо согласие на обработку данных'),
          ),
        );
      return;
    }

    if (DiscountPricingConfig.useDiscountPricingV1) {
      // Block submit if the user supplied a promo code that the quoter
      // rejected with a hard error. submit_order_v3 would reject anyway,
      // but blocking client-side gives an instant message.
      final quote = cubit.state.quote;
      final hasPromo = _promoCtrl.text.trim().isNotEmpty;
      if (hasPromo && quote != null && quote.ok) {
        const blockingPromoStatuses = {
          'not_found',
          'inactive',
          'expired',
          'limit_reached',
          'min_order_not_met',
          'no_matching_items',
        };
        if (blockingPromoStatuses.contains(quote.promoStatus)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  OrderQuoteDto.humanizePromoStatus(quote.promoStatus) ??
                      'Промокод не применён',
                ),
              ),
            );
          return;
        }
      }
    }

    cubit.submitOrderRequest(_buildForm());
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topInset = mq.padding.top;
    final bottomInset = mq.padding.bottom;

    // CartCubit is provided by the GoRoute builder above this widget so
    // both `context` here and the State's own `context` (used in initState
    // and post-frame callbacks for _runQuote) can resolve it.
    return BlocListener<CartCubit, CartState>(
        listenWhen: (prev, curr) =>
            prev.submissionSuccess != curr.submissionSuccess ||
            (prev.isSubmitting &&
                !curr.isSubmitting &&
                curr.errorMessage != null),
        listener: (context, state) {
          if (state.submissionSuccess) {
            context.go(RouteNames.requestSuccess);
          } else if (!state.isSubmitting && state.errorMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                      state.errorMessage ?? 'Не удалось отправить заявку'),
                ),
              );
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/home/order_bg.jpg',
                  fit: BoxFit.cover,
                ),
              ),
              Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.only(
                    top: topInset + kToolbarHeight + AppSpacing.lg,
                    bottom: 140,
                  ),
                  children: [
                    _buildOrderSummary(),
                    const SizedBox(height: AppSpacing.xs),
                    _buildContactSection(),
                    const SizedBox(height: AppSpacing.xs),
                    _buildPromoAndLoyaltySection(),
                    const SizedBox(height: AppSpacing.xs),
                    _buildFulfillmentSection(),
                    if (DiscountPricingConfig.useDiscountPricingV1) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _buildPriceBreakdownSection(),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    _buildSectionCard(
                      title: 'Способ оплаты',
                      children: [
                        ...PaymentOption.values.map(
                          (o) => _SelectionCard(
                            label: o.label,
                            subtitle: o.subtitle,
                            selected: _payment == o,
                            onTap: () => setState(() => _payment = o),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _buildSectionCard(
                      title: 'Комментарий к заказу',
                      children: [
                        _buildField(
                          controller: _commentCtrl,
                          hint: 'Ваш комментарий (необязательно)',
                          maxLines: 3,
                          action: TextInputAction.done,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildConsentRow(),
                  ],
                ),
              ),
              _buildFloatingHeader(topInset),
              _buildBottomCta(bottomInset),
            ],
          ),
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Transparent floating header
  // ---------------------------------------------------------------------------

  Widget _buildFloatingHeader(double topInset) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: topInset),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.55, 1.0],
            colors: [
              Color(0xCCF5F5F5),
              Color(0x88F5F5F5),
              Color(0x00F5F5F5),
            ],
          ),
        ),
        child: SizedBox(
          height: kToolbarHeight + 16,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const SizedBox(width: AppSpacing.xs),
                const AppBackButton(),
                const Expanded(
                  child: Text(
                    'Оформление заявки',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(width: 36 + AppSpacing.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom CTA with light gradient
  // ---------------------------------------------------------------------------

  Widget _buildBottomCta(double bottomInset) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: BlocBuilder<CartCubit, CartState>(
        buildWhen: (prev, curr) =>
            prev.isSubmitting != curr.isSubmitting,
        builder: (context, state) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.4, 1.0],
                colors: [
                  Color(0x00FFFFFF),
                  Color(0xCCF5F5F5),
                  Color(0xEEF5F5F5),
                ],
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.md + bottomInset,
            ),
            child: TiffanyPrimaryButton(
              label: 'Оформить заказ',
              onPressed: state.isSubmitting
                  ? null
                  : () => _handleSubmit(context.read<CartCubit>()),
              isLoading: state.isSubmitting,
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Order summary
  // ---------------------------------------------------------------------------

  Widget _buildOrderSummary() {
    return BlocBuilder<CartCubit, CartState>(
      buildWhen: (prev, curr) =>
          prev.totalItems != curr.totalItems ||
          prev.totalQuantity != curr.totalQuantity ||
          prev.totalPrice != curr.totalPrice ||
          prev.quote != curr.quote,
      builder: (context, state) {
        // Prefer the server-quoted grand total when available; otherwise
        // fall back to the local subtotal (legacy behavior).
        final quote = DiscountPricingConfig.useDiscountPricingV1
            ? state.quote
            : null;
        final displayTotal = (quote != null && quote.ok)
            ? quote.grandTotalAmount
            : state.totalPrice;

        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xl + 2,
            ),
            decoration: _summaryDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ваш заказ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${state.totalItems} поз. · ${state.totalQuantity} шт.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  PriceFormatter.formatRub(displayTotal),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Promo + loyalty section (with "Применить" button under the promo input).
  // ---------------------------------------------------------------------------

  Widget _buildPromoAndLoyaltySection() {
    return BlocBuilder<CartCubit, CartState>(
      buildWhen: (prev, curr) =>
          prev.quote != curr.quote ||
          prev.isQuoting != curr.isQuoting ||
          prev.quoteErrorMessage != curr.quoteErrorMessage ||
          prev.quoteStale != curr.quoteStale,
      builder: (context, state) {
        final stale = _stalePromoHint();
        final statusLine = stale == null ? _promoStatusLine(state) : null;
        return _buildSectionCard(
          title: 'Промокод и карта клиента',
          children: [
            _buildField(
              controller: _promoCtrl,
              hint: 'Промокод',
              action: TextInputAction.done,
              onChanged: _onPromoChanged,
            ),
            if (DiscountPricingConfig.useDiscountPricingV1) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildPromoActionRow(state),
              if (stale != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _buildPromoNeutralHint(stale),
              ] else if (statusLine != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _buildPromoStatusLine(statusLine, state.quote?.promoStatus),
              ],
            ],
            const SizedBox(height: AppSpacing.md),
            _buildField(
              controller: _loyaltyCtrl,
              hint: 'Номер карты клиента',
              action: TextInputAction.next,
            ),
          ],
        );
      },
    );
  }

  /// Handles promo input edits without running a quote on every keystroke.
  ///
  /// Beyond marking the existing quote stale, we silently re-quote on the
  /// transition "had a previously applied promo → user cleared the field"
  /// so the breakdown doesn't keep showing a discount the user has already
  /// removed. This is a one-shot trigger, not per-keystroke.
  void _onPromoChanged(String value) {
    final cubit = context.read<CartCubit>();
    cubit.markQuoteStale();

    final trimmed = value.trim();
    final hadAppliedPromo =
        (_lastQuotedPromo != null && _lastQuotedPromo!.isNotEmpty);
    if (trimmed.isEmpty && hadAppliedPromo) {
      // Re-quote silently with empty promo to drop the previous discount.
      _runQuote(silent: true);
      return;
    }
    setState(() {});
  }

  Widget _buildPromoActionRow(CartState state) {
    final isBusy = state.isQuoting;
    final hasInput = _promoCtrl.text.trim().isNotEmpty;
    final enabled = !isBusy && hasInput;

    return Row(
      children: [
        Expanded(
          child: Opacity(
            opacity: enabled || isBusy ? 1.0 : 0.45,
            child: GestureDetector(
              onTap: enabled ? () => _runQuote() : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDim,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.seed.withValues(alpha: 0.4),
                    width: 0.5,
                  ),
                ),
                child: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Применить',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Returns the stale-promo hint when the input has diverged from the most
  /// recently quoted code. Empty input or "matches last quote" returns null.
  String? _stalePromoHint() {
    final current = _normalizePromo(_promoCtrl.text);
    if (current.isEmpty) return null;
    final last = _lastQuotedPromo;
    if (last == null) return null;
    if (current == last) return null;
    return 'Промокод изменён — нажмите «Применить»';
  }

  String? _promoStatusLine(CartState state) {
    final raw = _promoCtrl.text.trim();
    if (raw.isEmpty) return null;
    if (state.quoteErrorMessage != null) return state.quoteErrorMessage;
    final quote = state.quote;
    if (quote == null) return null;
    if (!quote.ok) {
      return quote.errors.isEmpty
          ? null
          : OrderQuoteDto.localizeErrorCode(
              quote.errors.first.code,
              backendMessage: quote.errors.first.message,
            );
    }
    return OrderQuoteDto.humanizePromoStatus(
      quote.promoStatus,
      promoMessage: quote.promoMessage,
    );
  }

  Widget _buildPromoStatusLine(String text, String? status) {
    Color color;
    switch (status) {
      case 'applied':
        color = AppColors.seed;
        break;
      case 'not_best_discount':
        color = AppColors.textSecondary;
        break;
      default:
        color = AppColors.textTertiary;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.4,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPromoNeutralHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          height: 1.4,
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Price breakdown card — visible only with the discount pricing flag on.
  // ---------------------------------------------------------------------------

  Widget _buildPriceBreakdownSection() {
    return BlocBuilder<CartCubit, CartState>(
      buildWhen: (prev, curr) =>
          prev.quote != curr.quote ||
          prev.isQuoting != curr.isQuoting ||
          prev.totalPrice != curr.totalPrice ||
          prev.quoteStale != curr.quoteStale ||
          prev.quoteErrorMessage != curr.quoteErrorMessage,
      builder: (context, state) {
        final quote = state.quote;
        final hasQuote = quote != null && quote.ok;

        // Prefer server numbers; degrade to local subtotal + selected
        // fulfillment fee when the quote isn't available yet.
        final subtotal = hasQuote ? quote.subtotalAmount : state.totalPrice;
        final discount = hasQuote ? quote.discountAmount : 0.0;
        final fee = hasQuote ? quote.fulfillmentFee : _fulfillment.fee;
        final grand = hasQuote
            ? quote.grandTotalAmount
            : (subtotal - discount + fee);

        return _buildSectionCard(
          title: 'Сумма к оплате',
          children: [
            _buildBreakdownRow('Товары', PriceFormatter.formatRub(subtotal)),
            if (discount > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              _buildBreakdownRow(
                'Скидка',
                '-${PriceFormatter.formatRub(discount)}',
                valueColor: AppColors.seed,
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            _buildBreakdownRow('Доставка', PriceFormatter.formatRub(fee)),
            if (hasQuote && quote.appliedDiscountLabels.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              for (final label in quote.appliedDiscountLabels)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(height: 1),
            ),
            _buildBreakdownRow(
              'Итого к оплате',
              PriceFormatter.formatRub(grand),
              bold: true,
            ),
            if (state.quoteStale && hasQuote) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildCheckoutInfoHint(
                'Промокод изменён — нажмите «Применить», чтобы пересчитать.',
              ),
            ],
            if (!hasQuote && state.quoteErrorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildCheckoutInfoHint(state.quoteErrorMessage!),
            ],
            if (state.isQuoting) ...[
              const SizedBox(height: AppSpacing.sm),
              const Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBreakdownRow(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: bold ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 17 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ??
                (bold ? AppColors.textPrimary : AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Contact section with optional auth entry
  // ---------------------------------------------------------------------------

  Widget _buildContactSection() {
    final isGuest = !sl<AuthCubit>().state.isAuthenticated;

    return _buildSectionCard(
      title: 'Контактные данные',
      trailing: isGuest
          ? GestureDetector(
              onTap: () async {
                await context.push(RouteNames.login);
                if (!mounted) return;
                final auth = sl<AuthCubit>().state;
                if (auth.isAuthenticated) {
                  setState(() => _prefillFromAuth(auth));
                }
              },
              child: const Text(
                'Войти',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          : null,
      children: [
        _buildField(
          controller: _nameCtrl,
          hint: 'Имя',
          action: TextInputAction.next,
          validator: _requiredValidator('Укажите имя'),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildField(
          controller: _phoneCtrl,
          hint: 'Телефон',
          keyboard: TextInputType.phone,
          action: TextInputAction.next,
          validator: _phoneValidator,
        ),
        const SizedBox(height: AppSpacing.md),
        _buildField(
          controller: _emailCtrl,
          hint: 'Email (необязательно)',
          keyboard: TextInputType.emailAddress,
          action: TextInputAction.next,
          validator: _emailValidator,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Fulfillment section: method selector + store picker / address field
  // ---------------------------------------------------------------------------

  Widget _buildFulfillmentSection() {
    return _buildSectionCard(
      title: 'Способ получения',
      children: [
        _buildCheckoutInfoHint(
          'При заказе от 1000 ₽ доставка бесплатная',
        ),
        const SizedBox(height: AppSpacing.sm),
        ...FulfillmentOption.values.map(
          (o) => _SelectionCard(
            label: o.label,
            subtitle: o.subtitle,
            selected: _fulfillment == o,
            onTap: () {
              if (_fulfillment == o) return;
              setState(() {
                _fulfillment = o;
                if (o.isDelivery) _selectedStore = null;
              });
              if (DiscountPricingConfig.useDiscountPricingV1) {
                _runQuote(silent: true);
              }
            },
          ),
        ),
        if (_fulfillment.isPickup) ...[
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Выберите магазин',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...PickupStore.all.map(
            (store) => _SelectionCard(
              label: store.label,
              subtitle: null,
              selected: _selectedStore?.id == store.id,
              onTap: () => setState(() => _selectedStore = store),
            ),
          ),
        ],
        if (_fulfillment.isDelivery) ...[
          const SizedBox(height: AppSpacing.lg),
          _buildField(
            controller: _addressCtrl,
            hint: 'Адрес доставки',
            action: TextInputAction.next,
            maxLines: 2,
            validator: _requiredValidator('Укажите адрес доставки'),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section card
  // ---------------------------------------------------------------------------

  static BoxDecoration _summaryDecoration() => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.45),
          width: 0.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 16,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      );

  static BoxDecoration _sectionDecoration() => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      );

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: _sectionDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Checkout helper pill (UI only)
  // ---------------------------------------------------------------------------

  Widget _buildCheckoutInfoHint(String message) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceWarm,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.32),
              width: 0.5,
            ),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              letterSpacing: 0.22,
              color: AppColors.textTertiary.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Field helper
  // ---------------------------------------------------------------------------

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboard,
    TextInputAction action = TextInputAction.next,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(hintText: hint),
      keyboardType: keyboard,
      textInputAction: action,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
    );
  }

  static final _phonePattern = RegExp(r'^[\d\s\+\-\(\)]{7,20}$');
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  FormFieldValidator<String> _requiredValidator(String message) {
    return (v) => (v == null || v.trim().isEmpty) ? message : null;
  }

  String? _phoneValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Укажите телефон';
    if (!_phonePattern.hasMatch(v.trim())) return 'Некорректный номер телефона';
    return null;
  }

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (!_emailPattern.hasMatch(v.trim())) return 'Некорректный email';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Consent
  // ---------------------------------------------------------------------------

  Widget _buildConsentRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0,
      ),
      child: GestureDetector(
        onTap: () => setState(() => _consent = !_consent),
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: _consent ? AppColors.seed : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _consent ? AppColors.seed : AppColors.border,
                    width: _consent ? 0 : 1.5,
                  ),
                ),
                child: _consent
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Text(
                'Я согласен на обработку персональных данных',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Selection card with animated radio indicator and tap feedback
// =============================================================================

class _SelectionCard extends StatefulWidget {
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.label,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SelectionCard> createState() => _SelectionCardState();
}

class _SelectionCardState extends State<_SelectionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tapCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _tapCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) => _tapCtrl.forward();
  void _handleTapUp(TapUpDetails _) => _tapCtrl.reverse();
  void _handleTapCancel() => _tapCtrl.reverse();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: widget.selected
                  ? AppColors.surfaceDim
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: widget.selected
                    ? AppColors.seed.withValues(alpha: 0.4)
                    : AppColors.border.withValues(alpha: 0.35),
                width: widget.selected ? 1.0 : 0.5,
              ),
            ),
            child: Row(
              children: [
                _AnimatedRadio(selected: widget.selected),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: widget.selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (widget.subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            widget.subtitle!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Animated radio indicator
// =============================================================================

class _AnimatedRadio extends StatelessWidget {
  final bool selected;

  const _AnimatedRadio({required this.selected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.seed : AppColors.textTertiary,
            width: selected ? 2.0 : 1.5,
          ),
        ),
        child: Center(
          child: AnimatedScale(
            scale: selected ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.seed,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.seed.withValues(alpha: 0.2),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
