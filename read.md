# 📱 Personal Expense Tracker App (Flutter + SMS)

Android-first app that reads bank SMS alerts, extracts expenses, and shows daily/weekly/monthly spending insights.

## ✅ Current MVP Scaffold Included

This repository includes Flutter app logic for:

- SMS permission flow (`permission_handler`)
- SMS inbox ingestion (`another_telephony`)
- Parsing logic for amount / merchant / transaction type
- Basic category mapping (Food / Travel / Shopping / Others)
- Dashboard, Transactions, and Insights screens

---

## 🧱 Architecture

### Flutter Layer
- `lib/main.dart` – app shell, navigation, permission UX
- `lib/screens/*` – dashboard, transaction list, insights
- `lib/services/sms_service.dart` – runtime permission + inbox read
- `lib/services/sms_parser.dart` – regex extraction + categorization
- `lib/models/expense_transaction.dart` – normalized transaction model

### Android Layer
SMS access is Android-only. Ensure permissions are declared and runtime permissions are granted.

---

## 🔐 Permissions (Android)

Add these to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.READ_SMS"/>
<uses-permission android:name="android.permission.RECEIVE_SMS"/>
```

The app shows this message before prompting:

> "We read SMS only to detect your expenses automatically. No data is shared."

---

## 📩 SMS Parsing Rules

Example input:

`Rs 500 debited from A/C at Swiggy on 12-Apr`

Extracted fields:
- amount → 500
- merchant → Swiggy
- type → Debit
- category → Food

Regex strategy:
- amount supports `Rs`, `INR`, or `₹`
- merchant extracted from patterns like `at/to/towards/from ...`

---

## ⚙️ Build Checklist (important)

If release build fails with `Task 'assembleSafeRelease' not found`, your project does not define a `safe` product flavor.

### Use one of these options:

1. **Build without flavor** (default setup in this repo):
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

2. **Only use `--flavor safe` if your Android app defines flavor `safe`** in `android/app/build.gradle` or `android/app/build.gradle.kts`.

Also ensure this code is inside a full Flutter scaffold (`android/`, `ios/`, etc.). If missing, run:

```bash
flutter create .
```

Expected output APK path:
- `build/app/outputs/flutter-apk/app-release.apk`

---

## ⚠️ Limitations

- iOS cannot provide SMS inbox reading for this use-case.
- Works on Android devices only.
- Bank SMS formats vary; parser will need iterative hardening.
