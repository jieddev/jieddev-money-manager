import 'package:flutter/material.dart';

import '../../../core/currency_formatter.dart';
import '../../../core/date_formatter.dart';
import '../../../data/money_manager_repository.dart';

class RecentTransactionsCard extends StatelessWidget {
  const RecentTransactionsCard({
    super.key,
    required this.transactions,
    required this.hasMoreTransactions,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TransactionRecord> transactions;
  final bool hasMoreTransactions;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final ValueChanged<TransactionRecord> onEdit;
  final ValueChanged<TransactionRecord> onDelete;

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
              'RECENT TRANSACTIONS',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            if (transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No transactions yet.'),
              )
            else
              for (var index = 0; index < transactions.length; index++) ...[
                _TransactionRow(
                  transaction: transactions[index],
                  onEdit: () => onEdit(transactions[index]),
                  onDelete: () => onDelete(transactions[index]),
                ),
                if (index < transactions.length - 1) const Divider(height: 24),
              ],
            if (hasMoreTransactions)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: TextButton(
                    onPressed: isLoadingMore ? null : onLoadMore,
                    child: Text(
                      isLoadingMore ? 'Loading more...' : 'Load more',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
  });

  final TransactionRecord transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${transaction.isAddition ? '+' : '-'}${formatCurrency(transaction.amount)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: transaction.isAddition
                      ? Colors.green[700]
                      : Colors.red[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatDate(transaction.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                transaction.displayText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
            const PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              onEdit();
            } else if (value == 'delete') {
              onDelete();
            }
          },
        ),
      ],
    );
  }
}
