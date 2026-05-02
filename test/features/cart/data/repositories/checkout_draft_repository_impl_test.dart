import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffani/core/constants/storage_keys.dart';
import 'package:tiffani/features/cart/data/datasources/checkout_draft_local_data_source_impl.dart';
import 'package:tiffani/features/cart/data/repositories/checkout_draft_repository_impl.dart';
import 'package:tiffani/features/cart/domain/entities/checkout_draft_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<CheckoutDraftRepositoryImpl> buildRepo() async {
    final prefs = await SharedPreferences.getInstance();
    final local = CheckoutDraftLocalDataSourceImpl(prefs);
    return CheckoutDraftRepositoryImpl(local);
  }

  group('CheckoutDraftRepositoryImpl', () {
    test('load returns null when no draft is stored', () async {
      final repo = await buildRepo();

      final loaded = await repo.load();

      expect(loaded, isNull);
    });

    test('save then load returns normalized values', () async {
      final repo = await buildRepo();

      await repo.save(const CheckoutDraftEntity(
        name: '  Анна  ',
        phone: '+37360000000',
        email: '   anna@example.com ',
        loyaltyCard: '42',
      ));

      final loaded = await repo.load();

      expect(loaded, isNotNull);
      expect(loaded!.name, 'Анна');
      expect(loaded.phone, '+37360000000');
      expect(loaded.email, 'anna@example.com');
      expect(loaded.loyaltyCard, '42');
      expect(loaded.updatedAt, isNotNull);
    });

    test('saving an empty draft clears storage and load returns null',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        StorageKeys.checkoutDraftV1: '{"name":"X"}',
      });
      final repo = await buildRepo();
      expect(await repo.load(), isNotNull);

      await repo.save(const CheckoutDraftEntity(
        name: '   ',
        phone: '',
        email: null,
        loyaltyCard: '  ',
      ));

      final loaded = await repo.load();
      expect(loaded, isNull);
    });

    test('clear removes a previously stored draft', () async {
      final repo = await buildRepo();
      await repo.save(const CheckoutDraftEntity(name: 'Анна'));
      expect(await repo.load(), isNotNull);

      await repo.clear();

      expect(await repo.load(), isNull);
    });

    test('corrupted JSON returns null and does not throw', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        StorageKeys.checkoutDraftV1: 'not-json',
      });
      final repo = await buildRepo();

      final loaded = await repo.load();

      expect(loaded, isNull);
    });

    test('non-object JSON returns null and does not throw', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        StorageKeys.checkoutDraftV1: '[1,2,3]',
      });
      final repo = await buildRepo();

      final loaded = await repo.load();

      expect(loaded, isNull);
    });

    test('stored JSON without any recognised fields is treated as empty',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        StorageKeys.checkoutDraftV1: '{"foo":"bar"}',
      });
      final repo = await buildRepo();

      final loaded = await repo.load();

      expect(loaded, isNull);
    });

    test('save does not persist promo_code key even if added to raw JSON',
        () async {
      final repo = await buildRepo();

      await repo.save(const CheckoutDraftEntity(name: 'Анна'));
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(StorageKeys.checkoutDraftV1);

      expect(raw, isNotNull);
      expect(raw!.contains('promo_code'), isFalse);
    });
  });
}
