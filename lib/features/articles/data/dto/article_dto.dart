class ArticleDto {
  final String id;
  final String slug;
  final String title;
  final String? excerpt;
  final String? coverImageUrl;

  const ArticleDto({
    required this.id,
    required this.slug,
    required this.title,
    this.excerpt,
    this.coverImageUrl,
  });

  factory ArticleDto.fromMap(Map<String, dynamic> map) {
    return ArticleDto(
      id: map['id'] as String,
      slug: map['slug'] as String,
      title: map['title'] as String,
      excerpt: map['excerpt'] as String?,
      coverImageUrl: map['cover_image_url'] as String?,
    );
  }
}
