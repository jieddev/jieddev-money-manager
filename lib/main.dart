import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jieddev Money Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MoneyManagerHomePage(),
    );
  }
}

class MoneyManagerHomePage extends StatefulWidget {
  const MoneyManagerHomePage({super.key});

  @override
  State<MoneyManagerHomePage> createState() => _MoneyManagerHomePageState();
}

class _MoneyManagerHomePageState extends State<MoneyManagerHomePage> {
  static const List<String> _categories = <String>[
    'Food',
    'Transportation',
    'Bills',
    'Entertainment',
    'Savings',
    'Other',
    '__custom__',
  ];

  int _balance = 0;
  final List<TransactionRecord> _transactions = <TransactionRecord>[];

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

    setState(() {
      _balance += transaction.isAddition ? transaction.amount : -transaction.amount;
      _transactions.insert(
        0,
        TransactionRecord(
          amount: transaction.amount,
          category: transaction.category,
          isAddition: transaction.isAddition,
        ),
      );
    });

    await HomeWidget.saveWidgetData<int>('balance', _balance);
    await HomeWidget.updateWidget(name: 'MoneyManagerWidgetProvider');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${transaction.isAddition ? 'Added' : 'Subtracted'} ${_formatCurrency(transaction.amount)} in ${transaction.category}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Manager'),
        centerTitle: true,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Column(
                      children: [
                        Text(
                          _formatCurrency(_balance),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
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
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Transaction history',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _transactions.isEmpty
                      ? const Center(
                          child: Text('No transactions yet.'),
                        )
                      : ListView.separated(
                          itemCount: _transactions.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final transaction = _transactions[index];
                            return Card(
                              elevation: 0,
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Icon(
                                    transaction.isAddition ? Icons.add : Icons.remove,
                                  ),
                                ),
                                title: Text(transaction.category),
                                subtitle: Text(
                                  transaction.isAddition ? 'Added to balance' : 'Subtracted from balance',
                                ),
                                trailing: Text(
                                  '${transaction.isAddition ? '+' : '-'}${_formatCurrency(transaction.amount)}',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCurrency(int amount) {
    final prefix = amount < 0 ? '-' : '';
    return '$prefix₱${amount.abs()}';
  }
}

class TransactionEntry {
  const TransactionEntry({
    required this.amount,
    required this.category,
    required this.isAddition,
  });

  final int amount;
  final String category;
  final bool isAddition;
}

class TransactionRecord {
  const TransactionRecord({
    required this.amount,
    required this.category,
    required this.isAddition,
  });

  final int amount;
  final String category;
  final bool isAddition;
}

class TransactionEntryPage extends StatefulWidget {
  const TransactionEntryPage({
    super.key,
    required this.title,
    required this.categories,
    required this.actionLabel,
  });

  final String title;
  final List<String> categories;
  final String actionLabel;

  @override
  State<TransactionEntryPage> createState() => _TransactionEntryPageState();
}

class _TransactionEntryPageState extends State<TransactionEntryPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _customCategoryController = TextEditingController();
  String _selectedSign = '+';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.categories.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = int.tryParse(_amountController.text.trim());
    final category = _selectedCategory == '__custom__'
        ? _customCategoryController.text.trim()
        : _selectedCategory;

    if (amount == null || amount <= 0 || category == null || category.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      TransactionEntry(
        amount: amount,
        category: category,
        isAddition: _selectedSign == '+',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the amount and choose a category.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedSign,
                      decoration: const InputDecoration(
                        labelText: 'Sign',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem<String>(
                          value: '+',
                          child: Text('+'),
                        ),
                        DropdownMenuItem<String>(
                          value: '-',
                          child: Text('-'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSign = value ?? '+';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Enter a number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: widget.categories
                    .map(
                      (category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category == '__custom__' ? 'Custom category' : category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),
                if (_selectedCategory == '__custom__') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _customCategoryController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Custom category',
                      hintText: 'Enter category name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submit,
                child: Text('${widget.actionLabel} balance'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
