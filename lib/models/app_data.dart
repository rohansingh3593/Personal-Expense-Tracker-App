import 'expense_transaction.dart';

class AppData {
  const AppData({
    required this.version,
    required this.transactions,
    required this.incomeCategories,
    required this.expenseCategories,
    required this.subcategories,
    required this.budgets,
    required this.settings,
  });

  final int version;
  final List<ExpenseTransaction> transactions;
  final List<String> incomeCategories;
  final List<String> expenseCategories;
  final Map<String, List<String>> subcategories;
  final Map<String, double> budgets;
  final Map<String, dynamic> settings;

  AppData copyWith({
    int? version,
    List<ExpenseTransaction>? transactions,
    List<String>? incomeCategories,
    List<String>? expenseCategories,
    Map<String, List<String>>? subcategories,
    Map<String, double>? budgets,
    Map<String, dynamic>? settings,
  }) {
    return AppData(
      version: version ?? this.version,
      transactions: transactions ?? this.transactions,
      incomeCategories: incomeCategories ?? this.incomeCategories,
      expenseCategories: expenseCategories ?? this.expenseCategories,
      subcategories: subcategories ?? this.subcategories,
      budgets: budgets ?? this.budgets,
      settings: settings ?? this.settings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'incomeCategories': incomeCategories,
      'expenseCategories': expenseCategories,
      'subcategories': subcategories,
      'budgets': budgets.map((k, v) => MapEntry(k, v)),
      'settings': settings,
    };
  }

  factory AppData.fromJson(Map<String, dynamic> json) {
    final subs = <String, List<String>>{};
    final rawSubs = (json['subcategories'] as Map?) ?? {};
    for (final entry in rawSubs.entries) {
      subs[entry.key.toString()] = (entry.value as List?)?.map((e) => e.toString()).toList() ?? const [];
    }

    final budgets = <String, double>{};
    final rawBudgets = (json['budgets'] as Map?) ?? {};
    for (final entry in rawBudgets.entries) {
      final value = entry.value;
      final parsed = value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
      budgets[entry.key.toString()] = parsed;
    }

    return AppData(
      version: (json['version'] as num?)?.toInt() ?? 1,
      transactions: (json['transactions'] as List?)
              ?.map((e) => ExpenseTransaction.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      incomeCategories: (json['incomeCategories'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      expenseCategories: (json['expenseCategories'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      subcategories: subs,
      budgets: budgets,
      settings: Map<String, dynamic>.from((json['settings'] as Map?) ?? {}),
    );
  }

  static AppData defaults({required int version}) {
    return AppData(
      version: version,
      transactions: const [],
      incomeCategories: const ['Salary', 'Allowance', 'Bonus', 'Petty Cash', 'Other'],
      expenseCategories: const [
        'Food',
        'Social Life',
        'Transport',
        'Health',
        'Education',
        'Household',
        'Beauty',
        'Shopping',
        'Travel',
      ],
      subcategories: const {
        'Food': ['Lunch', 'Dinner', 'Eating Out', 'Beverages', 'Online', 'Fruits'],
        'Transport': ['Fuel', 'Cab', 'Bus'],
        'Shopping': ['Online', 'Offline'],
        'Travel': ['Train', 'Flight', 'Hotel'],
      },
      budgets: const {
        'Food': 5000,
        'Travel': 3000,
        'Shopping': 4000,
      },
      settings: const {
        'currency': 'INR',
        'showBudgetAlerts': true,
        'themePalette': 'blue',
      },
    );
  }
}
