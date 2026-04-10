class OrderSummaryEntity {
  final String id;
  final DateTime createdAt;
  final int totalItems;
  final int totalQuantity;
  final double totalPrice;
  final String status;

  const OrderSummaryEntity({
    required this.id,
    required this.createdAt,
    required this.totalItems,
    required this.totalQuantity,
    required this.totalPrice,
    required this.status,
  });
}
