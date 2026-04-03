/// Extracts clean top-level product categories from raw compound category
/// strings stored in the database.
///
/// Raw values use `;` to separate multiple categories and `>>>` for
/// sub-category hierarchy (e.g. `Лицо;Лицо>>>Маски;Скидки`).
class CategoryParser {
  CategoryParser._();

  static const _excludedTags = {
    'Скидки',
    'Хиты',
    'Новинки',
    'Подарки до 500р',
  };

  static final _hasCyrillic = RegExp(r'[\u0400-\u04FF]');

  /// Returns a sorted, deduplicated list of top-level category names.
  static List<String> extractTopLevel(List<String> raw) {
    final result = <String>{};
    for (final value in raw) {
      for (final segment in value.split(';')) {
        final trimmed = segment.trim();
        if (trimmed.isEmpty) continue;
        final root = trimmed.split('>>>').first.trim();
        if (root.isEmpty) continue;
        if (_excludedTags.contains(root)) continue;
        if (!_hasCyrillic.hasMatch(root)) continue;
        result.add(root);
      }
    }
    return result.toList()..sort();
  }
}
