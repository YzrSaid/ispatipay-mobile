import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class SettingsService {
  static const String _settingsKey = 'app_settings';
  static AppSettings _settings = const AppSettings();

  static AppSettings get settings => _settings;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_settingsKey);
    if (json != null) {
      _settings = AppSettings.fromJson(jsonDecode(json));
    }
  }

  static Future<void> save(AppSettings settings) async {
    _settings = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  static Future<void> clear() async {
    _settings = const AppSettings();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_settingsKey);
  }
}
