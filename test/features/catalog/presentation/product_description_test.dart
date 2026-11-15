import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/catalog/presentation/rich_text/catalog_html.dart';
import 'package:tiffani/features/catalog/presentation/widgets/product_description_section.dart';

/// Representative Tilda description. Not a copy of the stored CSV row.
const erborianHtml = '''
<p><strong>CC Eye</strong></p>
<p>Лёгкий крем с <strong>центеллой <em>азиатской</em></strong> выравнивает тон.</p>
<p>Первая строка ухода.<br>Вторая строка ухода.</p>
<ul>
<li>Скрывает тёмные круги</li>
<li>Увлажняет <u>деликатную</u> зону</li>
</ul>
<p><strong>Применение</strong></p>
<ol>
<li>Нанесите на очищенную кожу</li>
<li>Распределите кончиками пальцев</li>
</ol>
<p>Aqua, <span>Centella</span> &amp; Glycerin&#39;s blend.</p>
<p>Подробнее на <a href="https://tiffani.md/erborian">странице бренда</a>.</p>
<p><a href="javascript:alert(1)">не открывать</a></p>
<script>alert(1)</script>
<p>Неизвестный <font>тег</font> остаётся текстом.</p>
<p>Страна-производитель: Корея</p>
<p>Финальная строка состава видна только после раскрытия.</p>
''';

void main() {
  test('full HTML replaces the truncated introduction', () {
    final prepared = prepareCatalogDescription(
      full: erborianHtml,
      short: 'Короткий лид на 500 символов',
    );

    expect(prepared, isNotNull);
    expect(prepared!.isHtml, isTrue);
    expect(prepared.plain, isNull);
    expect(prepared.country, 'Корея');
    final rendered = _text(prepared.html);
    expect(rendered, isNot(contains('Короткий лид')));
    expect(rendered, isNot(contains('Страна-производитель')));
    expect(rendered, isNot(contains('alert')));
    expect(rendered, contains('центеллой'));
    expect(rendered, contains('тег остаётся текстом'));
  });

  test('parses emphasis, lists, breaks, entities and safe links', () {
    final nodes = parseCatalogHtml(erborianHtml);
    final heading = nodes.first as CatalogHtmlElement;
    expect(heading.tag, 'p');
    expect((heading.children.single as CatalogHtmlElement).tag, 'strong');

    final emphasis = nodes[1] as CatalogHtmlElement;
    final strong = emphasis.children[1] as CatalogHtmlElement;
    final em = strong.children[1] as CatalogHtmlElement;
    expect(strong.tag, 'strong');
    expect(em.tag, 'em');
    expect((em.children.single as CatalogHtmlText).text, 'азиатской');

    final broken = nodes[2] as CatalogHtmlElement;
    expect(
      broken.children.whereType<CatalogHtmlElement>().single.tag,
      'br',
    );

    final bullets = nodes[3] as CatalogHtmlElement;
    expect(bullets.tag, 'ul');
    expect(bullets.children.whereType<CatalogHtmlElement>().length, 2);

    final steps = nodes.whereType<CatalogHtmlElement>().firstWhere(
      (node) => node.tag == 'ol',
    );
    expect(steps.children.whereType<CatalogHtmlElement>().length, 2);

    final rendered = _text(nodes);
    expect(rendered, contains('&'));
    expect(rendered, contains("Glycerin's blend"));
    expect(rendered, isNot(contains('&amp;')));
    expect(rendered, isNot(contains('&#39;')));

    final links = _elements(nodes).where((node) => node.tag == 'a').toList();
    expect(links.first.href, 'https://tiffani.md/erborian');
    expect(links[1].href, isNull);
  });

  test('plain description remains when full text is absent', () {
    final prepared = prepareCatalogDescription(
      full: null,
      short: 'Только короткое описание &amp; уход.',
    );
    expect(prepared!.isHtml, isFalse);
    expect(prepared.plain, 'Только короткое описание & уход.');
  });

  testWidgets('long Erborian text expands and does not repeat the lead', (
    tester,
  ) async {
    await tester.pumpWidget(_host(
      const ProductDescriptionSection(
        fullDescription: erborianHtml,
        shortDescription: 'Короткий лид на 500 символов',
      ),
    ));
    await tester.pump();

    expect(find.textContaining('Короткий лид'), findsNothing);
    expect(find.text('Читать полностью'), findsOneWidget);
    expect(_isVisible(tester, find.textContaining('Финальная строка')), isFalse);

    await tester.tap(find.text('Читать полностью'));
    await tester.pumpAndSettle();

    expect(_isVisible(tester, find.textContaining('Финальная строка')), isTrue);
    expect(find.text('Свернуть'), findsOneWidget);
    expect(find.textContaining('тег остаётся текстом'), findsOneWidget);
  });

  testWidgets('missing full description shows the plain fallback', (
    tester,
  ) async {
    await tester.pumpWidget(_host(
      const ProductDescriptionSection(
        fullDescription: null,
        shortDescription: 'Только короткое описание.',
      ),
    ));
    await tester.pump();

    expect(find.textContaining('Только короткое описание'), findsOneWidget);
    expect(find.text('Читать полностью'), findsNothing);
  });

  testWidgets('reduced motion opens the description on the next frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _host(
          const ProductDescriptionSection(
            fullDescription: erborianHtml,
            shortDescription: 'Короткий лид',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Читать полностью'));
    await tester.pump();

    expect(_isVisible(tester, find.textContaining('Финальная строка')), isTrue);
  });
}

bool _isVisible(WidgetTester tester, Finder finder) {
  final textRect = tester.getRect(finder);
  final clipRect = tester.getRect(find.byKey(const Key('product-description-clip')));
  return clipRect.overlaps(textRect);
}

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    ),
  );
}

String _text(List<CatalogHtmlNode> nodes) {
  final buffer = StringBuffer();
  for (final node in nodes) {
    if (node is CatalogHtmlText) {
      buffer.write(node.text);
    } else {
      buffer.write(_text((node as CatalogHtmlElement).children));
    }
  }
  return buffer.toString();
}

Iterable<CatalogHtmlElement> _elements(List<CatalogHtmlNode> nodes) sync* {
  for (final node in nodes) {
    if (node is CatalogHtmlElement) {
      yield node;
      yield* _elements(node.children);
    }
  }
}
