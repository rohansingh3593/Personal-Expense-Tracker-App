import 'package:flutter/material.dart';

import '../models/expense_transaction.dart';
import '../services/sms_parser.dart';
import '../utils/text_format.dart';

class ReviewTransactionScreen extends StatefulWidget {
  const ReviewTransactionScreen({
    super.key,
    required this.draft,
    required this.expenseCategories,
    required this.subcategories,
  });

  final ParsedSmsDraft draft;
  final List<String> expenseCategories;
  final Map<String, List<String>> subcategories;

  @override
  State<ReviewTransactionScreen> createState() => _ReviewTransactionScreenState();
}

class _ReviewTransactionScreenState extends State<ReviewTransactionScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _noteController;
  late final TextEditingController _descriptionController;

  late DateTime _dateTime;
  late String _type;
  String _lendingFlow = 'Paid';
  late String _account;
  late String _category;
  String? _subcategory;
  late bool _bookmarked;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.draft.amount?.toStringAsFixed(2) ?? '',
    );
    _merchantController = TextEditingController(text: widget.draft.merchant);
    _noteController = TextEditingController();
    _descriptionController = TextEditingController(text: widget.draft.rawMessage);
    _dateTime = widget.draft.date;
    _type = widget.draft.type.toLowerCase() == 'credit' ? 'Credit' : 'Debit';
    _account = 'Cash';
    _bookmarked = false;
    _category = widget.expenseCategories.contains(widget.draft.category)
        ? widget.draft.category
        : (widget.expenseCategories.isEmpty ? 'Others' : widget.expenseCategories.first);

    final defaults = widget.subcategories[_category] ?? const <String>[];
    _subcategory = defaults.contains(widget.draft.subcategory)
        ? widget.draft.subcategory
        : (defaults.isEmpty ? null : defaults.first);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _dateTime,
    );
    if (d == null) return;
    setState(() {
      _dateTime = DateTime(d.year, d.month, d.day, _dateTime.hour, _dateTime.minute);
    });
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (t == null) return;
    setState(() {
      _dateTime = DateTime(
        _dateTime.year,
        _dateTime.month,
        _dateTime.day,
        t.hour,
        t.minute,
      );
    });
  }

  void _save() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    final tx = ExpenseTransaction(
      id: '${DateTime.now().millisecondsSinceEpoch}-${_merchantController.text.hashCode}',
      amount: amount,
      account: _account,
      merchant: _merchantController.text.trim().isEmpty ? 'Unknown' : toTitleCase(_merchantController.text.trim()),
      category: _category,
      subcategory: _subcategory,
      type: _category == 'Lending' ? _lendingFlow : _type,
      date: _dateTime,
      note: _noteController.text.trim(),
      description: _descriptionController.text.trim(),
      isBookmarked: _bookmarked,
      rawMessage: widget.draft.rawMessage,
      source: 'sms_manual',
    );

    Navigator.of(context).pop(tx);
  }

  @override
  Widget build(BuildContext context) {
    final subOptions = widget.subcategories[_category] ?? const <String>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Credit', label: Text('Income')),
              ButtonSegment(value: 'Debit', label: Text('Expense')),
              ButtonSegment(value: 'Transfer', label: Text('Transfer')),
            ],
            selected: {_type},
            onSelectionChanged: (value) => setState(() => _type = value.first),
          ),
          const SizedBox(height: 10),
          if (_category == 'Lending')
            Card(
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'Paid',
                    groupValue: _lendingFlow,
                    title: const Text('Paid (You gave money)'),
                    onChanged: (v) => setState(() => _lendingFlow = v ?? 'Paid'),
                  ),
                  RadioListTile<String>(
                    value: 'Received',
                    groupValue: _lendingFlow,
                    title: const Text('Received (You got money back)'),
                    onChanged: (v) => setState(() => _lendingFlow = v ?? 'Paid'),
                  ),
                ],
              ),
            ),
          if (_category == 'Lending') const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(_formatDate(_dateTime)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.access_time),
                          label: Text(_formatTime(_dateTime)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _account,
            items: const ['Cash', 'Bank']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _account = v ?? 'Cash'),
            decoration: const InputDecoration(labelText: 'Account', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _merchantController,
            decoration: const InputDecoration(labelText: 'Merchant', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _category,
            items: widget.expenseCategories
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _category = v;
                final subs = widget.subcategories[_category] ?? const <String>[];
                _subcategory = subs.isEmpty ? null : subs.first;
              });
            },
            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _subcategory,
            items: subOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _subcategory = v),
            decoration: const InputDecoration(labelText: 'Subcategory', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
          ),
          SwitchListTile(
            value: _bookmarked,
            title: const Text('Bookmark'),
            onChanged: (v) => setState(() => _bookmarked = v),
          ),
          FilledButton(
            onPressed: _save,
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

String _monthShort(int month) {
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return names[month - 1];
}

String _formatDate(DateTime dt) {
  final d = dt.day.toString().padLeft(2, '0');
  final month = _monthShort(dt.month);
  return '$d-$month-${dt.year}';
}

String _formatTime(DateTime dt) {
  var hour = dt.hour % 12;
  if (hour == 0) hour = 12;
  final mm = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '${hour.toString().padLeft(2, '0')}:$mm $ampm';
}
