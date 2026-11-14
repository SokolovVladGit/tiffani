import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/catalog/data/dto/product_image_dto.dart';
import 'package:tiffani/features/catalog/data/mappers/product_image_mapper.dart';
import 'package:tiffani/features/catalog/domain/entities/catalog_item_entity.dart';
import 'package:tiffani/features/catalog/domain/entities/catalog_page_result.dart';
import 'package:tiffani/features/catalog/domain/entities/catalog_sort_option.dart';
import 'package:tiffani/features/catalog/domain/entities/product_image_entity.dart';
import 'package:tiffani/features/catalog/domain/gallery/catalog_gallery.dart';
import 'package:tiffani/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:tiffani/features/catalog/domain/usecases/get_product_images_use_case.dart';
import 'package:tiffani/features/catalog/presentation/cubit/product_images_cubit.dart';
import 'package:tiffani/features/catalog/presentation/cubit/product_images_state.dart';
import 'package:tiffani/features/catalog/presentation/widgets/catalog_gallery_view.dart';

ProductImageEntity image({
  required String url,
  required int position,
  String? source,
}) {
  return ProductImageDto.fromMap({
    'id': 'img-$position',
    'product_id': 'product-1',
    'url': url,
    'position': position,
    'source': source,
  }).toEntity();
}

void main() {
  const variantPhoto =
      'https://static.tildacdn.com/stor3437-6134-4230-a135-306662326366/shade-2.jpg';

  test('single YML image keeps the variant photo and has no strip', () {
    final urls = composeCatalogGallery(
      variantPhotoUrl: variantPhoto,
      images: [
        image(url: variantPhoto, position: 0, source: 'yml_variant'),
      ],
      isTildaProduct: true,
    );
    expect(urls, [variantPhoto]);
    expect(urls.length > 1, isFalse);
  });

  test('16 variant photos are not angles of the opened shade', () {
    final images = List.generate(16, (index) {
      return image(
        url: 'https://static.tildacdn.com/stor3437-6134-4230-a135-306662326366/shade-$index.jpg',
        position: index,
        source: 'yml_variant',
      );
    });
    final urls = composeCatalogGallery(
      variantPhotoUrl: variantPhoto,
      images: images,
      isTildaProduct: true,
    );
    expect(urls, [variantPhoto]);
  });

  test('Celimax shows the primary photo plus two supplementary images', () {
    const primary =
        'https://static.tildacdn.com/stor3162-3938-4664-b330-336236643437/52670934.jpg';
    final urls = composeCatalogGallery(
      variantPhotoUrl: primary,
      images: [
        image(url: primary, position: 0, source: 'yml_variant'),
        image(
          url: 'https://static.tildacdn.one/stor3162-3938-4664-b330-336236643437/52670934.jpg',
          position: 1,
          source: 'tilda_gallery',
        ),
        image(
          url: 'https://static.tildacdn.one/extra/84530445.jpg',
          position: 2,
          source: 'tilda_gallery',
        ),
        image(
          url: 'https://static.tildacdn.one/extra/39405614.webp',
          position: 3,
          source: 'tilda_gallery',
        ),
      ],
      isTildaProduct: true,
    );
    expect(urls, [
      primary,
      'https://static.tildacdn.one/extra/84530445.jpg',
      'https://static.tildacdn.one/extra/39405614.webp',
    ]);
  });

  test('observed Erborian gallery is the variant photo plus two angles', () {
    const primary =
        'https://static.tildacdn.com/stor3031-6534-4332-a331-366138303634/dc00819f51e0b7e83aec82ff9301564d.png';
    const angleA =
        'https://static.tildacdn.one/stor6162-6532-4065-b765-306635356438/60941640.png';
    const angleB =
        'https://static.tildacdn.one/stor6235-6538-4761-a633-313636353133/97436353.png';
    final urls = composeCatalogGallery(
      variantPhotoUrl: primary,
      images: [
        image(url: primary, position: 0, source: 'yml_variant'),
        image(
          url: primary.replaceAll('.com', '.one'),
          position: 1,
          source: 'tilda_gallery',
        ),
        image(url: angleA, position: 2, source: 'tilda_gallery'),
        image(url: angleB, position: 3, source: 'tilda_gallery'),
        image(
          url: 'https://static.tildacdn.com/other-shade/nope.jpg',
          position: 4,
          source: 'yml_variant',
        ),
      ],
      isTildaProduct: true,
    );
    expect(urls, [primary, angleA, angleB]);
  });

  test('observed Celimax gallery keeps the primary ahead of two extras', () {
    const primary =
        'https://static.tildacdn.com/stor3162-3938-4664-b330-336236643437/52670934.jpg';
    const angleA =
        'https://static.tildacdn.one/stor6164-6562-4763-b537-386465666263/84530445.jpg';
    const angleB =
        'https://static.tildacdn.one/stor6231-6364-4339-b262-336166616666/39405614.webp';
    final urls = composeCatalogGallery(
      variantPhotoUrl: primary,
      images: [
        image(url: primary, position: 0, source: 'yml_variant'),
        image(url: angleA, position: 1, source: 'tilda_gallery'),
        image(url: angleB, position: 2, source: 'tilda_gallery'),
      ],
      isTildaProduct: true,
    );
    expect(urls, [primary, angleA, angleB]);
  });

  test('native NULL sources keep every stored image in position order', () {
    final urls = composeCatalogGallery(
      variantPhotoUrl: 'https://cdn.example/ignored.jpg',
      images: [
        image(url: 'https://cdn.example/b.jpg', position: 1),
        image(url: 'https://cdn.example/a.jpg', position: 0),
        image(url: 'https://cdn.example/a.jpg', position: 2),
      ],
      isTildaProduct: false,
    );
    expect(urls, [
      'https://cdn.example/a.jpg',
      'https://cdn.example/b.jpg',
    ]);
  });

  test('basename collisions in different directories stay distinct', () {
    expect(
      catalogImageIdentity(
        'https://static.tildacdn.com/dir-a/photo.jpg',
      ),
      isNot(catalogImageIdentity(
        'https://static.tildacdn.one/dir-b/photo.jpg',
      )),
    );
  });

  testWidgets('one display image hides the thumbnail strip', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CatalogGalleryThumbnails(
          urls: ['https://cdn.example/only.jpg'],
          selectedIndex: 0,
          onSelected: _noop,
        ),
      ),
    );
    expect(find.byKey(catalogGalleryStripKey), findsNothing);
  });

  testWidgets('three display images show three thumbnails', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogGalleryThumbnails(
          urls: const [
            'https://cdn.example/a.jpg',
            'https://cdn.example/b.jpg',
            'https://cdn.example/c.jpg',
          ],
          selectedIndex: selected,
          onSelected: (index) => selected = index,
        ),
      ),
    );
    expect(find.byKey(catalogGalleryStripKey), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-thumb-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-thumb-2')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('catalog-thumb-2')));
    expect(selected, 2);
  });

  testWidgets('Erborian supplementary strip switches the selected angle', (
    tester,
  ) async {
    const urls = [
      'https://static.tildacdn.com/stor3031-6534-4332-a331-366138303634/dc00819f51e0b7e83aec82ff9301564d.png',
      'https://static.tildacdn.one/stor6162-6532-4065-b765-306635356438/60941640.png',
      'https://static.tildacdn.one/stor6235-6538-4761-a633-313636353133/97436353.png',
    ];
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogGalleryThumbnails(
          urls: urls,
          selectedIndex: selected,
          onSelected: (index) => selected = index,
        ),
      ),
    );
    expect(find.byKey(catalogGalleryStripKey), findsOneWidget);
    expect(
      tester.widget<ListView>(find.byType(ListView)).scrollDirection,
      Axis.horizontal,
    );
    expect(find.byKey(const ValueKey('catalog-thumb-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-thumb-2')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('catalog-thumb-1')));
    expect(selected, 1);
  });

  testWidgets('missing image URL shows the fallback placeholder', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CatalogGalleryMainImage(url: null, height: 120),
      ),
    );
    expect(find.byKey(catalogGalleryFallbackKey), findsOneWidget);
  });

  test('image load failure leaves the gallery on the variant photo', () async {
    final cubit = ProductImagesCubit(
      GetProductImagesUseCase(_FailingImages()),
    );
    await cubit.load('product-1');
    expect(cubit.state.status, ProductImagesStatus.failure);
    expect(cubit.state.images, isEmpty);
    final urls = composeCatalogGallery(
      variantPhotoUrl: variantPhoto,
      images: cubit.state.images,
      isTildaProduct: true,
    );
    expect(urls, [variantPhoto]);
    await cubit.close();
  });
}

