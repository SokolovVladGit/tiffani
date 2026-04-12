/// Canonical payment options for checkout.
///
/// Each option maps to [code] for the backend and
/// [legacyPaymentMethod] for backward-compatible snapshots.
enum PaymentOption {
  cash(
    label: 'Наличные',
    subtitle: null,
    code: 'cash',
    legacyPaymentMethod: 'Наличные',
  ),
  mobilePayment(
    label: 'Мобильный платёж',
    subtitle: null,
    code: 'mobile_payment',
    legacyPaymentMethod: 'Мобильный платёж',
  ),
  bankTransfer(
    label: 'Оплата по реквизитам банка',
    subtitle: null,
    code: 'bank_transfer',
    legacyPaymentMethod: 'Оплата по реквизитам банка',
  ),
  cleverInstallment(
    label: 'Рассрочка по карте Клевер',
    subtitle: 'Беспроцентная',
    code: 'clever_installment',
    legacyPaymentMethod: 'Беспроцентная рассрочка по карте Клевер',
  );

  final String label;
  final String? subtitle;
  final String code;
  final String legacyPaymentMethod;

  const PaymentOption({
    required this.label,
    required this.subtitle,
    required this.code,
    required this.legacyPaymentMethod,
  });
}
