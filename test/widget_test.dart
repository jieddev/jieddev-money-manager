import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jieddev_money_manager/main.dart';

void main() {
  testWidgets('updates the balance when adding and subtracting',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text(r'$0'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    expect(find.text(r'$10'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Subtract'));
    await tester.pump();
    expect(find.text(r'$0'), findsOneWidget);
  });

  testWidgets('supports negative balances', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.widgetWithText(OutlinedButton, 'Subtract'));
    await tester.pump();

    expect(find.text(r'-$10'), findsOneWidget);
  });
}
