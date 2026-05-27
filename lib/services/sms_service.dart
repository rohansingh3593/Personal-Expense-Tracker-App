import 'package:permission_handler/permission_handler.dart';
import 'package:another_telephony/telephony.dart';

import '../models/expense_transaction.dart';
import 'sms_parser.dart';

class PendingSmsTransaction {
  const PendingSmsTransaction({
    required this.body,
    required this.date,
  });

  final String body;
  final DateTime date;
}

class SmsReadResult {
  const SmsReadResult({
    required this.parsedExpenses,
    required this.pendingManual,
  });

  final List<ExpenseTransaction> parsedExpenses;
  final List<PendingSmsTransaction> pendingManual;
}

class SmsService {
  SmsService({SmsParser? parser}) : _parser = parser ?? SmsParser();

  final SmsParser _parser;
  final Telephony _telephony = Telephony.instance;

  Future<PermissionStatus> requestSmsPermission() async {
    return Permission.sms.request();
  }

  Future<SmsReadResult> readExpensesFromSms() async {
    final messages = await _telephony.getInboxSms(
      columns: [SmsColumn.BODY, SmsColumn.DATE_SENT, SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    final parsed = <ExpenseTransaction>[];
    final pendingManual = <PendingSmsTransaction>[];

    for (final message in messages) {
      final body = message.body;
      if (body == null || body.isEmpty) continue;

      final millis = message.dateSent ?? message.date;
      final date = millis != null
          ? DateTime.fromMillisecondsSinceEpoch(millis)
          : DateTime.now();

      final parsedItem = _parser.parse(body, date);
      if (parsedItem != null) {
        if (parsedItem.type == 'Debit') {
          parsed.add(parsedItem);
        }
        continue;
      }

      if (_parser.looksLikeTransaction(body) && _parser.detectType(body) == 'Debit') {
        pendingManual.add(PendingSmsTransaction(body: body, date: date));
      }
    }

    parsed.sort((a, b) => b.date.compareTo(a.date));
    return SmsReadResult(parsedExpenses: parsed, pendingManual: pendingManual);
  }

  ExpenseTransaction createManualExpense({
    required PendingSmsTransaction pending,
    required double amount,
  }) {
    return _parser.createFromManualAmount(
      body: pending.body,
      smsDate: pending.date,
      amount: amount,
    );
  }
}
