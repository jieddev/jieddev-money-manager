String formatCurrency(int amount) {
  final prefix = amount < 0 ? '-' : '';
  return '$prefix₱${amount.abs().toStringAsFixed(2)}';
}
