class ArticleBlockDto {
  final String id;
  final String articleId;
  final String blockType;
  final String? textContent;
  final String? imageUrl;
  final String? caption;
  final List<String> items;
  final int sortOrder;

  const ArticleBlockDto({
    required this.id,
    required this.articleId,
    required this.blockType,
    this.textContent,
    this.imageUrl,
    this.caption,
    this.items = const [],
    this.sortOrder = 0,
  });

  factory ArticleBlockDto.fromMap(Map<String, dynamic> map) {
    return ArticleBlockDto(
      id: map['id'] as String,
      articleId: map['article_id'] as String,
      blockType: map['block_type'] as String? ?? 'unknown',
      textContent: map['text_content'] as String?,
      imageUrl: map['image_url'] as String?,
      caption: map['caption'] as String?,
      items: _parseItems(map['items']),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  static List<String> _parseItems(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.whereType<String>().toList();
    return [];
  }
}
