import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/glossary/data/glossary_static_entries.dart';
import 'package:tiffani/features/glossary/presentation/widgets/glossary_expandable_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') return null;
          return null;
        });
  });

  testWidgets('card expands, clips through the outer radius, then collapses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final first = kGlossaryStaticItems.first;
    final second = kGlossaryStaticItems[1];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              GlossaryExpandableCard(item: first),
              const SizedBox(height: 8),
              GlossaryExpandableCard(item: second),
            ],
          ),
        ),
      ),
    );

    final card = find.byType(GlossaryExpandableCard).first;
    final animatedSize = tester.widget<AnimatedSize>(
      find.descendant(of: card, matching: find.byType(AnimatedSize)),
    );
    expect(animatedSize.clipBehavior, Clip.none);
    expect(animatedSize.duration, const Duration(milliseconds: 280));
    expect(animatedSize.curve, Curves.easeOutCubic);

    final ink = tester.widget<InkWell>(
      find.descendant(of: card, matching: find.byType(InkWell)),
    );
    expect(ink.splashColor, Colors.transparent);
    expect(ink.highlightColor, Colors.transparent);
    expect(ink.overlayColor, isNull);

    expect(tester.widget<Text>(find.text(first.description)).maxLines, 1);

    await tester.tap(find.text(first.title));
    await tester.pump(const Duration(milliseconds: 140));

    final description = tester.renderObject<RenderBox>(
      find.text(first.description),
    );
    final clip = tester.renderObject<RenderClipPath>(
      find.descendant(of: card, matching: find.byType(ClipPath)),
    );
    expect(clip.clipBehavior, Clip.antiAlias);
    expect(_isAncestor(clip, description), isTrue);

    final descriptionBottom = description
        .localToGlobal(Offset(0, description.size.height))
        .dy;
    final clipBottom = clip.localToGlobal(Offset(0, clip.size.height)).dy;
    final neighborTop = tester
        .getTopLeft(find.byType(GlossaryExpandableCard).at(1))
        .dy;

    expect(descriptionBottom, greaterThan(clipBottom + 1));
    expect(neighborTop + 0.1, greaterThanOrEqualTo(clipBottom));
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 200));
    final expandedText = tester.widget<Text>(find.text(first.description));
    expect(expandedText.maxLines, isNull);
    expect(expandedText.data, first.description);

    await tester.tap(find.text(first.title));
    await tester.pump(const Duration(milliseconds: 140));
    expect(tester.takeException(), isNull);
    final collapsing = tester.renderObject<RenderBox>(
      find.text(first.description),
    );
    final collapsingClip = tester.renderObject<RenderClipPath>(
      find.descendant(of: card, matching: find.byType(ClipPath)),
    );
    expect(_isAncestor(collapsingClip, collapsing), isTrue);
    expect(
      tester.getTopLeft(find.byType(GlossaryExpandableCard).at(1)).dy + 0.1,
      greaterThanOrEqualTo(
        collapsingClip.localToGlobal(Offset(0, collapsingClip.size.height)).dy,
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<Text>(find.text(first.description)).maxLines, 1);
    expect(find.text(second.title), findsOneWidget);
  });
}

bool _isAncestor(RenderObject ancestor, RenderObject child) {
  RenderObject? node = child.parent;
  while (node != null) {
    if (identical(node, ancestor)) return true;
    node = node.parent;
  }
  return false;
}
