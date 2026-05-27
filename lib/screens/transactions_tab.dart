import 'dart:math';

import 'package:flutter/material.dart';

import '../models/expense_transaction.dart';
import 'transaction_detail_screen.dart';

enum TransactionViewMode { daily, calendar, monthly, yearly }

class TransactionsTab extends StatefulWidget {
  const TransactionsTab({
    super.key,
    required this.transactions,
    required this.onSyncSms,
    required this.budgets,
    required this.expenseCategories,
    required this.subcategories,
    required this.onTransactionUpdated,
    required this.accounts,
  });

  final List<ExpenseTransaction> transactions;
  final Future<void> Function() onSyncSms;
  final Map<String, double> budgets;
  final List<String> expenseCategories;
  final Map<String, List<String>> subcategories;
  final ValueChanged<ExpenseTransaction> onTransactionUpdated;
  final List<String> accounts;

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  TransactionViewMode _mode = TransactionViewMode.daily;
  DateTime? _selectedCalendarDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MonthPicker(
          selectedMonth: _selectedMonth,
          onPrevious: () => setState(
            () => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1),
          ),
          onNext: () => setState(
            () => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1),
          ),
          onSync: widget.onSyncSms,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            children: [
              _modeChip('Daily', TransactionViewMode.daily),
              _modeChip('Calendar', TransactionViewMode.calendar),
              _modeChip('Monthly', TransactionViewMode.monthly),
              _modeChip('Yearly/All', TransactionViewMode.yearly),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildModeContent()),
      ],
    );
  }

  Widget _modeChip(String label, TransactionViewMode mode) {
    return ChoiceChip(
      label: Text(label),
      selected: _mode == mode,
      onSelected: (_) => setState(() => _mode = mode),
    );
  }

  List<ExpenseTransaction> _sortedTransactions() {
    return widget.transactions
        .where((t) => _isOutgoingType(t.type) || _isIncomingType(t.type))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<ExpenseTransaction> _selectedMonthTx() {
    return _sortedTransactions()
        .where(
          (t) =>
              t.date.year == _selectedMonth.year &&
              t.date.month == _selectedMonth.month,
        )
        .toList();
  }

  Widget _buildModeContent() {
    switch (_mode) {
      case TransactionViewMode.daily:
        return _DailyListView(
          transactions: _sortedTransactions(),
          expenseCategories: widget.expenseCategories,
          subcategories: widget.subcategories,
          onTransactionUpdated: widget.onTransactionUpdated,
          accounts: widget.accounts,
        );
      case TransactionViewMode.calendar:
        return _CalendarView(
          month: _selectedMonth,
          transactions: _selectedMonthTx(),
          selectedDate: _selectedCalendarDate,
          onSelectDate: (value) => setState(() => _selectedCalendarDate = value),
        );
      case TransactionViewMode.monthly:
        return _MonthlySummaryView(
          currentMonthTx: _selectedMonthTx(),
          previousMonthTx: _sortedTransactions().where((t) {
            final prev = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
            return t.date.year == prev.year && t.date.month == prev.month;
          }).toList(),
          budgets: widget.budgets,
        );
      case TransactionViewMode.yearly:
        return _YearlyAllTimeView(transactions: _sortedTransactions());
    }
  }
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({
    required this.selectedMonth,
    required this.onPrevious,
    required this.onNext,
    required this.onSync,
  });

  final DateTime selectedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context) {
    final label = '${_monthName(selectedMonth.month)} ${selectedMonth.year}';
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
          FilledButton.tonalIcon(
            onPressed: onSync,
            icon: const Icon(Icons.sms),
            label: const Text('Sync'),
          ),
        ],
      ),
    );
  }
}

class _DailyListView extends StatelessWidget {
  const _DailyListView({
    required this.transactions,
    required this.expenseCategories,
    required this.subcategories,
    required this.onTransactionUpdated,
    required this.accounts,
  });

