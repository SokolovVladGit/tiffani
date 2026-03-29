import '../../../catalog/domain/entities/catalog_item_entity.dart';
import 'cart_item_entity.dart';

CartItemEntity cartItemFromCatalog(CatalogItemEntity catalog) {
  return CartItemEntity(
    id: catalog.id,
    productId: catalog.productId,
    title: catalog.title,
    quantity: 1,
    brand: catalog.brand,
    imageUrl: catalog.imageUrl,
    price: catalog.price,
    oldPrice: catalog.oldPrice,
    edition: catalog.edition,
    modification: catalog.modification,
  );
}
