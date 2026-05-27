import 'dart:math';

import 'package:flutter/material.dart';

import '../models/expense_transaction.dart';

enum StatsRange { overall, weekly, monthly, yearly, custom }

class StatsTab extends StatefulWidget {
  const StatsTab({super.key, required this.transactions});

  final List<ExpenseTransaction> transactions;

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  StatsRange _range = StatsRange.overall;
  DateTimeRange? _customRange;
  String? _selectedCategory;
  DateTime _periodAnchor = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final range = _resolveRange(now);
    final txInRange = _transactionsForRange(range);

    final totalIncome = txInRange
        .where((t) => _isIncomingType(t.type) && t.category != 'Lending')
        .fold<double>(0, (s, t) => s + t.amount);
    final totalExpense = txInRange
        .where((t) => _isOutgoingType(t.type) && t.category != 'Lending')
        .fold<double>(0, (s, t) => s + t.amount);
    final totalLending = txInRange
        .where((t) => _isOutgoingType(t.type) && t.category == 'Lending')
        .fold<double>(0, (s, t) => s + t.amount);
    final totalReceived = txInRange
        .where((t) => _isIncomingType(t.type) && t.category == 'Lending')
        .fold<double>(0, (s, t) => s + t.amount);

    final categorySpend = _categorySpend(txInRange);
    final totalCategorySpend =
        categorySpend.values.fold<double>(0, (s, v) => s + v);
    final lendingOwes = _lendingRemaining(txInRange);
    final spendingByAccount = <String, double>{};
    for (final tx in txInRange.where((t) => _isOutgoingType(t.type))) {
      spendingByAccount.update(
        tx.account,
        (v) => v + tx.amount,
        ifAbsent: () => tx.amount,
      );
    }
    final accountSpendTotal =
        spendingByAccount.values.fold<double>(0, (a, b) => a + b);
    final trendEntries = _monthTrend(txInRange).entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final previousRange = _previousRange(range);
    final prevTotal = previousRange == null
        ? 0.0
        : _transactionsForRange(previousRange)
            .where((t) => _isOutgoingType(t.type))
            .fold<double>(0, (s, t) => s + t.amount);
    final selectedSpend = totalExpense + totalLending;
    final diffPct = range == null || prevTotal <= 0
        ? null
        : ((selectedSpend - prevTotal) / prevTotal) * 100;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            const Text('Range: '),
            DropdownButton<StatsRange>(
              value: _range,
              items: const [
                DropdownMenuItem(
                  value: StatsRange.overall,
                  child: Text('Overall'),
                ),
                DropdownMenuItem(
                  value: StatsRange.weekly,
                  child: Text('Weekly'),
                ),
                DropdownMenuItem(
                  value: StatsRange.monthly,
                  child: Text('Monthly'),
                ),
                DropdownMenuItem(
                  value: StatsRange.yearly,
                  child: Text('Yearly'),
                ),
                DropdownMenuItem(
                  value: StatsRange.custom,
                  child: Text('Custom'),
                ),
              ],
              onChanged: (value) async {
                if (value == null) return;
                if (value == StatsRange.custom) {
                  setState(() => _range = value);
                  await _pickCustomRange(now);
                  return;
                }
                setState(() {
                  _range = value;
                  _periodAnchor = now;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_range == StatsRange.custom)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _pickCustomRange(now),
              icon: const Icon(Icons.date_range),
              label: Text(
                _customRange == null ? 'Pick date range' : _customRangeLabel(_customRange!),
              ),
            ),
          ),
        if (_range == StatsRange.weekly ||
            _range == StatsRange.monthly ||
            _range == StatsRange.yearly)
          Row(
            children: [
              IconButton(
                onPressed: _goToPreviousPeriod,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _periodLabel(range ?? _resolveRange(now)!),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              IconButton(
                onPressed:
                    _canGoToNextPeriod(now) ? () => _goToNextPeriod(now) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        Card(
          child: ListTile(
            title: const Text('Insights'),
            subtitle: Text(
              _range == StatsRange.overall
                  ? 'Showing complete account history with no date filter.'
                  : diffPct == null
                      ? 'Not enough previous data.'
                      : 'Compared with ${_previousPeriodLabel(range)}: you spent '
                          '${diffPct.abs().toStringAsFixed(1)}% '
                          '${diffPct >= 0 ? 'more' : 'less'}.',
            ),
          ),
        ),
        const SizedBox(height: 10),
        _StatsTotalsGrid(
          totalIncome: totalIncome,
          totalExpense: totalExpense,
          totalLending: totalLending,
          totalReceived: totalReceived,
        ),
        const SizedBox(height: 10),
        const Text(
          'Category Distribution',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        if (categorySpend.isEmpty) const Text('No data for selected range.'),
        if (categorySpend.isNotEmpty)
          SizedBox(
            height: 220,
            child: _PieChartCard(data: categorySpend),
          ),
        if (categorySpend.isNotEmpty) const SizedBox(height: 8),
        ...categorySpend.entries.map((entry) {
          final double pct = totalCategorySpend <= 0
              ? 0.0
              : entry.value / totalCategorySpend;
          return InkWell(
            onTap: () => setState(() => _selectedCategory = entry.key),
            child: Card(
              color: _selectedCategory == entry.key
                  ? Theme.of(context).colorScheme.surfaceVariant
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(entry.key)),
                        Text(
                          '\u20B9${entry.value.toStringAsFixed(0)} '
                          '(${(pct * 100).toStringAsFixed(0)}%)',
                        ),
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
            onSelectPerson: (person) => _openPersonDetail(person),
          ),
        ],
        const SizedBox(height: 10),
        if (lendingOwes.isNotEmpty) ...[
          const Text(
            'Lending by Person (Remaining)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          SizedBox(height: 220, child: _PieChartCard(data: lendingOwes)),
          ...lendingOwes.entries.map((entry) => ListTile(
                dense: true,
                title: Text(entry.key),
                trailing: Text('₹${entry.value.toStringAsFixed(0)}'),
                onTap: () => _openPersonDetail(entry.key),
              )),
          const SizedBox(height: 10),
        ],
        if (spendingByAccount.isNotEmpty) ...[
          const Text(
            'Spending by Account',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          SizedBox(height: 220, child: _PieChartCard(data: spendingByAccount)),
          ...spendingByAccount.entries.map((entry) {
            final pct = accountSpendTotal <= 0
                ? 0
                : (entry.value / accountSpendTotal) * 100;
            return ListTile(
              dense: true,
              title: Text(entry.key),
              trailing: Text(
                '₹${entry.value.toStringAsFixed(0)} '
                '(${pct.toStringAsFixed(0)}%)',
              ),
            );
          }),
          const SizedBox(height: 10),
        ],
        const Text(
          'Monthly Spending Trend',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        if (trendEntries.isEmpty)
          const Text('No trend data for selected range.'),
        ...trendEntries.map(
          (entry) => ListTile(
            dense: true,
            title: Text(entry.key),
            trailing: Text('\u20B9${entry.value.toStringAsFixed(0)}'),
          ),
        ),
      ],
    );
  }

  DateTimeRange? _resolveRange(DateTime now) {
    if (_range == StatsRange.custom && _customRange != null) {
      return _customRange!;
    }
    switch (_range) {
      case StatsRange.overall:
        return null;
      case StatsRange.weekly:
        final today = DateTime(_periodAnchor.year, _periodAnchor.month, _periodAnchor.day);
        final startOfWeek = today.subtract(
          Duration(days: today.weekday - DateTime.monday),
        );
        final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
        return DateTimeRange(start: startOfWeek, end: endOfWeek.isAfter(now) ? now : endOfWeek);
      case StatsRange.monthly:
        final monthStart = DateTime(_periodAnchor.year, _periodAnchor.month, 1);
        final monthEnd = DateTime(_periodAnchor.year, _periodAnchor.month + 1, 0, 23, 59, 59, 999);
        return DateTimeRange(start: monthStart, end: monthEnd.isAfter(now) ? now : monthEnd);
      case StatsRange.yearly:
        final yearStart = DateTime(_periodAnchor.year, 1, 1);
        final yearEnd = DateTime(_periodAnchor.year, 12, 31, 23, 59, 59, 999);
        return DateTimeRange(start: yearStart, end: yearEnd.isAfter(now) ? now : yearEnd);
      case StatsRange.custom:
        return DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );
    }
  }

  DateTimeRange? _previousRange(DateTimeRange? range) {
    if (range == null || _range == StatsRange.overall || _range == StatsRange.custom) return null;
    switch (_range) {
      case StatsRange.weekly:
        return DateTimeRange(start: range.start.subtract(const Duration(days: 7)), end: range.end.subtract(const Duration(days: 7)));
      case StatsRange.monthly:
        return DateTimeRange(
          start: DateTime(range.start.year, range.start.month - 1, 1),
          end: DateTime(range.start.year, range.start.month, 0, 23, 59, 59, 999),
        );
      case StatsRange.yearly:
        return DateTimeRange(start: DateTime(range.start.year - 1, 1, 1), end: DateTime(range.start.year - 1, 12, 31, 23, 59, 59, 999));
      default:
        return null;
    }
  }

  String _periodLabel(DateTimeRange range) {
    switch (_range) {
      case StatsRange.weekly:
        return '${range.start.day} ${_monthShort(range.start.month)} ${range.start.year} - ${range.end.day} ${_monthShort(range.end.month)} ${range.end.year}';
      case StatsRange.monthly:
        return '${_monthLong(range.start.month)} ${range.start.year}';
      case StatsRange.yearly:
        return '${range.start.year}';
      default:
        return '';
    }
  }

  String _previousPeriodLabel(DateTimeRange? currentRange) {
    final prev = _previousRange(currentRange);
    return prev == null ? 'previous period' : _periodLabel(prev);
  }

  String _monthShort(int m) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
  String _monthLong(int m) => const ['January','February','March','April','May','June','July','August','September','October','November','December'][m - 1];

  bool _canGoToNextPeriod(DateTime now) {
    switch (_range) {
      case StatsRange.weekly:
        final start = DateTime(_periodAnchor.year, _periodAnchor.month, _periodAnchor.day).subtract(Duration(days: _periodAnchor.weekday - DateTime.monday));
        final thisWeekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - DateTime.monday));
        return start.isBefore(thisWeekStart);
      case StatsRange.monthly:
        return _periodAnchor.year < now.year || (_periodAnchor.year == now.year && _periodAnchor.month < now.month);
      case StatsRange.yearly:
        return _periodAnchor.year < now.year;
      default:
        return false;
    }
  }

  void _goToPreviousPeriod() {
    setState(() {
      _periodAnchor = switch (_range) {
        StatsRange.weekly => _periodAnchor.subtract(const Duration(days: 7)),
        StatsRange.monthly => DateTime(_periodAnchor.year, _periodAnchor.month - 1, 1),
        StatsRange.yearly => DateTime(_periodAnchor.year - 1, 1, 1),
        _ => _periodAnchor,
      };
    });
  }

  void _goToNextPeriod(DateTime now) {
    if (!_canGoToNextPeriod(now)) return;
    setState(() {
      _periodAnchor = switch (_range) {
        StatsRange.weekly => _periodAnchor.add(const Duration(days: 7)),
        StatsRange.monthly => DateTime(_periodAnchor.year, _periodAnchor.month + 1, 1),
        StatsRange.yearly => DateTime(_periodAnchor.year + 1, 1, 1),
        _ => _periodAnchor,
      };
    });
  }

  Future<void> _pickCustomRange(DateTime now) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      _customRange = DateTimeRange(
        start: picked.start,
        end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999),
      );
    });
  }

