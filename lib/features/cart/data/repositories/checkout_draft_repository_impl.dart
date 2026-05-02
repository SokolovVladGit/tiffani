import '../../domain/entities/checkout_draft_entity.dart';
import '../../domain/repositories/checkout_draft_repository.dart';
import '../datasources/checkout_draft_local_data_source.dart';

/// Thin local-only implementation. No remote calls — the checkout draft
/// is intentionally decoupled from the Supabase `profiles` row so a
/// successful checkout does not silently rewrite the user's profile.
class CheckoutDraftRepositoryImpl implements CheckoutDraftRepository {
  final CheckoutDraftLocalDataSource _local;

  const CheckoutDraftRepositoryImpl(this._local);

  @override
  Future<CheckoutDraftEntity?> load() => _local.load();

  @override
  Future<void> save(CheckoutDraftEntity draft) => _local.save(draft);

  @override
  Future<void> clear() => _local.clear();
}
