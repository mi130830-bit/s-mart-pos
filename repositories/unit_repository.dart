import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';
import '../models/unit.dart';

class UnitRepository {
  final MySQLService _db = MySQLService();

  // 1. ดึงหน่วยทั้งหมด
  Future<List<Unit>> getAllUnits() async {
    if (!_db.isConnected()) await _db.connect();
    try {
      // ตรวจสอบว่ามีตาราง unit หรือยัง (ในระบบจริงควรสร้างตารางไว้แล้ว)
      // CREATE TABLE IF NOT EXISTS unit (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50) NOT NULL);
      const sql = 'SELECT * FROM unit ORDER BY name;';
      final rows = await _db.query(sql);
      return rows.map((r) => Unit.fromJson(r)).toList();
    } catch (e) {
      debugPrint('Error fetching units: $e');
      return [];
    }
  }

  // 2. บันทึกหน่วย (ถ้ามีชื่อซ้ำจะคืนค่า ID เดิม, ถ้าไม่มีจะสร้างใหม่)
  Future<int> saveUnit(String name) async {
    if (name.trim().isEmpty) return 0;
    if (!_db.isConnected()) await _db.connect();

    try {
      // ตรวจสอบชื่อซ้ำ
      final check = await _db.query(
          'SELECT id FROM unit WHERE name = :name', {'name': name.trim()});

      if (check.isNotEmpty) {
        return int.parse(check.first['id'].toString());
      }

      // สร้างใหม่
      const sql = 'INSERT INTO unit (name) VALUES (:name)';
      final res = await _db.execute(sql, {'name': name.trim()});
      return res.lastInsertID.toInt();
    } catch (e) {
      debugPrint('Error saving unit: $e');
      return 0;
    }
  }

  // 3. ฟังก์ชันสำหรับ Import (ทำงานเหมือน saveUnit แต่ตั้งชื่อให้ตรงกับโค้ด Import)
  Future<int> getOrCreateUnitId(String unitName) async {
    return await saveUnit(unitName);
  }

  // 4. ลบหน่วย
  Future<bool> deleteUnit(int id) async {
    if (!_db.isConnected()) await _db.connect();
    try {
      // ตรวจสอบก่อนว่ามีการใช้งานอยู่หรือไม่ (Optional)
      /*
      final check = await _db.query('SELECT count(*) as count FROM product WHERE unitId = :id', {'id': id});
      if (check.isNotEmpty && int.parse(check.first['count'].toString()) > 0) {
        return false; // ห้ามลบถ้ามีการใช้งาน
      }
      */

      const sql = 'DELETE FROM unit WHERE id = :id';
      final res = await _db.execute(sql, {'id': id});
      return res.affectedRows.toInt() > 0;
    } catch (e) {
      debugPrint('Error deleting unit: $e');
      return false;
    }
  }

  // 5. แก้ไขหน่วย
  Future<bool> updateUnit(int id, String newName) async {
    if (newName.trim().isEmpty) return false;
    if (!_db.isConnected()) await _db.connect();

    try {
      // Check duplicate name
      final check = await _db.query(
          'SELECT id FROM unit WHERE name = :name AND id != :id',
          {'name': newName.trim(), 'id': id});
      if (check.isNotEmpty) return false; // Duplicate

      const sql = 'UPDATE unit SET name = :name WHERE id = :id';
      final res = await _db.execute(sql, {'name': newName.trim(), 'id': id});
      return res.affectedRows.toInt() > 0;
    } catch (e) {
      debugPrint('Error updating unit: $e');
      return false;
    }
  }
}
