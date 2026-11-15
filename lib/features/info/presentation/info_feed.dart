import '../domain/entities/info_block_entity.dart';

/// One row in the Info feed: a Supabase block, or the static brand/glossary insert.
class InfoFeedSlot {
  final InfoBlockEntity? block;
  final bool isEditorial;

  const InfoFeedSlot.block(InfoBlockEntity this.block) : isEditorial = false;

  const InfoFeedSlot.editorial() : block = null, isEditorial = true;
}

/// Places the static brand history and glossary immediately before the first
/// `cta` block. Gallery stays out of the feed (it is inlined into delivery).
/// `blog_entry` is omitted so a future link card does not repeat this section.
List<InfoFeedSlot> composeInfoFeed(List<InfoBlockEntity> blocks) {
  final visible = <InfoBlockEntity>[
    for (final block in blocks)
      if (block.blockType != 'gallery' && block.blockType != 'blog_entry')
        block,
  ];

  final ctaIndex = visible.indexWhere((block) => block.blockType == 'cta');
  final insertAt = ctaIndex < 0 ? visible.length : ctaIndex;

  return <InfoFeedSlot>[
    for (final block in visible.take(insertAt)) InfoFeedSlot.block(block),
    const InfoFeedSlot.editorial(),
    for (final block in visible.skip(insertAt)) InfoFeedSlot.block(block),
  ];
}
