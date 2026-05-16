import 'package:flutter/foundation.dart';
import 'mysql_service.dart';

class QuickMenuConfig {
  Map<int, String> pageNames = {};
  Map<String, int> slots = {}; // 'page_slot' -> productId

  QuickMenuConfig({Map<int, String>? pageNames, Map<String, int>? slots}) {
    if (pageNames != null) this.pageNames = pageNames;
    if (slots != null) this.slots = slots;
  }
}

class QuickMenuService {
  final MySQLService _db = MySQLService();
  final QuickMenuConfig _config = QuickMenuConfig();
  bool _isLoaded = false;

  QuickMenuConfig get config => _config;
  bool get isLoaded => _isLoaded;

  Future<void> loadConfig() async {
    try {
      if (!await _db.hasConfig()) return;

      // Load Pages
      final pagesResult =
          await _db.query('SELECT id, name FROM quick_menu_page');
      for (var row in pagesResult) {
        final id = int.tryParse(row['id'].toString()) ?? 0;
        _config.pageNames[id] = row['name'].toString();
      }

      // Load Items
      final itemsResult = await _db
          .query('SELECT page_id, slot_id, product_id FROM quick_menu_item');
      for (var row in itemsResult) {
        final productId = int.tryParse(row['product_id'].toString()) ?? 0;
        final key = '${row['page_id']}_${row['slot_id']}';
        _config.slots[key] = productId;
      }
      _isLoaded = true;
      debugPrint(
          '✅ QuickMenuService: Loaded ${_config.slots.length} items from DB.');
    } catch (e) {
      debugPrint('❌ QuickMenuService Error loading config: $e');
    }
  }

  // No longer needed as separate public call, but kept for compatibility if needed
  Future<void> saveConfig() async {
    // In DB mode, we save incrementally on setPageName/setProductId
  }

  String getPageName(int page) {
    return _config.pageNames[page] ?? 'หน้า $page';
  }

  Future<void> setPageName(int page, String name) async {
    _config.pageNames[page] = name;
    try {
      await _db.execute(
        'INSERT INTO quick_menu_page (id, name) VALUES (:id, :name) ON DUPLICATE KEY UPDATE name = :name',
        {'id': page, 'name': name},
      );
    } catch (e) {
      debugPrint('❌ Error saving page name: $e');
    }
  }

  int getProductId(int page, int slotIndex) {
    // slotIndex 0-19
    final key = '${page}_$slotIndex';
    return _config.slots[key] ?? 0;
  }

  Future<void> setProductId(int page, int slotIndex, int productId) async {
    final key = '${page}_$slotIndex';

    if (productId <= 0) {
      _config.slots.remove(key);
      try {
        await _db.execute(
            'DELETE FROM quick_menu_item WHERE page_id = :p AND slot_id = :s',
            {'p': page, 's': slotIndex});
      } catch (e) {
        debugPrint('❌ Error removing quick menu item: $e');
      }
    } else {
      _config.slots[key] = productId;
      try {
        await _db.execute(
          'INSERT INTO quick_menu_item (page_id, slot_id, product_id) VALUES (:p, :s, :pid) ON DUPLICATE KEY UPDATE product_id = :pid',
          {'p': page, 's': slotIndex, 'pid': productId},
        );
      } catch (e) {
        debugPrint('❌ Error saving quick menu item: $e');
      }
    }
  }
}
