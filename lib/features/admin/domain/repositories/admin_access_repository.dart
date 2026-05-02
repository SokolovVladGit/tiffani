/// Lightweight access-control probe for the Flutter admin UI.
///
/// The truth source is RLS on Supabase. This is purely UX gating: showing
/// or hiding admin-oriented sections of the Account screen.
abstract interface class AdminAccessRepository {
  /// Calls `public.is_admin()` and returns the boolean result.
  /// Returns `false` when unauthenticated, when the RPC throws, or when
  /// the response payload cannot be coerced to a boolean.
  Future<bool> isAdmin();
}
