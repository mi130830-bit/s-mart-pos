// ไฟล์: lib/repositories/category_repository.dart

import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';

class CategoryRepository {
  final MySQLService _db = MySQLService();

  // 1. ดึงหมวดหมู่ทั้งหมด
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    if (!_db.isConnected()) await _db.connect();
    try {
      // ตรวจสอบว่ามีตาราง category หรือยัง
      // CREATE TABLE IF NOT EXISTS category (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100) NOT NULL);
      const sql = 'SELECT * FROM category ORDER BY name;';
      return await _db.query(sql);
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      return [];
    }
  }

  // 2. ฟังก์ชันหลักที่ใช้ในการ Import: ค้นหาชื่อ ถ้าไม่เจอให้สร้างใหม่แล้วคืนค่า ID
  Future<int> getOrCreateCategoryId(String name) async {
    String categoryName = name.trim();
    if (categoryName.isEmpty) return 0; // คืนค่า 0 หรือ ID ของ "ทั่วไป"

    if (!_db.isConnected()) await _db.connect();

    try {
      // ตรวจสอบว่ามีชื่อหมวดหมู่นี้หรือยัง
      final check = await _db.query(
          'SELECT id FROM category WHERE name = :name LIMIT 1',
          {'name': categoryName});

      if (check.isNotEmpty) {
        // ถ้าเจอแล้ว ให้คืนค่า ID นั้นกลับไป
        return int.parse(check.first['id'].toString());
      }

      // ถ้ายังไม่มี ให้ทำการเพิ่มใหม่
      final res = await _db.execute(
          'INSERT INTO category (name) VALUES (:name)', {'name': categoryName});

      // คืนค่า ID ที่เพิ่งสร้างใหม่
      return res.lastInsertID.toInt();
    } catch (e) {
      debugPrint('Error getOrCreateCategoryId: $e');
      return 0;
    }
  }

  // 3. ลบหมวดหมู่
  Future<bool> deleteCategory(int id) async {
    if (!_db.isConnected()) await _db.connect();
    try {
      const sql = 'DELETE FROM category WHERE id = :id';
      final res = await _db.execute(sql, {'id': id});
      return res.affectedRows.toInt() > 0;
    } catch (e) {
      debugPrint('Error deleting category: $e');
      return false;
    }
  }
}
