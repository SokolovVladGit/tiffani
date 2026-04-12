/// Controlled list of pickup store locations for checkout.
///
/// IDs are stable slugs used as `pickup_store_id` in the order.
/// These will be reconciled with the `stores` table PK once that
/// schema is codified in a migration.
class PickupStore {
  final String id;
  final String label;

  const PickupStore({required this.id, required this.label});

  static const List<PickupStore> all = [
    PickupStore(
      id: 'store_central',
      label: 'Тирасполь, ул. 25 Октября 94',
    ),
    PickupStore(
      id: 'store_balka',
      label: 'Тирасполь, ул. Юности 18/1',
    ),
    PickupStore(
      id: 'store_bendery',
      label: 'Бендеры, ул. Ленина 15, ТЦ «Пассаж» бутик №14',
    ),
  ];
}
