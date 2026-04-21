# 📱 Personal Expense Tracker App (Flutter + SMS)

Android-first app that reads bank SMS alerts, extracts expenses, and shows daily/weekly/monthly spending insights.

## ✅ Current MVP Scaffold Included

This repository now includes a starter Flutter structure with:

- SMS permission flow (`permission_handler`)
- SMS ingestion service (`sms_advanced`)
- Parsing logic for amount / merchant / transaction type
- Basic category mapping (Food / Travel / Shopping / Others)
- Dashboard, Transactions, and Insights screens

---

## 🧱 Architecture

### Flutter Layer
- `lib/main.dart` – app shell, navigation, permission UX
- `lib/screens/*` – dashboard, transaction list, insights
- `lib/services/sms_service.dart` – reads SMS + calls parser
- `lib/services/sms_parser.dart` – regex extraction + categorization
- `lib/models/expense_transaction.dart` – normalized transaction model

### Android Layer (required)
Because SMS access is Android-only, add SMS permissions in Android manifest and request runtime permission from Flutter.

---

## 🔐 Permissions

Add these in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.READ_SMS"/>
<uses-permission android:name="android.permission.RECEIVE_SMS"/>
```

The app shows this user-facing message before requesting permission:

> "We read SMS only to detect your expenses automatically. No data is shared."

---

## 📩 SMS Parsing Rules

Sample supported message:

`Rs 500 debited from A/C at Swiggy on 12-Apr`

Extracted fields:
- amount → 500
- merchant → Swiggy
- type → Debit
- category → Food

Regex strategy:
- amount pattern supports `Rs`, `INR`, or `₹`
- merchant extracted from `at/to/towards/from ...`

---

## 🗂️ Category Mapping

- Swiggy / Zomato → Food
- Uber / Ola → Travel
- Amazon / Flipkart → Shopping
- fallback → Others

---

## 💾 Storage (next step)

Recommended for Phase 2:
- Hive (simple + fast)
- or sqflite (SQL flexibility)

Persist:

```json
{
  "amount": 500,
  "merchant": "Swiggy",
  "category": "Food",
  "date": "2026-04-21"
}
```

---

## 📊 Build Phases

### Phase 1 (MVP)
- [x] Basic Flutter app skeleton
- [x] SMS permission screen
- [x] Read SMS and parse expenses
- [x] Show parsed list

### Phase 2
- [ ] Persistent storage (Hive/sqflite)
- [ ] Budget + summaries by period
- [ ] Better parsing for more banks

### Phase 3
- [ ] Charts (`fl_chart`)
- [ ] Budget alerts
- [ ] Smarter categorization

---

## ⚠️ Limitations

- iOS cannot provide SMS inbox reading for this use-case.
- Works on Android devices only.
- Bank SMS formats vary; parser will need iterative hardening.
