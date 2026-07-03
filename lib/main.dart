import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'data/money_manager_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = SqliteMoneyManagerRepository();
  runApp(MyApp(repository: repository));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.repository});

  final MoneyManagerRepository repository;

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
      home: MoneyManagerHomePage(repository: repository),
    );
  }
}

class MoneyManagerHomePage extends StatefulWidget {
  const MoneyManagerHomePage({super.key, required this.repository});

  final MoneyManagerRepository repository;

  @override
  State<MoneyManagerHomePage> createState() => _MoneyManagerHomePageState();
}

class _MoneyManagerHomePageState extends State<MoneyManagerHomePage> {
  int _balance = 0;
  final List<TransactionRecord> _transactions = <TransactionRecord>[];
  List<String> _categories = <String>['__custom__'];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    final snapshot = await widget.repository.loadSnapshot();
    if (!mounted) {
      return;
    }

    setState(() {
      _balance = snapshot.balance;
      _transactions
        ..clear()
        ..addAll(snapshot.transactions);
      _categories = <String>[...snapshot.categories, '__custom__'];
      _isLoading = false;
    });

    await HomeWidget.saveWidgetData<int>('balance', _balance);
    await HomeWidget.updateWidget(name: 'MoneyManagerWidgetProvider');
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
                _formatCurrency(_balance),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
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
      _BalanceChartCard(points: _buildWeeklyBalanceSeries()),
      const SizedBox(height: 24),
      Text(
        'Transaction history',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      if (_transactions.isEmpty)
        const Center(child: Text('No transactions yet.'))
      else
        ListView.separated(
          itemCount: _transactions.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
                  transaction.isAddition
                      ? 'Added to balance'
                      : 'Subtracted from balance',
                ),
                trailing: Text(
                  '${transaction.isAddition ? '+' : '-'}${_formatCurrency(transaction.amount)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            );
          },
        ),
    ]);

    return children;
  }

  List<_DailyBalancePoint> _buildWeeklyBalanceSeries() {
    final today = DateTime.now();
    final startDate = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 6));
    final orderedTransactions = _transactions.toList()
      ..sort((first, second) => first.createdAt.compareTo(second.createdAt));

    final points = <_DailyBalancePoint>[];
    var runningBalance = 0;
    var cursor = 0;

    while (cursor < orderedTransactions.length &&
        orderedTransactions[cursor].createdAt.toLocal().isBefore(startDate)) {
      final transaction = orderedTransactions[cursor];
      runningBalance += transaction.isAddition
          ? transaction.amount
          : -transaction.amount;
      cursor++;
    }

    for (var offset = 0; offset < 7; offset++) {
      final day = startDate.add(Duration(days: offset));
      final nextDayStart = day.add(const Duration(days: 1));

      while (cursor < orderedTransactions.length &&
          orderedTransactions[cursor].createdAt.toLocal().isBefore(
            nextDayStart,
          )) {
        final transaction = orderedTransactions[cursor];
        runningBalance += transaction.isAddition
            ? transaction.amount
            : -transaction.amount;
        cursor++;
      }

      points.add(
        _DailyBalancePoint(
          label: _weekdayLabel(day.weekday),
          balance: runningBalance,
        ),
      );
    }

    return points;
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
      isAddition: transaction.isAddition,
    );

    await _loadSnapshot();

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

  String _formatCurrency(int amount) {
    final prefix = amount < 0 ? '-' : '';
    return '$prefix₱${amount.abs()}';
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

class _DailyBalancePoint {
  const _DailyBalancePoint({required this.label, required this.balance});

  final String label;
  final int balance;
}

class _BalanceChartCard extends StatelessWidget {
  const _BalanceChartCard({required this.points});

  final List<_DailyBalancePoint> points;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Balance by day',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('Last 7 days', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: _WeeklyBalanceLineChart(points: points),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyBalanceLineChart extends StatefulWidget {
  const _WeeklyBalanceLineChart({required this.points});

  final List<_DailyBalancePoint> points;

  @override
  State<_WeeklyBalanceLineChart> createState() => _WeeklyBalanceLineChartState();
}

class _WeeklyBalanceLineChartState extends State<_WeeklyBalanceLineChart> {
  int? _selectedIndex;

  void _handleTapDown(TapDownDetails details, Size size) {
    final geometry = _WeeklyBalanceChartGeometry.fromSize(
      size: size,
      points: widget.points,
    );

    setState(() {
      _selectedIndex = geometry.nearestIndex(details.localPosition, widget.points);
    });
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.points.map((point) => point.label).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartSize = Size(constraints.maxWidth, 120);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      key: const Key('weekly-balance-chart'),
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) => _handleTapDown(details, chartSize),
                      child: CustomPaint(
                        size: chartSize,
                        painter: _WeeklyBalanceLinePainter(
                          points: widget.points,
                          selectedIndex: _selectedIndex,
                          color: Theme.of(context).colorScheme.primary,
                          gridColor: Theme.of(context).colorScheme.outlineVariant,
                          surfaceColor: Theme.of(context).colorScheme.surface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: labels
                        .map(
                          (label) => SizedBox(
                            width: 36,
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedIndex == null
                        ? 'Tap a point to inspect its balance.'
                        : 'Selected: ${widget.points[_selectedIndex!].label} · ${_formatAxisCurrency(widget.points[_selectedIndex!].balance)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WeeklyBalanceLinePainter extends CustomPainter {
  _WeeklyBalanceLinePainter({
    required this.points,
    required this.selectedIndex,
    required this.color,
    required this.gridColor,
    required this.surfaceColor,
  });

  final List<_DailyBalancePoint> points;
  final int? selectedIndex;
  final Color color;
  final Color gridColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }

    final geometry = _WeeklyBalanceChartGeometry.fromSize(
      size: size,
      points: points,
    );

    final backgroundPaint = Paint()..color = surfaceColor;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final dotPaint = Paint()..color = color;

    canvas.drawRRect(
      RRect.fromRectAndRadius(geometry.chartRect, const Radius.circular(16)),
      backgroundPaint,
    );

    for (var index = 0; index < 4; index++) {
      final y = geometry.chartRect.top + (geometry.chartRect.height / 3) * index;
      canvas.drawLine(
        Offset(geometry.chartRect.left, y),
        Offset(geometry.chartRect.right, y),
        gridPaint,
      );
    }

    final offsets = <Offset>[];
    for (var index = 0; index < points.length; index++) {
      offsets.add(geometry.pointOffset(index, points[index].balance, points.length));
    }

    if (offsets.length > 1) {
      final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final offset in offsets.skip(1)) {
        linePath.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(linePath, linePaint);

      final areaPath = Path()..moveTo(offsets.first.dx, geometry.chartRect.bottom);
      areaPath.lineTo(offsets.first.dx, offsets.first.dy);
      for (final offset in offsets.skip(1)) {
        areaPath.lineTo(offset.dx, offset.dy);
      }
      areaPath.lineTo(offsets.last.dx, geometry.chartRect.bottom);
      areaPath.close();
      canvas.drawPath(areaPath, fillPaint);
    }

    for (final offset in offsets) {
      canvas.drawCircle(offset, 5.5, dotPaint);
      canvas.drawCircle(offset, 2.5, Paint()..color = Colors.white);
    }

    if (selectedIndex != null && selectedIndex! >= 0 && selectedIndex! < offsets.length) {
      final selectedOffset = offsets[selectedIndex!];
      canvas.drawCircle(selectedOffset, 10, Paint()..color = color.withValues(alpha: 0.18));
      canvas.drawCircle(
        selectedOffset,
        7,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(selectedOffset, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyBalanceLinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.color != color ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.surfaceColor != surfaceColor;
  }
}

class _WeeklyBalanceChartGeometry {
  _WeeklyBalanceChartGeometry({
    required this.chartRect,
    required this.minBalance,
    required this.effectiveRange,
  });

  factory _WeeklyBalanceChartGeometry.fromSize({
    required Size size,
    required List<_DailyBalancePoint> points,
  }) {
    final chartRect = Rect.fromLTWH(12, 8, size.width - 24, size.height - 16);
    final minBalance = points.map((point) => point.balance).reduce((a, b) => a < b ? a : b);
    final maxBalance = points.map((point) => point.balance).reduce((a, b) => a > b ? a : b);
    final balanceRange = (maxBalance - minBalance).abs();
    return _WeeklyBalanceChartGeometry(
      chartRect: chartRect,
      minBalance: minBalance,
      effectiveRange: balanceRange == 0 ? 1 : balanceRange,
    );
  }

  final Rect chartRect;
  final int minBalance;
  final int effectiveRange;

  Offset pointOffset(int index, int balance, int count) {
    final horizontalStep = count == 1 ? 0.0 : chartRect.width / (count - 1);
    final x = chartRect.left + horizontalStep * index;
    final normalized = (balance - minBalance) / effectiveRange;
    final y = chartRect.bottom - (normalized * chartRect.height);
    return Offset(x, y);
  }

  int nearestIndex(Offset localPosition, List<_DailyBalancePoint> points) {
    var nearest = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < points.length; index++) {
      final point = pointOffset(index, points[index].balance, points.length);
      final distance = (point - localPosition).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = index;
      }
    }
    return nearest;
  }
}

String _formatAxisCurrency(int amount) {
  final prefix = amount < 0 ? '-' : '';
  return '$prefix₱${amount.abs()}';
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
  final TextEditingController _customCategoryController =
      TextEditingController();
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
                        DropdownMenuItem<String>(value: '+', child: Text('+')),
                        DropdownMenuItem<String>(value: '-', child: Text('-')),
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
                        child: Text(
                          category == '__custom__'
                              ? 'Custom category'
                              : category,
                        ),
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
