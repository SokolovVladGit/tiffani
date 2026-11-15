import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:tiffani/core/router/route_names.dart';
import 'package:tiffani/core/services/logger_service.dart';
import 'package:tiffani/features/consultation/domain/entities/consultation_form_entity.dart';
import 'package:tiffani/features/consultation/domain/entities/consultation_result_entity.dart';
import 'package:tiffani/features/consultation/domain/repositories/consultation_repository.dart';
import 'package:tiffani/features/consultation/domain/usecases/submit_consultation_use_case.dart';
import 'package:tiffani/features/consultation/presentation/cubit/consultation_cubit.dart';
import 'package:tiffani/features/glossary/data/glossary_about_body.dart';
import 'package:tiffani/features/glossary/data/glossary_static_entries.dart';
import 'package:tiffani/features/glossary/presentation/pages/glossary_about_page.dart';
import 'package:tiffani/features/glossary/presentation/pages/glossary_page.dart';
import 'package:tiffani/features/glossary/presentation/widgets/glossary_expandable_card.dart';
import 'package:tiffani/features/info/domain/entities/info_block_entity.dart';
import 'package:tiffani/features/info/presentation/info_feed.dart';
import 'package:tiffani/features/info/presentation/pages/info_page.dart';

InfoBlockEntity _block({
  required String id,
  required String type,
  required int order,
  String? title,
}) {
  return InfoBlockEntity(
    id: id,
    blockType: type,
    sortOrder: order,
    title: title,
  );
}

final _infoBlocks = [
  _block(id: 'hero', type: 'hero', order: 1, title: 'Доставка и обслуживание'),
  _block(id: 'delivery', type: 'delivery', order: 2, title: 'Доставка'),
  _block(id: 'stores', type: 'stores', order: 3, title: 'Наши магазины'),
  _block(id: 'gallery', type: 'gallery', order: 4, title: 'Галерея'),
  _block(id: 'blog', type: 'blog_entry', order: 45, title: 'Гид-дубль'),
  _block(id: 'cta', type: 'cta', order: 5, title: 'Поможем подобрать уход'),
];

class _SilentConsultationRepository implements ConsultationRepository {
  @override
  Future<ConsultationResultEntity> submit(ConsultationFormEntity form) async {
    return ConsultationResultEntity(
      consultationId: 'test',
      createdAt: DateTime.utc(2026),
      status: 'new',
    );
  }
}

void _registerConsultation() {
  final sl = GetIt.instance;
  if (sl.isRegistered<ConsultationCubit>()) return;
  sl.registerFactory(
    () => ConsultationCubit(
      SubmitConsultationUseCase(_SilentConsultationRepository()),
      LoggerService(),
    ),
  );
}

void _mockHaptics() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') return null;
        return null;
      });
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final target = tester.renderObject<RenderBox>(finder);
  final viewport = RenderAbstractViewport.of(target);
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  final revealed = viewport.getOffsetToReveal(target, 0.2);
  position.jumpTo(
    revealed.offset.clamp(position.minScrollExtent, position.maxScrollExtent),
  );
  await tester.pump();
}

void _expectSharedGlossaryCard(WidgetTester tester) {
  final card = find.byType(GlossaryExpandableCard);
  expect(card, findsWidgets);
  expect(
    tester
        .widget<AnimatedSize>(
          find.descendant(of: card.first, matching: find.byType(AnimatedSize)),
        )
        .clipBehavior,
    Clip.none,
  );
  final ink = tester.widget<InkWell>(
    find.descendant(of: card.first, matching: find.byType(InkWell)),
  );
  expect(ink.splashColor, Colors.transparent);
  expect(ink.highlightColor, Colors.transparent);
  expect(ink.onTap, isNotNull);
}

