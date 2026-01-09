import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuickMenuConfig {
  Map<int, String> pageNames = {};
  Map<String, int> slots = {}; // 'page_slot' -> productId

  QuickMenuConfig({Map<int, String>? pageNames, Map<String, int>? slots}) {
    if (pageNames != null) this.pageNames = pageNames;
    if (slots != null) this.slots = slots;
  }

  Map<String, dynamic> toJson() => {
        'pageNames':
            pageNames.map((key, value) => MapEntry(key.toString(), value)),
        'slots': slots,
      };

  factory QuickMenuConfig.fromJson(Map<String, dynamic> json) {
    final pageNames = <int, String>{};
    if (json['pageNames'] != null) {
      (json['pageNames'] as Map<String, dynamic>).forEach((k, v) {
        pageNames[int.parse(k)] = v.toString();
      });
    }

    final slots = <String, int>{};
    if (json['slots'] != null) {
      (json['slots'] as Map<String, dynamic>).forEach((k, v) {
        slots[k] = v is int ? v : int.tryParse(v.toString()) ?? 0;
      });
    }

    return QuickMenuConfig(pageNames: pageNames, slots: slots);
  }
}

class QuickMenuService {
  static const String _storageKey = 'pos_quick_menu_config';
  QuickMenuConfig _config = QuickMenuConfig();

  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        _config = QuickMenuConfig.fromJson(jsonDecode(jsonStr));
      }
    } catch (e) {
      debugPrint('Error loading QuickMenuConfig: $e');
    }
  }

  Future<void> saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_config.toJson()));
    } catch (e) {
      debugPrint('Error saving QuickMenuConfig: $e');
    }
  }

  String getPageName(int page) {
    return _config.pageNames[page] ?? 'หน้า $page';
  }

  Future<void> setPageName(int page, String name, {bool save = true}) async {
    _config.pageNames[page] = name;
    if (save) await saveConfig();
  }

  int getProductId(int page, int slotIndex) {
    // slotIndex 0-19
    final key = '${page}_$slotIndex';
    return _config.slots[key] ?? 0;
  }

  Future<void> setProductId(int page, int slotIndex, int productId,
      {bool save = true}) async {
    final key = '${page}_$slotIndex';
    if (productId <= 0) {
      _config.slots.remove(key);
    } else {
      _config.slots[key] = productId;
    }
    if (save) await saveConfig();
  }
}
