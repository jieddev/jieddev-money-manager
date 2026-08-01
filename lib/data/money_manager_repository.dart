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
  });

  final int balance;
  final List<TransactionRecord> transactions;
  final List<String> categories;
}

abstract class MoneyManagerRepository {
  Future<MoneyManagerSnapshot> loadSnapshot();

  Future<void> addTransaction({
    required int amount,
    String? category,
    String? description,
    required bool isAddition,
  });
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
  Future<MoneyManagerSnapshot> loadSnapshot() async {
    final db = await _db;
    final categoryRows = await db.query('categories', orderBy: 'name ASC');
    final transactionRows = await db.query(
      'transactions',
      orderBy: 'created_at DESC, id DESC',
    );

    final transactions = transactionRows
        .map(
          (row) => TransactionRecord(
            id: row['id'] as int,
            amount: row['amount'] as int,
            category: row['category'] as String?,
            description: row['description'] as String?,
            isAddition: (row['is_addition'] as int) == 1,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList(growable: false);

    final balance = transactions.fold<int>(
      0,
      (current, transaction) => current + (transaction.isAddition ? transaction.amount : -transaction.amount),
    );

    return MoneyManagerSnapshot(
      balance: balance,
      transactions: transactions,
      categories: categoryRows.map((row) => row['name'] as String).toList(growable: false),
    );
  }

  @override
  Future<void> addTransaction({
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
    await db.insert(
      'transactions',
      <String, Object?>{
        'amount': amount,
        'category': category,
        'description': description,
        'is_addition': isAddition ? 1 : 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

    if (category != null && category.isNotEmpty) {
      await db.insert(
        'categories',
        <String, Object?>{'name': category},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
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
}