  final List<ExpenseTransaction> transactions;
  final List<String> expenseCategories;
  final Map<String, List<String>> subcategories;
  final ValueChanged<ExpenseTransaction> onTransactionUpdated;
  final List<String> accounts;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(child: Text('No transactions yet.'));
    }

    final grouped = _groupTransactions(transactions, DateTime.now());
    final sections = grouped.entries.where((entry) => entry.value.isNotEmpty);

    return ListView(
      children: [
        for (final section in sections)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.key,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...section.value.map(
                    (tx) => _TransactionRow(
                      transaction: tx,
                      expenseCategories: expenseCategories,
                      subcategories: subcategories,
                      accounts: accounts,
                      onTransactionUpdated: onTransactionUpdated,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Map<String, List<ExpenseTransaction>> _groupTransactions(
    List<ExpenseTransaction> transactions,
    DateTime now,
  ) {
    final groups = <String, List<ExpenseTransaction>>{};
    final sorted = [...transactions]..sort((a, b) => b.date.compareTo(a.date));
    final today = _dateOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final tx in sorted) {
      final txDate = _dateOnly(tx.date);
      final label = txDate == today
          ? 'Today'
          : txDate == yesterday
              ? 'Yesterday'
              : _formatSectionDate(txDate);
      groups.putIfAbsent(label, () => <ExpenseTransaction>[]).add(tx);
    }

    return groups;
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.expenseCategories,
    required this.subcategories,
    required this.accounts,
    required this.onTransactionUpdated,
  });

  final ExpenseTransaction transaction;
  final List<String> expenseCategories;
  final Map<String, List<String>> subcategories;
  final List<String> accounts;
  final ValueChanged<ExpenseTransaction> onTransactionUpdated;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final updated = await Navigator.of(context).push<ExpenseTransaction>(
          MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(
              transaction: transaction,
              expenseCategories: expenseCategories,
              subcategories: subcategories,
              accounts: accounts,
            ),
          ),
        );
        if (updated != null) {
          onTransactionUpdated(updated);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(transaction.merchant),
                  Text(
                    _formatTime(transaction.date),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              '${_isIncomingType(transaction.type) ? '+' : '-'}'
              '\u20B9${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: _isIncomingType(transaction.type)
                    ? Colors.green
                    : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarView extends StatelessWidget {
  const _CalendarView({
    required this.month,
    required this.transactions,
    required this.selectedDate,
    required this.onSelectDate,
  });

  final DateTime month;
  final List<ExpenseTransaction> transactions;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final daySpend = <int, double>{};
    for (final tx in transactions) {
      final signed = _isIncomingType(tx.type) ? -tx.amount : tx.amount;
      daySpend.update(tx.date.day, (v) => v + signed, ifAbsent: () => signed);
    }

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;

    final selectedList = selectedDate == null
        ? const <ExpenseTransaction>[]
        : (transactions
            .where((t) => _isSameDate(t.date, selectedDate!))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date)));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 42,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - (firstWeekday - 2);
            if (dayNumber < 1 || dayNumber > daysInMonth) return const SizedBox.shrink();

            final spend = daySpend[dayNumber] ?? 0;
            final isSelected = selectedDate?.day == dayNumber;
            return InkWell(
              onTap: () => onSelectDate(DateTime(month.year, month.month, dayNumber)),
              child: Card(
                color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$dayNumber',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (spend > 0)
                        Text(
                          '\u20B9${spend.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (selectedDate != null) ...[
          const SizedBox(height: 10),
          Text(
            'Transactions on ${selectedDate!.day} ${_monthName(selectedDate!.month)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (selectedList.isEmpty) const Text('No transactions.'),
          ...selectedList.map(
            (tx) => ListTile(
              dense: true,
              title: Text(tx.merchant),
              subtitle: Text(_formatTime(tx.date)),
              trailing: Text(
                '${_isIncomingType(tx.type) ? '+' : '-'}'
                '\u20B9${tx.amount.toStringAsFixed(2)}',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MonthlySummaryView extends StatelessWidget {
  const _MonthlySummaryView({
    required this.currentMonthTx,
    required this.previousMonthTx,
    required this.budgets,
  });

  final List<ExpenseTransaction> currentMonthTx;
  final List<ExpenseTransaction> previousMonthTx;
  final Map<String, double> budgets;

  @override
  Widget build(BuildContext context) {
    final total = currentMonthTx.fold<double>(
      0,
      (s, t) => s + (_isIncomingType(t.type) ? -t.amount : t.amount),
    );
    final prevTotal = previousMonthTx.fold<double>(
      0,
      (s, t) => s + (_isIncomingType(t.type) ? -t.amount : t.amount),
    );

    final categorySpend = <String, double>{};
    for (final tx in currentMonthTx) {
      final signed = _isIncomingType(tx.type) ? -tx.amount : tx.amount;
      categorySpend.update(tx.category, (v) => v + signed, ifAbsent: () => signed);
    }
    final entries = categorySpend.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final diffPct = prevTotal <= 0 ? null : ((total - prevTotal) / prevTotal) * 100;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            title: const Text('Total spent'),
            subtitle: Text('\u20B9${total.toStringAsFixed(2)}'),
            trailing: diffPct == null
                ? const Text('-')
                : Text(
                    '${diffPct >= 0 ? '+' : ''}${diffPct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: diffPct >= 0 ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Category breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (entries.isEmpty) const Text('No expenses in this month.'),
        ...entries.map(
          (entry) {
            final budget = budgets[entry.key];
            final usedPct = budget == null || budget <= 0
                ? null
                : min(1.0, entry.value / budget);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(entry.key)),
                        Text('\u20B9${entry.value.toStringAsFixed(2)}'),
                      ],
                    ),
                    if (budget != null) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: usedPct),
                      const SizedBox(height: 4),
                      Text(
                        'Budget: \u20B9${entry.value.toStringAsFixed(0)} / '
                        '\u20B9${budget.toStringAsFixed(0)}',
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _YearlyAllTimeView extends StatelessWidget {
  const _YearlyAllTimeView({required this.transactions});

  final List<ExpenseTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) return const Center(child: Text('No transactions yet.'));

    final yearly = <int, double>{};
    final monthly = <String, double>{};
    for (final tx in transactions) {
      final signed = _isIncomingType(tx.type) ? -tx.amount : tx.amount;
      yearly.update(tx.date.year, (v) => v + signed, ifAbsent: () => signed);
      final key = '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      monthly.update(key, (v) => v + signed, ifAbsent: () => signed);
    }

    final yearEntries = yearly.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    final monthEntries = monthly.entries.toList()..sort((a, b) => b.key.compareTo(a.key));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Year-wise trends',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        ...yearEntries.map(
          (e) => ListTile(
            title: Text('${e.key}'),
            trailing: Text('\u20B9${e.value.toStringAsFixed(2)}'),
          ),
        ),
        const Divider(),
        const Text(
          'Month-wise totals',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        ...monthEntries.take(24).map(
          (e) => ListTile(
            dense: true,
            title: Text(e.key),
            trailing: Text('\u20B9${e.value.toStringAsFixed(2)}'),
          ),
        ),
      ],
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isSameDate(DateTime a, DateTime b) => _dateOnly(a) == _dateOnly(b);

String _formatSectionDate(DateTime date) {
  return '${date.day} ${_monthName(date.month)} ${date.year}';
}

String _monthName(int month) {
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
    'Dec'
  ];
  return names[month - 1];
}

String _formatTime(DateTime dt) {
  var hour = dt.hour % 12;
  if (hour == 0) hour = 12;
  final mm = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '${hour.toString().padLeft(2, '0')}:$mm $ampm';
}

bool _isOutgoingType(String type) =>
    type == 'Debit' || type == 'Paid' || type == 'paid';

bool _isIncomingType(String type) =>
    type == 'Credit' || type == 'Received' || type == 'received';
