import 'package:flutter/material.dart';

import '../../../data/money_manager_repository.dart';
import 'weekly_balance_line_chart.dart';

class BalanceChartCard extends StatelessWidget {
  const BalanceChartCard({super.key, required this.points});

  final List<BalancePoint> points;

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
              child: WeeklyBalanceLineChart(points: points),
            ),
          ],
        ),
      ),
    );
  }
}
