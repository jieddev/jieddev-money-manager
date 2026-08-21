import 'package:flutter/material.dart';

class TransactionEntry {
  const TransactionEntry({
    required this.amount,
    required this.category,
    required this.description,
    required this.isAddition,
  });

  final int amount;
  final String? category;
  final String? description;
  final bool isAddition;
}

class TransactionEntryPage extends StatefulWidget {
  const TransactionEntryPage({
    super.key,
    required this.title,
    required this.categories,
    required this.actionLabel,
    this.initialEntry,
  });

  final String title;
  final List<String> categories;
  final String actionLabel;
  final TransactionEntry? initialEntry;

  @override
  State<TransactionEntryPage> createState() => _TransactionEntryPageState();
}

class _TransactionEntryPageState extends State<TransactionEntryPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _customCategoryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedSign = '+';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();

    final initialEntry = widget.initialEntry;
    if (initialEntry == null) {
      _selectedCategory = widget.categories.first;
      return;
    }

    _selectedSign = initialEntry.isAddition ? '+' : '-';
    _amountController.text = initialEntry.amount.toString();
    _descriptionController.text = initialEntry.description ?? '';

    if (initialEntry.category != null &&
        widget.categories.contains(initialEntry.category)) {
      _selectedCategory = initialEntry.category;
    } else if (initialEntry.category != null) {
      _selectedCategory = '__custom__';
      _customCategoryController.text = initialEntry.category!;
    } else {
      _selectedCategory = widget.categories.first;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _customCategoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = int.tryParse(_amountController.text.trim());

    final category = _selectedCategory == '__custom__'
        ? _customCategoryController.text.trim()
        : _selectedCategory;
    final description = _descriptionController.text.trim();

    if (amount == null || amount <= 0) {
      return;
    }

    if ((category == null || category.isEmpty) && description.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      TransactionEntry(
        amount: amount,
        category: category?.isEmpty == true ? null : category,
        description: description.isEmpty ? null : description,
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
                'Enter the amount and optionally add a category and description.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              const SizedBox(height: 16),
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
                  labelText: 'Category (optional)',
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
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Enter anything associated with the transaction',
                  border: OutlineInputBorder(),
                ),
              ),
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
