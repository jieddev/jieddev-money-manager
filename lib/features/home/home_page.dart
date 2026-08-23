import 'package:flutter/material.dart';

import '../../core/currency_formatter.dart';
import '../../data/money_manager_repository.dart';
import 'enter_balance_dialog.dart';
import 'envelope_transaction_page.dart';
import 'home_widget_sync_service.dart';
import 'transaction_entry_page.dart';
import 'widgets/balance_chart_card.dart';
import 'widgets/budget_breakdown_card.dart';
import 'widgets/recent_transactions_card.dart';

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
  int _needsBalance = 0;
  int _rewardFundBalance = 0;
  int _emergencyFundBalance = 0;
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
      _needsBalance = snapshot.needsBalance;
      _rewardFundBalance = snapshot.rewardFundBalance;
      _emergencyFundBalance = snapshot.emergencyFundBalance;
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

  static const int _needsMaxPerYear = 50000;
  static const int _rewardFundMaxPerYear = 10000;
  static const int _savingsMaxPerYear = 100000;
  static const int _emergencyFundMaxPerYear = 20000;

  List<EnvelopeBudget> get _envelopeBudgets => [
    EnvelopeBudget(
      envelope: Envelope.needs,
      label: 'Needs',
      percentage: 40,
      balance: _needsBalance,
      maxPerYear: _needsMaxPerYear,
    ),
    EnvelopeBudget(
      envelope: Envelope.rewardFund,
      label: 'Reward Fund/Wants',
      percentage: 20,
      balance: _rewardFundBalance,
      maxPerYear: _rewardFundMaxPerYear,
    ),
    EnvelopeBudget(
      envelope: Envelope.savings,
      label: 'Savings',
      percentage: 30,
      balance: _savingsBalance,
      maxPerYear: _savingsMaxPerYear,
    ),
    EnvelopeBudget(
      envelope: Envelope.emergencyFund,
      label: 'Emergency Fund',
      percentage: 10,
      balance: _emergencyFundBalance,
      maxPerYear: _emergencyFundMaxPerYear,
    ),
  ];

  List<Widget> _buildBodyChildren(BuildContext context) {
    final children = <Widget>[
      const SizedBox(height: 12),
      Text(
        'Overall Balance',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        formatCurrency(
          _balance +
              _needsBalance +
              _rewardFundBalance +
              _savingsBalance +
              _emergencyFundBalance,
        ),
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        'Spare Balance: ${formatCurrency(_balance)}',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 24),
      Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              onPressed: _openTransactionPage,
              child: const Text('Update Money'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                  side: const BorderSide(color: Colors.black),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              onPressed: _openEnterBalanceDialog,
              child: const Text('Set Balance'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      BudgetBreakdownCard(
        budgets: _envelopeBudgets,
        onTapEnvelope: _openEnvelopeEntryPage,
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
      RecentTransactionsCard(
        transactions: _transactions,
        hasMoreTransactions: _hasMoreTransactions,
        isLoadingMore: _isLoadingMoreTransactions,
        onLoadMore: _loadMoreTransactions,
        onEdit: _editTransaction,
        onDelete: _deleteTransaction,
      ),
      const SizedBox(height: 24),
      BalanceChartCard(points: _weeklyBalancePoints),
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

  int _balanceFor(Envelope envelope) => switch (envelope) {
    Envelope.savings => _savingsBalance,
    Envelope.needs => _needsBalance,
    Envelope.rewardFund => _rewardFundBalance,
    Envelope.emergencyFund => _emergencyFundBalance,
  };

  Future<void> _openEnvelopeEntryPage(Envelope envelope) async {
    final transaction = await Navigator.of(context).push<TransactionEntry>(
      MaterialPageRoute(
        builder: (context) => EnvelopeTransactionPage(
          envelope: envelope,
          envelopeBalance: _balanceFor(envelope),
          overallBalance: _balance,
        ),
      ),
    );

    if (transaction == null || !mounted) return;

    await widget.repository.addTransaction(
      amount: transaction.amount,
      category: envelope.categoryMarker,
      description: transaction.description,
      isAddition: transaction.isAddition,
      isSavings: true,
    );

    await _loadSnapshot();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${transaction.isAddition ? 'Added' : 'Deducted'} ${formatCurrency(transaction.amount)} '
          '${transaction.isAddition ? 'to' : 'from'} ${envelope.label}',
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
      appBar: AppBar(
        title: Text(
          'JIEDDEV MONEY MANAGER',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: false,
      ),
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
