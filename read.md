# 📱 SMS Expense Tracker (Flutter)

A smart Flutter application that automatically tracks your expenses by reading SMS alerts (bank transactions, debit/credit messages) and converting them into structured financial insights.

---

## 🚀 Features

* 📩 Read SMS messages (bank transaction alerts)
* 💸 Automatically detect expenses (debit/credit)
* 🧠 Extract amount, merchant, and date using parsing logic
* 🗂️ Categorize transactions (Food, Travel, Shopping, etc.)
* 📊 Dashboard with:

  * Daily spending
  * Weekly & monthly summaries
* 📈 Visual charts for expense analysis
* 🔐 Secure and private (data stored locally only)

---

## 🧱 Tech Stack

* **Flutter** – UI framework
* **Dart** – Programming language
* **Hive / Sqflite** – Local database
* **SMS Plugins** – Read messages from device
* **fl_chart** – Data visualization

---

## 🔐 Permissions Required

The app requires SMS permissions to function:

```xml
<uses-permission android:name="android.permission.READ_SMS"/>
<uses-permission android:name="android.permission.RECEIVE_SMS"/>
```

### 📢 Why this permission?

We use SMS access **only to detect financial transactions automatically**.
No personal data is shared or sent outside your device.

---

## 📦 Installation

1. Clone the repository:

```bash
git clone https://github.com/your-username/sms-expense-tracker.git
cd sms-expense-tracker
```

2. Install dependencies:

```bash
flutter pub get
```

3. Run the app:

```bash
flutter run
```

---

## 📂 Project Structure

```
lib/
│── main.dart
│── screens/
│   ├── dashboard.dart
│   ├── transactions.dart
│── services/
│   ├── sms_reader.dart
│   ├── parser.dart
│── models/
│   ├── transaction.dart
│── database/
│   ├── db_service.dart
```

---

## 🧠 How It Works

1. App requests SMS permission
2. Reads incoming & existing messages
3. Filters relevant messages (bank alerts)
4. Extracts:

   * Amount 💰
   * Merchant 🏪
   * Date 📅
5. Stores data locally
6. Displays insights on dashboard

---

## 📊 Example SMS Parsing

**Input SMS:**

```
Rs 500 debited from A/C at Swiggy on 12-Apr
```

**Parsed Output:**

```json
{
  "amount": 500,
  "merchant": "Swiggy",
  "category": "Food",
  "type": "Debit"
}
```

---

## ⚠️ Limitations

* ❌ Works only on **Android** (iOS restricts SMS access)
* ⚠️ SMS formats may vary across banks
* 🔍 Parsing logic may need improvements for edge cases

---

## 🔮 Future Enhancements

* Budget tracking & alerts
* Subscription detection
* AI-based categorization
* Cloud sync (optional)
* Multi-bank intelligent parsing

---

## 🤝 Contributing

Contributions are welcome!

1. Fork the repo
2. Create your feature branch
3. Commit your changes
4. Submit a pull request

---

## 📜 License

This project is licensed under the MIT License.

---

## 👨‍💻 Author

Developed by **Rohan Singh**

---

## 💡 Disclaimer

This app accesses SMS data **only for expense tracking purposes**.
All data remains on the user's device and is not shared externally.
