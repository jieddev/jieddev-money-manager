import 'package:flutter/material.dart';

import '../../../core/currency_formatter.dart';
import '../envelope_transaction_page.dart';

class EnvelopeBudget {
  const EnvelopeBudget({
    required this.envelope,
    required this.label,
    required this.percentage,
    required this.balance,
    required this.maxPerYear,
  });

  final Envelope envelope;
  final String label;
  final int percentage;
  final int balance;
  final int maxPerYear;
}

class BudgetBreakdownCard extends StatelessWidget {
  const BudgetBreakdownCard({
    super.key,
    required this.budgets,
    required this.onTapEnvelope,
  });

  final List<EnvelopeBudget> budgets;
  final ValueChanged<Envelope> onTapEnvelope;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BUDGET BREAKDOWN',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 18),
            for (var index = 0; index < budgets.length; index++) ...[
              _BudgetRow(
                budget: budgets[index],
                onTap: () => onTapEnvelope(budgets[index].envelope),
              ),
              if (index < budgets.length - 1) const SizedBox(height: 22),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.budget, required this.onTap});

  final EnvelopeBudget budget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = budget.maxPerYear > 0
        ? (budget.balance / budget.maxPerYear).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${budget.label} (${budget.percentage}%)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatCurrency(budget.balance),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${formatCurrency(budget.maxPerYear)} Max / Year',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
