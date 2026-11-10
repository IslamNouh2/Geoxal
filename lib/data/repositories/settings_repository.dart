import '../datasources/settings_datasource.dart';
import '../models/app_setting.dart';

class SettingsRepository {
  final SettingsDataSource _dataSource;

  SettingsRepository(this._dataSource);

  Future<Map<String, AppSetting>> getAllSettings() => _dataSource.getAllSettings();

  Future<String?> getSettingValue(String key) => _dataSource.getSettingValue(key);

  Future<bool> getBoolSetting(String key, {bool defaultValue = false}) async {
    final val = await _dataSource.getSettingValue(key);
    if (val == null) return defaultValue;
    return val.toUpperCase() == 'O' || val.toUpperCase() == 'TRUE' || val == '1';
  }

  Future<void> setSetting(String key, String value, {String? description}) =>
      _dataSource.setSetting(key, value, description: description);

  Future<void> setBoolSetting(String key, bool value, {String? description}) =>
      _dataSource.setSetting(key, value ? 'O' : 'N', description: description);
}

