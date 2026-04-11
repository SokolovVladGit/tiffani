/// Maps checkout form fields to the `p_customer` parameter of `submit_order_v2`.
class RequestSubmissionPayloadDto {
  final String name;
  final String phone;
  final String? email;
  final String? deliveryMethod;
  final String? deliveryAddress;
  final String? paymentMethod;
  final String? promoCode;
  final String? loyaltyCard;
  final String? comment;
  final bool consentGiven;
  final String? userId;

  const RequestSubmissionPayloadDto({
    required this.name,
    required this.phone,
    this.email,
    this.deliveryMethod,
    this.deliveryAddress,
    this.paymentMethod,
    this.promoCode,
    this.loyaltyCard,
    this.comment,
    required this.consentGiven,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      if (email != null) 'email': email,
      if (deliveryMethod != null) 'delivery_method': deliveryMethod,
      if (deliveryAddress != null) 'delivery_address': deliveryAddress,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (promoCode != null) 'promo_code': promoCode,
      if (loyaltyCard != null) 'loyalty_card': loyaltyCard,
      if (comment != null) 'comment': comment,
      'consent_given': consentGiven,
      if (userId != null) 'user_id': userId,
    };
  }
}
