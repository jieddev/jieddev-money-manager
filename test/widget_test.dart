import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jieddev_money_manager/data/money_manager_repository.dart';
import 'package:jieddev_money_manager/main.dart';

// The app syncs to the home screen widget through this platform channel on
// every load/mutation. Without a mock handler the call never resolves in a
// widget test (there's no platform on the other end), which stalls anything
// awaiting `_loadSnapshot()` — including the SnackBar shown after a save.
const _homeWidgetChannel = MethodChannel('home_widget');

class FakeMoneyManagerRepository implements MoneyManagerRepository {
  FakeMoneyManagerRepository({MoneyManagerSnapshot? initialSnapshot})
      : _snapshot =
            initialSnapshot ??
            const MoneyManagerSnapshot(
              balance: 0,
              transactions: <TransactionRecord>[],
              categories: <String>['Bills', 'Entertainment', 'Food', 'Other', 'Savings', 'Transportation'],
              hasMoreTransactions: false,
              weeklyBalancePoints: <BalancePoint>[
                BalancePoint(label: 'Mon', balance: 0),
                BalancePoint(label: 'Tue', balance: 0),
                BalancePoint(label: 'Wed', balance: 0),
                BalancePoint(label: 'Thu', balance: 0),
                BalancePoint(label: 'Fri', balance: 0),
                BalancePoint(label: 'Sat', balance: 0),
                BalancePoint(label: 'Sun', balance: 0),
              ],
            );

  MoneyManagerSnapshot _snapshot;

  List<TransactionRecord> get _allTransactions => _snapshot.transactions;

  int _nextId = 1000;

  @override
  Future<TransactionRecord> addTransaction({
    required int amount,
    String? category,
    String? description,
    required bool isAddition,
  }) async {
    final transaction = TransactionRecord(
      id: _nextId++,
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
      transactions: <TransactionRecord>[transaction, ..._allTransactions],
      categories: updatedCategories,
      hasMoreTransactions: false,
      weeklyBalancePoints: _snapshot.weeklyBalancePoints,
    );

    return transaction;
  }

  @override
  Future<void> deleteTransaction(int id) async {
    final transaction = _allTransactions.firstWhere((t) => t.id == id);
    final updatedBalance = _snapshot.balance - (transaction.isAddition ? transaction.amount : -transaction.amount);

    _snapshot = MoneyManagerSnapshot(
      balance: updatedBalance,
      transactions: _allTransactions.where((t) => t.id != id).toList(growable: false),
      categories: _snapshot.categories,
      hasMoreTransactions: _snapshot.hasMoreTransactions,
      weeklyBalancePoints: _snapshot.weeklyBalancePoints,
    );
  }

  @override
  Future<MoneyManagerSnapshot> loadSnapshot({int transactionLimit = 10}) async {
    final visibleTransactions = _allTransactions.take(transactionLimit).toList(growable: false);
    return MoneyManagerSnapshot(
      balance: _snapshot.balance,
      transactions: visibleTransactions,
      categories: _snapshot.categories,
      hasMoreTransactions: _allTransactions.length > transactionLimit,
      weeklyBalancePoints: _buildWeeklyBalancePoints(),
    );
  }

  @override
  Future<TransactionPage> loadMoreTransactions({
    required TransactionRecord beforeTransaction,
    int transactionLimit = 10,
  }) async {
    final index = _allTransactions.indexWhere((transaction) => transaction.id == beforeTransaction.id);
    if (index < 0) {
      return const TransactionPage(
        transactions: <TransactionRecord>[],
        hasMoreTransactions: false,
      );
    }

    final start = index + 1;
    final end = start + transactionLimit > _allTransactions.length
        ? _allTransactions.length
        : start + transactionLimit;

    return TransactionPage(
      transactions: _allTransactions.sublist(start, end),
      hasMoreTransactions: end < _allTransactions.length,
    );
  }

  List<BalancePoint> _buildWeeklyBalancePoints() {
    return <BalancePoint>[
      const BalancePoint(label: 'Mon', balance: 0),
      const BalancePoint(label: 'Tue', balance: 0),
      const BalancePoint(label: 'Wed', balance: 0),
      const BalancePoint(label: 'Thu', balance: 0),
      const BalancePoint(label: 'Fri', balance: 0),
      const BalancePoint(label: 'Sat', balance: 0),
      const BalancePoint(label: 'Sun', balance: 0),
    ];
  }
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_homeWidgetChannel, (MethodCall call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_homeWidgetChannel, null);
  });

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
        hasMoreTransactions: false,
        weeklyBalancePoints: const <BalancePoint>[
          BalancePoint(label: 'Mon', balance: 0),
          BalancePoint(label: 'Tue', balance: 0),
          BalancePoint(label: 'Wed', balance: 0),
          BalancePoint(label: 'Thu', balance: 0),
          BalancePoint(label: 'Fri', balance: 0),
          BalancePoint(label: 'Sat', balance: 0),
          BalancePoint(label: 'Sun', balance: 0),
        ],
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
    // Avoid pumpAndSettle here: it pumps far enough to run past the
    // SnackBar's auto-dismiss duration, hiding it before we can tap Undo.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(repository._snapshot.transactions.first.description, 'Lunch with client');
    expect(repository._snapshot.transactions.first.category, 'Food');
    expect(repository._snapshot.categories.contains('Lunch with client'), isFalse);
    expect(repository._snapshot.balance, 300);

    expect(find.widgetWithText(SnackBarAction, 'Undo'), findsOneWidget);

    await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository._snapshot.balance, 250);
    expect(repository._snapshot.transactions, hasLength(1));
    expect(find.textContaining('₱250'), findsWidgets);
  });

  testWidgets('loads only the latest 10 transactions and pages older ones on demand',
      (WidgetTester tester) async {
    final transactions = List<TransactionRecord>.generate(
      12,
      (index) => TransactionRecord(
        id: index + 1,
        amount: 10,
        category: 'Food',
        description: 'Txn ${index + 1}',
        isAddition: true,
        createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
      ),
    )..sort((first, second) => second.createdAt.compareTo(first.createdAt));

    final repository = FakeMoneyManagerRepository(
      initialSnapshot: MoneyManagerSnapshot(
        balance: 120,
        transactions: transactions,
        categories: <String>['Bills', 'Entertainment', 'Food', 'Other', 'Savings', 'Transportation'],
        hasMoreTransactions: true,
        weeklyBalancePoints: const <BalancePoint>[
          BalancePoint(label: 'Mon', balance: 0),
          BalancePoint(label: 'Tue', balance: 0),
          BalancePoint(label: 'Wed', balance: 0),
          BalancePoint(label: 'Thu', balance: 0),
          BalancePoint(label: 'Fri', balance: 0),
          BalancePoint(label: 'Sat', balance: 0),
          BalancePoint(label: 'Sun', balance: 0),
        ],
      ),
    );

    final firstPage = await repository.loadSnapshot(transactionLimit: 10);
    expect(firstPage.transactions, hasLength(10));
    expect(firstPage.hasMoreTransactions, isTrue);

    await tester.pumpWidget(MyApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, 'Load more'),
      400,
    );
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNWidgets(10));

    await tester.tap(find.widgetWithText(TextButton, 'Load more'));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNWidgets(12));
    expect(find.widgetWithText(TextButton, 'Load more'), findsNothing);
  });
}
