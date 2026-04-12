import 'fulfillment_option.dart';
import 'payment_option.dart';
import 'pickup_store.dart';

class RequestFormEntity {
  final String name;
  final String phone;
  final String? email;
  final String? promoCode;
  final String? loyaltyCard;
  final String? comment;
  final bool consentGiven;

  final FulfillmentOption fulfillment;
  final PickupStore? pickupStore;
  final String? deliveryAddress;
  final PaymentOption payment;

  const RequestFormEntity({
    required this.name,
    required this.phone,
    this.email,
    this.promoCode,
    this.loyaltyCard,
    this.comment,
    this.consentGiven = false,
    required this.fulfillment,
    this.pickupStore,
    this.deliveryAddress,
    required this.payment,
  });
}
