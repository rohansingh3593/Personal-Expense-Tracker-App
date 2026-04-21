import 'package:permission_handler/permission_handler.dart';
import 'package:sms_advanced/sms_advanced.dart';

import '../models/expense_transaction.dart';
import 'sms_parser.dart';

class SmsService {
  SmsService({SmsParser? parser}) : _parser = parser ?? SmsParser();

  final SmsParser _parser;

  Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<List<ExpenseTransaction>> readExpensesFromSms() async {
    final query = SmsQuery();
    final messages = await query.getAllSms;

    final parsed = <ExpenseTransaction>[];

    for (final message in messages) {
      final body = message.body;
      if (body == null || body.isEmpty) continue;

      final date = message.date ?? DateTime.now();
      final item = _parser.parse(body, date);
      if (item != null && item.type == 'Debit') {
        parsed.add(item);
      }
    }

    parsed.sort((a, b) => b.date.compareTo(a.date));
    return parsed;
  }
}
