import 'package:flutter/material.dart';

import '../models/expense_transaction.dart';

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    required this.expenseCategories,
    required this.subcategories,
  });

  final ExpenseTransaction transaction;
  final List<String> expenseCategories;
  final Map<String, List<String>> subcategories;

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  bool _isEditing = true;

  late String _type;
  late DateTime _dateTime;
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _noteController;
  late final TextEditingController _descriptionController;
  late String _account;
  late String _category;
  String? _subcategory;
  late bool _bookmarked;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _type = t.type;
    _dateTime = t.date;
    _amountController = TextEditingController(text: t.amount.toStringAsFixed(2));
    _merchantController = TextEditingController(text: t.merchant);
    _noteController = TextEditingController(text: t.note);
    _descriptionController = TextEditingController(
      text: t.description.isEmpty ? t.rawMessage : t.description,
    );
    _account = t.account;
    _category = widget.expenseCategories.contains(t.category)
        ? t.category
        : (widget.expenseCategories.isEmpty ? 'Others' : widget.expenseCategories.first);
    final subs = widget.subcategories[_category] ?? const <String>[];
    _subcategory = subs.contains(t.subcategory) ? t.subcategory : (subs.isEmpty ? null : subs.first);
    _bookmarked = t.isBookmarked;
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
    if (!_isEditing) return;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _dateTime,
    );
    if (date == null || !mounted) return;
    setState(() {
      _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        _dateTime.hour,
        _dateTime.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    if (!_isEditing) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dateTime = DateTime(
        _dateTime.year,
        _dateTime.month,
        _dateTime.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _save() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid amount')));
      return;
    }
    final updated = widget.transaction.copyWith(
      type: _type,
      date: _dateTime,
      account: _account,
      category: _category,
      subcategory: _subcategory,
      amount: amount,
      note: _noteController.text.trim(),
      merchant: _merchantController.text.trim().isEmpty ? 'Unknown' : _merchantController.text.trim(),
      description: _descriptionController.text.trim(),
      isBookmarked: _bookmarked,
    );
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final subOptions = widget.subcategories[_category] ?? const <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _isEditing = !_isEditing),
            icon: Icon(_isEditing ? Icons.visibility : Icons.edit),
            tooltip: _isEditing ? 'View' : 'Edit',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Income', label: Text('Income')),
              ButtonSegment(value: 'Debit', label: Text('Expense')),
              ButtonSegment(value: 'Transfer', label: Text('Transfer')),
            ],
            selected: {_type == 'Credit' ? 'Income' : (_type == 'Debit' ? 'Debit' : 'Transfer')},
            onSelectionChanged: _isEditing
                ? (value) {
                    final selected = value.first;
                    setState(() => _type = selected == 'Income' ? 'Credit' : selected);
                  }
                : null,
          ),
          const SizedBox(height: 10),
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
                          onPressed: _isEditing ? _pickDate : null,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(_formatDate(_dateTime)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isEditing ? _pickTime : null,
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
            decoration: const InputDecoration(labelText: 'Account', border: OutlineInputBorder()),
            items: const ['Cash', 'Bank'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: _isEditing ? (v) => setState(() => _account = v ?? 'Cash') : null,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            items: widget.expenseCategories
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: _isEditing
                ? (v) {
                    if (v == null) return;
                    setState(() {
                      _category = v;
                      final subs = widget.subcategories[_category] ?? const <String>[];
                      _subcategory = subs.isEmpty ? null : subs.first;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _subcategory,
            decoration: const InputDecoration(labelText: 'Subcategory', border: OutlineInputBorder()),
            items: subOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: _isEditing ? (v) => setState(() => _subcategory = v) : null,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amountController,
            enabled: _isEditing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _merchantController,
            enabled: _isEditing,
            decoration: const InputDecoration(labelText: 'Merchant', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            enabled: _isEditing,
            decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            enabled: _isEditing,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
          ),
          SwitchListTile(
            value: _bookmarked,
            title: const Text('Bookmark'),
            onChanged: _isEditing ? (v) => setState(() => _bookmarked = v) : null,
          ),
          if (_isEditing) FilledButton(onPressed: _save, child: const Text('Save Changes')),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  return '${_formatDate(dt)}, ${_formatTime(dt)}';
}

String _formatDate(DateTime dt) {
  final d = dt.day.toString().padLeft(2, '0');
  final month = _monthShort(dt.month);
  final y = dt.year;
  return '$d-$month-$y';
}

String _formatTime(DateTime dt) {
  var hour = dt.hour % 12;
  if (hour == 0) hour = 12;
  final mm = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '${hour.toString().padLeft(2, '0')}:$mm $ampm';
}

String _monthShort(int month) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return names[month - 1];
}
