class RequestSubmissionPayloadDto {
  final String customerName;
  final String phone;
  final String? comment;
  final int totalItems;
  final int totalQuantity;
  final double totalPrice;
  final String status;
  final String source;
  final String? userId;

  const RequestSubmissionPayloadDto({
    required this.customerName,
    required this.phone,
    this.comment,
    required this.totalItems,
    required this.totalQuantity,
    required this.totalPrice,
    this.status = 'new',
    this.source = 'mobile_app',
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'customer_name': customerName,
      'phone': phone,
      'comment': comment,
      'total_items': totalItems,
      'total_quantity': totalQuantity,
      'total_price': totalPrice,
      'status': status,
      'source': source,
      if (userId != null) 'user_id': userId,
    };
  }
}
