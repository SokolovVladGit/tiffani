import '../entities/checkout_draft_entity.dart';

/// Local-only store for the customer's last successful checkout contact
/// snapshot. Used to prefill subsequent checkout sessions.
///
/// Implementations must never throw on malformed persisted data — they
/// should recover by returning `null` from [load]. Callers treat `null`
/// and a fully-empty entity as equivalent "no draft" signals.
abstract interface class CheckoutDraftRepository {
  /// Returns the stored draft, or `null` when none is persisted or the
  /// persisted payload is unreadable.
  Future<CheckoutDraftEntity?> load();

  /// Saves [draft] locally after normalization. When the normalized draft
  /// is empty, persisted storage is cleared instead of writing a blank
  /// record.
  Future<void> save(CheckoutDraftEntity draft);

  /// Removes any persisted draft. Safe to call when none is stored.
  Future<void> clear();
}
