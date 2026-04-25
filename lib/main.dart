import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/expense_transaction.dart';
import 'screens/accounts_tab.dart';
import 'screens/more_tab.dart';
import 'screens/stats_tab.dart';
import 'screens/transactions_tab.dart';
import 'services/sms_service.dart';

void main() {
  runApp(const ExpenseTrackerApp());
}

const bool smsFeatureEnabled = bool.fromEnvironment(
  'SMS_ENABLED',
  defaultValue: true,
);

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SmsService _smsService = SmsService();
  final List<ExpenseTransaction> _transactions = [];

  final List<String> _incomeCategories = ['Salary', 'Allowance', 'Bonus', 'Petty Cash', 'Other'];
  final List<String> _expenseCategories = [
    'Food',
    'Social Life',
    'Transport',
    'Health',
    'Education',
    'Household',
    'Beauty',
    'Shopping',
    'Travel',
  ];
  Map<String, List<String>> _subcategories = {
    'Food': ['Lunch', 'Dinner', 'Eating Out', 'Beverages', 'Online', 'Fruits'],
    'Transport': ['Fuel', 'Cab', 'Bus'],
    'Shopping': ['Online', 'Offline'],
    'Travel': ['Train', 'Flight', 'Hotel'],
  };
  Map<String, double> _budgets = {
    'Food': 5000,
    'Travel': 3000,
    'Shopping': 4000,
  };

  bool _loading = false;
  bool _permissionGranted = false;
  bool _limitedMode = false;
  bool _showOpenSettings = false;
  String? _permissionMessage;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    if (!smsFeatureEnabled) {
      _limitedMode = true;
      _permissionMessage = 'SMS auto-read is disabled in this build.';
    }
  }

  Future<void> _requestPermissionAndLoad() async {
    if (!smsFeatureEnabled) {
      setState(() {
        _permissionGranted = false;
        _limitedMode = true;
      });
      return;
    }

    setState(() => _loading = true);

    final status = await _smsService.requestSmsPermission();
    if (!mounted) return;

    if (!status.isGranted) {
      setState(() {
        _permissionGranted = false;
        _showOpenSettings = status.isPermanentlyDenied || status.isRestricted;
        _permissionMessage = status.isPermanentlyDenied
            ? 'SMS permission is permanently denied. Please enable it in app settings.'
            : 'SMS permission denied. You can continue and enable it later.';
        _loading = false;
      });
      return;
    }

    final result = await _smsService.readExpensesFromSms();
    if (!mounted) return;

    setState(() {
      _permissionGranted = true;
      _limitedMode = false;
      _showOpenSettings = false;
      _permissionMessage = null;
      _transactions
        ..clear()
        ..addAll(result.parsedExpenses);
      _loading = false;
    });

    for (final pending in result.pendingManual.take(20)) {
      final manual = await _askManualAmountForSms(pending);
      if (!mounted || manual == null) continue;
      setState(() => _transactions.insert(0, manual));
    }

    _showBudgetAlerts();
  }

  Future<ExpenseTransaction?> _askManualAmountForSms(
    PendingSmsTransaction pending,
  ) async {
    final amountController = TextEditingController();
    try {
      final amount = await showDialog<double>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Amount Not Detected'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Could not read amount from SMS. Enter it manually:'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(pending.body, style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Amount',
                    hintText: 'e.g. 540.50',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Skip'),
              ),
              FilledButton(
                onPressed: () {
                  final parsed = double.tryParse(amountController.text.trim());
                  Navigator.of(context).pop(parsed);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (amount == null || amount <= 0) return null;
      return _smsService.createManualExpense(pending: pending, amount: amount);
    } finally {
      amountController.dispose();
    }
  }

  void _showBudgetAlerts() {
    final now = DateTime.now();
    final monthTx = _transactions
        .where((t) => t.type == 'Debit')
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .toList();

    final byCategory = <String, double>{};
    for (final tx in monthTx) {
      byCategory.update(tx.category, (v) => v + tx.amount, ifAbsent: () => tx.amount);
    }

    for (final entry in _budgets.entries) {
      final used = byCategory[entry.key] ?? 0;
      if (entry.value <= 0) continue;
      final ratio = used / entry.value;
      if (ratio >= 1.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${entry.key} budget exceeded (${used.toStringAsFixed(0)}/${entry.value.toStringAsFixed(0)})')),
        );
      } else if (ratio >= 0.8) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${entry.key} reached 80% budget (${used.toStringAsFixed(0)}/${entry.value.toStringAsFixed(0)})')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense Tracker')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_permissionGranted && !_limitedMode
              ? _PermissionView(
                  onGrant: _requestPermissionAndLoad,
                  onContinueWithoutSms: () => setState(() => _limitedMode = true),
                  showOpenSettings: _showOpenSettings,
                  message: _permissionMessage,
                )
              : _buildTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (value) => setState(() => _tabIndex = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Transactions'),
          NavigationDestination(icon: Icon(Icons.pie_chart), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.account_balance), label: 'Accounts'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }

  Widget _buildTab() {
    switch (_tabIndex) {
      case 0:
        return TransactionsTab(
          transactions: _transactions,
          onSyncSms: _requestPermissionAndLoad,
          budgets: _budgets,
        );
      case 1:
        return StatsTab(transactions: _transactions);
      case 2:
        return AccountsTab(
          transactions: _transactions,
          categorySubcategories: _subcategories,
        );
      case 3:
        return MoreTab(
          incomeCategories: _incomeCategories,
          expenseCategories: _expenseCategories,
          subcategories: _subcategories,
          budgets: _budgets,
          onUpdateIncomeCategories: (value) => setState(() {
            _incomeCategories
              ..clear()
              ..addAll(value);
          }),
          onUpdateExpenseCategories: (value) => setState(() {
            _expenseCategories
              ..clear()
              ..addAll(value);
          }),
          onUpdateSubcategories: (value) => setState(() => _subcategories = value),
          onUpdateBudgets: (value) => setState(() => _budgets = value),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _PermissionView extends StatelessWidget {
  const _PermissionView({
    required this.onGrant,
    required this.onContinueWithoutSms,
    required this.showOpenSettings,
    this.message,
  });

  final Future<void> Function() onGrant;
  final VoidCallback onContinueWithoutSms;
  final bool showOpenSettings;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sms, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Allow SMS access to auto-detect your transactions. Data stays on your device.',
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: smsFeatureEnabled ? onGrant : null,
              child: const Text('Grant SMS permission'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onContinueWithoutSms,
              child: const Text('Continue without SMS'),
            ),
            if (showOpenSettings) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: openAppSettings,
                child: const Text('Open app settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
