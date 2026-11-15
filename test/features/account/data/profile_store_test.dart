import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiffani/features/account/data/profile_store.dart';
import 'package:tiffani/features/account/domain/sign_up_outcome.dart';

class _FakeProfilesApi implements ProfilesApi {
  final Map<String, Map<String, dynamic>> rows = {};
  Object? insertError;
  int inserts = 0;

  @override
  Future<Map<String, dynamic>?> findById(String id) async {
    final row = rows[id];
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  @override
  Future<void> insertId(String id) async {
    inserts++;
    if (insertError != null) {
      final error = insertError!;
      if (error is PostgrestException && error.code == '23505') {
        rows.putIfAbsent(id, () => {'id': id, 'name': 'Уже есть'});
      }
      throw error;
    }
    rows[id] = {'id': id};
  }
}

void main() {
  test('classifySignUp separates session, confirmation and rejection', () {
    expect(
      classifySignUp(hasUser: true, hasSession: true, identitiesEmpty: false),
      SignUpClassification.session,
    );
    expect(
      classifySignUp(hasUser: true, hasSession: false, identitiesEmpty: false),
      SignUpClassification.confirmationRequired,
    );
    expect(
      classifySignUp(hasUser: true, hasSession: false, identitiesEmpty: true),
      SignUpClassification.rejected,
    );
    expect(
      classifySignUp(hasUser: false, hasSession: false, identitiesEmpty: false),
      SignUpClassification.rejected,
    );
    expect(
      classifySignUp(hasUser: true, hasSession: true, identitiesEmpty: true),
      SignUpClassification.session,
    );
  });

  test(
    'creates a profile id for an authenticated user without extra fields',
    () async {
      final api = _FakeProfilesApi();
      final store = ProfileStore(api);

      final loaded = await store.loadOrCreate('user-1');

      expect(loaded.seedError, isNull);
      expect(loaded.profile.id, 'user-1');
      expect(loaded.profile.name, isNull);
      expect(loaded.profile.phone, isNull);
      expect(api.inserts, 1);
      expect(api.rows['user-1']!.keys, ['id']);
    },
  );

  test('missing profile is created once and an existing row is kept', () async {
    final api = _FakeProfilesApi();
    final store = ProfileStore(api);

    await store.loadOrCreate('user-1');
    api.rows['user-1'] = {
      'id': 'user-1',
      'name': 'Анна',
      'phone': '+373000000',
      'loyalty_card': '42',
    };

    final again = await store.loadOrCreate('user-1');

    expect(api.inserts, 1);
    expect(again.profile.name, 'Анна');
    expect(again.profile.phone, '+373000000');
    expect(again.profile.loyaltyCard, '42');
    expect(api.rows['user-1']!['name'], 'Анна');
  });

  test('unique violation keeps the stored row', () async {
    final api = _FakeProfilesApi()
      ..insertError = const PostgrestException(
        message: 'duplicate key',
        code: '23505',
      );
    final store = ProfileStore(api);

    final loaded = await store.loadOrCreate('user-1');

    expect(loaded.seedError, isNull);
    expect(loaded.profile.name, 'Уже есть');
  });

  test(
    'insert failure does not throw and does not invent saved fields',
    () async {
      final api = _FakeProfilesApi()
        ..insertError = const PostgrestException(
          message: 'permission denied',
          code: '42501',
        );
      final store = ProfileStore(api);

      final loaded = await store.loadOrCreate('user-1');

      expect(loaded.seedError, isNotNull);
      expect(loaded.profile.id, 'user-1');
      expect(loaded.profile.name, isNull);
      expect(loaded.profile.phone, isNull);
    },
  );
}
