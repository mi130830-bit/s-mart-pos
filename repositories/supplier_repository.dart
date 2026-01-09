import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';
import '../models/supplier.dart';

class SupplierRepository {
  final MySQLService _db = MySQLService();

  Future<List<Supplier>> getAllSuppliers() async {
    if (!_db.isConnected()) await _db.connect();
    try {
      const sql = 'SELECT * FROM supplier ORDER BY name;';
      final rows = await _db.query(sql);
      return rows.map((r) => Supplier.fromJson(r)).toList();
    } catch (e) {
      debugPrint('Error fetching suppliers: $e');
      return [];
    }
  }

  Future<bool> saveSupplier(Supplier s) async {
    if (!_db.isConnected()) await _db.connect();
    try {
      if (s.id == 0) {
        const sql =
            'INSERT INTO supplier (name, phone, address, saleName, saleLineId) VALUES (:name, :phone, :address, :saleName, :saleLineId)';
        final res = await _db.execute(sql, {
          'name': s.name,
          'phone': s.phone,
          'address': s.address,
          'saleName': s.saleName ?? '',
          'saleLineId': s.saleLineId ?? '',
        });
        return res.affectedRows.toInt() > 0;
      } else {
        const sql =
            'UPDATE supplier SET name = :name, phone = :phone, address = :address, saleName = :saleName, saleLineId = :saleLineId WHERE id = :id';
        final res = await _db.execute(sql, {
          'name': s.name,
          'phone': s.phone,
          'address': s.address,
          'saleName': s.saleName ?? '',
          'saleLineId': s.saleLineId ?? '',
          'id': s.id,
        });
        return res.affectedRows.toInt() > 0;
      }
    } catch (e) {
      debugPrint('Error saving supplier: $e');
      return false;
    }
  }

  Future<bool> deleteSupplier(int id) async {
    if (!_db.isConnected()) await _db.connect();
    try {
      const sql = 'DELETE FROM supplier WHERE id = :id';
      final res = await _db.execute(sql, {'id': id});
      return res.affectedRows.toInt() > 0;
    } catch (e) {
      debugPrint('Error deleting supplier: $e');
      return false;
    }
  }

  Future<int> getOrCreateSupplierId(String name) async {
    if (!_db.isConnected()) await _db.connect();

    // Truncate name if too long (Assuming VARCHAR(100) or similar, safe to 100)
    String safeName = name.length > 100 ? name.substring(0, 100) : name;

    // 1. Try to find existing
    try {
      final rows = await _db.query(
        'SELECT id FROM supplier WHERE name = :name LIMIT 1',
        {'name': safeName},
      );
      if (rows.isNotEmpty) {
        final val = rows.first['id'];
        if (val is int) return val;
        if (val is String) return int.tryParse(val) ?? 0;
        return 0;
      }

      // 2. Create new if not found
      final insertRes = await _db.execute(
        'INSERT INTO supplier (name, phone, address) VALUES (:name, "", "")',
        {'name': safeName},
      );

      // ignore: unnecessary_null_comparison
      if (insertRes.lastInsertID != null) {
        return insertRes.lastInsertID.toInt();
      }

      // Fallback: Re-query just in case
      final newRows = await _db.query(
        'SELECT id FROM supplier WHERE name = :name LIMIT 1',
        {'name': safeName},
      );
      if (newRows.isNotEmpty) {
        final val = newRows.first['id'];
        if (val is int) return val;
        if (val is String) return int.tryParse(val) ?? 0;
      }
      return 0; // Fail
    } catch (e) {
      debugPrint('Error getOrCreateSupplierId: $e');
      return 0;
    }
  }

  // --- Pagination Methods ---
  Future<List<Supplier>> getSuppliersPaginated(int page, int pageSize,
      {String? searchTerm}) async {
    if (!_db.isConnected()) await _db.connect();
    try {
      final offset = (page - 1) * pageSize;
      String sql = 'SELECT * FROM supplier';
      Map<String, dynamic> params = {
        'limit': pageSize,
        'offset': offset,
      };

      if (searchTerm != null && searchTerm.isNotEmpty) {
        sql += ' WHERE name LIKE :term OR phone LIKE :term';
        params['term'] = '%$searchTerm%';
      }

      sql += ' ORDER BY name LIMIT :limit OFFSET :offset';

      final rows = await _db.query(sql, params);
      return rows.map((r) => Supplier.fromJson(r)).toList();
    } catch (e) {
      debugPrint('Error fetching paginated suppliers: $e');
      return [];
    }
  }

  Future<int> getSupplierCount({String? searchTerm}) async {
    if (!_db.isConnected()) await _db.connect();
    try {
      String sql = 'SELECT COUNT(*) as count FROM supplier';
      Map<String, dynamic> params = {};

      if (searchTerm != null && searchTerm.isNotEmpty) {
        sql += ' WHERE name LIKE :term OR phone LIKE :term';
        params['term'] = '%$searchTerm%';
      }

      final rows = await _db.query(sql, params);
      if (rows.isNotEmpty) {
        final val = rows.first['count'];
        // Safe parsing
        if (val is int) return val;
        if (val is String) return int.tryParse(val) ?? 0;
        if (val is BigInt) return val.toInt();
      }
      return 0;
    } catch (e) {
      debugPrint('Error counting suppliers: $e');
      return 0;
    }
  }
}
