import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../glossary/data/glossary_static_entries.dart';
import '../../../glossary/presentation/widgets/care_guide_about_panel.dart';
import '../../../glossary/presentation/widgets/glossary_expandable_card.dart';
import '../../../glossary/presentation/widgets/glossary_section_heading.dart';

/// Static brand history and glossary preview for the Info feed.
///
/// The column is not itself scrollable. Info shows the first
/// [previewCount] terms until the reader asks for the full static list.
class InfoEditorialSection extends StatefulWidget {
  final double topPadding;

  static const int previewCount = 4;

  const InfoEditorialSection({super.key, this.topPadding = AppSpacing.xxl});

  @override
  State<InfoEditorialSection> createState() => _InfoEditorialSectionState();
}

class _InfoEditorialSectionState extends State<InfoEditorialSection> {
  final _headingKey = GlobalKey();
  bool _showAll = false;

  void _setShowAll(bool value) {
    if (_showAll == value) return;
    HapticFeedback.selectionClick();
    final headingVisible = value || _headingIsVisible();
    setState(() => _showAll = value);
    if (headingVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _headingKey.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(target, alignment: 0, duration: Duration.zero);
    });
  }

  bool _headingIsVisible() {
    final target = _headingKey.currentContext;
    final box = target?.findRenderObject();
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox ||
        !box.hasSize ||
        viewport is! RenderBox ||
        !viewport.hasSize) {
      return true;
    }
    final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final bottom = top + box.size.height;
    return bottom > 0 && top < viewport.size.height;
  }

  @override
  Widget build(BuildContext context) {
    final items = kGlossaryStaticItems;
    final visibleCount = _showAll
        ? items.length
        : InfoEditorialSection.previewCount.clamp(0, items.length);
    final visible = items.take(visibleCount).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: widget.topPadding),
        const CareGuideAboutPanel(),
        KeyedSubtree(
          key: _headingKey,
          child: GlossarySectionHeading(
            count: items.length,
            onCollapse: _showAll ? () => _setShowAll(false) : null,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < visible.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: GlossaryExpandableCard(item: visible[i]),
          ),
          if (i != visible.length - 1)
            const SizedBox(height: AppSpacing.md - 2),
        ],
        if (items.length > InfoEditorialSection.previewCount)
          _GlossaryListToggle(
            expanded: _showAll,
            total: items.length,
            onTap: () => _setShowAll(!_showAll),
          ),
      ],
    );
  }
}

class _GlossaryListToggle extends StatelessWidget {
  final bool expanded;
  final int total;
  final VoidCallback onTap;

  const _GlossaryListToggle({
    required this.expanded,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = expanded ? 'Свернуть список' : 'Показать все $total термина';
    final color = AppColors.textPrimary.withValues(alpha: 0.78);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md + 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.55),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 0.2,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
