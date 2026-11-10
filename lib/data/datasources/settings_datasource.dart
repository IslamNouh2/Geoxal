import '../../../core/database/database.dart';
import '../models/app_setting.dart';

class SettingsDataSource {
  final Database db;

  SettingsDataSource(this.db);

  void _ensureConnected() {
    if (!db.connection.isConnected) {
      throw Exception('Database not connected.');
    }
  }

  Future<Map<String, AppSetting>> getAllSettings() async {
    _ensureConnected();
    final rows = await db.connection.connection!.execute(
      "SELECT SETTING_KEY, SETTING_VALUE, DESCRIPTION FROM APP_SETTINGS",
    );
    final map = <String, AppSetting>{};
    for (final r in rows) {
      final s = AppSetting.fromMap(r);
      map[s.key] = s;
    }
    return map;
  }

  Future<String?> getSettingValue(String key) async {
    _ensureConnected();
    final rows = await db.connection.connection!.execute(
      "SELECT SETTING_VALUE FROM APP_SETTINGS WHERE SETTING_KEY = '$key'",
    );
    if (rows.isEmpty) return null;
    return rows.first['SETTING_VALUE']?.toString().trim();
  }

  Future<void> setSetting(String key, String value, {String? description}) async {
    _ensureConnected();
    final cleanVal = value.trim().replaceAll("'", "''");
    final cleanDesc = (description ?? '').trim().replaceAll("'", "''");

    final query = '''
      UPDATE OR INSERT INTO APP_SETTINGS (SETTING_KEY, SETTING_VALUE, DESCRIPTION)
      VALUES ('$key', '$cleanVal', '$cleanDesc')
      MATCHING (SETTING_KEY)
    ''';
    await db.connection.connection!.execute(query);
  }
}

