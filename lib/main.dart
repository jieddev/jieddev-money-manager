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
  static const int _transactionAmount = 10;

  int _balance = 0;

  Future<void> _adjustBalance({required bool add}) async {
    final controller = TextEditingController();

    final amountText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(add ? 'Add amount' : 'Subtract amount'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount',
            hintText: 'Enter a number',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    final amount = int.tryParse(amountText ?? '');
    if (amount == null) return;

    setState(() {
      _balance += add ? amount : -amount;
    });

    await HomeWidget.saveWidgetData<int>('balance', _balance);
    await HomeWidget.updateWidget(name: 'MoneyManagerWidgetProvider');
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
                        const SizedBox(height: 8),
                        Text(
                          'Tap add or subtract to change the total by \$$_transactionAmount.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
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
                        onPressed: () => _adjustBalance(add: true),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _adjustBalance(add: false),
                        icon: const Icon(Icons.remove),
                        label: const Text('Subtract'),
                      ),
                    ),
                  ],
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
    return '$prefix\$${amount.abs()}';
  }
}
