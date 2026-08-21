import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.amount,
    required this.category,
    required this.description,
    required this.isAddition,
    required this.createdAt,
    this.isSavings = false,
  });

  final int id;
  final int amount;
  final String? category;
  final String? description;
  final bool isAddition;
  final DateTime createdAt;
  final bool isSavings;

  String get displayText {
    final hasCategory = category != null && category!.isNotEmpty;
    final hasDescription = description != null && description!.isNotEmpty;

    if (hasCategory && hasDescription) {
      return '$category — $description';
    }

    if (hasCategory) {
      return category!;
    }

    if (hasDescription) {
      return description!;
    }

    return '';
  }
}

class MoneyManagerSnapshot {
  const MoneyManagerSnapshot({
    required this.balance,
    required this.transactions,
    required this.categories,
    required this.hasMoreTransactions,
    required this.weeklyBalancePoints,
    this.savingsBalance = 0,
  });

  final int balance;
  final List<TransactionRecord> transactions;
  final List<String> categories;
  final bool hasMoreTransactions;
  final List<BalancePoint> weeklyBalancePoints;
  final int savingsBalance;
}

class BalancePoint {
  const BalancePoint({required this.label, required this.balance});

  final String label;
  final int balance;
}

class TransactionPage {
  const TransactionPage({
    required this.transactions,
    required this.hasMoreTransactions,
  });

  final List<TransactionRecord> transactions;
  final bool hasMoreTransactions;
}

abstract class MoneyManagerRepository {
  Future<MoneyManagerSnapshot> loadSnapshot({int transactionLimit = 10});

  Future<TransactionPage> loadMoreTransactions({
    required TransactionRecord beforeTransaction,
    int transactionLimit = 10,
  });

  Future<TransactionRecord> addTransaction({
    required int amount,
    String? category,
    String? description,
    required bool isAddition,
    bool allowSplit = true,
    bool isSavings = false,
  });

  Future<void> deleteTransaction(int id);

  Future<TransactionRecord> updateTransaction({
    required int id,
    required int amount,
    String? category,
    String? description,
    required bool isAddition,
  });

  Future<bool> loadSaveTenPercentEnabled();

  Future<void> setSaveTenPercentEnabled(bool enabled);
}

class SqliteMoneyManagerRepository implements MoneyManagerRepository {
  SqliteMoneyManagerRepository({String? databaseName})
      : _databaseName = databaseName ?? 'money_manager.db';

  final String _databaseName;
  Database? _database;

  static const String _saveTenPercentSettingKey = 'save_ten_percent_enabled';

  static const List<String> _defaultCategories = <String>[
    'Food',
    'Transportation',
    'Bills',
    'Entertainment',
    'Savings',
    'Other',
  ];

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final databasesPath = await getDatabasesPath();
    final db = await openDatabase(
      path.join(databasesPath, _databaseName),
      version: 3,
      onCreate: (database, version) async {
        await _createSchema(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateTransactionsToDescriptionAwareSchema(database);
        }
        if (oldVersion < 3) {
          await _addSavingsSupport(database);
        }
      },
    );

