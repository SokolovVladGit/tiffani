class RequestFormEntity {
  final String name;
  final String phone;
  final String? email;
  final String? promoCode;
  final String? loyaltyCard;
  final String? deliveryMethod;
  final String? address;
  final String? paymentMethod;
  final String? comment;
  final bool consentGiven;

  const RequestFormEntity({
    required this.name,
    required this.phone,
    this.email,
    this.promoCode,
    this.loyaltyCard,
    this.deliveryMethod,
    this.address,
    this.paymentMethod,
    this.comment,
    this.consentGiven = false,
  });
}
