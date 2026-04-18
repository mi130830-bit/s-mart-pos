import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';
import '../models/shelf.dart';

class ShelfRepository {
  final MySQLService _db = MySQLService();
  bool _hasSeeded = false;

  // 1. ดึงชั้นวางทั้งหมด
  Future<List<Shelf>> getAllShelves() async {
    if (!_db.isConnected()) await _db.connect();

    try {
      // ตรวจสอบหรือสร้างตาราง (ในระบบจริงควรมี Migration script หรือสร้างตารางล่วงหน้า)
      await _db.execute('''
        CREATE TABLE IF NOT EXISTS shelf (
          id INT AUTO_INCREMENT PRIMARY KEY, 
          name VARCHAR(50) NOT NULL UNIQUE
        )
      ''');

      // Auto-Seed ชั้น 1-40 ถ้าตารางเพิ่งสร้าง / ไม่มีข้อมูลเลย
      if (!_hasSeeded) {
        final countRes = await _db.query('SELECT COUNT(*) as count FROM shelf');
        if (countRes.isNotEmpty &&
            int.parse(countRes.first['count'].toString()) == 0) {
          debugPrint('🔧 Seeding Default Shelves 1-40...');
          for (int i = 1; i <= 40; i++) {
            await saveShelf('ชั้นที่ $i');
          }
        }
        _hasSeeded = true;
      }

      const sql = 'SELECT * FROM shelf ORDER BY id ASC;';
      final rows = await _db.query(sql);
      return rows.map((r) => Shelf.fromJson(r)).toList();
    } catch (e) {
      debugPrint('Error fetching shelves: $e');
      return [];
    }
  }

  // 2. บันทึกชั้นวาง
  Future<int> saveShelf(String name) async {
    if (name.trim().isEmpty) return 0;
    if (!_db.isConnected()) await _db.connect();

    try {
      // ตรวจสอบชื่อซ้ำ
      final check = await _db.query(
          'SELECT id FROM shelf WHERE name = :name', {'name': name.trim()});

      if (check.isNotEmpty) {
        return int.parse(check.first['id'].toString());
      }

      // สร้างใหม่
      const sql = 'INSERT INTO shelf (name) VALUES (:name)';
      final res = await _db.execute(sql, {'name': name.trim()});
      return res.lastInsertID.toInt();
    } catch (e) {
      debugPrint('Error saving shelf: $e');
      return 0;
    }
  }

  // 3. ฟังก์ชันสำหรับ Import หรือ Get Existing
  Future<int> getOrCreateShelfId(String shelfName) async {
    return await saveShelf(shelfName);
  }

  // 4. ลบชั้นวาง
  Future<bool> deleteShelf(int id) async {
    if (!_db.isConnected()) await _db.connect();
    try {
      const sql = 'DELETE FROM shelf WHERE id = :id';
      final res = await _db.execute(sql, {'id': id});
      return res.affectedRows.toInt() > 0;
    } catch (e) {
      debugPrint('Error deleting shelf: $e');
      return false;
    }
  }

  // 5. แก้ไขชั้นวาง
  Future<bool> updateShelf(int id, String newName) async {
    if (newName.trim().isEmpty) return false;
    if (!_db.isConnected()) await _db.connect();

    try {
      // Check duplicate name
      final check = await _db.query(
          'SELECT id FROM shelf WHERE name = :name AND id != :id',
          {'name': newName.trim(), 'id': id});
      if (check.isNotEmpty) return false; // Duplicate

      const sql = 'UPDATE shelf SET name = :name WHERE id = :id';
      final res = await _db.execute(sql, {'name': newName.trim(), 'id': id});
      return res.affectedRows.toInt() > 0;
    } catch (e) {
      debugPrint('Error updating shelf: $e');
      return false;
    }
  }
}
