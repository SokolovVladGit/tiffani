import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/logger_service.dart';
import '../../domain/checkout_phone_sync.dart';
import '../../domain/entities/order_summary_entity.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/sign_up_outcome.dart';
import '../profile_store.dart';

/// Custom scheme for Supabase auth email redirects.
/// Must match the scheme registered in AndroidManifest.xml and Info.plist,
/// and be allow-listed in Supabase dashboard → Auth → URL Configuration.
const _authCallbackUrl = 'io.supabase.tiffani://auth-callback';

class AccountRepositoryImpl implements AccountRepository {
  final SupabaseClient _client;
  final LoggerService _logger;
  final ProfileStore _profiles;

  AccountRepositoryImpl(this._client, this._logger, {ProfileStore? profiles})
    : _profiles = profiles ?? ProfileStore(SupabaseProfilesApi(_client));

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  bool get isAuthenticated => _client.auth.currentUser != null;

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    _logger.d('signUp: $email');
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: _authCallbackUrl,
    );
    final user = response.user;
    final classification = classifySignUp(
      hasUser: user != null,
      hasSession: response.session != null,
      identitiesEmpty: user?.identities?.isEmpty ?? false,
    );
    if (classification == SignUpClassification.rejected) {
      throw Exception(
        user == null ? 'Не удалось создать аккаунт' : 'already been registered',
      );
    }
    if (classification == SignUpClassification.confirmationRequired) {
      return SignUpOutcome.confirmationRequired;
    }

    // Session is present. Seed is best-effort and must not fail Auth.
    if (_client.auth.currentUser?.id == user!.id) {
      try {
        final loaded = await _profiles.loadOrCreate(user.id);
        if (loaded.seedError != null) {
          _logger.w('Profile seed after signup failed: ${loaded.seedError}');
        }
      } catch (e) {
        _logger.w('Profile seed after signup failed: $e');
      }
    }
    return SignUpOutcome.session;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
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
      final loaded = await _profiles.loadOrCreate(user.id);
      if (loaded.seedError != null) {
        _logger.w('Profile seed failed: ${loaded.seedError}');
      }
      return loaded.profile;
    } catch (e) {
      _logger.w('getProfile failed: $e');
      return ProfileEntity(id: user.id);
    }
  }

  @override
  Future<ProfileEntity?> saveCheckoutPhone(String phone) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final row = await _client
          .from('profiles')
          .select('id, name, phone, loyalty_card')
          .eq('id', user.id)
          .maybeSingle();
      final existing = row == null
          ? null
          : ProfileEntity(
              id: row['id'] as String,
              name: row['name'] as String?,
              phone: row['phone'] as String?,
              loyaltyCard: row['loyalty_card'] as String?,
            );
      if (existing != null && existing.id != user.id) {
        _logger.w('checkout phone sync skipped');
        return null;
      }
      final next = profileAfterCheckoutPhone(
        userId: user.id,
        existing: existing,
        submittedPhone: phone,
      );
      if (next == null) {
        return existing ?? ProfileEntity(id: user.id);
      }
      final nextPhone = next.phone;
      if (nextPhone == null || nextPhone.isEmpty) return next;
      final updatedAt = DateTime.now().toIso8601String();
      if (existing == null) {
        try {
          await _client
              .from('profiles')
              .insert(
                checkoutPhoneInsertPayload(
                  userId: user.id,
                  phone: nextPhone,
                  updatedAt: updatedAt,
                ),
              );
        } catch (e) {
          if (!isUniqueViolation(e)) rethrow;
          await _client
              .from('profiles')
              .update(
                checkoutPhoneUpdatePayload(
                  phone: nextPhone,
                  updatedAt: updatedAt,
                ),
              )
              .eq('id', user.id);
        }
      } else {
        await _client
            .from('profiles')
            .update(
              checkoutPhoneUpdatePayload(
                phone: nextPhone,
                updatedAt: updatedAt,
              ),
            )
            .eq('id', user.id);
      }
      return next;
    } catch (e) {
      _logger.w('checkout phone sync failed');
      rethrow;
    }
  }

  @override
  Future<void> upsertProfile(ProfileEntity profile) async {
    _logger.d('upsertProfile: ${profile.id}');
    try {
      await _client.from('profiles').upsert({
        'id': profile.id,
        'name': profile.name,
        'phone': profile.phone,
        'loyalty_card': profile.loyaltyCard,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
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
          .select(
            'id, created_at, total_items, total_quantity, total_price, status',
          )
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
