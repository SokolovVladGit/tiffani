/// Canonical fulfillment options for checkout.
///
/// Each option maps to a set of backend fields:
/// [fulfillmentType], [methodCode], [zoneCode], [fee], and
/// a [legacyDeliveryMethod] for backward-compatible snapshots.
enum FulfillmentOption {
  pickupStore(
    label: 'Самовывоз из магазина',
    subtitle: 'Бесплатно',
    fulfillmentType: 'pickup',
    methodCode: 'pickup_store',
    zoneCode: null,
    fee: 0,
    legacyDeliveryMethod: 'Самовывоз из магазина',
  ),
  courierTiraspol(
    label: 'Доставка курьером по Тирасполю',
    subtitle: '50 ₽',
    fulfillmentType: 'delivery',
    methodCode: 'courier_tiraspol',
    zoneCode: 'tiraspol',
    fee: 50,
    legacyDeliveryMethod: 'Доставка курьером по Тирасполю',
  ),
  courierBender(
    label: 'Доставка курьером по Бендерам',
    subtitle: '40 ₽',
    fulfillmentType: 'delivery',
    methodCode: 'courier_bender',
    zoneCode: 'bender',
    fee: 40,
    legacyDeliveryMethod: 'Доставка курьером по Бендерам',
  ),
  expressPost(
    label: 'Доставка экспресс-почтой',
    subtitle: '40 ₽',
    fulfillmentType: 'delivery',
    methodCode: 'express_post',
    zoneCode: 'express',
    fee: 40,
    legacyDeliveryMethod: 'Доставка экспресс-почтой',
  ),
  moldovaPost(
    label: 'Доставка почтой Молдовы',
    subtitle: '30 ₽',
    fulfillmentType: 'delivery',
    methodCode: 'moldova_post',
    zoneCode: 'moldova',
    fee: 30,
    legacyDeliveryMethod: 'Доставка почтой Молдовы',
  );

  final String label;
  final String subtitle;
  final String fulfillmentType;
  final String methodCode;
  final String? zoneCode;
  final double fee;
  final String legacyDeliveryMethod;

  const FulfillmentOption({
    required this.label,
    required this.subtitle,
    required this.fulfillmentType,
    required this.methodCode,
    required this.zoneCode,
    required this.fee,
    required this.legacyDeliveryMethod,
  });

  bool get isPickup => fulfillmentType == 'pickup';
  bool get isDelivery => fulfillmentType == 'delivery';
}
