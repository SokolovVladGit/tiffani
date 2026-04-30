/// Centralized builder for product-navigation Hero tags.
///
/// Hero tags MUST be unique per source instance on the route they live on,
/// otherwise Flutter's `HeroController` will assert
/// `manifest.tag == newManifest.tag` (`heroes.dart`) when a flight is
/// diverted onto a different manifest. The product flow is reachable from
/// many surfaces — multiple Home shelves (new arrivals, hits, sale,
/// recently viewed), the catalog grid, the favorites list, and the PDP
/// "similar products" carousel — and the same product can simultaneously
/// appear in more than one of them.
///
/// Using a plain `'<id>'` tag is therefore unsafe; using a localizable
/// display string (`'home-${title.toLowerCase()}-<id>'`) is fragile because
/// the tag silently changes if the title is edited or translated.
///
/// This helper makes the tag scheme explicit, stable, and centralized:
///
///   * `home:<section>:<productId>` for Home shelves;
///   * `catalog:<productId>` for the catalog grid/list;
///   * `catalog:similar:<productId>` for the PDP "similar products" rail;
///   * `favorites:<productId>` for the favorites list.
///
/// All consumers MUST go through this class so source/destination Heroes
/// always agree on the same string.
class ProductHeroTag {
  ProductHeroTag._();

  /// Home shelf tag, e.g. `home:new:42`, `home:hits:42`, `home:sale:42`,
  /// `home:recent:42`. [section] is a stable internal key — never a
  /// localized display title.
  static String home(String section, String productId) =>
      'home:$section:$productId';

  /// Catalog grid / list card.
  static String catalog(String productId) => 'catalog:$productId';

  /// PDP "similar products" carousel.
  static String similar(String productId) => 'catalog:similar:$productId';

  /// Favorites list card.
  static String favorites(String productId) => 'favorites:$productId';
}
