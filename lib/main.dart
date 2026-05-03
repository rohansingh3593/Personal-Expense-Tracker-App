import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/app_data.dart';
import 'models/expense_transaction.dart';
import 'screens/accounts_tab.dart';
import 'screens/manual_add_transaction_screen.dart';
import 'screens/more_tab.dart';
import 'screens/paste_sms_screen.dart';
import 'screens/stats_tab.dart';
import 'screens/transactions_tab.dart';
import 'services/app_data_repository.dart';
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
    return const _ExpenseTrackerAppShell();
  }
}

class _ExpenseTrackerAppShell extends StatefulWidget {
  const _ExpenseTrackerAppShell();

  @override
  State<_ExpenseTrackerAppShell> createState() => _ExpenseTrackerAppShellState();
}

class _ExpenseTrackerAppShellState extends State<_ExpenseTrackerAppShell> {
  String _themePalette = 'blue';

  void _handleThemeChanged(String palette) {
    setState(() => _themePalette = palette);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpendSnap',
      theme: _buildTheme(_themePalette),
      home: HomeScreen(onThemeChanged: _handleThemeChanged),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onThemeChanged});

  final ValueChanged<String> onThemeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SmsService _smsService = SmsService();
  final AppDataRepository _repository = AppDataRepository();
  AppData _appData = AppData.defaults(version: AppDataRepository.currentSchemaVersion);

  bool _loading = false;
  bool _dataLoaded = false;
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
    _loadAppData();
  }

  List<ExpenseTransaction> get _transactions => _appData.transactions;
  List<String> get _incomeCategories => _appData.incomeCategories;
  List<String> get _expenseCategories => _appData.expenseCategories;
  Set<String> get _archivedExpenseCategories =>
      Set<String>.from((_appData.settings['archivedExpenseCategories'] as List?)?.map((e) => e.toString()) ?? const []);
  List<String> get _activeExpenseCategories =>
      _expenseCategories.where((category) => !_archivedExpenseCategories.contains(category)).toList();
  Map<String, List<String>> get _subcategories => _appData.subcategories;
  Map<String, double> get _budgets => _appData.budgets;
  List<Map<String, dynamic>> get _accounts {
    final raw = _appData.settings['accounts'] as List?;
    if (raw == null || raw.isEmpty) {
      return const [
        {'id': 'cash', 'name': 'Cash', 'is_active': true},
        {'id': 'bank', 'name': 'Bank', 'is_active': true},
      ];
    }
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  List<String> get _activeAccountNames => _accounts
      .where((a) => a['is_active'] == true)
      .map((a) => a['name'].toString())
      .toList();
  String get _themePalette => (_appData.settings['themePalette'] as String?) ?? 'blue';

  Future<void> _loadAppData() async {
    setState(() => _loading = true);
    final loaded = await _repository.load();
    var changed = false;
    final normalizedExpenseCategories = List<String>.from(loaded.expenseCategories);
    if (!normalizedExpenseCategories.contains('Lending')) {
      normalizedExpenseCategories.add('Lending');
      changed = true;
    }
    final normalizedSubcategories = Map<String, List<String>>.from(loaded.subcategories);
    if (!normalizedSubcategories.containsKey('Lending')) {
      normalizedSubcategories['Lending'] = <String>[];
      changed = true;
    }
    final normalized = changed
        ? loaded.copyWith(
            expenseCategories: normalizedExpenseCategories,
            subcategories: normalizedSubcategories,
          )
        : loaded;
    if (!mounted) return;
    setState(() {
      _appData = normalized;
      _dataLoaded = true;
      _loading = false;
    });
    if (changed) {
      unawaited(_repository.save(normalized));
    }
    widget.onThemeChanged(_themePalette);
  }

  Future<void> _saveAppData() async {
    await _repository.save(_appData);
  }

  void _persistAppData() {
    unawaited(_saveAppData());
  }

  void _updateThemePalette(String palette) {
    final updatedSettings = Map<String, dynamic>.from(_appData.settings);
    updatedSettings['themePalette'] = palette;
    setState(() => _appData = _appData.copyWith(settings: updatedSettings));
    widget.onThemeChanged(palette);
    _persistAppData();
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
      _appData = _appData.copyWith(transactions: List<ExpenseTransaction>.from(result.parsedExpenses));
      _loading = false;
    });
    await _saveAppData();

    for (final pending in result.pendingManual.take(20)) {
      final manual = await _askManualAmountForSms(pending);
      if (!mounted || manual == null) continue;
      setState(() {
        final updated = List<ExpenseTransaction>.from(_transactions)..insert(0, manual);
        _appData = _appData.copyWith(transactions: updated);
      });
      await _saveAppData();
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
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
                  ],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Amount',
                    hintText: 'Enter amount (₹)',
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

  Future<void> _openAddTransactionFlow() async {
    final option = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Manual'),
              onTap: () => Navigator.of(context).pop('manual'),
            ),
            ListTile(
              leading: const Icon(Icons.sms),
              title: const Text('Paste SMS'),
              onTap: () => Navigator.of(context).pop('sms'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || option == null) return;

    ExpenseTransaction? created;
    if (option == 'manual') {
      created = await Navigator.of(context).push<ExpenseTransaction>(
        MaterialPageRoute(
          builder: (_) => ManualAddTransactionScreen(
            expenseCategories: _expenseCategories,
            archivedExpenseCategories: _archivedExpenseCategories,
            subcategories: _subcategories,
            accounts: _activeAccountNames,
          ),
        ),
      );
    } else {
      created = await Navigator.of(context).push<ExpenseTransaction>(
        MaterialPageRoute(
          builder: (_) => PasteSmsScreen(
            expenseCategories: _expenseCategories,
            archivedExpenseCategories: _archivedExpenseCategories,
            subcategories: _subcategories,
            accounts: _activeAccountNames,
          ),
        ),
      );
    }
    if (!mounted || created == null) return;
    final transaction = created;
    setState(() {
      final updated = List<ExpenseTransaction>.from(_transactions)..insert(0, transaction);
      _appData = _appData.copyWith(transactions: updated);
    });
    await _saveAppData();
    _showBudgetAlerts();
  }

  void _updateTransaction(ExpenseTransaction updated) {
    final index = _transactions.indexWhere((t) => t.id == updated.id);
    if (index < 0) return;
    setState(() {
      final next = List<ExpenseTransaction>.from(_transactions);
      next[index] = updated;
      _appData = _appData.copyWith(transactions: next);
    });
    _persistAppData();
    _showBudgetAlerts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SpendSnap'),
        actions: [
          IconButton(
            onPressed: _openAddTransactionFlow,
            icon: const Icon(Icons.add),
            tooltip: 'Add Transaction',
          ),
        ],
      ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _openAddTransactionFlow,
              icon: const Icon(Icons.add),
              label: const Text('Add Transaction'),
            )
          : null,
      body: _loading || !_dataLoaded
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
          expenseCategories: _expenseCategories,
          subcategories: _subcategories,
          onTransactionUpdated: _updateTransaction,
          accounts: _activeAccountNames,
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
          activeExpenseCategories: _activeExpenseCategories,
          subcategories: _subcategories,
          budgets: _budgets,
          onUpdateIncomeCategories: (value) {
            setState(() => _appData = _appData.copyWith(incomeCategories: List<String>.from(value)));
            _persistAppData();
          },
          onUpdateExpenseCategories: (value) {
            final merged = [
              ...value,
              ..._expenseCategories.where(
                (category) => _archivedExpenseCategories.contains(category) && !value.contains(category),
              ),
            ];
            setState(() => _appData = _appData.copyWith(expenseCategories: List<String>.from(merged)));
            _persistAppData();
          },
          onUpdateSubcategories: (value) {
            setState(() => _appData = _appData.copyWith(subcategories: value));
            _persistAppData();
          },
          onUpdateBudgets: (value) {
            setState(() => _appData = _appData.copyWith(budgets: value));
            _persistAppData();
          },
          onUpdateArchivedExpenseCategories: (value) {
            final updatedSettings = Map<String, dynamic>.from(_appData.settings);
            updatedSettings['archivedExpenseCategories'] = value.toList()..sort();
            setState(() => _appData = _appData.copyWith(settings: updatedSettings));
            _persistAppData();
          },
          selectedThemePalette: _themePalette,
          onThemeChanged: _updateThemePalette,
          accounts: _accounts,
          onUpdateAccounts: (accounts) {
            final updatedSettings = Map<String, dynamic>.from(_appData.settings);
            updatedSettings['accounts'] = accounts;
            setState(() => _appData = _appData.copyWith(settings: updatedSettings));
            _persistAppData();
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

ThemeData _buildTheme(String palette) {
  switch (palette) {
    case 'legacy_green':
      return _paletteTheme(
        primary: const Color(0xFF468432),
        secondary: const Color(0xFF9AD872),
        tertiary: const Color(0xFFFAA02E),
        surface: const Color(0xFFFEF9E7),
      );
    case 'legacy_blue':
      return _paletteTheme(
        primary: const Color(0xFF2F2FE4),
        secondary: const Color(0xFF162E93),
        tertiary: const Color(0xFF1A1953),
        surface: const Color(0xFF080616),
      );
    case 'legacy_orange':
      return _paletteTheme(
        primary: const Color(0xFFFF8B5A),
        secondary: const Color(0xFFFFA95A),
        tertiary: const Color(0xFFFF5A5A),
        surface: const Color(0xFFFFD45A),
      );
    case 'legacy_red':
      return _paletteTheme(
        primary: const Color(0xFFBF1A1A),
        secondary: const Color(0xFFFF6C0C),
        tertiary: const Color(0xFF060771),
        surface: const Color(0xFFFEE08F),
      );
    case 'legacy_mono':
      return _paletteTheme(
        primary: const Color(0xFF202940),
        secondary: const Color(0xFF4B4038),
        tertiary: const Color(0xFF9A8678),
        surface: const Color(0xFFCAAA98),
      );
    case 'green':
      return _paletteTheme(
        primary: const Color(0xFF636B2F),
        secondary: const Color(0xFFBAC095),
        tertiary: const Color(0xFFD4DE95),
        surface: const Color(0xFF3D4127),
      );
    case 'blue':
      return _paletteTheme(
        primary: const Color(0xFF6A89A7),
        secondary: const Color(0xFFBDDDFC),
        tertiary: const Color(0xFF88BDF2),
        surface: const Color(0xFF384959),
      );
    case 'blue_eclipse':
      return _paletteTheme(
        primary: const Color(0xFF272757),
        secondary: const Color(0xFF8686AC),
        tertiary: const Color(0xFF505081),
        surface: const Color(0xFF0F0E47),
      );
    case 'lush_forest':
      return _paletteTheme(
        primary: const Color(0xFF2E6F40),
        secondary: const Color(0xFFCFFFDC),
        tertiary: const Color(0xFF68BA7F),
        surface: const Color(0xFF253D2C),
      );
    case 'green_juice':
      return _paletteTheme(
        primary: const Color(0xFF4CBB17),
        secondary: const Color(0xFF48872B),
        tertiary: const Color(0xFF39542C),
        surface: const Color(0xFF293325),
      );
    case 'orange':
      return _paletteTheme(
        primary: const Color(0xFF713600),
        secondary: const Color(0xFFC05800),
        tertiary: const Color(0xFFFDFBD4),
        surface: const Color(0xFF38240D),
      );
    case 'red':
      return _paletteTheme(
        primary: const Color(0xFFCD1C18),
        secondary: const Color(0xFFFFA896),
        tertiary: const Color(0xFF9B1313),
        surface: const Color(0xFF38000A),
      );
    case 'wisteria_bloom':
      return _paletteTheme(
        primary: const Color(0xFFD3D3FF),
        secondary: const Color(0xFF9400D3),
        tertiary: const Color(0xFFD8BFD8),
        surface: const Color(0xFFED80E9),
      );
    case 'blooming_romance':
      return _paletteTheme(
        primary: const Color(0xFF660033),
        secondary: const Color(0xFFE673AC),
        tertiary: const Color(0xFF469110),
        surface: const Color(0xFF00520A),
      );
    case 'lavender_fields':
      return _paletteTheme(
        primary: const Color(0xFFFDFBD4),
        secondary: const Color(0xFFBDB96A),
        tertiary: const Color(0xFFC1BFFF),
        surface: const Color(0xFFCF6DFC),
      );
    case 'mono':
    case 'stormy_ink':
      return _paletteTheme(
        primary: const Color(0xFF202940),
        secondary: const Color(0xFF4B4038),
        tertiary: const Color(0xFF9A8678),
        surface: const Color(0xFFCAAA98),
      );
    default:
      return _paletteTheme(
        primary: const Color(0xFF2F2FE4),
        secondary: const Color(0xFF162E93),
        tertiary: const Color(0xFF1A1953),
        surface: const Color(0xFF080616),
      );
  }
}

ThemeData _paletteTheme({
  required Color primary,
  required Color secondary,
  required Color tertiary,
  required Color surface,
}) {
  final surfaceBrightness = ThemeData.estimateBrightnessForColor(surface);
  final isDark = surfaceBrightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    primary: primary,
    secondary: secondary,
    tertiary: tertiary,
    surface: surface,
    brightness: isDark ? Brightness.dark : Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerHighest,
    ),
    listTileTheme: ListTileThemeData(
      textColor: scheme.onSurface,
      iconColor: scheme.onSurfaceVariant,
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
  );
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
