import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/admin/domain/entities/admin_catalog_product.dart';
import 'package:tiffani/features/admin/domain/entities/admin_native_product_form.dart';
import 'package:tiffani/features/admin/domain/repositories/admin_catalog_repository.dart';
import 'package:tiffani/features/admin/presentation/cubit/admin_catalog_cubit.dart';

class _FakeAdminCatalogRepository implements AdminCatalogRepository {
  _FakeAdminCatalogRepository({
    this.products = const [],
    this.detail,
    this.detailError,
    this.upsertError,
  });

  List<AdminCatalogProduct> products;
  AdminNativeProductForm? detail;
  Object? detailError;
  Object? upsertError;
  int upsertCalls = 0;
  int refreshCalls = 0;
  AdminNativeProductForm? lastUpsertForm;

  @override
  Future<List<AdminCatalogProduct>> listProducts({String search = ''}) async {
    refreshCalls++;
    return products;
  }

  @override
  Future<AdminCatalogVisibilityResult> setVisibility({
    required String productId,
    required bool visible,
  }) async {
    return AdminCatalogVisibilityResult(
      productId: productId,
      appIsVisible: visible,
      effectiveIsActive: visible,
    );
  }

  @override
  Future<AdminNativeProductForm> getNativeProductDetail(String productId) async {
    if (detailError != null) throw detailError!;
    return detail!;
  }

  @override
  Future<AdminNativeProductUpsertResult> upsertNativeProduct(
    AdminNativeProductForm form,
  ) async {
    upsertCalls++;
    lastUpsertForm = form;
    if (upsertError != null) throw upsertError!;
    final result = AdminNativeProductUpsertResult(
      productId: form.productId ?? 'new-product-id',
      variantId: 'admin_testvariantid000000000000000001',
      title: form.title,
      price: form.price ?? 0,
      quantity: form.quantity,
      appIsVisible: form.appIsVisible,
      isActive: true,
      effectiveIsActive: form.appIsVisible,
      photo: form.imageUrls.isNotEmpty ? form.imageUrls.first : null,
    );
    final row = AdminCatalogProduct.fromUpsertResult(result);
    products = [
      row,
      ...products.where((p) => p.id != row.id),
    ];
    return result;
  }
}

void main() {
  group('AdminCatalogCubit', () {
    test('saveNativeProduct success upserts and refreshes list', () async {
      final repo = _FakeAdminCatalogRepository(
        products: [
          const AdminCatalogProduct(
            id: 'existing',
            title: 'Old',
            isActive: true,
            appIsVisible: true,
          ),
        ],
      );
      final cubit = AdminCatalogCubit(repo);

      final ok = await cubit.saveNativeProduct(
        const AdminNativeProductForm(
          title: 'Created',
          price: 10,
          quantity: 1,
        ),
      );

      expect(ok, isTrue);
      expect(repo.upsertCalls, 1);
      expect(repo.refreshCalls, 1);
      expect(cubit.state.isSavingNativeProduct, isFalse);
      expect(cubit.state.products.first.title, 'Created');
    });

    test('saveNativeProduct failure keeps error and returns false', () async {
      final repo = _FakeAdminCatalogRepository(
        upsertError: Exception('network'),
      );
      final cubit = AdminCatalogCubit(repo);

      final ok = await cubit.saveNativeProduct(
        const AdminNativeProductForm(
          title: 'Fail',
          price: 1,
          quantity: 0,
        ),
      );

      expect(ok, isFalse);
      expect(cubit.state.errorMessage, isNotNull);
      expect(cubit.state.isSavingNativeProduct, isFalse);
    });

    test('setVisibility updates only matching product', () async {
      final repo = _FakeAdminCatalogRepository(
        products: [
          const AdminCatalogProduct(
            id: 'a',
            title: 'A',
            isActive: true,
            appIsVisible: true,
          ),
          const AdminCatalogProduct(
            id: 'b',
            title: 'B',
            isActive: true,
            appIsVisible: true,
          ),
        ],
      );
      final cubit = AdminCatalogCubit(repo);
      await cubit.loadInitial();

      await cubit.setVisibility('a', false);

      expect(cubit.state.products[0].appIsVisible, isFalse);
      expect(cubit.state.products[1].appIsVisible, isTrue);
    });

    test('loadNativeProductForEdit sets loading id then clears', () async {
      final repo = _FakeAdminCatalogRepository(
        detail: const AdminNativeProductForm(
          productId: 'native-1',
          title: 'Native',
          price: 5,
          quantity: 0,
        ),
      );
      final cubit = AdminCatalogCubit(repo);

      final form = await cubit.loadNativeProductForEdit('native-1');

      expect(form.title, 'Native');
      expect(cubit.state.loadingEditProductId, isNull);
    });

    test('loadNativeProductForEdit propagates Tilda error', () async {
      final repo = _FakeAdminCatalogRepository(
        detailError: FormatException('Tilda products cannot be edited'),
      );
      final cubit = AdminCatalogCubit(repo);

      await expectLater(
        cubit.loadNativeProductForEdit('tilda-1'),
        throwsA(isA<FormatException>()),
      );
      expect(cubit.state.loadingEditProductId, isNull);
    });
  });
}