  String _customRangeLabel(DateTimeRange range) => '${range.start.day} ${_monthShort(range.start.month)} ${range.start.year} - ${range.end.day} ${_monthShort(range.end.month)} ${range.end.year}';

  List<ExpenseTransaction> _transactionsForRange(
    DateTimeRange? range, {
    bool inclusiveEnd = true,
  }) {
    final transactions = widget.transactions.where(
      (t) => _isOutgoingType(t.type) || _isIncomingType(t.type),
    );
    if (range == null) return transactions.toList();

    return transactions.where((t) {
      final isAfterStart = !t.date.isBefore(range.start);
      final isBeforeEnd = inclusiveEnd
          ? !t.date.isAfter(range.end)
          : t.date.isBefore(range.end);
      return isAfterStart && isBeforeEnd;
    }).toList();
  }

  Map<String, double> _categorySpend(List<ExpenseTransaction> transactions) {
    final result = <String, double>{};
    for (final tx in transactions.where((t) => _isOutgoingType(t.type))) {
      result.update(
        tx.category,
        (v) => v + tx.amount,
        ifAbsent: () => tx.amount,
      );
    }
    return Map.fromEntries(
      result.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  Map<String, double> _monthTrend(List<ExpenseTransaction> transactions) {
    final outgoingTransactions = transactions
        .where((t) => _isOutgoingType(t.type))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (outgoingTransactions.isEmpty) return const <String, double>{};

    final first = outgoingTransactions.first.date;
    final last = outgoingTransactions.last.date;
    final result = <String, double>{};
    for (
      var cursor = DateTime(first.year, first.month);
      !cursor.isAfter(DateTime(last.year, last.month));
      cursor = DateTime(cursor.year, cursor.month + 1)
    ) {
      result[_monthKey(cursor)] = 0;
    }

    for (final tx in outgoingTransactions) {
      final key = _monthKey(tx.date);
      result.update(key, (v) => v + tx.amount, ifAbsent: () => tx.amount);
    }
    return result;
  }

  String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  Map<String, double> _lendingRemaining(List<ExpenseTransaction> txInRange) {
    final given = <String, double>{};
    final returned = <String, double>{};
    for (final tx in txInRange.where(
      (t) =>
          t.category == 'Lending' &&
          (t.subcategory ?? '').trim().isNotEmpty,
    )) {
      final person = tx.subcategory!.trim();
      if (tx.type == 'Debit' || tx.type == 'Paid' || tx.type == 'paid') {
        given.update(
          person,
          (v) => v + tx.amount,
          ifAbsent: () => tx.amount,
        );
      } else if (tx.type == 'Credit' ||
          tx.type == 'Received' ||
          tx.type == 'received') {
        returned.update(
          person,
          (v) => v + tx.amount,
          ifAbsent: () => tx.amount,
        );
      }
    }
    final result = <String, double>{};
    for (final person in {...given.keys, ...returned.keys}) {
      final remaining = (given[person] ?? 0) - (returned[person] ?? 0);
      if (remaining > 0) result[person] = remaining;
    }
    return result;
  }

  void _openPersonDetail(String person) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LendingPersonDetailScreen(
          person: person,
          transactions: widget.transactions,
        ),
      ),
    );
  }
}

