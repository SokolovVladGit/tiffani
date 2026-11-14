import '../entities/product_image_entity.dart';

const tildaGallerySource = 'tilda_gallery';

const _tildaCdnHosts = {
  'static.tildacdn.com',
  'static.tildacdn.one',
};

/// Identity of a catalog image.
///
/// `static.tildacdn.com` and `static.tildacdn.one` are the same file when
/// the path matches. The path includes the storage directory, so two files
/// that merely share a basename stay distinct. Other hosts are not aliased.
String catalogImageIdentity(String raw) {
  final trimmed = raw.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return trimmed;
  final host = uri.host.toLowerCase();
  if (_tildaCdnHosts.contains(host)) return 'tildacdn:${uri.path}';
  return '$host${uri.path}';
}

/// Display order for the product details gallery.
///
/// Tilda: the opened variant photo stays first. Only `tilda_gallery` rows
/// are appended. Variant-primary rows are not angles of this variant.
///
/// Native (`tildaUid` empty): every stored image, position order. An empty
/// store falls back to [variantPhotoUrl].
List<String> composeCatalogGallery({
  required String? variantPhotoUrl,
  required List<ProductImageEntity> images,
  required bool isTildaProduct,
}) {
  if (!isTildaProduct) {
    return _nativeGallery(variantPhotoUrl, images);
  }
  return _tildaGallery(variantPhotoUrl, images);
}

List<String> _nativeGallery(
  String? variantPhotoUrl,
  List<ProductImageEntity> images,
) {
  final ordered = [...images]..sort((a, b) => a.position.compareTo(b.position));
  final urls = <String>[];
  final seen = <String>{};
  for (final image in ordered) {
    final url = image.url.trim();
    if (url.isEmpty || !seen.add(url)) continue;
    urls.add(url);
  }
  if (urls.isEmpty) {
    final photo = variantPhotoUrl?.trim() ?? '';
    if (photo.isNotEmpty) urls.add(photo);
  }
  return urls;
}

List<String> _tildaGallery(
  String? variantPhotoUrl,
  List<ProductImageEntity> images,
) {
  final extras = images.where((image) => image.source == tildaGallerySource).toList()
    ..sort((a, b) => a.position.compareTo(b.position));
  final urls = <String>[];
  final seen = <String>{};

  void add(String? raw) {
    final url = raw?.trim() ?? '';
    if (url.isEmpty) return;
    if (!seen.add(catalogImageIdentity(url))) return;
    urls.add(url);
  }

  add(variantPhotoUrl);
  for (final extra in extras) {
    add(extra.url);
  }
  return urls;
}
