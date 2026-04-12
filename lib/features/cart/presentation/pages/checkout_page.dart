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

  @override
  void initState() {
    super.initState();
    _tryPrefill();
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

    cubit.submitOrderRequest(
      RequestFormEntity(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topInset = mq.padding.top;
    final bottomInset = mq.padding.bottom;

    return BlocProvider.value(
      value: sl<CartCubit>(),
      child: BlocListener<CartCubit, CartState>(
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
                    _buildSectionCard(
                      title: 'Промокод и карта клиента',
                      children: [
                        _buildField(
                          controller: _promoCtrl,
                          hint: 'Промокод',
                          action: TextInputAction.next,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildField(
                          controller: _loyaltyCtrl,
                          hint: 'Номер карты клиента',
                          action: TextInputAction.next,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _buildFulfillmentSection(),
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
          prev.totalPrice != curr.totalPrice,
      builder: (context, state) {
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
                  PriceFormatter.formatRub(state.totalPrice),
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
        ...FulfillmentOption.values.map(
          (o) => _SelectionCard(
            label: o.label,
            subtitle: o.subtitle,
            selected: _fulfillment == o,
            onTap: () => setState(() {
              _fulfillment = o;
              if (o.isDelivery) _selectedStore = null;
            }),
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
  // Field helper
  // ---------------------------------------------------------------------------

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboard,
    TextInputAction action = TextInputAction.next,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(hintText: hint),
      keyboardType: keyboard,
      textInputAction: action,
      maxLines: maxLines,
      validator: validator,
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
