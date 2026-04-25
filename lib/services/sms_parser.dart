import '../models/expense_transaction.dart';

class SmsParser {
  static final RegExp _amountRegex =
      RegExp(r'(?:rs\.?|inr|\u20B9)\s?([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
  static final RegExp _merchantRegex = RegExp(
    r'(?:at|to|towards|from)\s+([A-Za-z0-9 .&_-]{2,})',
    caseSensitive: false,
  );

  ExpenseTransaction? parse(String body, DateTime smsDate) {
    if (!looksLikeTransaction(body)) return null;

    final amountMatch = _amountRegex.firstMatch(body);
    if (amountMatch == null) return null;

    final rawAmount = amountMatch.group(1)?.replaceAll(',', '');
    final amount = double.tryParse(rawAmount ?? '');
    if (amount == null) return null;

    final merchantMatch = _merchantRegex.firstMatch(body);
    final merchant = _sanitizeMerchant(merchantMatch?.group(1) ?? 'Unknown');

    return ExpenseTransaction(
      amount: amount,
      merchant: merchant,
      category: _categorizeMerchant(merchant),
      type: detectType(body),
      date: smsDate,
      rawMessage: body,
    );
  }

  ExpenseTransaction createFromManualAmount({
    required String body,
    required DateTime smsDate,
    required double amount,
  }) {
    final merchantMatch = _merchantRegex.firstMatch(body);
    final merchant = _sanitizeMerchant(merchantMatch?.group(1) ?? 'Unknown');

    return ExpenseTransaction(
      amount: amount,
      merchant: merchant,
      category: _categorizeMerchant(merchant),
      type: detectType(body),
      date: smsDate,
      rawMessage: body,
    );
  }

  bool looksLikeTransaction(String body) {
    final lower = body.toLowerCase();
    return lower.contains('debited') ||
        lower.contains('spent') ||
        lower.contains('credited') ||
        lower.contains('txn');
  }

  String detectType(String body) {
    final lower = body.toLowerCase();
    if (lower.contains('credited')) return 'Credit';
    return 'Debit';
  }

  String _categorizeMerchant(String merchant) {
    final lower = merchant.toLowerCase();
    if (lower.contains('swiggy') || lower.contains('zomato')) return 'Food';
    if (lower.contains('uber') || lower.contains('ola')) return 'Travel';
    if (lower.contains('amazon') || lower.contains('flipkart')) return 'Shopping';
    return 'Others';
  }

  String _sanitizeMerchant(String merchant) {
    return merchant
        .replaceAll(RegExp(r'\s+on\s+\d{1,2}[-/]\w+.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+avl.*$', caseSensitive: false), '')
        .trim();
  }
}
