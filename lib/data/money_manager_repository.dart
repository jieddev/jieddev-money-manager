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
  });

  final int id;
  final int amount;
  final String? category;
  final String? description;
  final bool isAddition;
  final DateTime createdAt;

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
  });

  final int balance;
  final List<TransactionRecord> transactions;
  final List<String> categories;
  final bool hasMoreTransactions;
  final List<BalancePoint> weeklyBalancePoints;
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
  });

  Future<void> deleteTransaction(int id);
}

class SqliteMoneyManagerRepository implements MoneyManagerRepository {
  SqliteMoneyManagerRepository({String? databaseName})
      : _databaseName = databaseName ?? 'money_manager.db';

  final String _databaseName;
  Database? _database;

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
      version: 2,
      onCreate: (database, version) async {
        await _createSchema(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateTransactionsToDescriptionAwareSchema(database);
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
  }) async {
    if ((category == null || category.isEmpty) &&
        (description == null || description.isEmpty)) {
      throw ArgumentError('Either category or description must be provided.');
    }

    final db = await _db;
    final createdAt = DateTime.now().toUtc();
    final id = await db.insert(
      'transactions',
      <String, Object?>{
        'amount': amount,
        'category': category,
        'description': description,
        'is_addition': isAddition ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      },
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
      createdAt: createdAt,
    );
  }

  @override
  Future<void> deleteTransaction(int id) async {
    final db = await _db;
    await db.delete('transactions', where: 'id = ?', whereArgs: <Object?>[id]);
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
        created_at TEXT NOT NULL
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

  TransactionRecord _transactionFromRow(Map<String, Object?> row) {
    return TransactionRecord(
      id: row['id'] as int,
      amount: row['amount'] as int,
      category: row['category'] as String?,
      description: row['description'] as String?,
      isAddition: (row['is_addition'] as int) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
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
      WHERE created_at < ?
      ''',
      <Object?>[startDate.toIso8601String()],
    );
    var runningBalance = (balanceBeforeStartRows.first['balance'] as int?) ?? 0;

    final dailyRows = await db.rawQuery(
      '''
      SELECT substr(created_at, 1, 10) AS day,
             COALESCE(SUM(CASE WHEN is_addition = 1 THEN amount ELSE -amount END), 0) AS delta
      FROM transactions
      WHERE created_at >= ? AND created_at < ?
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