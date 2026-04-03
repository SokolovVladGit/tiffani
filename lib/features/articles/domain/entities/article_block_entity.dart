enum ArticleBlockType {
  heading,
  paragraph,
  image,
  bulletList,
  quote,
  unknown;

  static ArticleBlockType fromString(String value) {
    return switch (value) {
      'heading' => heading,
      'paragraph' => paragraph,
      'image' => image,
      'bullet_list' => bulletList,
      'quote' => quote,
      _ => unknown,
    };
  }
}

class ArticleBlockEntity {
  final String id;
  final ArticleBlockType blockType;
  final String? textContent;
  final String? imageUrl;
  final String? caption;
  final List<String> items;
  final int sortOrder;

  const ArticleBlockEntity({
    required this.id,
    required this.blockType,
    this.textContent,
    this.imageUrl,
    this.caption,
    this.items = const [],
    this.sortOrder = 0,
  });
}
