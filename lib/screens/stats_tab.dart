import 'package:flutter/material.dart';

import '../models/expense_transaction.dart';

enum StatsRange { weekly, monthly, yearly, custom }

class StatsTab extends StatefulWidget {
  const StatsTab({super.key, required this.transactions});

  final List<ExpenseTransaction> transactions;

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  StatsRange _range = StatsRange.monthly;
  DateTimeRange? _customRange;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final range = _resolveRange(now);
    final txInRange = widget.transactions
        .where((t) => t.type == 'Debit')
        .where((t) => !t.date.isBefore(range.start) && !t.date.isAfter(range.end))
        .toList();

    final categorySpend = <String, double>{};
    for (final tx in txInRange) {
      categorySpend.update(tx.category, (v) => v + tx.amount, ifAbsent: () => tx.amount);
    }
    final total = txInRange.fold<double>(0, (s, t) => s + t.amount);

    final prevRange = DateTimeRange(
      start: range.start.subtract(range.duration),
      end: range.start,
    );
    final prevTotal = widget.transactions
        .where((t) => t.type == 'Debit')
        .where((t) => !t.date.isBefore(prevRange.start) && t.date.isBefore(prevRange.end))
        .fold<double>(0, (s, t) => s + t.amount);

    final diffPct = prevTotal <= 0 ? null : ((total - prevTotal) / prevTotal) * 100;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            const Text('Range: '),
            DropdownButton<StatsRange>(
              value: _range,
              items: const [
                DropdownMenuItem(value: StatsRange.weekly, child: Text('Weekly')),
                DropdownMenuItem(value: StatsRange.monthly, child: Text('Monthly')),
                DropdownMenuItem(value: StatsRange.yearly, child: Text('Yearly')),
                DropdownMenuItem(value: StatsRange.custom, child: Text('Custom')),
              ],
              onChanged: (value) async {
                if (value == null) return;
                if (value == StatsRange.custom) {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(now.year + 1),
                  );
                  if (picked != null) {
                    setState(() {
                      _range = value;
                      _customRange = picked;
                    });
                  }
                  return;
                }
                setState(() => _range = value);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: const Text('Insights'),
            subtitle: Text(
              diffPct == null
                  ? 'Not enough previous data.'
                  : 'You spent ${diffPct.abs().toStringAsFixed(1)}% ${diffPct >= 0 ? 'more' : 'less'} than previous period.',
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text('Category Distribution', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (categorySpend.isEmpty) const Text('No data for selected range.'),
        ...categorySpend.entries.map((entry) {
          final pct = total <= 0 ? 0 : entry.value / total;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(entry.key)),
                      Text('₹${entry.value.toStringAsFixed(0)} (${(pct * 100).toStringAsFixed(0)}%)'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: pct),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        const Text('Monthly Spending Trend', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ..._monthTrend(widget.transactions).entries.toList().reversed.take(12).map(
              (entry) => ListTile(
                dense: true,
                title: Text(entry.key),
                trailing: Text('₹${entry.value.toStringAsFixed(0)}'),
              ),
            ),
      ],
    );
  }

  DateTimeRange _resolveRange(DateTime now) {
    if (_range == StatsRange.custom && _customRange != null) return _customRange!;
    switch (_range) {
      case StatsRange.weekly:
        return DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      case StatsRange.monthly:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case StatsRange.yearly:
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
      case StatsRange.custom:
        return DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
    }
  }

  Map<String, double> _monthTrend(List<ExpenseTransaction> transactions) {
    final result = <String, double>{};
    for (final tx in transactions.where((t) => t.type == 'Debit')) {
      final key = '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      result.update(key, (v) => v + tx.amount, ifAbsent: () => tx.amount);
    }
    return result;
  }
}
