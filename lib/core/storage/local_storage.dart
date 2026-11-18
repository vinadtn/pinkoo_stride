import 'package:shared_preferences/shared_preferences.dart';

/// Lớp bọc SharedPreferences: code khác không phụ thuộc trực tiếp vào plugin,
/// dễ mock khi test và dễ thay bằng storage khác (Hive, secure storage...).
class LocalStorage {
  LocalStorage(this._prefs);

  final SharedPreferences _prefs;

  String? getString(String key) => _prefs.getString(key);
  Future<bool> setString(String key, String value) => _prefs.setString(key, value);

  bool? getBool(String key) => _prefs.getBool(key);
  Future<bool> setBool(String key, {required bool value}) => _prefs.setBool(key, value);

  double? getDouble(String key) => _prefs.getDouble(key);
  Future<bool> setDouble(String key, double value) => _prefs.setDouble(key, value);

  int? getInt(String key) => _prefs.getInt(key);
  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  Future<bool> remove(String key) => _prefs.remove(key);
  Future<bool> clear() => _prefs.clear();
}
