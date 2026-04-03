class ArticleDetailsPayload {
  final String slug;
  final String title;
  final String? coverImageUrl;
  final String? heroTag;

  const ArticleDetailsPayload({
    required this.slug,
    required this.title,
    this.coverImageUrl,
    this.heroTag,
  });
}
