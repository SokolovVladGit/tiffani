import '../../domain/entities/article_entity.dart';
import '../dto/article_dto.dart';

extension ArticleMapper on ArticleDto {
  ArticleEntity toEntity() {
    return ArticleEntity(
      id: id,
      slug: slug,
      title: title,
      excerpt: excerpt,
      coverImageUrl: coverImageUrl,
    );
  }
}
