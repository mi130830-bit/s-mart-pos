import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeState {
  final ThemeMode themeMode;
  final String fontFamily;

  ThemeState({
    this.themeMode = ThemeMode.light,
    this.fontFamily = 'Sarabun',
  });

  bool get isDarkMode => themeMode == ThemeMode.dark;

  ThemeState copyWith({
    ThemeMode? themeMode,
    String? fontFamily,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }
}

final themeProvider = AutoDisposeNotifierProvider<ThemeNotifier, ThemeState>(
  () => ThemeNotifier(),
);

class ThemeNotifier extends AutoDisposeNotifier<ThemeState> {
  @override
  ThemeState build() {
    ref.keepAlive(); // Global state should be kept alive
    _loadTheme();
    return ThemeState();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('dark_mode') ?? false;
    final fontFamily = prefs.getString('app_font_family') ?? 'Sarabun';
    final themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    state = state.copyWith(themeMode: themeMode, fontFamily: fontFamily);
  }

  void toggleTheme(bool isDark) {
    debugPrint('ThemeNotifier: Toggling theme to isDark=$isDark');
    final themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    state = state.copyWith(themeMode: themeMode);
    _saveTheme(isDark);
  }

  void setFontFamily(String family) {
    state = state.copyWith(fontFamily: family);
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
