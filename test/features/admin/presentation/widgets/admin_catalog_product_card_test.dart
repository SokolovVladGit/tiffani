import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/admin/domain/entities/admin_catalog_product.dart';
import 'package:tiffani/features/admin/presentation/widgets/admin_catalog_product_card.dart';

void main() {
  testWidgets('Tilda product can be shown or hidden and cannot be edited', (
    tester,
  ) async {
    bool? next;
    var editTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminCatalogProductCard(
            product: AdminCatalogProduct(
              id: 'cd9b2e33-a379-4cc3-991c-755dd7fcbcd5',
              title: 'Bless Beauty Glow Lip Filler',
              isActive: true,
              appIsVisible: false,
              tildaUid: '848933724282',
            ),
            isMutating: false,
            onVisibilityChanged: (visible) => next = visible,
            onEdit: () => editTaps++,
          ),
        ),
      ),
    );

    expect(find.text('Tilda'), findsOneWidget);
    expect(find.text('Скрыт в каталоге'), findsWidgets);
    expect(find.byTooltip('Редактировать'), findsNothing);

    await tester.tap(find.byType(Switch));
    expect(next, isTrue);
    expect(editTaps, 0);
  });
}
