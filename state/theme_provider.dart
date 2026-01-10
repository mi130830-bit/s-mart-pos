import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String _fontFamily = 'Sarabun';

  ThemeMode get themeMode => _themeMode;
  String get fontFamily => _fontFamily;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('dark_mode') ?? false;
    _fontFamily = prefs.getString('app_font_family') ?? 'Sarabun';
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void toggleTheme(bool isDark) {
    debugPrint('ThemeProvider: Toggling theme to isDark=$isDark');
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    _saveTheme(isDark);
  }

  void setFontFamily(String family) {
    _fontFamily = family;
    notifyListeners();
    _saveFont(family);
  }

  Future<void> _saveTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', isDark);
  }

  Future<void> _saveFont(String family) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_font_family', family);
  }
}
