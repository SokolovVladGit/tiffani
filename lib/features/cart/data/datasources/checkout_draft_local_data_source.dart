import '../../domain/entities/checkout_draft_entity.dart';

/// Low-level persistence contract for a single checkout contact snapshot
/// keyed by [StorageKeys.checkoutDraftV1]. See
/// [CheckoutDraftLocalDataSourceImpl] for the concrete implementation.
abstract interface class CheckoutDraftLocalDataSource {
  Future<CheckoutDraftEntity?> load();
  Future<void> save(CheckoutDraftEntity draft);
  Future<void> clear();
}
