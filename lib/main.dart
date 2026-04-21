import 'package:flutter/material.dart';

import 'models/expense_transaction.dart';
import 'screens/dashboard_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/transactions_screen.dart';
import 'services/sms_service.dart';

void main() {
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMS Expense Tracker',
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

  bool _loading = false;
  bool _permissionGranted = false;
  int _tabIndex = 0;

  Future<void> _requestPermissionAndLoad() async {
    setState(() => _loading = true);

    final granted = await _smsService.requestSmsPermission();
    if (!mounted) return;

    if (!granted) {
      setState(() {
        _permissionGranted = false;
        _loading = false;
      });
      return;
    }

    final transactions = await _smsService.readExpensesFromSms();
    if (!mounted) return;

    setState(() {
      _permissionGranted = true;
      _transactions
        ..clear()
        ..addAll(transactions);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Expense Tracker'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _requestPermissionAndLoad,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_permissionGranted
              ? _PermissionView(onGrant: _requestPermissionAndLoad)
              : _contentByIndex(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (value) => setState(() => _tabIndex = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.receipt), label: 'Transactions'),
          NavigationDestination(icon: Icon(Icons.insights), label: 'Insights'),
        ],
      ),
    );
  }

  Widget _contentByIndex() {
    switch (_tabIndex) {
      case 0:
        return DashboardScreen(transactions: _transactions);
      case 1:
        return TransactionsScreen(transactions: _transactions);
      case 2:
        return InsightsScreen(transactions: _transactions);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _PermissionView extends StatelessWidget {
  const _PermissionView({required this.onGrant});

  final Future<void> Function() onGrant;

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
              'We read SMS only to detect your expenses automatically. No data is shared.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onGrant,
              child: const Text('Grant SMS permission'),
            )
          ],
        ),
      ),
    );
  }
}
