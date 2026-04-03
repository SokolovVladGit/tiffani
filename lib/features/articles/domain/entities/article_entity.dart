class ArticleEntity {
  final String id;
  final String slug;
  final String title;
  final String? excerpt;
  final String? coverImageUrl;

  const ArticleEntity({
    required this.id,
    required this.slug,
    required this.title,
    this.excerpt,
    this.coverImageUrl,
  });
}
