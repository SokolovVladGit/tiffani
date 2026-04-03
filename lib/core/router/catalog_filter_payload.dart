class CatalogFilterPayload {
  final String? title;
  final String? brand;
  final String? category;
  final String? mark;
  final bool saleOnly;

  const CatalogFilterPayload({
    this.title,
    this.brand,
    this.category,
    this.mark,
    this.saleOnly = false,
  });
}
