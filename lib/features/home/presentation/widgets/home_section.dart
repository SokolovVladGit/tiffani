import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../catalog/domain/entities/catalog_item_entity.dart';
import 'home_horizontal_item_card.dart';

class HomeSection extends StatelessWidget {
  final String title;
  final List<CatalogItemEntity> items;

  const HomeSection({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        SizedBox(
          height: 228,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: items.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppSpacing.md),
            itemBuilder: (_, index) => HomeHorizontalItemCard(
              item: items[index],
              heroTag: 'home-${title.toLowerCase()}-${items[index].id}',
            ),
          ),
        ),
      ],
    );
  }
}
