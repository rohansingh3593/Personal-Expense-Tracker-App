import 'package:flutter/material.dart';

import '../models/expense_transaction.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.transactions});

  final List<ExpenseTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final spentToday = transactions
        .where(
          (tx) =>
              tx.date.year == now.year &&
              tx.date.month == now.month &&
              tx.date.day == now.day,
        )
        .fold<double>(0, (sum, tx) => sum + tx.amount);

    final spentThisWeek = transactions
        .where((tx) => now.difference(tx.date).inDays < 7)
        .fold<double>(0, (sum, tx) => sum + tx.amount);

    final spentThisMonth = transactions
        .where((tx) => tx.date.year == now.year && tx.date.month == now.month)
        .fold<double>(0, (sum, tx) => sum + tx.amount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MetricCard(title: 'Spent Today', value: spentToday),
        _MetricCard(title: 'Spent This Week', value: spentThisWeek),
        _MetricCard(title: 'Spent This Month', value: spentThisMonth),
        if (transactions.isEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'No transactions yet. Grant SMS access to auto-import bank alerts.',
          ),
        ],
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value});

  final String title;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text('\u20B9${value.toStringAsFixed(2)}'),
      ),
    );
  }
}
