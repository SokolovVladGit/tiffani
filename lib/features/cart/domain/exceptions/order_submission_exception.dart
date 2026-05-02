/// Thrown when `submit_order_v3` returns `ok=false` (user-correctable error).
///
/// Carries the canonical [code] from the backend plus a Russian [message]
/// already mapped for direct UI display. [requiresRequote] is true when the
/// caller should refresh the quote (currently only for
/// `quote_changed_or_discount_unavailable`).
class OrderSubmissionException implements Exception {
  final String code;
  final String message;
  final bool requiresRequote;
  final String? campaignId;

  const OrderSubmissionException({
    required this.code,
    required this.message,
    this.requiresRequote = false,
    this.campaignId,
  });

  @override
  String toString() => message;
}
