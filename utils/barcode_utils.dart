import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BarcodeUtils {
  static const String _prefKeyEnabled = 'barcode_fix_enabled';
  static const String _prefKeyMapping = 'barcode_custom_mapping';

  // Default Kedmanee layout mapping
  static final Map<String, String> _defaultThaiToEng = {
    'ๅ': '1',
    '/': '2',
    '-': '3',
    'ภ': '4',
    'ถ': '5',
    'ุ': '6',
    'ึ': '7',
    'ค': '8',
    'ต': '9',
    'จ': '0',
    'ข': '-',
    'ช': '=',
    'ๆ': 'q',
    'ไ': 'w',
    'ำ': 'e',
    'พ': 'r',
    'ะ': 't',
    'ั': 'y',
    'ี': 'u',
    'ร': 'i',
    'น': 'o',
    'ย': 'p',
    'บ': '[',
    'ล': ']',
    'ฃ': '\\',
    'ฟ': 'a',
    'ห': 's',
    'ก': 'd',
    'ด': 'f',
    'เ': 'g',
    '้': 'h',
    '่': 'j',
    'า': 'k',
    'ส': 'l',
    'ว': ';',
    'ง': '\'',
    'ผ': 'z',
    'ป': 'x',
    'แ': 'c',
    'อ': 'v',
    'ิ': 'b',
    'ื': 'n',
    'ท': 'm',
    'ม': ',',
    'ใ': '.',
    'ฝ': '/',
    '+': '!',
    '๑': '@',
    '๒': '#',
    '๓': '\$',
    '๔': '%',
    'ู': '^',
    '฿': '&',
    '๕': '*',
    '๖': '(',
    '๗': ')',
    '๘': '_',
    '๙': '+',
    // Shifted Row 2
    '๐': 'Q', '"': 'W', 'ฎ': 'E', 'ฑ': 'R', 'ธ': 'T', 'ํ': 'Y', '๊': 'U',
    'ณ': 'I', 'ฯ': 'O', 'ญ': 'P', 'ฐ': '{', ',': '}', 'ฅ': '|',
    // Shifted Row 3
    'ฤ': 'A', 'ฆ': 'S', 'ฏ': 'D', 'โ': 'F', 'ฌ': 'G', '็': 'H', '๋': 'J',
    'ษ': 'K', 'ศ': 'L', 'ซ': ':', '.': '"',
    // Shifted Row 4
    '(': 'Z', ')': 'X', 'ฉ': 'C', 'ฮ': 'V', 'ฺ': 'B', '์': 'N', '?': 'M',
    'ฒ': '<', 'ฬ': '>', 'ฦ': '?',
  };

  static Map<String, String> _activeMapping = {};
  static bool _isEnabled = true;

  static bool get isEnabled => _isEnabled;

  /// Initialize and load settings from SharedPreferences
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_prefKeyEnabled) ?? true;

    // Load custom mapping if exists, else use default
    final jsonString = prefs.getString(_prefKeyMapping);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(jsonString);
        _activeMapping = Map<String, String>.from(decoded);
      } catch (e) {
        _activeMapping = Map.from(_defaultThaiToEng);
      }
    } else {
      _activeMapping = Map.from(_defaultThaiToEng);
    }
  }

  /// Save current mapping to SharedPreferences
  static Future<void> saveSettings(
      {required bool enabled, required Map<String, String> mapping}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyEnabled, enabled);
    await prefs.setString(_prefKeyMapping, jsonEncode(mapping));

    _isEnabled = enabled;
    _activeMapping = Map.from(mapping);
  }

  /// Reset to default mapping
  static Future<void> resetToDefault() async {
    await saveSettings(enabled: true, mapping: _defaultThaiToEng);
  }

  static Map<String, String> getCurrentMapping() =>
      Map.unmodifiable(_activeMapping);

  /// Convert Thai input string to English based on active mapping
  static String fixThaiInput(String input) {
    if (!_isEnabled) return input;

    // If not initialized yet (shouldn't happen if init called in main), fallback to default
    final map = _activeMapping.isNotEmpty ? _activeMapping : _defaultThaiToEng;

    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      String char = input[i];
      buffer.write(map[char] ?? char);
    }
    return buffer.toString();
  }

  /// Check if string contains Thai characters
  static bool isThaiInput(String input) {
    final thaiRegex = RegExp(r'[\u0E00-\u0E7F]');
    return thaiRegex.hasMatch(input);
  }
}