    _database = db;
    return db;
  }

  @override
  Future<MoneyManagerSnapshot> loadSnapshot({
    int transactionLimit = 10,
  }) async {
    final db = await _db;
    final categoryRows = await db.query('categories', orderBy: 'name ASC');
    final balanceRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE WHEN is_addition = 1 THEN amount ELSE -amount END), 0) AS balance
      FROM transactions
      WHERE is_savings = 0
      ''',
    );
    final savingsBalanceRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE WHEN is_addition = 1 THEN amount ELSE -amount END), 0) AS savings_balance
      FROM transactions
      WHERE is_savings = 1
      ''',
    );
    final transactionRows = await db.query(
      'transactions',
      orderBy: 'created_at DESC, id DESC',
      limit: transactionLimit + 1,
    );

    final hasMoreTransactions = transactionRows.length > transactionLimit;
    final limitedRows = hasMoreTransactions
        ? transactionRows.take(transactionLimit)
        : transactionRows;

    final transactions = limitedRows
        .map(_transactionFromRow)
        .toList(growable: false);

    final weeklyBalancePoints = await _loadWeeklyBalancePoints(db);

    return MoneyManagerSnapshot(
      balance: (balanceRows.first['balance'] as int?) ?? 0,
      transactions: transactions,
      categories: categoryRows.map((row) => row['name'] as String).toList(growable: false),
      hasMoreTransactions: hasMoreTransactions,
      weeklyBalancePoints: weeklyBalancePoints,
      savingsBalance: (savingsBalanceRows.first['savings_balance'] as int?) ?? 0,
    );
  }

  @override
  Future<TransactionPage> loadMoreTransactions({
    required TransactionRecord beforeTransaction,
    int transactionLimit = 10,
  }) async {
    final db = await _db;
    final beforeCreatedAt = beforeTransaction.createdAt.toUtc().toIso8601String();
    final transactionRows = await db.query(
      'transactions',
      where: '(created_at < ? OR (created_at = ? AND id < ?))',
      whereArgs: <Object?>[
        beforeCreatedAt,
        beforeCreatedAt,
        beforeTransaction.id,
      ],
      orderBy: 'created_at DESC, id DESC',
      limit: transactionLimit + 1,
    );

    final hasMoreTransactions = transactionRows.length > transactionLimit;
    final limitedRows = hasMoreTransactions
        ? transactionRows.take(transactionLimit)
        : transactionRows;

    return TransactionPage(
      transactions: limitedRows.map(_transactionFromRow).toList(growable: false),
      hasMoreTransactions: hasMoreTransactions,
    );
  }

  @override
  Future<TransactionRecord> addTransaction({
    required int amount,
    String? category,
    String? description,
    required bool isAddition,
    bool allowSplit = true,
    bool isSavings = false,
  }) async {
    if ((category == null || category.isEmpty) &&
        (description == null || description.isEmpty)) {
      throw ArgumentError('Either category or description must be provided.');
    }

    final db = await _db;
    final createdAt = DateTime.now().toUtc();

    final shouldAttemptSplit = !isSavings && isAddition && allowSplit && amount > 0;
    final savingsCut = shouldAttemptSplit ? (amount * 10) ~/ 100 : 0;
    final isSplitting = savingsCut > 0 && await _isSaveTenPercentEnabled(db);
    final mainAmount = isSplitting ? amount - savingsCut : amount;

    final mainId = await db.insert(
      'transactions',
      <String, Object?>{
        'amount': mainAmount,
        'category': category,
        'description': description,
        'is_addition': isAddition ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'is_savings': isSavings ? 1 : 0,
        'linked_transaction_id': null,
      },
    );

    if (isSplitting) {
      await db.insert(
        'transactions',
        <String, Object?>{
          'amount': savingsCut,
          'category': category,
          'description': description,
          'is_addition': 1,
          'created_at': createdAt.toIso8601String(),
          'is_savings': 1,
          'linked_transaction_id': mainId,
        },
      );
    }

    if (category != null && category.isNotEmpty) {
      await db.insert(
        'categories',
        <String, Object?>{'name': category},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    return TransactionRecord(
      id: mainId,
      amount: mainAmount,
      category: category,
      description: description,
      isAddition: isAddition,
      createdAt: createdAt,
      isSavings: isSavings,
    );
  }

  @override
  Future<void> deleteTransaction(int id) async {
    final db = await _db;
    await db.delete(
      'transactions',
      where: '''
        id = ?
        OR linked_transaction_id = ?
        OR id = (SELECT linked_transaction_id FROM transactions WHERE id = ?)
      ''',
      whereArgs: <Object?>[id, id, id],
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
    if ((category == null || category.isEmpty) &&
        (description == null || description.isEmpty)) {
      throw ArgumentError('Either category or description must be provided.');
    }

    final db = await _db;
    final rows = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Transaction $id not found.');
    }
    final existing = _transactionFromRow(rows.first);

    await db.update(
      'transactions',
      <String, Object?>{
        'amount': amount,
        'category': category,
        'description': description,
        'is_addition': isAddition ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );

    if (category != null && category.isNotEmpty) {
      await db.insert(
        'categories',
        <String, Object?>{'name': category},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    return TransactionRecord(
      id: id,
      amount: amount,
      category: category,
      description: description,
      isAddition: isAddition,
      createdAt: existing.createdAt,
      isSavings: existing.isSavings,
    );
  }

  @override
  Future<bool> loadSaveTenPercentEnabled() async {
    final db = await _db;
    return _isSaveTenPercentEnabled(db);
  }

  @override
  Future<void> setSaveTenPercentEnabled(bool enabled) async {
    final db = await _db;
    await db.insert(
      'settings',
      <String, Object?>{
        'key': _saveTenPercentSettingKey,
        'value': enabled ? '1' : '0',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> _isSaveTenPercentEnabled(Database db) async {
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: <Object?>[_saveTenPercentSettingKey],
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['value'] == '1';
  }

  Future<void> _createSchema(Database database) async {
    await database.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
    await database.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        category TEXT,
        description TEXT,
        is_addition INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        is_savings INTEGER NOT NULL DEFAULT 0,
        linked_transaction_id INTEGER
      )
    ''');
    await database.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    final batch = database.batch();
    for (final category in _defaultCategories) {
      batch.insert(
        'categories',
        <String, Object?>{'name': category},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _migrateTransactionsToDescriptionAwareSchema(
    Database database,
  ) async {
    await database.execute('ALTER TABLE transactions RENAME TO transactions_old');
    await database.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        category TEXT,
        description TEXT,
        is_addition INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await database.execute('''
      INSERT INTO transactions (id, amount, category, description, is_addition, created_at)
      SELECT id, amount, category, NULL, is_addition, created_at
      FROM transactions_old
    ''');
    await database.execute('DROP TABLE transactions_old');
  }

  Future<void> _addSavingsSupport(Database database) async {
    await database.execute(
      'ALTER TABLE transactions ADD COLUMN is_savings INTEGER NOT NULL DEFAULT 0',
    );
    await database.execute(
      'ALTER TABLE transactions ADD COLUMN linked_transaction_id INTEGER',
    );
    await database.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  TransactionRecord _transactionFromRow(Map<String, Object?> row) {
    return TransactionRecord(
      id: row['id'] as int,
      amount: row['amount'] as int,
      category: row['category'] as String?,
      description: row['description'] as String?,
      isAddition: (row['is_addition'] as int) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      isSavings: (row['is_savings'] as int? ?? 0) == 1,
    );
  }

  Future<List<BalancePoint>> _loadWeeklyBalancePoints(Database db) async {
    final today = DateTime.now().toUtc();
    final startDate = DateTime.utc(today.year, today.month, today.day)
        .subtract(const Duration(days: 6));
    final endExclusive = startDate.add(const Duration(days: 7));

    final balanceBeforeStartRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE WHEN is_addition = 1 THEN amount ELSE -amount END), 0) AS balance
      FROM transactions
      WHERE created_at < ? AND is_savings = 0
      ''',
      <Object?>[startDate.toIso8601String()],
    );
    var runningBalance = (balanceBeforeStartRows.first['balance'] as int?) ?? 0;

    final dailyRows = await db.rawQuery(
      '''
      SELECT substr(created_at, 1, 10) AS day,
             COALESCE(SUM(CASE WHEN is_addition = 1 THEN amount ELSE -amount END), 0) AS delta
      FROM transactions
      WHERE created_at >= ? AND created_at < ? AND is_savings = 0
      GROUP BY substr(created_at, 1, 10)
      ORDER BY day ASC
      ''',
      <Object?>[
        startDate.toIso8601String(),
        endExclusive.toIso8601String(),
      ],
    );

    final balanceByDay = <String, int>{};
    for (final row in dailyRows) {
      balanceByDay[row['day'] as String] = (row['delta'] as int?) ?? 0;
    }

    final points = <BalancePoint>[];
    for (var offset = 0; offset < 7; offset++) {
      final day = startDate.add(Duration(days: offset));
      final dayKey = day.toIso8601String().substring(0, 10);
      runningBalance += balanceByDay[dayKey] ?? 0;
      points.add(
        BalancePoint(
          label: _weekdayLabel(day.weekday),
          balance: runningBalance,
        ),
      );
    }

    return points;
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }
}