bool _isOutgoingType(String type) =>
    type == 'Debit' || type == 'Paid' || type == 'paid';

bool _isIncomingType(String type) =>
    type == 'Credit' || type == 'Received' || type == 'received';

class _StatsTotalsGrid extends StatelessWidget {
  const _StatsTotalsGrid({
    required this.totalIncome,
    required this.totalExpense,
    required this.totalLending,
    required this.totalReceived,
  });

  final double totalIncome;
  final double totalExpense;
  final double totalLending;
  final double totalReceived;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.45,
      children: [
        _StatsTotalCard(
          label: 'Total income',
          amount: totalIncome,
          color: Colors.green,
        ),
        _StatsTotalCard(
          label: 'Total expense',
          amount: totalExpense,
          color: Colors.red,
        ),
        _StatsTotalCard(
          label: 'Total lending',
          amount: totalLending,
          color: Colors.orange,
        ),
        _StatsTotalCard(
          label: 'Total received',
          amount: totalReceived,
          color: Colors.blue,
        ),
      ],
    );
  }
}

class _StatsTotalCard extends StatelessWidget {
  const _StatsTotalCard({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '₹${amount.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
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
                  colors: List.generate(
                    entries.length,
                    (i) => colors[i % colors.length],
                  ),
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
      oldDelegate.values != values ||
      oldDelegate.colors != colors ||
      oldDelegate.borderColor != borderColor;
}

class _SubcategoryBreakdown extends StatelessWidget {
  const _SubcategoryBreakdown({
    required this.category,
    required this.transactions,
    required this.onSelectPerson,
  });

  final String category;
  final List<ExpenseTransaction> transactions;
  final ValueChanged<String> onSelectPerson;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, double>{};
    for (final tx in transactions.where(
      (t) => t.category == category && _isOutgoingType(t.type),
    )) {
      final rawSubcategory = tx.subcategory?.trim() ?? '';
      final sub = rawSubcategory.isEmpty ? 'Uncategorized' : rawSubcategory;
      grouped.update(sub, (v) => v + tx.amount, ifAbsent: () => tx.amount);
    }
    final total = grouped.values.fold<double>(0, (a, b) => a + b);
    final sorted = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
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
            trailing: Text(
              '₹${entry.value.toStringAsFixed(0)} '
              '(${pct.toStringAsFixed(0)}%)',
            ),
            onTap:
                category == 'Lending' ? () => onSelectPerson(entry.key) : null,
          );
        }),
      ],
    );
  }
}

