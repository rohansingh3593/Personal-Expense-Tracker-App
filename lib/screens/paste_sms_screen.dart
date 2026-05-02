import 'package:flutter/material.dart';

import '../services/sms_parser.dart';
import 'review_transaction_screen.dart';

class PasteSmsScreen extends StatefulWidget {
  const PasteSmsScreen({
    super.key,
    required this.expenseCategories,
    required this.archivedExpenseCategories,
    required this.subcategories,
    required this.accounts,
  });

  final List<String> expenseCategories;
  final Set<String> archivedExpenseCategories;
  final Map<String, List<String>> subcategories;
  final List<String> accounts;

  @override
  State<PasteSmsScreen> createState() => _PasteSmsScreenState();
}

class _PasteSmsScreenState extends State<PasteSmsScreen> {
  final TextEditingController _smsController = TextEditingController();
  final SmsParser _parser = SmsParser();

  ParsedSmsDraft? _draft;
  String? _error;

  @override
  void dispose() {
    _smsController.dispose();
    super.dispose();
  }

  void _autoParse(String text) {
    final value = text.trim();
    if (value.isEmpty) {
      setState(() {
        _draft = null;
        _error = null;
      });
      return;
    }

    final draft = _parser.extractDraft(value, DateTime.now());
    setState(() {
      _draft = draft;
      _error = draft.amount == null ? "Couldn't detect amount. You can enter manually in next step." : null;
    });
  }

  Future<void> _goNext() async {
    if (_draft == null) return;
    final saved = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewTransactionScreen(
          draft: _draft!,
          expenseCategories: widget.expenseCategories
              .where((category) => !widget.archivedExpenseCategories.contains(category))
              .toList(),
          subcategories: widget.subcategories,
          accounts: widget.accounts,
        ),
      ),
    );
    if (!mounted) return;
    if (saved != null) {
      Navigator.of(context).pop(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paste SMS')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _smsController,
              minLines: 5,
              maxLines: 7,
              onChanged: _autoParse,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste SMS here',
              ),
            ),
            const SizedBox(height: 12),
            if (_draft != null) ...[
              Card(
                child: ListTile(
                  title: Text('Amount: ${_draft!.amount == null ? '-' : '\u20B9${_draft!.amount!.toStringAsFixed(2)}'}'),
                  subtitle: Text('Merchant: ${_draft!.merchant}\nType: ${_draft!.type}'),
                  isThreeLine: true,
                ),
              ),
            ],
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _draft == null ? null : _goNext,
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
