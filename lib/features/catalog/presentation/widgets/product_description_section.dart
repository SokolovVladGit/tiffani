import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../rich_text/catalog_html.dart';

/// One description block. A populated full HTML body replaces the
/// truncated plain introduction instead of repeating it.
class ProductDescriptionSection extends StatefulWidget {
  final String? fullDescription;
  final String? shortDescription;

  const ProductDescriptionSection({
    super.key,
    required this.fullDescription,
    required this.shortDescription,
  });

  @override
  State<ProductDescriptionSection> createState() =>
      _ProductDescriptionSectionState();
}

class _ProductDescriptionSectionState extends State<ProductDescriptionSection> {
  static const double _collapsedHeight = 156;

  final GlobalKey _contentKey = GlobalKey();
  bool _expanded = false;
  bool _overflows = false;
  double? _fullHeight;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  CatalogDescription? get _description => prepareCatalogDescription(
        full: widget.fullDescription,
        short: widget.shortDescription,
      );

  @override
  void didUpdateWidget(ProductDescriptionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fullDescription != widget.fullDescription ||
        oldWidget.shortDescription != widget.shortDescription) {
      _expanded = false;
      _overflows = false;
      _fullHeight = null;
      _scheduleMeasure();
    }
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (!mounted || box == null || !box.hasSize) return;
    final full = box.size.height;
    final overflows = full > _collapsedHeight + 1;
    if (full == _fullHeight && overflows == _overflows) return;
    setState(() {
      _fullHeight = full;
      _overflows = overflows;
    });
  }

  @override
  Widget build(BuildContext context) {
    final description = _description;
    if (description == null || description.isEmpty) {
      return const SizedBox.shrink();
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 320);
    final shownHeight = _shownHeight();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ОПИСАНИЕ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRect(
          key: const Key('product-description-clip'),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            height: shownHeight,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  alignment: Alignment.topLeft,
                  children: [
                    OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: constraints.maxWidth,
                      maxWidth: constraints.maxWidth,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: KeyedSubtree(
                        key: _contentKey,
                        child: _DescriptionBody(description: description),
                      ),
                    ),
                    if (_overflows && !_expanded)
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 36,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x00FFFFFF),
                                AppColors.surface,
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        if (_overflows) ...[
          const SizedBox(height: AppSpacing.sm),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Свернуть' : 'Читать полностью',
              style: AppTextStyles.sectionAction.copyWith(
                color: AppColors.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ],
    );
  }

  double? _shownHeight() {
    final full = _fullHeight;
    if (full == null) return _collapsedHeight;
    if (!_overflows || _expanded) return full;
    return full < _collapsedHeight ? full : _collapsedHeight;
  }
}

class _DescriptionBody extends StatelessWidget {
  final CatalogDescription description;

  const _DescriptionBody({required this.description});

  @override
  Widget build(BuildContext context) {
    if (description.isHtml) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _blocks(description.html, _bodyStyle),
      );
    }
    return _plain(description.plain ?? '');
  }

  static const _bodyStyle = AppTextStyles.bodySecondary;

  static const _headingStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.45,
    letterSpacing: -0.15,
  );
}

Widget _plain(String text) {
  final paragraphs = text
      .split(RegExp(r'\n\s*\n'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < paragraphs.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpacing.md),
        Text(paragraphs[i], style: _DescriptionBody._bodyStyle),
      ],
    ],
  );
}

List<Widget> _blocks(List<CatalogHtmlNode> nodes, TextStyle style) {
  final widgets = <Widget>[];
  final inline = <CatalogHtmlNode>[];

  void flush() {
    if (inline.isEmpty) return;
    widgets.add(_richText(inline, style));
    inline.clear();
  }

  for (final node in nodes) {
    if (_isInline(node)) {
      inline.add(node);
      continue;
    }
    flush();
    widgets.add(_block(node as CatalogHtmlElement, style));
  }
  flush();
  return _spaced(widgets);
}

