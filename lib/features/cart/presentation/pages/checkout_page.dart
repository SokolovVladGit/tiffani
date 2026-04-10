import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/sticky_cta_bar.dart';
import '../../../../core/widgets/tiffany_primary_button.dart';
import '../../../account/presentation/cubit/auth_cubit.dart';
import '../../../account/presentation/cubit/auth_state.dart';
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

  String _delivery = _DeliveryOption.values.first.label;
  String _payment = _PaymentOption.values.first.label;
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

  /// Fills empty controllers from auth/profile data without overwriting edits.
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

  bool get _needsAddress {
    return _delivery != 'Самовывоз';
  }

  void _handleSubmit(CartCubit cubit) {
    if (!_formKey.currentState!.validate()) return;
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
        deliveryMethod: _delivery,
        address: _addressCtrl.text.isEmpty ? null : _addressCtrl.text,
        paymentMethod: _payment,
        comment: _commentCtrl.text.isEmpty ? null : _commentCtrl.text,
        consentGiven: _consent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          appBar: AppBar(
            leading: const Center(child: AppBackButton()),
            title: const Text('Оформление заявки'),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: 120,
              ),
              children: [
                _buildOrderSummary(),
                _buildContactSection(),
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
                _buildSectionCard(
                  title: 'Способ доставки',
                  children: [
                    ..._DeliveryOption.values.map(
                      (o) => _RadioTile(
                        label: o.label,
                        subtitle: o.subtitle,
                        selected: _delivery == o.label,
                        onTap: () => setState(() => _delivery = o.label),
                      ),
                    ),
                    if (_needsAddress) ...[
                      const SizedBox(height: AppSpacing.md),
                      _buildField(
                        controller: _addressCtrl,
                        hint: 'Адрес доставки',
                        action: TextInputAction.next,
                        maxLines: 2,
                        validator:
                            _requiredValidator('Укажите адрес доставки'),
                      ),
                    ],
                  ],
                ),
                _buildSectionCard(
                  title: 'Способ оплаты',
                  children: [
                    ..._PaymentOption.values.map(
                      (o) => _RadioTile(
                        label: o.label,
                        subtitle: o.subtitle,
                        selected: _payment == o.label,
                        onTap: () => setState(() => _payment = o.label),
                      ),
                    ),
                  ],
                ),
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
                _buildConsentRow(),
              ],
            ),
          ),
          bottomNavigationBar: BlocBuilder<CartCubit, CartState>(
            buildWhen: (prev, curr) =>
                prev.isSubmitting != curr.isSubmitting,
            builder: (context, state) {
              return StickyCtaBar(
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
        ),
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
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm,
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: AppDecorations.cardSoft(radius: AppRadius.lg),
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
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${state.totalItems} поз. · ${state.totalQuantity} шт.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  PriceFormatter.formatRub(state.totalPrice),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
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
          validator: _requiredValidator('Укажите телефон'),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildField(
          controller: _emailCtrl,
          hint: 'Email (необязательно)',
          keyboard: TextInputType.emailAddress,
          action: TextInputAction.next,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section card
  // ---------------------------------------------------------------------------

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.cardSoft(radius: AppRadius.lg),
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
          const SizedBox(height: AppSpacing.md),
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

  FormFieldValidator<String> _requiredValidator(String message) {
    return (v) => (v == null || v.trim().isEmpty) ? message : null;
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
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: _consent ? AppColors.seed : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: _consent ? AppColors.seed : AppColors.border,
                    width: _consent ? 0 : 1.5,
                  ),
                ),
                child: _consent
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
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
// Delivery options
// =============================================================================

enum _DeliveryOption {
  pickup('Самовывоз', 'Бесплатно'),
  tiraspol('Доставка по Тирасполю', null),
  bender('Доставка по Бендерам', null),
  express('Экспресс-почта', null),
  moldova('Доставка по Молдове', null);

  final String label;
  final String? subtitle;
  const _DeliveryOption(this.label, this.subtitle);
}

// =============================================================================
// Payment options
// =============================================================================

enum _PaymentOption {
  cash('Наличные', null),
  mobile('Мобильный платёж', null),
  bank('Оплата по реквизитам банка', null),
  klever('Рассрочка по карте Клевер', 'Беспроцентная');

  final String label;
  final String? subtitle;
  const _PaymentOption(this.label, this.subtitle);
}

// =============================================================================
// Radio tile
// =============================================================================

class _RadioTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RadioTile({
    required this.label,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.seed : AppColors.textTertiary,
                  width: selected ? 6 : 1.5,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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
}
