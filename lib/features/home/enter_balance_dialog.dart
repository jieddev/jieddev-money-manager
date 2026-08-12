import 'package:flutter/material.dart';

class EnterBalanceDialog extends StatefulWidget {
  const EnterBalanceDialog({super.key, required this.currentBalance});

  final int currentBalance;

  @override
  State<EnterBalanceDialog> createState() => _EnterBalanceDialogState();
}

class _EnterBalanceDialogState extends State<EnterBalanceDialog> {
  late final TextEditingController _amountController = TextEditingController(
    text: widget.currentBalance.toString(),
  );
  String? _errorText;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = int.tryParse(_amountController.text.trim());

    if (amount == null || amount < 0) {
      setState(() {
        _errorText = 'Enter a valid amount (0 or more)';
      });
      return;
    }

    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Balance'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Enter the cash you currently have. We'll adjust your balance to match.",
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Current balance',
              border: const OutlineInputBorder(),
              errorText: _errorText,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Set Balance'),
        ),
      ],
    );
  }
}
