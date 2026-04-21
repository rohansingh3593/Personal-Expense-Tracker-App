import 'package:flutter/material.dart';

import '../models/expense_transaction.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key, required this.transactions});

  final List<ExpenseTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, double>{};

    for (final tx in transactions) {
      byCategory.update(tx.category, (value) => value + tx.amount,
          ifAbsent: () => tx.amount);
    }

    final tiles = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Top categories',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 8),
        ...tiles.map(
          (entry) => Card(
            child: ListTile(
              title: Text(entry.key),
              trailing: Text('₹${entry.value.toStringAsFixed(2)}'),
            ),
          ),
        ),
      ],
    );
  }
}
