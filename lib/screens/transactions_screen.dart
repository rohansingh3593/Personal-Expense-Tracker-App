import 'package:flutter/material.dart';

import '../models/expense_transaction.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key, required this.transactions});

  final List<ExpenseTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(
        child: Text('No expenses found yet. Tap refresh after granting SMS access.'),
      );
    }

    return ListView.separated(
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return ListTile(
          leading: CircleAvatar(child: Text(tx.category.characters.first)),
          title: Text(tx.merchant),
          subtitle: Text('${tx.category} • ${tx.date.toLocal()}'),
          trailing: Text('₹${tx.amount.toStringAsFixed(2)}'),
        );
      },
    );
  }
}
