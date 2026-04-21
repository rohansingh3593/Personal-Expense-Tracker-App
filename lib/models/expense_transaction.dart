class ExpenseTransaction {
  const ExpenseTransaction({
    required this.amount,
    required this.merchant,
    required this.category,
    required this.type,
    required this.date,
    required this.rawMessage,
  });

  final double amount;
  final String merchant;
  final String category;
  final String type;
  final DateTime date;
  final String rawMessage;

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'merchant': merchant,
      'category': category,
      'type': type,
      'date': date.toIso8601String(),
      'rawMessage': rawMessage,
    };
  }

  factory ExpenseTransaction.fromJson(Map<String, dynamic> json) {
    return ExpenseTransaction(
      amount: (json['amount'] as num).toDouble(),
      merchant: json['merchant'] as String,
      category: json['category'] as String,
      type: json['type'] as String,
      date: DateTime.parse(json['date'] as String),
      rawMessage: json['rawMessage'] as String,
    );
  }
}
