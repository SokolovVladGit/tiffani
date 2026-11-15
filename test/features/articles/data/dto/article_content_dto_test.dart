import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/articles/data/dto/article_block_dto.dart';
import 'package:tiffani/features/articles/data/dto/article_dto.dart';
import 'package:tiffani/features/articles/data/mappers/article_block_mapper.dart';
import 'package:tiffani/features/articles/data/mappers/article_mapper.dart';
import 'package:tiffani/features/articles/domain/entities/article_block_entity.dart';

void main() {
  test('article row matches the unpublished editorial contract', () {
    final entity = ArticleDto.fromMap({
      'id': 'b7d19138-6873-52af-8c0f-e1767047e15c',
      'slug': 'mikrobiom',
      'title': 'Микробиом',
      'excerpt': 'Микробиом кожи.',
      'cover_image_url':
          'https://static.tildacdn.com/tild3864-3666-4732-a364-623461316262/beautiful-asian-woma.jpg',
    }).toEntity();

    expect(entity.slug, 'mikrobiom');
    expect(entity.title, 'Микробиом');
    expect(entity.excerpt, 'Микробиом кожи.');
    expect(entity.coverImageUrl, contains('tildacdn.com'));
  });

  test('article blocks accept the stored block types', () {
    final cases = <Map<String, Object?>>[
      {
        'block_type': 'heading',
        'text_content': 'МИФ №1',
        'items': <String>[],
        'expected': ArticleBlockType.heading,
      },
      {
        'block_type': 'paragraph',
        'text_content': 'SPF нужен только летом и на пляже.',
        'items': <String>[],
        'expected': ArticleBlockType.paragraph,
      },
      {
        'block_type': 'image',
        'text_content': null,
        'image_url': 'https://static.tildacdn.com/example.jpg',
        'items': <String>[],
        'expected': ArticleBlockType.image,
      },
      {
        'block_type': 'bullet_list',
        'text_content': null,
        'items': <String>['Очищение', 'Защита от солнца'],
        'expected': ArticleBlockType.bulletList,
      },
      {
        'block_type': 'quote',
        'text_content': 'ВЫВОД: богатый микробиом - здоровая кожа.',
        'items': <String>[],
        'expected': ArticleBlockType.quote,
      },
      {
        'block_type': 'unknown-legacy',
        'text_content': 'ignored',
        'items': <String>[],
        'expected': ArticleBlockType.unknown,
      },
    ];

    for (final item in cases) {
      final entity = ArticleBlockDto.fromMap({
        'id': 'block-1',
        'article_id': 'article-1',
        'block_type': item['block_type'],
        'text_content': item['text_content'],
        'image_url': item['image_url'],
        'caption': null,
        'items': item['items'],
        'sort_order': 1,
      }).toEntity();

      expect(entity.blockType, item['expected'], reason: '${item['block_type']}');
      expect(entity.sortOrder, 1);
    }
  });

  test('missing items stay an empty list', () {
    final dto = ArticleBlockDto.fromMap({
      'id': 'block-1',
      'article_id': 'article-1',
      'block_type': 'paragraph',
      'text_content': 'Текст',
      'sort_order': 2,
    });

    expect(dto.items, isEmpty);
    expect(dto.textContent, 'Текст');
  });
}
