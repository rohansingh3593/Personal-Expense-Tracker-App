import 'dart:math';

import 'package:flutter/material.dart';

import '../models/expense_transaction.dart';

class AccountsTab extends StatelessWidget {
  const AccountsTab({
    super.key,
    required this.transactions,
    required this.categorySubcategories,
  });

  final List<ExpenseTransaction> transactions;
  final Map<String, List<String>> categorySubcategories;

  @override
  Widget build(BuildContext context) {
    final debitTx = transactions.where((t) => t.type == 'Debit').toList();
    final monthNow = _totalForMonth(DateTime.now(), debitTx);
    final monthPrev = _totalForMonth(
      DateTime(DateTime.now().year, DateTime.now().month - 1),
      debitTx,
    );
    final weekNow = _totalForDays(7, debitTx);
    final weekPrev = _totalBetween(
      DateTime.now().subtract(const Duration(days: 14)),
      DateTime.now().subtract(const Duration(days: 7)),
      debitTx,
    );
    final yearNow = _totalForYear(DateTime.now().year, debitTx);
    final yearPrev = _totalForYear(DateTime.now().year - 1, debitTx);

    final categoryNow = _categoryTotalsForMonth(DateTime.now(), debitTx);
    final categoryPrev = _categoryTotalsForMonth(
      DateTime(DateTime.now().year, DateTime.now().month - 1),
      debitTx,
    );
    final categoryKeys = categoryNow.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Spending Trend', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: CustomPaint(
            painter: _SimpleTrendPainter(_last30DaySeries(debitTx)),
            child: Container(),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Comparison', style: TextStyle(fontWeight: FontWeight.bold)),
        _compareTile('This week', weekNow, weekPrev),
        _compareTile('This month', monthNow, monthPrev),
        _compareTile('This year', yearNow, yearPrev),
        const SizedBox(height: 12),
        const Text(
          'Category-wise Change',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        ...categoryKeys.map((cat) {
          final nowVal = categoryNow[cat] ?? 0;
          final prevVal = categoryPrev[cat] ?? 0;
          final pct = prevVal <= 0 ? null : ((nowVal - prevVal) / prevVal) * 100;
          return ListTile(
            dense: true,
            title: Text(cat),
            subtitle: Text('\u20B9${nowVal.toStringAsFixed(0)}'),
            trailing: Text(
              pct == null ? '-' : '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
              style: TextStyle(
                color: pct != null && pct > 0 ? Colors.red : Colors.green,
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        const Text(
          'Subcategory Insights',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        ...categorySubcategories.entries.map(
          (entry) => Card(
            child: ListTile(
              title: Text(entry.key),
              subtitle: Text(
                entry.value.isEmpty ? 'No subcategories' : entry.value.join(', '),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _compareTile(String label, double current, double previous) {
    final pct = previous <= 0 ? null : ((current - previous) / previous) * 100;
    return ListTile(
      dense: true,
      title: Text(label),
      subtitle: Text(
        'Current: \u20B9${current.toStringAsFixed(0)} | Previous: \u20B9${previous.toStringAsFixed(0)}',
      ),
      trailing: Text(
        pct == null ? '-' : '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
        style: TextStyle(color: pct != null && pct > 0 ? Colors.red : Colors.green),
      ),
    );
  }

  double _totalForMonth(DateTime date, List<ExpenseTransaction> tx) {
    return tx
        .where((t) => t.date.year == date.year && t.date.month == date.month)
        .fold<double>(0, (s, t) => s + t.amount);
  }

  double _totalForYear(int year, List<ExpenseTransaction> tx) {
    return tx
        .where((t) => t.date.year == year)
        .fold<double>(0, (s, t) => s + t.amount);
  }

  double _totalForDays(int days, List<ExpenseTransaction> tx) {
    final from = DateTime.now().subtract(Duration(days: days));
    return tx
        .where((t) => t.date.isAfter(from))
        .fold<double>(0, (s, t) => s + t.amount);
  }

  double _totalBetween(
    DateTime start,
    DateTime end,
    List<ExpenseTransaction> tx,
  ) {
    return tx
        .where((t) => !t.date.isBefore(start) && t.date.isBefore(end))
        .fold<double>(0, (s, t) => s + t.amount);
  }

  Map<String, double> _categoryTotalsForMonth(
    DateTime date,
    List<ExpenseTransaction> tx,
  ) {
    final map = <String, double>{};
    for (final t
        in tx.where((x) => x.date.year == date.year && x.date.month == date.month)) {
      map.update(t.category, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    return map;
  }

  List<double> _last30DaySeries(List<ExpenseTransaction> tx) {
    final now = DateTime.now();
    final values = <double>[];
    for (var i = 29; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final total = tx
          .where(
            (t) =>
                t.date.year == day.year &&
                t.date.month == day.month &&
                t.date.day == day.day,
          )
          .fold<double>(0, (s, t) => s + t.amount);
      values.add(total);
    }
    return values;
  }
}

class _SimpleTrendPainter extends CustomPainter {
  _SimpleTrendPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final maxVal = max(1.0, values.reduce(max));
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] / maxVal) * (size.height - 8)) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SimpleTrendPainter oldDelegate) =>
      oldDelegate.values != values;
}
