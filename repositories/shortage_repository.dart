import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/mysql_service.dart';
import '../models/shortage_log_model.dart';

class ShortageRepository {
  final MySQLService _mysqlService = MySQLService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ShortageRepository() {
    _initTable();
  }

  Future<void> _initTable() async {
    const createSql = '''
      CREATE TABLE IF NOT EXISTS shortage_logs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        item_name VARCHAR(255) NOT NULL,
        status VARCHAR(50) DEFAULT 'open',
        reported_by VARCHAR(100),
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        ordered_at DATETIME NULL,
        received_at DATETIME NULL,
        INDEX(status),
        INDEX(created_at)
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    ''';
    try {
      await _mysqlService.execute(createSql);
      // Migration: add received_at if not exists
      await _mysqlService.execute(
        "ALTER TABLE shortage_logs ADD COLUMN IF NOT EXISTS received_at DATETIME NULL"
      );
    } catch (e) {
      debugPrint('Error initializing shortage_logs table: \$e');
    }
  }

  Future<List<ShortageLogModel>> getOpenShortages() async {
    const sql = '''
      SELECT * FROM shortage_logs 
      WHERE status = 'open'
      ORDER BY created_at DESC
    ''';

    try {
      final results = await _mysqlService.query(sql);
      return results.map((row) => ShortageLogModel.fromMap(row)).toList();
    } catch (e) {
      debugPrint('MySQL Error (getOpenShortages): $e');
      return [];
    }
  }

  Future<List<ShortageLogModel>> getOrderedShortages() async {
    const sql = '''
      SELECT * FROM shortage_logs 
      WHERE status = 'ordered'
      ORDER BY ordered_at DESC
    ''';

    try {
      final results = await _mysqlService.query(sql);
      return results.map((row) => ShortageLogModel.fromMap(row)).toList();
    } catch (e) {
      debugPrint('MySQL Error (getOrderedShortages): $e');
      return [];
    }
  }

  Future<List<ProductSearchResult>> searchProducts(String keyword) async {
    if (keyword.isEmpty) return [];
    // POS table is 'product' (singular)
    const sql = '''
      SELECT name, barcode, stockQuantity FROM product
      WHERE isActive = 1 AND (name LIKE :keyword OR barcode LIKE :keyword)
      LIMIT 10
    ''';

    try {
      final results = await _mysqlService.query(sql, {'keyword': '%$keyword%'});
      return results.map((row) => ProductSearchResult.fromMap(row)).toList();
    } catch (e) {
      debugPrint('MySQL Search Error: $e');
      return [];
    }
  }

  Future<void> createShortage(String itemName, String reporterId) async {
    const sql = '''
      INSERT INTO shortage_logs (item_name, status, reported_by, created_at)
      VALUES (:itemName, 'open', :reporterId, NOW())
    ''';

    try {
      await _mysqlService.execute(sql, {
        'itemName': itemName,
        'reporterId': reporterId,
      });

      await _triggerNotification(itemName, reporterId);
    } catch (e) {
      debugPrint('Error creating shortage: $e');
      rethrow;
    }
  }

  Future<void> _triggerNotification(String itemName, String reporterId) async {
    try {
      await _firestore.collection('stock_alerts').add({
        'product_info': itemName,
        'reporter_id': reporterId,
        'created_at': FieldValue.serverTimestamp(),
        'status': 'pending',
        'source': 'pos_desktop',
      });
    } catch (e) {
      debugPrint('Shared notification failed: $e');
    }
  }

  Future<void> markAsOrdered(int id) async {
    const sql = '''
      UPDATE shortage_logs 
      SET status = 'ordered', ordered_at = NOW() 
      WHERE id = :id
    ''';
    await _mysqlService.execute(sql, {'id': id});
  }

  Future<void> markAsReceived(int id) async {
    const sql = '''
      UPDATE shortage_logs 
      SET status = 'received', received_at = NOW() 
      WHERE id = :id
    ''';
    await _mysqlService.execute(sql, {'id': id});
  }

  Future<void> markAsDone(int id) async {
    const sql = 'DELETE FROM shortage_logs WHERE id = :id';
    await _mysqlService.execute(sql, {'id': id});
  }

