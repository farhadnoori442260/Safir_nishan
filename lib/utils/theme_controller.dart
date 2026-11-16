import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// انتخاب تم: روشن / تاریک / سیستم. انتخاب کاربر ذخیره می‌شود.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const String _key = 'safir_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// قبل از runApp صدا زده شود تا اولین فریم با تم درست بیاید.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      switch (prefs.getString(_key)) {
        case 'light':
          _mode = ThemeMode.light;
          break;
        case 'dark':
          _mode = ThemeMode.dark;
          break;
        default:
          _mode = ThemeMode.system;
      }
    } catch (_) {}
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        mode == ThemeMode.light
            ? 'light'
            : mode == ThemeMode.dark
                ? 'dark'
                : 'system',
      );
    } catch (_) {}
  }

  /// آیا با این حالت و روشنایی سیستم، تاریک است؟
  bool resolveDark(Brightness platform) =>
      _mode == ThemeMode.dark ||
      (_mode == ThemeMode.system && platform == Brightness.dark);
}
