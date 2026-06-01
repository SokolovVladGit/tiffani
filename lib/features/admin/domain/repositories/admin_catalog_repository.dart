import '../entities/admin_catalog_product.dart';
import '../entities/admin_native_product_form.dart';

abstract interface class AdminCatalogRepository {
  Future<List<AdminCatalogProduct>> listProducts({String search});

  Future<AdminCatalogVisibilityResult> setVisibility({
    required String productId,
    required bool visible,
  });

  Future<AdminNativeProductForm> getNativeProductDetail(String productId);

  Future<AdminNativeProductUpsertResult> upsertNativeProduct(
    AdminNativeProductForm form,
  );
}
