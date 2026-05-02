class ExpenseTransaction {
  const ExpenseTransaction({
    required this.id,
    required this.amount,
    required this.account,
    required this.merchant,
    required this.category,
    this.subcategory,
    required this.type,
    required this.date,
    this.note = '',
    this.description = '',
    this.imagePaths = const [],
    this.isBookmarked = false,
    required this.rawMessage,
    this.source = 'sms_auto',
  });

  final String id;
  final double amount;
  final String account;
  final String merchant;
  final String category;
  final String? subcategory;
  final String type;
  final DateTime date;
  final String note;
  final String description;
  final List<String> imagePaths;
  final bool isBookmarked;
  final String rawMessage;
  final String source;

  ExpenseTransaction copyWith({
    String? id,
    double? amount,
    String? account,
    String? merchant,
    String? category,
    String? subcategory,
    String? type,
    DateTime? date,
    String? note,
    String? description,
    List<String>? imagePaths,
    bool? isBookmarked,
    String? rawMessage,
    String? source,
  }) {
    return ExpenseTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      account: account ?? this.account,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      type: type ?? this.type,
      date: date ?? this.date,
      note: note ?? this.note,
      description: description ?? this.description,
      imagePaths: imagePaths ?? this.imagePaths,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      rawMessage: rawMessage ?? this.rawMessage,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'account': account,
      'merchant': merchant,
      'category': category,
      'subcategory': subcategory,
      'type': type,
      'date': date.toIso8601String(),
      'note': note,
      'description': description,
      'imagePaths': imagePaths,
      'isBookmarked': isBookmarked,
      'rawMessage': rawMessage,
      'source': source,
    };
  }

  factory ExpenseTransaction.fromJson(Map<String, dynamic> json) {
    return ExpenseTransaction(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      account: (json['account'] as String?) ?? 'Cash',
      merchant: json['merchant'] as String,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      type: json['type'] as String,
      date: DateTime.parse(json['date'] as String),
      note: (json['note'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      imagePaths: (json['imagePaths'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      isBookmarked: (json['isBookmarked'] as bool?) ?? false,
      rawMessage: json['rawMessage'] as String,
      source: (json['source'] as String?) ?? 'sms_auto',
    );
  }
}
