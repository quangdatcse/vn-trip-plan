import 'package:sqflite/sqflite.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  static const dealClickCountingKey = 'deal_click_counting_enabled';
  static const dealClickCountKey = 'deal_click_count';
  static const onboardingDoneKey = 'onboarding_done';
  static const themeModeKey = 'theme_mode';

  final Database _db;

  Future<String?> get(String key) async {
    final rows =
        await _db.query('app_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> set(String key, String value) => _db.insert(
        'app_settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> remove(String key) =>
      _db.delete('app_settings', where: 'key = ?', whereArgs: [key]);

  Future<bool> getBool(String key, {bool fallback = false}) async {
    final value = await get(key);
    return value == null ? fallback : value == 'true';
  }

  Future<void> setBool(String key, bool value) => set(key, '$value');
}
