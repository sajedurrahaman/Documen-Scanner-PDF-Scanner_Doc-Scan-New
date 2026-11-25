import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {

  static final LocalStorage _instance = LocalStorage._internal();
  late SharedPreferences _prefs;

  factory LocalStorage() {
    return _instance;
  }

  LocalStorage._internal();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String getString(String key) {
    return _prefs.getString(key) ?? '';
  }

  Future<bool> setString(String key, String value) {
    return _prefs.setString(key, value);
  }

  Future<bool> setBool(String key, bool value) {
    return _prefs.setBool(key, value);
  }

  bool getBool(String key) {
    return _prefs.getBool(key) ?? true;
  }

  /// Returns [defaultValue] when the key was never written.
  bool getBoolOr(String key, {required bool defaultValue}) {
    return _prefs.getBool(key) ?? defaultValue;
  }

  bool containsKey(String key) => _prefs.containsKey(key);
}
