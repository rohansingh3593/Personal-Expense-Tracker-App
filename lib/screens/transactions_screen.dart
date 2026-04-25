import 'package:flutter/material.dart';

import '../models/expense_transaction.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key, required this.transactions});

  final List<ExpenseTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(
        child: Text(
          'No expenses found yet. Grant SMS permission to auto-read transactions.',
          textAlign: TextAlign.center,
        ),
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
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${tx.category} - ${tx.date.toLocal()}'),
              const SizedBox(height: 4),
              Text(
                tx.rawMessage,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          trailing: Text('\u20B9${tx.amount.toStringAsFixed(2)}'),
          isThreeLine: true,
        );
      },
    );
  }
}
