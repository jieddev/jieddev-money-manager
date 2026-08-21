import 'package:flutter/material.dart';

import '../../core/currency_formatter.dart';
import '../../core/date_formatter.dart';
import '../../data/money_manager_repository.dart';
import 'enter_balance_dialog.dart';
import 'home_widget_sync_service.dart';
import 'transaction_entry_page.dart';
import 'widgets/balance_chart_card.dart';

class MoneyManagerHomePage extends StatefulWidget {
  const MoneyManagerHomePage({super.key, required this.repository});

  final MoneyManagerRepository repository;

  @override
  State<MoneyManagerHomePage> createState() => _MoneyManagerHomePageState();
}

class _MoneyManagerHomePageState extends State<MoneyManagerHomePage> {
  final HomeWidgetSyncService _widgetSyncService = HomeWidgetSyncService();

  int _balance = 0;
  int _savingsBalance = 0;
  final List<TransactionRecord> _transactions = <TransactionRecord>[];
  List<String> _categories = <String>['__custom__'];
  List<BalancePoint> _weeklyBalancePoints = const <BalancePoint>[];
  bool _isLoading = true;
  bool _isLoadingMoreTransactions = false;
  bool _hasMoreTransactions = false;
  static const int _transactionsPageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    final snapshot = await widget.repository.loadSnapshot(
      transactionLimit: _transactionsPageSize,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _balance = snapshot.balance;
      _savingsBalance = snapshot.savingsBalance;
      _transactions
        ..clear()
        ..addAll(snapshot.transactions);
      _categories = <String>[...snapshot.categories, '__custom__'];
      _weeklyBalancePoints = snapshot.weeklyBalancePoints;
      _hasMoreTransactions = snapshot.hasMoreTransactions;
      _isLoading = false;
      _isLoadingMoreTransactions = false;
    });

    await _widgetSyncService.sync(snapshot);
  }

  Future<void> _loadMoreTransactions() async {
    if (_isLoadingMoreTransactions ||
        !_hasMoreTransactions ||
        _transactions.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingMoreTransactions = true;
    });

    final olderTransactions = await widget.repository.loadMoreTransactions(
      beforeTransaction: _transactions.last,
      transactionLimit: _transactionsPageSize,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _transactions.addAll(olderTransactions.transactions);
      _hasMoreTransactions = olderTransactions.hasMoreTransactions;
      _isLoadingMoreTransactions = false;
    });
  }

  List<Widget> _buildBodyChildren(BuildContext context) {
    final children = <Widget>[
      const SizedBox(height: 12),
      Text(
        'Current balance',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              Text(
                formatCurrency(_balance),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Savings: ${formatCurrency(_savingsBalance)}',
        textAlign: TextAlign.start,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _openTransactionPage,
              label: const Text('Update Money'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _openEnterBalanceDialog,
              label: const Text('Set Balance'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
    ];

    if (_isLoading) {
      children.add(
        const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
      return children;
    }

    children.addAll(<Widget>[
      BalanceChartCard(points: _weeklyBalancePoints),
      const SizedBox(height: 24),
      Text(
        'Transaction history',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      if (_transactions.isEmpty)
        const Center(child: Text('No transactions yet.'))
      else
        Column(
          children: [
            for (var index = 0; index < _transactions.length; index++) ...[
              Card(
                elevation: 0,
                color: _transactions[index].isSavings
                    ? Colors.green.withValues(alpha: 0.12)
                    : null,
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      _transactions[index].isAddition
                          ? Icons.add
                          : Icons.remove,
                    ),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_transactions[index].isAddition ? '+' : '-'}${formatCurrency(_transactions[index].amount)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: _transactions[index].isAddition
                                  ? Colors.green[700]
                                  : Colors.red[700],
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(_transactions[index].displayText),
                    ],
                  ),
                  subtitle: Text(formatDate(_transactions[index].createdAt)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _editTransaction(_transactions[index]),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            _deleteTransaction(_transactions[index]),
                      ),
                    ],
                  ),
                ),
              ),
              if (index < _transactions.length - 1) const SizedBox(height: 12),
            ],
            if (_hasMoreTransactions)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton(
                  onPressed: _isLoadingMoreTransactions
                      ? null
                      : _loadMoreTransactions,
                  child: Text(
                    _isLoadingMoreTransactions
                        ? 'Loading more...'
                        : 'Load more',
                  ),
                ),
              ),
          ],
        ),
    ]);

    return children;
  }

  Future<void> _openTransactionPage() async {
    final transaction = await Navigator.of(context).push<TransactionEntry>(
      MaterialPageRoute(
        builder: (context) => TransactionEntryPage(
          title: 'Log',
          categories: _categories,
          actionLabel: 'Update',
        ),
      ),
    );

    if (transaction == null || !mounted) return;

    await widget.repository.addTransaction(
      amount: transaction.amount,
      category: transaction.category,
      description: transaction.description,
      isAddition: transaction.isAddition,
    );

    await _loadSnapshot();

    if (!mounted) return;

    final transactionLabel =
        transaction.category != null && transaction.description != null
        ? '${transaction.category} — ${transaction.description}'
        : transaction.category ?? transaction.description;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${transaction.isAddition ? 'Added' : 'Subtracted'} ${formatCurrency(transaction.amount)} in $transactionLabel',
        ),
      ),
    );
  }

  Future<void> _openSavingsEntryPage() async {
    final transaction = await Navigator.of(context).push<TransactionEntry>(
      MaterialPageRoute(
        builder: (context) => TransactionEntryPage(
          title: 'Savings',
          categories: _categories,
          actionLabel: 'Update savings',
        ),
      ),
    );

    if (transaction == null || !mounted) return;

    await widget.repository.addTransaction(
      amount: transaction.amount,
      category: transaction.category,
      description: transaction.description,
      isAddition: transaction.isAddition,
      allowSplit: false,
      isSavings: true,
    );

    await _loadSnapshot();

    if (!mounted) return;

    final transactionLabel =
        transaction.category != null && transaction.description != null
        ? '${transaction.category} — ${transaction.description}'
        : transaction.category ?? transaction.description;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${transaction.isAddition ? 'Added' : 'Subtracted'} ${formatCurrency(transaction.amount)} '
          '${transaction.isAddition ? 'to' : 'from'} savings${transactionLabel != null ? ' in $transactionLabel' : ''}',
        ),
      ),
    );
  }

  Future<void> _openEnterBalanceDialog() async {
    final newBalance = await showDialog<int>(
      context: context,
      builder: (context) => EnterBalanceDialog(currentBalance: _balance),
    );
    if (newBalance == null || !mounted) return;

    final difference = newBalance - _balance;
    if (difference == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Balance already matches')));
      return;
    }

    await widget.repository.addTransaction(
      amount: difference.abs(),
      category: null,
      description: 'Balance adjustment',
      isAddition: difference > 0,
      allowSplit: false,
    );

    await _loadSnapshot();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Balance set to ${formatCurrency(newBalance)}')),
    );
  }

  Future<void> _editTransaction(TransactionRecord transaction) async {
    final updated = await Navigator.of(context).push<TransactionEntry>(
      MaterialPageRoute(
        builder: (context) => TransactionEntryPage(
          title: 'Edit transaction',
          categories: _categories,
          actionLabel: 'Save',
          initialEntry: TransactionEntry(
            amount: transaction.amount,
            category: transaction.category,
            description: transaction.description,
            isAddition: transaction.isAddition,
          ),
        ),
      ),
    );

    if (updated == null || !mounted) return;

    await widget.repository.updateTransaction(
      id: transaction.id,
      amount: updated.amount,
      category: updated.category,
      description: updated.description,
      isAddition: updated.isAddition,
    );

    await _loadSnapshot();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Transaction updated')));
  }

  Future<void> _deleteTransaction(TransactionRecord transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(
          'This will remove "${transaction.displayText}" and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await widget.repository.deleteTransaction(transaction.id);
    await _loadSnapshot();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Transaction deleted')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Money Manager'), centerTitle: true),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainerHighest,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(children: _buildBodyChildren(context)),
          ),
        ),
      ),
    );
  }
}
