import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/app_data.dart';

class AppDataRepository {
  static const int currentSchemaVersion = 2;
  static const String _fileName = 'expense_tracker_data.json';

  Future<AppData> load() async {
    final file = await _dataFile();
    if (!await file.exists()) {
      final fresh = AppData.defaults(version: currentSchemaVersion);
      await save(fresh);
      return fresh;
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      final fresh = AppData.defaults(version: currentSchemaVersion);
      await save(fresh);
      return fresh;
    }

    final json = jsonDecode(raw) as Map<String, dynamic>;
    final loaded = AppData.fromJson(json);
    final migrated = _migrateIfNeeded(loaded);
    if (migrated.version != loaded.version) {
      await save(migrated);
    }
    return migrated;
  }

  Future<void> save(AppData data) async {
    final file = await _dataFile();
    await file.create(recursive: true);
    await file.writeAsString(jsonEncode(data.toJson()));
  }

  AppData _migrateIfNeeded(AppData data) {
    var current = data;
    if (current.version < 2) {
      current = _migrateV1ToV2(current);
    }
    if (current.version != currentSchemaVersion) {
      current = current.copyWith(version: currentSchemaVersion);
    }
    return current;
  }

  AppData _migrateV1ToV2(AppData data) {
    final patched = data.transactions.map((t) {
      return t.copyWith(
        account: t.account.isEmpty ? 'Cash' : t.account,
        note: t.note,
        description: t.description.isEmpty ? t.rawMessage : t.description,
        source: t.source.isEmpty ? 'legacy' : t.source,
      );
    }).toList();

    final mergedSettings = <String, dynamic>{
      'currency': 'INR',
      'showBudgetAlerts': true,
      'themePalette': 'blue',
      ...data.settings,
    };

    return data.copyWith(
      version: 2,
      transactions: patched,
      settings: mergedSettings,
    );
  }

  Future<File> _dataFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }
}
