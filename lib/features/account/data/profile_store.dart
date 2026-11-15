import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/profile_entity.dart';

/// Read/insert access to `public.profiles`. Inserts only the id.
abstract class ProfilesApi {
  Future<Map<String, dynamic>?> findById(String id);
  Future<void> insertId(String id);
}

class SupabaseProfilesApi implements ProfilesApi {
  final SupabaseClient _client;

  const SupabaseProfilesApi(this._client);

  @override
  Future<Map<String, dynamic>?> findById(String id) {
    return _client.from('profiles').select().eq('id', id).maybeSingle();
  }

  @override
  Future<void> insertId(String id) {
    return _client.from('profiles').insert({'id': id});
  }
}

class ProfileLoad {
  final ProfileEntity profile;

  /// Set when the insert failed for a reason other than "row already exists".
  /// The in-memory profile is still returned so Auth can succeed.
  final Object? seedError;

  const ProfileLoad({required this.profile, this.seedError});
}

bool isUniqueViolation(Object error) {
  if (error is PostgrestException && error.code == '23505') return true;
  return error.toString().contains('23505');
}

/// Creates the caller's profile row once. Never writes name, phone, or
/// loyalty fields, so a retry cannot wipe data saved at checkout.
class ProfileStore {
  final ProfilesApi _api;

  const ProfileStore(this._api);

  Future<ProfileLoad> loadOrCreate(String userId) async {
    final existing = await _api.findById(userId);
    if (existing != null) {
      return ProfileLoad(profile: _map(existing));
    }

    Object? seedError;
    try {
      await _api.insertId(userId);
    } catch (e) {
      if (!isUniqueViolation(e)) seedError = e;
    }

    final created = await _api.findById(userId);
    if (created != null) {
      return ProfileLoad(profile: _map(created), seedError: seedError);
    }
    return ProfileLoad(
      profile: ProfileEntity(id: userId),
      seedError: seedError,
    );
  }

  ProfileEntity _map(Map<String, dynamic> row) {
    return ProfileEntity(
      id: row['id'] as String,
      name: row['name'] as String?,
      phone: row['phone'] as String?,
      loyaltyCard: row['loyalty_card'] as String?,
    );
  }
}