  // Returns {stockQty, unit} or null if product not found
  Future<Map<String, dynamic>?> getProductStockByName(String itemName) async {
    try {
      final cleanName = itemName.replaceAll(RegExp(r'\s*\(คงเหลือ:.*?\)'), '').trim();
      final res = await _mysqlService.query(
        'SELECT stockQuantity FROM product WHERE name LIKE :name ORDER BY (name = :exact) DESC LIMIT 1',
        {'name': '%$cleanName%', 'exact': cleanName},
      );
      if (res.isNotEmpty) {
        return {
          'stockQty': double.tryParse(res.first['stockQuantity'].toString()) ?? 0,
          'unit': '',
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error getting stock for $itemName: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getCheapestSupplierSuggestions(String itemName) async {
    try {
      // Strip trailing "(คงเหลือ: ...)" or "(คงเหลือ: ...)" appended by UI
      final cleanName = itemName.replaceAll(RegExp(r'\s*\(คงเหลือ:.*?\)'), '').trim();

      // 1. Find the product by name (exact + LIKE)
      final pRes = await _mysqlService.query(
        'SELECT id, name FROM product WHERE name LIKE :name ORDER BY (name = :exact) DESC LIMIT 1',
        {'name': '%$cleanName%', 'exact': cleanName},
      );

      int? productId;
      if (pRes.isNotEmpty) {
        productId = int.tryParse(pRes.first['id'].toString());
        debugPrint('🔎 [Suggestion] "$itemName" → product found: ${pRes.first['name']} (id=$productId)');
      } else {
        debugPrint('🔎 [Suggestion] "$itemName" → no product match in DB');
      }

      // 2. Collect all related product IDs (self + parents + children via product_components)
      Set<int> relatedIds = {};
      if (productId != null && productId > 0) {
        relatedIds.add(productId);

        // Find child components
        final children = await _mysqlService.query(
          'SELECT child_product_id FROM product_components WHERE parent_product_id = :pid',
          {'pid': productId},
        );
        for (var r in children) {
          final id = int.tryParse(r['child_product_id'].toString()) ?? 0;
          if (id > 0) relatedIds.add(id);
        }

        // Find parent products (this product is a component of some parent)
        final parents = await _mysqlService.query(
          'SELECT parent_product_id FROM product_components WHERE child_product_id = :pid',
          {'pid': productId},
        );
        for (var r in parents) {
          final id = int.tryParse(r['parent_product_id'].toString()) ?? 0;
          if (id > 0) relatedIds.add(id);
        }

        debugPrint('🔎 [Suggestion] "$itemName" → relatedIds: $relatedIds');
      }

      // 3. Build WHERE clause
      String whereClause;
      Map<String, dynamic> params = {};

      if (relatedIds.isNotEmpty) {
        final idList = relatedIds.join(',');
        whereClause = 'poi.productId IN ($idList)';
      } else {
        // Fallback: match by product name in PO items
        whereClause = 'poi.productName LIKE :name';
        params = {'name': '%$itemName%'};
        debugPrint('🔎 [Suggestion] "$itemName" → using name LIKE fallback in PO items');
      }

      // 4. Query cheapest suppliers — use COALESCE to handle walk-in/freeform suppliers
      final sql = '''
        SELECT 
          COALESCE(s.name, CONCAT('ผู้ขาย #', po.supplierId), 'ไม่ระบุ') as supplierName,
          MIN(NULLIF(poi.costPrice, 0)) as costPrice,
          MAX(po.createdAt) as lastBought
        FROM purchase_order_item poi
        JOIN purchase_order po ON poi.poId = po.id
        LEFT JOIN supplier s ON po.supplierId = s.id
        WHERE $whereClause
          AND po.status IN ('RECEIVED', 'PARTIAL')
        GROUP BY po.supplierId, s.name
        HAVING costPrice IS NOT NULL
        ORDER BY costPrice ASC
        LIMIT 2;
      ''';

      debugPrint('🔎 [Suggestion] "$itemName" → WHERE: $whereClause | params: $params');

      final results = await _mysqlService.query(sql, params);
      debugPrint('🔎 [Suggestion] "$itemName" → final results count: ${results.length}');
      return results;
    } catch (e) {
      debugPrint('❌ [Suggestion Error] "$itemName": $e');
      return [];
    }
  }
}
