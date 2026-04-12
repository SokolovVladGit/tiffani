/// Maps checkout form fields to the `p_customer` parameter of `submit_order_v2`.
///
/// Sends both canonical fields and legacy readable fields for backward
/// compatibility with existing notification formatting and order history.
class RequestSubmissionPayloadDto {
  final String name;
  final String phone;
  final String? email;
  final String? promoCode;
  final String? loyaltyCard;
  final String? comment;
  final bool consentGiven;
  final String? userId;

  // Legacy readable fields (kept for Telegram / order history compatibility).
  final String? deliveryMethod;
  final String? deliveryAddress;
  final String? paymentMethod;

  // Canonical fulfillment fields.
  final String fulfillmentType;
  final String fulfillmentMethodCode;
  final double fulfillmentFee;
  final String? pickupStoreId;
  final String? deliveryZoneCode;

  // Canonical payment field.
  final String paymentMethodCode;

  const RequestSubmissionPayloadDto({
    required this.name,
    required this.phone,
    this.email,
    this.promoCode,
    this.loyaltyCard,
    this.comment,
    required this.consentGiven,
    this.userId,
    this.deliveryMethod,
    this.deliveryAddress,
    this.paymentMethod,
    required this.fulfillmentType,
    required this.fulfillmentMethodCode,
    required this.fulfillmentFee,
    this.pickupStoreId,
    this.deliveryZoneCode,
    required this.paymentMethodCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      if (email != null) 'email': email,
      if (promoCode != null) 'promo_code': promoCode,
      if (loyaltyCard != null) 'loyalty_card': loyaltyCard,
      if (comment != null) 'comment': comment,
      'consent_given': consentGiven,
      if (userId != null) 'user_id': userId,

      // Legacy readable fields.
      if (deliveryMethod != null) 'delivery_method': deliveryMethod,
      if (deliveryAddress != null) 'delivery_address': deliveryAddress,
      if (paymentMethod != null) 'payment_method': paymentMethod,

      // Canonical fulfillment fields.
      'fulfillment_type': fulfillmentType,
      'fulfillment_method_code': fulfillmentMethodCode,
      'fulfillment_fee': fulfillmentFee,
      if (pickupStoreId != null) 'pickup_store_id': pickupStoreId,
      if (deliveryZoneCode != null) 'delivery_zone_code': deliveryZoneCode,

      // Canonical payment field.
      'payment_method_code': paymentMethodCode,
    };
  }
}
