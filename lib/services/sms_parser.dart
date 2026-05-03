import '../models/expense_transaction.dart';
import '../utils/text_format.dart';

class ParsedSmsDraft {
  const ParsedSmsDraft({
    required this.rawMessage,
    required this.date,
    this.amount,
    required this.merchant,
    required this.type,
    required this.category,
    this.subcategory,
  });

  final String rawMessage;
  final DateTime date;
  final double? amount;
  final String merchant;
  final String type;
  final String category;
  final String? subcategory;
}

class SmsParser {
  static final RegExp _amountRegex =
      RegExp(r'(?:rs\.?|inr|\u20B9)\s?([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
  static final RegExp _merchantRegex = RegExp(
    r'(?:at|to|towards|from)\s+([A-Za-z0-9 .&_-]{2,})',
    caseSensitive: false,
  );

  ExpenseTransaction? parse(String body, DateTime smsDate) {
    final draft = extractDraft(body, smsDate);
    if (!looksLikeTransaction(body) || draft.amount == null) return null;
    return ExpenseTransaction(
      id: '${draft.date.millisecondsSinceEpoch}-${draft.merchant.hashCode}',
      amount: draft.amount!,
      account: 'Bank',
      merchant: draft.merchant,
      category: draft.category,
      subcategory: draft.subcategory,
      type: draft.type,
      date: draft.date,
      note: '',
      description: '',
      rawMessage: draft.rawMessage,
      source: 'sms_auto',
    );
  }

  ParsedSmsDraft extractDraft(String body, DateTime smsDate) {
    final amountMatch = _amountRegex.firstMatch(body);
    final rawAmount = amountMatch?.group(1)?.replaceAll(',', '');
    final amount = double.tryParse(rawAmount ?? '');

    final merchantMatch = _merchantRegex.firstMatch(body);
    final merchant = _sanitizeMerchant(merchantMatch?.group(1) ?? 'Unknown');
    final category = _categorizeMerchant(merchant);
    final subcategory = _suggestSubcategory(merchant, category);

    return ParsedSmsDraft(
      rawMessage: body,
      date: smsDate,
      amount: amount,
      merchant: merchant,
      type: detectType(body).toLowerCase(),
      category: category,
      subcategory: subcategory,
    );
  }

  ExpenseTransaction createFromManualAmount({
    required String body,
    required DateTime smsDate,
    required double amount,
  }) {
    final merchantMatch = _merchantRegex.firstMatch(body);
    final merchant = _sanitizeMerchant(merchantMatch?.group(1) ?? 'Unknown');
    final category = _categorizeMerchant(merchant);
    final subcategory = _suggestSubcategory(merchant, category);

    return ExpenseTransaction(
      id: '${smsDate.millisecondsSinceEpoch}-${merchant.hashCode}-manual',
      amount: amount,
      account: 'Bank',
      merchant: merchant,
      category: category,
      subcategory: subcategory,
      type: detectType(body),
      date: smsDate,
      note: '',
      description: '',
      rawMessage: body,
      source: 'sms_manual',
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

  String? _suggestSubcategory(String merchant, String category) {
    final lower = merchant.toLowerCase();
    if (category == 'Food') return 'Eating Out';
    if (category == 'Travel') return 'Cab';
    if (category == 'Shopping' && (lower.contains('amazon') || lower.contains('flipkart'))) {
      return 'Online';
    }
    return null;
  }

  String _sanitizeMerchant(String merchant) {
    return toTitleCase(
      merchant
        .replaceAll(RegExp(r'\s+on\s+\d{1,2}[-/]\w+.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+avl.*$', caseSensitive: false), '')
        .trim(),
    );
  }
}
