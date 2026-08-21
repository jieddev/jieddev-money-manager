import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jieddev_money_manager/data/money_manager_repository.dart';
import 'package:jieddev_money_manager/features/settings/settings_page.dart';
import 'package:jieddev_money_manager/main.dart';

// The app syncs to the home screen widget through this platform channel on
// every load/mutation. Without a mock handler the call never resolves in a
// widget test (there's no platform on the other end), which stalls anything
// awaiting `_loadSnapshot()` — including the SnackBar shown after a save.
const _homeWidgetChannel = MethodChannel('home_widget');

class FakeMoneyManagerRepository implements MoneyManagerRepository {
  FakeMoneyManagerRepository({
    MoneyManagerSnapshot? initialSnapshot,
    bool initialSaveTenPercentEnabled = false,
  })  : _saveTenPercentEnabled = initialSaveTenPercentEnabled,
        _snapshot =
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
  bool _saveTenPercentEnabled;
  final Map<int, int> _linkedIds = {};

  List<TransactionRecord> get _allTransactions => _snapshot.transactions;

  int _nextId = 1000;

  @override
  Future<TransactionRecord> addTransaction({
    required int amount,
    String? category,
    String? description,
    required bool isAddition,
    bool allowSplit = true,
    bool isSavings = false,
  }) async {
    final shouldAttemptSplit = !isSavings && isAddition && allowSplit && amount > 0;
    final savingsCut = shouldAttemptSplit ? (amount * 10) ~/ 100 : 0;
    final isSplitting = savingsCut > 0 && _saveTenPercentEnabled;
    final mainAmount = isSplitting ? amount - savingsCut : amount;

    final mainTransaction = TransactionRecord(
      id: _nextId++,
      amount: mainAmount,
      category: category,
      description: description,
      isAddition: isAddition,
      createdAt: DateTime.utc(2026, 1, 1),
      isSavings: isSavings,
    );

    var newTransactions = <TransactionRecord>[mainTransaction, ..._allTransactions];
    var updatedSavingsBalance = _snapshot.savingsBalance;

    if (isSplitting) {
      final savingsTransaction = TransactionRecord(
        id: _nextId++,
        amount: savingsCut,
        category: category,
        description: description,
        isAddition: true,
        createdAt: DateTime.utc(2026, 1, 1),
        isSavings: true,
      );
      newTransactions = <TransactionRecord>[savingsTransaction, ...newTransactions];
      _linkedIds[mainTransaction.id] = savingsTransaction.id;
      _linkedIds[savingsTransaction.id] = mainTransaction.id;
      updatedSavingsBalance += savingsCut;
    }

    if (isSavings) {
      updatedSavingsBalance += isAddition ? mainAmount : -mainAmount;
    }

    final updatedCategories = category == null
        ? _snapshot.categories
        : <String>{..._snapshot.categories, category}.toList();
    final updatedBalance = isSavings
        ? _snapshot.balance
        : _snapshot.balance + (isAddition ? mainAmount : -mainAmount);

    _snapshot = MoneyManagerSnapshot(
      balance: updatedBalance,
      transactions: newTransactions,
      categories: updatedCategories,
      hasMoreTransactions: false,
      weeklyBalancePoints: _snapshot.weeklyBalancePoints,
      savingsBalance: updatedSavingsBalance,
    );

    return mainTransaction;
  }

  @override
  Future<void> deleteTransaction(int id) async {
    final idsToRemove = <int>{id, if (_linkedIds[id] != null) _linkedIds[id]!};

    var updatedBalance = _snapshot.balance;
    var updatedSavingsBalance = _snapshot.savingsBalance;
    for (final removedId in idsToRemove) {
      final transaction = _allTransactions.firstWhere((t) => t.id == removedId);
      final delta = transaction.isAddition ? transaction.amount : -transaction.amount;
      if (transaction.isSavings) {
        updatedSavingsBalance -= delta;
      } else {
        updatedBalance -= delta;
      }
    }

    for (final removedId in idsToRemove) {
      _linkedIds.remove(removedId);
    }

    _snapshot = MoneyManagerSnapshot(
      balance: updatedBalance,
      transactions: _allTransactions.where((t) => !idsToRemove.contains(t.id)).toList(growable: false),
      categories: _snapshot.categories,
      hasMoreTransactions: _snapshot.hasMoreTransactions,
      weeklyBalancePoints: _snapshot.weeklyBalancePoints,
      savingsBalance: updatedSavingsBalance,
    );
  }

