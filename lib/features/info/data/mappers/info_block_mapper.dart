import '../../domain/entities/info_block_entity.dart';
import '../dto/info_block_dto.dart';

extension InfoBlockMapper on InfoBlockDto {
  InfoBlockEntity toEntity() {
    return InfoBlockEntity(
      id: id,
      blockType: blockType,
      sortOrder: sortOrder,
      title: title,
      subtitle: subtitle,
      textContent: textContent,
      imageUrl: imageUrl,
      itemsJson: itemsJson,
    );
  }
}
