import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/logger_service.dart';
import '../../domain/entities/order_summary_entity.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/account_repository.dart';

/// Custom scheme for Supabase auth email redirects.
/// Must match the scheme registered in AndroidManifest.xml and Info.plist,
/// and be allow-listed in Supabase dashboard → Auth → URL Configuration.
const _authCallbackUrl = 'io.supabase.tiffani://auth-callback';

class AccountRepositoryImpl implements AccountRepository {
  final SupabaseClient _client;
  final LoggerService _logger;

  const AccountRepositoryImpl(this._client, this._logger);

  @override
  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  bool get isAuthenticated => _client.auth.currentUser != null;

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    _logger.d('signUp: $email');
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: _authCallbackUrl,
    );
    if (response.user == null) {
      throw Exception('Не удалось создать аккаунт');
    }
    try {
      await _client.from('profiles').upsert({
        'id': response.user!.id,
      });
    } catch (e) {
      _logger.w('Profile seed after signup failed: $e');
    }
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _logger.d('signIn: $email');
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user == null) {
      throw Exception('Неверный email или пароль');
    }
  }

  @override
  Future<void> signOut() async {
    _logger.d('signOut');
    await _client.auth.signOut();
  }

  @override
  Future<ProfileEntity?> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (row == null) return ProfileEntity(id: user.id);

      return ProfileEntity(
        id: row['id'] as String,
        name: row['name'] as String?,
        phone: row['phone'] as String?,
        loyaltyCard: row['loyalty_card'] as String?,
      );
    } catch (e) {
      _logger.w('getProfile failed: $e');
      return ProfileEntity(id: user.id);
    }
  }

  @override
  Future<void> upsertProfile(ProfileEntity profile) async {
    _logger.d('upsertProfile: ${profile.id}');
    try {
      await _client.from('profiles').upsert(
        {
          'id': profile.id,
          'name': profile.name,
          'phone': profile.phone,
          'loyalty_card': profile.loyaltyCard,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'id',
      );
    } catch (e, st) {
      _logger.e('upsertProfile failed: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<List<OrderSummaryEntity>> getOrderHistory() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final rows = await _client
          .from('order_requests')
          .select('id, created_at, total_items, total_quantity, total_price, status')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      return (rows as List).map((r) {
        return OrderSummaryEntity(
          id: r['id'] as String,
          createdAt: DateTime.parse(r['created_at'] as String),
          totalItems: (r['total_items'] as num?)?.toInt() ?? 0,
          totalQuantity: (r['total_quantity'] as num?)?.toInt() ?? 0,
          totalPrice: (r['total_price'] as num?)?.toDouble() ?? 0,
          status: (r['status'] as String?) ?? 'new',
        );
      }).toList();
    } catch (e) {
      _logger.w('getOrderHistory failed: $e');
      return [];
    }
  }
}
