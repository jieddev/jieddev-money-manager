import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jieddev_money_manager/data/money_manager_repository.dart';
import 'package:jieddev_money_manager/main.dart';

class FakeMoneyManagerRepository implements MoneyManagerRepository {
  FakeMoneyManagerRepository({MoneyManagerSnapshot? initialSnapshot})
      : _snapshot =
            initialSnapshot ??
            const MoneyManagerSnapshot(
              balance: 0,
              transactions: <TransactionRecord>[],
              categories: <String>['Bills', 'Entertainment', 'Food', 'Other', 'Savings', 'Transportation'],
            );

  MoneyManagerSnapshot _snapshot;

  @override
  Future<void> addTransaction({
    required int amount,
    String? category,
    String? description,
    required bool isAddition,
  }) async {
    final transaction = TransactionRecord(
      id: _snapshot.transactions.length + 1,
      amount: amount,
      category: category,
      description: description,
      isAddition: isAddition,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    final updatedCategories = category == null
        ? _snapshot.categories
        : <String>{..._snapshot.categories, category}.toList();
    final updatedBalance = _snapshot.balance + (isAddition ? amount : -amount);

    _snapshot = MoneyManagerSnapshot(
      balance: updatedBalance,
      transactions: <TransactionRecord>[transaction, ..._snapshot.transactions],
      categories: updatedCategories,
    );
  }

  @override
  Future<MoneyManagerSnapshot> loadSnapshot() async => _snapshot;
}

void main() {
  testWidgets('loads persisted data and saves new transactions',
      (WidgetTester tester) async {
    final repository = FakeMoneyManagerRepository(
      initialSnapshot: MoneyManagerSnapshot(
        balance: 250,
        transactions: <TransactionRecord>[
          TransactionRecord(
            id: 1,
            amount: 250,
            category: 'Food',
            description: null,
            isAddition: true,
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ],
        categories: <String>['Bills', 'Entertainment', 'Food', 'Other', 'Savings', 'Transportation'],
      ),
    );

    await tester.pumpWidget(MyApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.textContaining('₱250'), findsWidgets);
    expect(find.text('Balance by day'), findsOneWidget);

    await tester.tap(find.byKey(const Key('weekly-balance-chart')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Selected:'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Update Money'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '50');

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Lunch with client');
    await tester.tap(find.widgetWithText(FilledButton, 'Update balance'));
    await tester.pumpAndSettle();

    expect(repository._snapshot.transactions.first.description, 'Lunch with client');
    expect(repository._snapshot.transactions.first.category, 'Food');
    expect(repository._snapshot.categories.contains('Lunch with client'), isFalse);
    expect(repository._snapshot.balance, 300);
  });
}
