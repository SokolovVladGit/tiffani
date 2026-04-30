/// Home-local visual metrics.
///
/// Encapsulates the vertical rhythm and recurring paddings used across
/// Home sections so that all blocks (products, recommendations, brands,
/// recently viewed, contacts) share a single, intentional pace.
///
/// These values are intentionally Home-only to avoid disturbing other
/// screens that share `SectionHeader` and similar primitives.
class HomeMetrics {
  HomeMetrics._();

  /// Horizontal page edge padding (matches `AppSpacing.lg`).
  static const double pageEdge = 16;

  /// Top padding of the very first section header right after the hero
  /// continuation strip — tighter, since the strip already provides air.
  static const double firstSectionTop = 20;

  /// Top padding for every subsequent section header — the canonical
  /// inter-section breathing space.
  static const double sectionTop = 34;

  /// Bottom padding under a section header before its content row.
  static const double sectionHeaderBottom = 16;

  /// Top padding before the compact contacts teaser block.
  static const double contactsTop = 44;
}
