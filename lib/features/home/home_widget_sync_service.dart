import 'package:home_widget/home_widget.dart';

import '../../core/currency_formatter.dart';
import '../../data/money_manager_repository.dart';

class HomeWidgetSyncService {
  Future<void> sync(MoneyManagerSnapshot snapshot) async {
    await HomeWidget.saveWidgetData<int>('balance', snapshot.balance + snapshot.needsBalance + snapshot.rewardFundBalance + snapshot.savingsBalance + snapshot.emergencyFundBalance);
    await HomeWidget.saveWidgetData<int>('spare_balance', snapshot.balance);
    await HomeWidget.saveWidgetData<String>(
      'transaction_history',
      _buildWidgetTransactionHistory(snapshot.transactions),
    );
    await HomeWidget.updateWidget(name: 'MoneyManagerWidgetProvider');
  }

  String _buildWidgetTransactionHistory(List<TransactionRecord> transactions) {
    if (transactions.isEmpty) {
      return 'No transactions yet.';
    }

    final recentTransactions = transactions.take(3);
    return recentTransactions.map((transaction) {
      final sign = transaction.isAddition ? '+' : '-';
      final month = transaction.createdAt.month.toString().padLeft(2, '0');
      final day = transaction.createdAt.day.toString().padLeft(2, '0');
      return '$month/$day  ${transaction.displayText}  $sign${formatCurrency(transaction.amount)}';
    }).join('\n');
  }
}