  @override
  Future<TransactionRecord> updateTransaction({
    required int id,
    required int amount,
    String? category,
    String? description,
    required bool isAddition,
  }) async {
    final index = _allTransactions.indexWhere((t) => t.id == id);
    final existing = _allTransactions[index];

    final updated = TransactionRecord(
      id: id,
      amount: amount,
      category: category,
      description: description,
      isAddition: isAddition,
      createdAt: existing.createdAt,
      isSavings: existing.isSavings,
    );

    final oldDelta = existing.isAddition ? existing.amount : -existing.amount;
    final newDelta = isAddition ? amount : -amount;
    final diff = newDelta - oldDelta;

    var updatedBalance = _snapshot.balance;
    var updatedSavingsBalance = _snapshot.savingsBalance;
    if (existing.isSavings) {
      updatedSavingsBalance += diff;
    } else {
      updatedBalance += diff;
    }

    final updatedCategories = category == null
        ? _snapshot.categories
        : <String>{..._snapshot.categories, category}.toList();

    final newTransactions = List<TransactionRecord>.from(_allTransactions);
    newTransactions[index] = updated;

    _snapshot = MoneyManagerSnapshot(
      balance: updatedBalance,
      transactions: newTransactions,
      categories: updatedCategories,
      hasMoreTransactions: _snapshot.hasMoreTransactions,
      weeklyBalancePoints: _snapshot.weeklyBalancePoints,
      savingsBalance: updatedSavingsBalance,
    );

    return updated;
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
      savingsBalance: _snapshot.savingsBalance,
    );
  }

  @override
  Future<bool> loadSaveTenPercentEnabled() async => _saveTenPercentEnabled;

  @override
  Future<void> setSaveTenPercentEnabled(bool enabled) async {
    _saveTenPercentEnabled = enabled;
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(repository._snapshot.transactions.first.description, 'Lunch with client');
    expect(repository._snapshot.transactions.first.category, 'Food');
    expect(repository._snapshot.categories.contains('Lunch with client'), isFalse);
    expect(repository._snapshot.balance, 300);
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

  testWidgets('sets balance higher by recording an adjustment transaction',
      (WidgetTester tester) async {
    final repository = FakeMoneyManagerRepository(
      initialSnapshot: const MoneyManagerSnapshot(
        balance: 250,
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
      ),
    );

    await tester.pumpWidget(MyApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Set Balance'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '400');
    await tester.tap(find.widgetWithText(FilledButton, 'Set Balance'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(repository._snapshot.balance, 400);
    expect(repository._snapshot.transactions.first.isAddition, isTrue);
    expect(repository._snapshot.transactions.first.amount, 150);
    expect(repository._snapshot.transactions.first.category, isNull);
    expect(repository._snapshot.transactions.first.description, 'Balance adjustment');
  });

  testWidgets('sets balance lower by recording an adjustment transaction',
      (WidgetTester tester) async {
    final repository = FakeMoneyManagerRepository(
      initialSnapshot: const MoneyManagerSnapshot(
        balance: 250,
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
      ),
    );

    await tester.pumpWidget(MyApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Set Balance'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.widgetWithText(FilledButton, 'Set Balance'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(repository._snapshot.balance, 100);
    expect(repository._snapshot.transactions.first.isAddition, isFalse);
    expect(repository._snapshot.transactions.first.amount, 150);
  });

  testWidgets('entering the current balance does not record a transaction',
      (WidgetTester tester) async {
    final repository = FakeMoneyManagerRepository(
      initialSnapshot: const MoneyManagerSnapshot(
        balance: 250,
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
      ),
    );

    await tester.pumpWidget(MyApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Set Balance'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '250');
    await tester.tap(find.widgetWithText(FilledButton, 'Set Balance'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(repository._snapshot.balance, 250);
    expect(repository._snapshot.transactions, isEmpty);
    expect(find.text('Balance already matches'), findsOneWidget);
  });

  test('splits income into a main transaction and a linked savings transaction when enabled', () async {
    final repository = FakeMoneyManagerRepository(initialSaveTenPercentEnabled: true);

    final mainTransaction = await repository.addTransaction(
      amount: 1000,
      category: 'Food',
      description: null,
      isAddition: true,
    );

    expect(mainTransaction.amount, 900);
    expect(mainTransaction.isSavings, isFalse);
    expect(repository._snapshot.balance, 900);
    expect(repository._snapshot.savingsBalance, 100);
    expect(repository._snapshot.transactions, hasLength(2));
    expect(repository._snapshot.transactions.where((t) => t.isSavings).single.amount, 100);
  });

  test('does not split when the 10% cut floors to zero', () async {
    final repository = FakeMoneyManagerRepository(initialSaveTenPercentEnabled: true);

    await repository.addTransaction(
      amount: 5,
      category: 'Food',
      description: null,
      isAddition: true,
    );

    expect(repository._snapshot.transactions, hasLength(1));
    expect(repository._snapshot.balance, 5);
    expect(repository._snapshot.savingsBalance, 0);
  });

  test('main and savings amounts always reconstruct the original amount', () async {
    final repository = FakeMoneyManagerRepository(initialSaveTenPercentEnabled: true);

    for (var amount = 1; amount <= 25; amount++) {
      final balanceBefore = repository._snapshot.balance;
      final savingsBefore = repository._snapshot.savingsBalance;

      await repository.addTransaction(
        amount: amount,
        category: 'Food',
        description: null,
        isAddition: true,
      );

      final mainDelta = repository._snapshot.balance - balanceBefore;
      final savingsDelta = repository._snapshot.savingsBalance - savingsBefore;

      expect(mainDelta + savingsDelta, amount);
      expect(savingsDelta, (amount * 10) ~/ 100);
    }
  });

  test('balance adjustments are never split even when the setting is enabled', () async {
    final repository = FakeMoneyManagerRepository(initialSaveTenPercentEnabled: true);

    final transaction = await repository.addTransaction(
      amount: 153,
      category: null,
      description: 'Balance adjustment',
      isAddition: true,
      allowSplit: false,
    );

    expect(transaction.amount, 153);
    expect(repository._snapshot.balance, 153);
    expect(repository._snapshot.savingsBalance, 0);
    expect(repository._snapshot.transactions, hasLength(1));
  });

  test('income is not split when the setting is disabled', () async {
    final repository = FakeMoneyManagerRepository();

    await repository.addTransaction(
      amount: 1000,
      category: 'Food',
      description: null,
      isAddition: true,
    );

    expect(repository._snapshot.balance, 1000);
    expect(repository._snapshot.savingsBalance, 0);
    expect(repository._snapshot.transactions, hasLength(1));
  });

  test('deleting a split main transaction also removes its linked savings transaction', () async {
    final repository = FakeMoneyManagerRepository(initialSaveTenPercentEnabled: true);

    final mainTransaction = await repository.addTransaction(
      amount: 1000,
      category: 'Food',
      description: null,
      isAddition: true,
    );

    await repository.deleteTransaction(mainTransaction.id);

    expect(repository._snapshot.transactions, isEmpty);
    expect(repository._snapshot.balance, 0);
    expect(repository._snapshot.savingsBalance, 0);
  });

  test('save-10%-of-income setting persists through the repository', () async {
    final repository = FakeMoneyManagerRepository();

    expect(await repository.loadSaveTenPercentEnabled(), isFalse);

    await repository.setSaveTenPercentEnabled(true);

    expect(await repository.loadSaveTenPercentEnabled(), isTrue);
  });

  testWidgets(
      'recording income with the setting enabled splits 90/10 into savings and highlights the savings row',
      (WidgetTester tester) async {
    final repository = FakeMoneyManagerRepository(initialSaveTenPercentEnabled: true);

    await tester.pumpWidget(MyApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Update Money'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '1000');

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Update balance'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(repository._snapshot.balance, 900);
    expect(repository._snapshot.savingsBalance, 100);
    expect(repository._snapshot.transactions, hasLength(2));

    expect(find.text('Savings: ₱100.00'), findsOneWidget);
    expect(find.text('+₱100.00'), findsOneWidget);
    expect(find.text('+₱900.00'), findsOneWidget);

    final savingsCard = tester.widget<Card>(
      find.ancestor(of: find.text('+₱100.00'), matching: find.byType(Card)).first,
    );
    final mainCard = tester.widget<Card>(
      find.ancestor(of: find.text('+₱900.00'), matching: find.byType(Card)).first,
    );

    expect(savingsCard.color, isNotNull);
    expect(mainCard.color, isNull);
  });

  testWidgets('Set Balance does not split into savings even when the setting is enabled',
      (WidgetTester tester) async {
    final repository = FakeMoneyManagerRepository(
      initialSnapshot: const MoneyManagerSnapshot(
        balance: 250,
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
      ),
      initialSaveTenPercentEnabled: true,
    );

    await tester.pumpWidget(MyApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Set Balance'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '403');
    await tester.tap(find.widgetWithText(FilledButton, 'Set Balance'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(repository._snapshot.balance, 403);
    expect(repository._snapshot.savingsBalance, 0);
    expect(repository._snapshot.transactions, hasLength(1));
  });

  testWidgets('settings page persists the save-10% toggle across instances', (WidgetTester tester) async {
    final repository = FakeMoneyManagerRepository();

    await tester.pumpWidget(MaterialApp(home: SettingsPage(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.byType(SwitchListTile), findsOneWidget);
    var switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(switchTile.value, isFalse);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(switchTile.value, isTrue);

    await tester.pumpWidget(MaterialApp(home: SettingsPage(repository: repository)));
    await tester.pumpAndSettle();

    switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(switchTile.value, isTrue);
  });
}