class _LendingPersonDetailScreen extends StatelessWidget {
  const _LendingPersonDetailScreen({
    required this.person,
    required this.transactions,
  });

  final String person;
  final List<ExpenseTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final items = transactions
        .where(
          (t) => t.category == 'Lending' && (t.subcategory ?? '').trim() == person,
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    var paid = 0.0;
    var received = 0.0;
    for (final tx in items) {
      if (tx.type == 'Paid' || tx.type == 'paid' || tx.type == 'Debit') {
        paid += tx.amount;
      } else if (tx.type == 'Received' ||
          tx.type == 'received' ||
          tx.type == 'Credit') {
        received += tx.amount;
      }
    }
    final pending = paid - received;
    return Scaffold(
      appBar: AppBar(title: Text(person)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Paid: ₹${paid.toStringAsFixed(0)}'),
                  Text('Received: ₹${received.toStringAsFixed(0)}'),
                  Text('Pending: ₹${pending.toStringAsFixed(0)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('History', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (items.isEmpty) const Text('No lending transactions for this person.'),
          ...items.map((tx) {
            final isPaid =
                tx.type == 'Paid' || tx.type == 'paid' || tx.type == 'Debit';
            final label = isPaid ? 'Paid' : 'Received';
            return ListTile(
              dense: true,
              title: Text('${tx.date.day}/${tx.date.month}/${tx.date.year}'),
              trailing: Text(
                '${isPaid ? '-' : '+'}₹${tx.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  color: isPaid ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text('$label ₹${tx.amount.toStringAsFixed(0)}'),
            );
          }),
        ],
      ),
    );
  }
}