bool _isInline(CatalogHtmlNode node) {
  if (node is CatalogHtmlText) return true;
  final tag = (node as CatalogHtmlElement).tag;
  return tag == 'strong' ||
      tag == 'em' ||
      tag == 'u' ||
      tag == 'span' ||
      tag == 'a' ||
      tag == 'br';
}

Widget _block(CatalogHtmlElement element, TextStyle style) {
  switch (element.tag) {
    case 'p':
      if (_isHeading(element)) {
        return Text(_plainOf(element.children), style: _DescriptionBody._headingStyle);
      }
      return _richText(element.children, style);
    case 'ul':
      return _list(element.children, ordered: false, style: style);
    case 'ol':
      return _list(element.children, ordered: true, style: style);
    case 'li':
      return _richText(element.children, style);
    default:
      return _richText(element.children, style);
  }
}

bool _isHeading(CatalogHtmlElement paragraph) {
  final meaningful = paragraph.children.where((node) {
    if (node is CatalogHtmlText) return node.text.trim().isNotEmpty;
    return true;
  }).toList();
  if (meaningful.length != 1 || meaningful.first is! CatalogHtmlElement) {
    return false;
  }
  return (meaningful.first as CatalogHtmlElement).tag == 'strong';
}

Widget _list(
  List<CatalogHtmlNode> items, {
  required bool ordered,
  required TextStyle style,
}) {
  final rows = <Widget>[];
  var index = 1;
  for (final item in items) {
    if (item is! CatalogHtmlElement || item.tag != 'li') {
      if (item is CatalogHtmlText && item.text.trim().isEmpty) continue;
      rows.add(_richText([item], style));
      continue;
    }
    final marker = ordered ? '$index.' : '•';
    index++;
    rows.add(
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text(marker, style: style.copyWith(color: AppColors.textPrimary)),
            ),
            Expanded(child: _richText(item.children, style)),
          ],
        ),
      ),
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: rows,
  );
}

Widget _richText(List<CatalogHtmlNode> nodes, TextStyle style) {
  final spans = <InlineSpan>[];
  _writeSpans(nodes, style, spans);
  if (spans.isEmpty) return const SizedBox.shrink();
  return Text.rich(TextSpan(children: spans, style: style));
}

void _writeSpans(
  List<CatalogHtmlNode> nodes,
  TextStyle style,
  List<InlineSpan> spans,
) {
  for (final node in nodes) {
    if (node is CatalogHtmlText) {
      spans.add(TextSpan(text: node.text, style: style));
      continue;
    }
    final element = node as CatalogHtmlElement;
    switch (element.tag) {
      case 'br':
        spans.add(const TextSpan(text: '\n'));
      case 'strong':
        _writeSpans(
          element.children,
          style.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          spans,
        );
      case 'em':
        _writeSpans(
          element.children,
          style.copyWith(fontStyle: FontStyle.italic),
          spans,
        );
      case 'u':
        _writeSpans(
          element.children,
          style.copyWith(decoration: TextDecoration.underline),
          spans,
        );
      case 'a':
        final linkStyle = style.copyWith(
          color: AppColors.textPrimary,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.textPrimary,
        );
        final href = element.href;
        if (href == null) {
          _writeSpans(element.children, linkStyle, spans);
          break;
        }
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => launchUrl(
                Uri.parse(href),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(_plainOf(element.children), style: linkStyle),
            ),
          ),
        );
      case 'ul':
      case 'ol':
      case 'p':
        spans.add(WidgetSpan(child: _block(element, style)));
      default:
        _writeSpans(element.children, style, spans);
    }
  }
}

String _plainOf(List<CatalogHtmlNode> nodes) {
  final buffer = StringBuffer();
  for (final node in nodes) {
    if (node is CatalogHtmlText) {
      buffer.write(node.text);
    } else {
      buffer.write(_plainOf((node as CatalogHtmlElement).children));
    }
  }
  return buffer.toString();
}

List<Widget> _spaced(List<Widget> widgets) {
  final visible = widgets.where((widget) => widget is! SizedBox).toList();
  return [
    for (var i = 0; i < visible.length; i++) ...[
      if (i > 0) const SizedBox(height: AppSpacing.md),
      visible[i],
    ],
  ];
}
