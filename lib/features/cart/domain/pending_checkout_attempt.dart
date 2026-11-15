class PendingCheckoutAttempt {
  final String requestId;
  final String digest;
  final Map<String, dynamic> customer;
  final List<Map<String, dynamic>> items;

  /// Null is a guest attempt. An authenticated attempt stores auth user id.
  final String? ownerId;

  const PendingCheckoutAttempt({
    required this.requestId,
    required this.digest,
    required this.customer,
    required this.items,
    this.ownerId,
  });
}

abstract interface class PendingCheckoutStore {
  Future<PendingCheckoutAttempt?> load(String? ownerId);
  Future<void> save(PendingCheckoutAttempt attempt);
  Future<void> clear(String? ownerId);
}
