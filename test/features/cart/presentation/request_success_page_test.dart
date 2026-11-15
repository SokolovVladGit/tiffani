import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/cart/domain/order_reference.dart';
import 'package:tiffani/features/cart/presentation/pages/request_success_page.dart';

void main() {
  test('short reference matches the Telegram prefix', () {
    expect(
      shortOrderReference('b1f40755-1111-4111-8111-111111111111'),
      'B1F40755',
    );
  });

  testWidgets(
    'success screen shows the reference and does not claim delivery',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RequestSuccessPage(
            orderId: 'b1f40755-1111-4111-8111-111111111111',
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Заказ оформлен. Мы получили вашу заявку.'),
        findsOneWidget,
      );
      expect(find.text('Номер заказа #B1F40755'), findsOneWidget);
      expect(find.textContaining('переданы менеджеру'), findsNothing);
      expect(find.textContaining('Оформить заказ'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    },
  );
}
