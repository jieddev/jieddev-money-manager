import 'package:flutter/material.dart';

import '../../core/currency_formatter.dart';
import 'transaction_entry_page.dart';

enum Envelope { savings, needs, rewardFund, emergencyFund }

extension EnvelopeDisplay on Envelope {
  String get label => switch (this) {
    Envelope.savings => 'Savings',
    Envelope.needs => 'Needs',
    Envelope.rewardFund => 'Reward Fund',
    Envelope.emergencyFund => 'Emergency Fund',
  };

  // Passed as `category` to MoneyManagerRepository.addTransaction(isSavings:
  // true, ...) so SqliteMoneyManagerRepository can derive the DB `envelope`
  // column from it. Null for Savings, which needs no marker. Must stay in
  // sync with SqliteMoneyManagerRepository._envelopeCategoryMarkers' keys.
  String? get categoryMarker => switch (this) {
    Envelope.savings => null,
    Envelope.needs => 'Needs',
    Envelope.rewardFund => 'Reward Fund',
    Envelope.emergencyFund => 'Emergency Fund',
  };
}

class EnvelopeTransactionPage extends StatefulWidget {
  const EnvelopeTransactionPage({
    super.key,
    required this.envelope,
    required this.envelopeBalance,
    required this.overallBalance,
  });

  final Envelope envelope;
  final int envelopeBalance;
  final int overallBalance;

  @override
  State<EnvelopeTransactionPage> createState() =>
      _EnvelopeTransactionPageState();
}

class _EnvelopeTransactionPageState extends State<EnvelopeTransactionPage> {
  final TextEditingController _amountController = TextEditingController();
  String _selectedSign = '+';
  double _sliderValue = 0;
  bool _isSyncingFromSlider = false;
  String? _errorText;

  bool get _isAddition => _selectedSign == '+';

  int get _maxBound {
    final bound = _isAddition ? widget.overallBalance : widget.envelopeBalance;
    return bound > 0 ? bound : 0;
  }

  bool get _hasAvailableBound => _maxBound > 0;

  double get _sliderMax => _hasAvailableBound ? _maxBound.toDouble() : 1.0;

  int? get _sliderDivisions => _hasAvailableBound ? _maxBound : null;

  int _clamp(int value) {
    if (value < 0) return 0;
    if (value > _maxBound) return _maxBound;
    return value;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _handleAmountChanged(String value) {
    if (_isSyncingFromSlider) return;

    final parsed = int.tryParse(value.trim());
    setState(() {
      _errorText = null;
      if (parsed != null) {
        _sliderValue = _clamp(parsed).toDouble();
      }
    });
  }

  void _handleSliderChanged(double value) {
    final rounded = value.round();
    setState(() {
      _sliderValue = rounded.toDouble();
      _errorText = null;
    });

    _isSyncingFromSlider = true;
    _amountController.text = rounded.toString();
    _amountController.selection = TextSelection.collapsed(
      offset: _amountController.text.length,
    );
    _isSyncingFromSlider = false;
  }

  void _handleSignChanged(String? value) {
    setState(() {
      _selectedSign = value ?? '+';
      _errorText = null;

      final currentAmount = int.tryParse(_amountController.text.trim()) ?? 0;
      final clamped = _clamp(currentAmount);
      _sliderValue = clamped.toDouble();

      if (clamped != currentAmount) {
        _isSyncingFromSlider = true;
        _amountController.text = clamped.toString();
        _isSyncingFromSlider = false;
      }
    });
  }

  void _submit() {
    final amount = int.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      setState(() => _errorText = 'Enter a valid amount greater than 0');
      return;
    }

    if (amount > _maxBound) {
      setState(() {
        _errorText = _isAddition
            ? 'Amount exceeds your available balance (${formatCurrency(_maxBound)})'
            : 'Amount exceeds your ${widget.envelope.label} balance (${formatCurrency(_maxBound)})';
      });
      return;
    }

    Navigator.of(context).pop(
      TransactionEntry(
        amount: amount,
        category: null,
        description: _isAddition
            ? '${widget.envelope.label} deposit'
            : '${widget.envelope.label} withdrawal',
        isAddition: _isAddition,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.envelope.label)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.envelope.label} Balance',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                formatCurrency(widget.envelopeBalance),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 32),
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
                      onChanged: _handleSignChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      onChanged: _handleAmountChanged,
                      decoration: InputDecoration(
                        labelText: _isAddition
                            ? 'Enter balance to add'
                            : 'Enter balance to deduct',
                        prefixText: '₱',
                        hintText: '0',
                        border: const OutlineInputBorder(),
                        errorText: _errorText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatCurrency(0)),
                  Text(formatCurrency(_maxBound)),
                ],
              ),
              Slider(
                // Keyed so toggling onChanged null<->non-null rebuilds a
                // fresh element instead of updating in place, which avoids
                // a semantics-tree crash when interactivity and divisions
                // change in the same frame.
                key: ValueKey<bool>(_hasAvailableBound),
                value: _hasAvailableBound
                    ? _sliderValue.clamp(0.0, _sliderMax).toDouble()
                    : 0.0,
                min: 0,
                max: _sliderMax,
                divisions: _sliderDivisions,
                label: formatCurrency(_sliderValue.round()),
                onChanged: _hasAvailableBound ? _handleSliderChanged : null,
              ),
              if (!_hasAvailableBound)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _isAddition
                        ? 'You have no available balance to add.'
                        : 'You have no ${widget.envelope.label} to deduct.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _hasAvailableBound ? _submit : null,
                child: Text(
                  _isAddition
                      ? 'Add To ${widget.envelope.label}'
                      : 'Deduct From ${widget.envelope.label}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
