import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';
import '../models/product_type.dart';

class ProductTypeRepository {
  final MySQLService _db = MySQLService();

  // 1. Get All
  Future<List<ProductType>> getAllProductTypes() async {
    if (!_db.isConnected()) await _db.connect();

    // Ensure table exists first (or assume init is called elsewhere)
    await _db.initProductTypeTable();

    try {
      const sql = 'SELECT * FROM product_type ORDER BY id ASC'; // 0, 1, 2...
      final rows = await _db.query(sql);
      return rows.map((r) => ProductType.fromJson(r)).toList();
    } catch (e) {
      debugPrint('Error fetching product types: $e');
      return [];
    }
  }

  // 2. Save (Updates if ID > 0, Creates if ID 0 or specified new?)
  // Typically ID is AutoInc for new types.
  Future<int> saveProductType(ProductType type) async {
    if (type.name.trim().isEmpty) return 0;
    if (!_db.isConnected()) await _db.connect();

    try {
      if (type.id > 0) {
        // Checking for existing ID
        // Note: For ID 0/1 (System default), maybe we allow name edit but NOT isWeighing edit?
        // Or trust the user. User said "Make it neat".
        // Let's ALLOW edit fully.

        const sql =
            'UPDATE product_type SET name = :name, isWeighing = :w WHERE id = :id';
        await _db.execute(sql, {
          'name': type.name.trim(),
          'w': type.isWeighing ? 1 : 0,
          'id': type.id
        });
        return type.id;
      } else {
        // Insert new
        const sql =
            'INSERT INTO product_type (name, isWeighing) VALUES (:name, :w)';
        final res = await _db.execute(sql, {
          'name': type.name.trim(),
          'w': type.isWeighing ? 1 : 0,
        });
        return res.lastInsertID.toInt();
      }
    } catch (e) {
      debugPrint('Error saving product type: $e');
      return 0;
    }
  }

  // 3. Delete
  Future<bool> deleteProductType(int id) async {
    if (id <= 1) {
      // Protect System Defaults (0: General, 1: Weighing)??
      // Usually good practice.
      debugPrint('Cannot delete system default types (ID 0, 1)');
      return false;
    }

    if (!_db.isConnected()) await _db.connect();
    try {
      // Check usage?
      final check = await _db.query(
          'SELECT count(*) as c FROM product WHERE productType = :id',
          {'id': id});
      if (check.isNotEmpty) {
        final count = int.tryParse(check.first['c'].toString()) ?? 0;
        if (count > 0) return false; // In use
      }

      await _db.execute('DELETE FROM product_type WHERE id = :id', {'id': id});
      return true;
    } catch (e) {
      debugPrint('Error deleting product type: $e');
      return false;
    }
  }

  // 4. Get Weighing IDs (For POS Logic)
  Future<Set<int>> getWeighingTypeIds() async {
    // This should be fast.
    if (!_db.isConnected()) await _db.connect();
    // make sure table exists
    await _db.initProductTypeTable();

    try {
      final rows =
          await _db.query('SELECT id FROM product_type WHERE isWeighing = 1');
      return rows
          .map((r) => int.tryParse(r['id'].toString()) ?? -1)
          .where((id) => id >= 0)
          .toSet();
    } catch (e) {
      debugPrint('Error getting weighing type ids: $e');
      return {1}; // Default fallback
    }
  }
}