Widget _infoHost(List<InfoBlockEntity> blocks) {
  final router = GoRouter(
    initialLocation: '/info',
    routes: [
      GoRoute(
        path: '/info',
        builder: (_, _) => Scaffold(body: InfoLoadedContent(blocks: blocks)),
      ),
      GoRoute(
        path: RouteNames.glossaryAbout,
        builder: (_, _) => const GlossaryAboutPage(),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _mockHaptics();
    _registerConsultation();
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  test('editorial slot sits before cta and skips blog_entry', () {
    final slots = composeInfoFeed(_infoBlocks);
    expect(
      slots.map(
        (slot) => slot.isEditorial ? 'editorial' : slot.block!.blockType,
      ),
      ['hero', 'delivery', 'stores', 'editorial', 'cta'],
    );

    final withoutCta = composeInfoFeed([
      _block(id: 'hero', type: 'hero', order: 1, title: 'Hero'),
    ]);
    expect(withoutCta.last.isEditorial, isTrue);
    expect(withoutCta.first.block!.blockType, 'hero');
  });

  test('static glossary still has 32 titled descriptions', () {
    expect(kGlossaryStaticItems, hasLength(32));
    expect(glossaryAboutParagraphs(), isNotEmpty);
    for (final item in kGlossaryStaticItems) {
      expect(item.title.trim(), isNotEmpty);
      expect(item.description.trim(), isNotEmpty);
    }
  });

  testWidgets('info shows brand history, all 32 terms, then the cta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_infoHost(_infoBlocks));
    await tester.pump();

    expect(find.text('Доставка и обслуживание'), findsOneWidget);
    expect(find.text('Доставка'), findsOneWidget);
    expect(find.text('Наши магазины'), findsOneWidget);
    expect(find.text('Гид-дубль'), findsNothing);

    final scrollable = find.byType(Scrollable).first;
    final position = tester.state<ScrollableState>(scrollable).position;

    await tester.scrollUntilVisible(
      find.text('История TIFFANI'),
      400,
      scrollable: scrollable,
    );
    expect(find.text('История TIFFANI'), findsOneWidget);
    expect(find.text('О БРЕНДЕ'), findsOneWidget);
    final brandOffset = position.pixels;

    await tester.scrollUntilVisible(
      find.text('Глоссарий'),
      400,
      scrollable: scrollable,
    );
    expect(find.text('Глоссарий'), findsOneWidget);
    expect(find.text('32 терминов'), findsOneWidget);
    final glossaryOffset = position.pixels;
    expect(glossaryOffset, greaterThanOrEqualTo(brandOffset));

    for (final item in kGlossaryStaticItems.take(4)) {
      expect(find.text(item.title), findsOneWidget);
    }
    expect(find.text(kGlossaryStaticItems[4].title), findsNothing);
    expect(find.text('Показать все 32 термина'), findsOneWidget);
    _expectSharedGlossaryCard(tester);

    final term = kGlossaryStaticItems.first;
    await tester.scrollUntilVisible(
      find.text(term.title),
      200,
      scrollable: scrollable,
    );
    expect(tester.widget<Text>(find.text(term.description)).maxLines, 1);
    await tester.tap(find.text(term.title));
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.widget<Text>(find.text(term.description)).maxLines, isNull);
    expect(
      tester.widget<Text>(find.text(term.description)).data,
      term.description,
    );

    await tester.scrollUntilVisible(
      find.text('Поможем подобрать уход'),
      400,
      scrollable: scrollable,
    );
    expect(position.pixels, greaterThanOrEqualTo(glossaryOffset));
    expect(find.text('Поможем подобрать уход'), findsOneWidget);
    expect(find.text(kGlossaryStaticItems[4].title), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Показать все 32 термина'),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Показать все 32 термина'));
    await tester.pump();

    for (final item in kGlossaryStaticItems) {
      expect(find.text(item.title), findsOneWidget);
    }
    expect(find.text('Свернуть список'), findsOneWidget);

    await _reveal(tester, find.text('Свернуть список'));
    await tester.tap(find.text('Свернуть список'));
    await tester.pump();
    expect(find.text(kGlossaryStaticItems[4].title), findsNothing);
    expect(find.text(kGlossaryStaticItems[3].title), findsOneWidget);
    expect(find.text('Показать все 32 термина'), findsOneWidget);

    await tester.tap(find.text('Показать все 32 термина'));
    await tester.pump();
    await _reveal(tester, find.byKey(const Key('glossary-heading-collapse')));
    await tester.tap(find.byKey(const Key('glossary-heading-collapse')));
    await tester.pump();
    expect(find.text(kGlossaryStaticItems[4].title), findsNothing);
    expect(find.text('Показать все 32 термина'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('brand history opens the existing about route', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_infoHost(_infoBlocks));
    await tester.pump();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('История TIFFANI'),
      400,
      scrollable: scrollable,
    );
    await _reveal(tester, find.text('ЧИТАТЬ'));
    expect(find.text('ЧИТАТЬ'), findsOneWidget);
    expect(find.text('СВЕРНУТЬ'), findsNothing);

    await tester.tap(find.text('ЧИТАТЬ'));
    await tester.pumpAndSettle();
    expect(find.text('СВЕРНУТЬ'), findsWidgets);
    expect(find.text('ОТКРЫТЬ ПОЛНОСТЬЮ'), findsOneWidget);

    await _reveal(tester, find.text('СВЕРНУТЬ').first);
    await tester.tap(find.text('СВЕРНУТЬ').first);
    await tester.pumpAndSettle();
    expect(find.text('ЧИТАТЬ'), findsOneWidget);
    expect(find.text('ОТКРЫТЬ ПОЛНОСТЬЮ'), findsNothing);

    await tester.tap(find.text('ЧИТАТЬ'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('ОТКРЫТЬ ПОЛНОСТЬЮ'));
    await tester.pumpAndSettle();
    final fullOnly = glossaryAboutParagraphs()[3];
    expect(find.text(fullOnly), findsNothing);

    await tester.tap(find.text('ОТКРЫТЬ ПОЛНОСТЬЮ'));
    await tester.pumpAndSettle();

    expect(find.text(fullOnly), findsOneWidget);
  });

  testWidgets('standalone glossary page still lists the static terms', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: RouteNames.glossary,
      routes: [
        GoRoute(
          path: RouteNames.glossary,
          builder: (_, _) => const GlossaryPage(),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Глоссарий'),
      400,
      scrollable: scrollable,
    );
    expect(find.text('История TIFFANI'), findsOneWidget);
    expect(find.text('Глоссарий'), findsOneWidget);
    expect(find.text('Показать все 32 термина'), findsNothing);
    expect(find.byKey(const Key('glossary-heading-collapse')), findsNothing);
    _expectSharedGlossaryCard(tester);

    final last = kGlossaryStaticItems.last;
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(find.text(last.title), findsOneWidget);

    position.jumpTo(0);
    await tester.pump();
    final term = kGlossaryStaticItems[3];
    await tester.scrollUntilVisible(
      find.text(term.title),
      300,
      scrollable: scrollable,
    );
    await _reveal(tester, find.text(term.title));
    await tester.tap(find.text(term.title));
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.widget<Text>(find.text(term.description)).maxLines, isNull);
    await tester.pump(const Duration(seconds: 1));
  });
}
