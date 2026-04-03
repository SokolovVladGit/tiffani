import '../../domain/entities/article_block_entity.dart';
import '../dto/article_block_dto.dart';

extension ArticleBlockMapper on ArticleBlockDto {
  ArticleBlockEntity toEntity() {
    return ArticleBlockEntity(
      id: id,
      blockType: ArticleBlockType.fromString(blockType),
      textContent: textContent,
      imageUrl: imageUrl,
      caption: caption,
      items: items,
      sortOrder: sortOrder,
    );
  }
}
