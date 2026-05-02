import 'package:flutter/material.dart';
import 'dart:math';

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
  String? _selectedCategory;
  String? _selectedPerson;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final range = _resolveRange(now);
    final txInRange = widget.transactions
        .where((t) => t.type == 'Debit' || t.type == 'Paid' || t.type == 'paid')
        .where((t) => !t.date.isBefore(range.start) && !t.date.isAfter(range.end))
        .toList();

    final categorySpend = <String, double>{};
    for (final tx in txInRange) {
      categorySpend.update(tx.category, (v) => v + tx.amount, ifAbsent: () => tx.amount);
    }
    final lendingOwes = _lendingRemaining(txInRange);
    final total = txInRange.fold<double>(0, (s, t) => s + t.amount);

    final prevRange = DateTimeRange(
      start: range.start.subtract(range.duration),
      end: range.start,
    );
    final prevTotal = widget.transactions
        .where((t) => t.type == 'Debit' || t.type == 'Paid' || t.type == 'paid')
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
        if (categorySpend.isNotEmpty)
          SizedBox(
            height: 220,
            child: _PieChartCard(data: categorySpend),
          ),
        if (categorySpend.isNotEmpty) const SizedBox(height: 8),
        ...categorySpend.entries.map((entry) {
          final double pct = total <= 0 ? 0.0 : entry.value / total;
          return InkWell(
            onTap: () => setState(() => _selectedCategory = entry.key),
            child: Card(
              color: _selectedCategory == entry.key ? Theme.of(context).colorScheme.surfaceVariant : null,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(entry.key)),
                        Text('\u20B9${entry.value.toStringAsFixed(0)} (${(pct * 100).toStringAsFixed(0)}%)'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: pct),
                  ],
                ),
              ),
            ),
          );
        }),
        if (_selectedCategory != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_selectedCategory!} Subcategories',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedCategory = null),
                child: const Text('Back'),
              ),
            ],
          ),
          _SubcategoryBreakdown(
            category: _selectedCategory!,
            transactions: txInRange,
            selectedPerson: _selectedPerson,
            onSelectPerson: (person) => setState(() => _selectedPerson = person),
          ),
        ],
        const SizedBox(height: 10),
        if (lendingOwes.isNotEmpty) ...[
          const Text('Lending by Person (Remaining)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          SizedBox(height: 220, child: _PieChartCard(data: lendingOwes)),
          ...lendingOwes.entries.map((entry) => ListTile(
                dense: true,
                title: Text(entry.key),
                trailing: Text('₹${entry.value.toStringAsFixed(0)}'),
              )),
          const SizedBox(height: 10),
        ],
        const Text('Monthly Spending Trend', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ..._monthTrend(widget.transactions).entries.toList().reversed.take(12).map(
              (entry) => ListTile(
                dense: true,
                title: Text(entry.key),
                trailing: Text('\u20B9${entry.value.toStringAsFixed(0)}'),
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
    for (final tx in transactions.where((t) => t.type == 'Debit' || t.type == 'Paid' || t.type == 'paid')) {
      final key = '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      result.update(key, (v) => v + tx.amount, ifAbsent: () => tx.amount);
    }
    return result;
  }

  Map<String, double> _lendingRemaining(List<ExpenseTransaction> txInRange) {
    final given = <String, double>{};
    final returned = <String, double>{};
    for (final tx in txInRange.where((t) => t.category == 'Lending' && (t.subcategory ?? '').trim().isNotEmpty)) {
      final person = tx.subcategory!.trim();
      if (tx.type == 'Debit' || tx.type == 'Paid' || tx.type == 'paid') {
        given.update(person, (v) => v + tx.amount, ifAbsent: () => tx.amount);
      } else if (tx.type == 'Credit' || tx.type == 'Received' || tx.type == 'received') {
        returned.update(person, (v) => v + tx.amount, ifAbsent: () => tx.amount);
      }
    }
    final result = <String, double>{};
    for (final person in {...given.keys, ...returned.keys}) {
      final remaining = (given[person] ?? 0) - (returned[person] ?? 0);
      if (remaining > 0) result[person] = remaining;
    }
    return result;
  }
}

class _PieChartCard extends StatelessWidget {
  const _PieChartCard({required this.data});

  final Map<String, double> data;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.where((e) => e.value > 0).toList();
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.teal,
      Colors.amber,
      Colors.indigo,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: CustomPaint(
                painter: _PieChartPainter(
                  values: entries.map((e) => e.value).toList(),
                  colors: List.generate(entries.length, (i) => colors[i % colors.length]),
                  borderColor: Theme.of(context).colorScheme.surface,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(entries.length, (i) {
                  final color = colors[i % colors.length];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entries[i].key,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  _PieChartPainter({
    required this.values,
    required this.colors,
    required this.borderColor,
  });

  final List<double> values;
  final List<Color> colors;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.38;
    final rect = Rect.fromCircle(center: center, radius: radius);
    var start = -pi / 2;

    for (var i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * pi;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.55
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }

    final border = Paint()
      ..color = borderColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, border);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors || oldDelegate.borderColor != borderColor;
}

class _SubcategoryBreakdown extends StatelessWidget {
  const _SubcategoryBreakdown({
    required this.category,
    required this.transactions,
    required this.selectedPerson,
    required this.onSelectPerson,
  });

  final String category;
  final List<ExpenseTransaction> transactions;
  final String? selectedPerson;
  final ValueChanged<String> onSelectPerson;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, double>{};
    for (final tx in transactions.where((t) => t.category == category)) {
      final sub = (tx.subcategory ?? 'Uncategorized').trim().isEmpty ? 'Uncategorized' : tx.subcategory!.trim();
      grouped.update(sub, (v) => v + tx.amount, ifAbsent: () => tx.amount);
    }
    final total = grouped.values.fold<double>(0, (a, b) => a + b);
    final sorted = grouped.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) return const Text('No subcategory data.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total: ₹${total.toStringAsFixed(0)}'),
        const SizedBox(height: 6),
        SizedBox(height: 220, child: _PieChartCard(data: grouped)),
        ...sorted.map((entry) {
          final pct = total <= 0 ? 0 : (entry.value / total) * 100;
          return ListTile(
            dense: true,
            title: Text(entry.key),
            trailing: Text('₹${entry.value.toStringAsFixed(0)} (${pct.toStringAsFixed(0)}%)'),
            onTap: category == 'Lending' ? () => onSelectPerson(entry.key) : null,
          );
        }),
        if (category == 'Lending' && selectedPerson != null)
          _LendingPersonDetail(
            person: selectedPerson!,
            transactions: transactions,
          ),
      ],
    );
  }
}

class _LendingPersonDetail extends StatelessWidget {
  const _LendingPersonDetail({required this.person, required this.transactions});
  final String person;
  final List<ExpenseTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final items = transactions
        .where((t) => t.category == 'Lending' && (t.subcategory ?? '').trim() == person)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    var paid = 0.0;
    var received = 0.0;
    for (final tx in items) {
      if (tx.type == 'Paid' || tx.type == 'paid' || tx.type == 'Debit') {
        paid += tx.amount;
      } else if (tx.type == 'Received' || tx.type == 'received' || tx.type == 'Credit') {
        received += tx.amount;
      }
    }
    final pending = paid - received;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(person, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('Total Paid: ₹${paid.toStringAsFixed(0)}'),
        Text('Total Received: ₹${received.toStringAsFixed(0)}'),
        Text('Pending: ₹${pending.toStringAsFixed(0)}'),
        const SizedBox(height: 6),
        ...items.map((tx) {
          final isPaid = tx.type == 'Paid' || tx.type == 'paid' || tx.type == 'Debit';
          final label = isPaid ? 'Paid' : 'Received';
          return ListTile(
            dense: true,
            title: Text('${tx.date.day}/${tx.date.month}/${tx.date.year} → $label ₹${tx.amount.toStringAsFixed(0)}'),
            titleTextStyle: TextStyle(color: isPaid ? Colors.red : Colors.green),
          );
        }),
      ],
    );
  }
}