void _noop(int _) {}

class _FailingImages implements CatalogRepository {
  @override
  Future<List<ProductImageEntity>> getProductImages(String productId) async {
    throw StateError('offline');
  }

  @override
  Future<CatalogPageResult> getCatalogPage({
    required int from,
    required int to,
    String? brand,
    String? category,
    String? mark,
    CatalogSortOption sortOption = CatalogSortOption.defaultOrder,
    Map<String, Set<String>>? attributeFilters,
    bool saleOnly = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<CatalogPageResult> searchCatalog({
    required String query,
    int from = 0,
    int to = 29,
    String? brand,
    String? category,
    String? mark,
    CatalogSortOption sortOption = CatalogSortOption.defaultOrder,
    Map<String, Set<String>>? attributeFilters,
    bool saleOnly = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<CatalogItemEntity?> getCatalogItemByVariantId(String variantId) =>
      throw UnimplementedError();

  @override
  Future<CatalogItemEntity?> getCatalogItemByProductId(String productId) =>
      throw UnimplementedError();

  @override
  Future<List<CatalogItemEntity>> getCatalogItemsByVariantIds(List<String> ids) =>
      throw UnimplementedError();

  @override
  Future<List<String>> getAvailableBrands() => throw UnimplementedError();

  @override
  Future<List<String>> getAvailableCategories() => throw UnimplementedError();

  @override
  Future<List<String>> getAvailableMarks() => throw UnimplementedError();

  @override
  Future<List<CatalogItemEntity>> getSimilarProducts({
    required String excludeId,
    String? brand,
    String? category,
    int limit = 10,
  }) =>
      throw UnimplementedError();
}
