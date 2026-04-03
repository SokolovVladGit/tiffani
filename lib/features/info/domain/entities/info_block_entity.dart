class InfoBlockEntity {
  final String id;
  final String blockType;
  final int sortOrder;
  final String? title;
  final String? subtitle;
  final String? textContent;
  final String? imageUrl;
  final Map<String, dynamic>? itemsJson;

  const InfoBlockEntity({
    required this.id,
    required this.blockType,
    required this.sortOrder,
    this.title,
    this.subtitle,
    this.textContent,
    this.imageUrl,
    this.itemsJson,
  });
}
