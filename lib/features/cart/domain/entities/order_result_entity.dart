/// Server response from `submit_order_v2`.
class OrderResultEntity {
  final String orderId;
  final int totalItems;
  final int totalQuantity;
  final double totalPrice;

  const OrderResultEntity({
    required this.orderId,
    required this.totalItems,
    required this.totalQuantity,
    required this.totalPrice,
  });
}
