import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';

class FuelPriceRepository {
  final MySQLService _db = MySQLService();

  /// สร้างตาราง fuel_prices ถ้ายังไม่มี
  Future<void> initTable() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS fuel_prices (
        id INT PRIMARY KEY AUTO_INCREMENT,
        effective_date DATE NOT NULL,
        price_per_liter DECIMAL(8,2) NOT NULL,
        note VARCHAR(200) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_fuel_date (effective_date)
      )
    ''');
    debugPrint('✅ [FuelPriceRepository] Table ready.');
  }

  /// ดึงราคาน้ำมันทั้งหมด เรียงจากใหม่ไปเก่า
  Future<List<Map<String, dynamic>>> getAllPrices() async {
    final rows = await _db.query(
      'SELECT * FROM fuel_prices ORDER BY effective_date DESC',
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// ดึงราคาน้ำมัน ณ วันที่ที่ระบุ
  /// ใช้หลักการ "ราคาที่มีผลล่าสุด ≤ วันที่ระบุ"
  Future<double?> getPriceForDate(DateTime date) async {
    final dateStr = _formatDate(date);
    final rows = await _db.query(
      'SELECT price_per_liter FROM fuel_prices WHERE effective_date <= :d ORDER BY effective_date DESC LIMIT 1',
      {'d': dateStr},
    );
    if (rows.isEmpty) return null;
    return double.tryParse(rows.first['price_per_liter']?.toString() ?? '');
  }

  /// ดึงราคาล่าสุด (วันที่ใหม่ที่สุด)
  Future<Map<String, dynamic>?> getLatestPrice() async {
    final rows = await _db.query(
      'SELECT * FROM fuel_prices ORDER BY effective_date DESC LIMIT 1',
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  /// เพิ่มหรืออัปเดตราคาน้ำมัน (Upsert ตามวันที่)
  Future<void> upsertPrice({
    required DateTime date,
    required double pricePerLiter,
    String? note,
  }) async {
    final dateStr = _formatDate(date);
    await _db.execute(
      '''
      INSERT INTO fuel_prices (effective_date, price_per_liter, note)
      VALUES (:d, :p, :n)
      ON DUPLICATE KEY UPDATE price_per_liter = :p, note = :n
      ''',
      {'d': dateStr, 'p': pricePerLiter, 'n': note ?? ''},
    );
    debugPrint('✅ [FuelPriceRepository] Upserted price $pricePerLiter for $dateStr');
  }

  /// ลบราคาน้ำมันตาม id
  Future<void> deletePrice(int id) async {
    await _db.execute(
      'DELETE FROM fuel_prices WHERE id = :id',
      {'id': id},
    );
    debugPrint('🗑️ [FuelPriceRepository] Deleted price id=$id');
  }

  /// ดึงราคาน้ำมันรายเดือนสำหรับรายงาน (ช่วง startDate - endDate)
  Future<List<Map<String, dynamic>>> getPricesInRange(
      DateTime start, DateTime end) async {
    final s = _formatDate(start);
    final e = _formatDate(end);
    final rows = await _db.query(
      'SELECT * FROM fuel_prices WHERE effective_date BETWEEN :s AND :e ORDER BY effective_date ASC',
      {'s': s, 'e': e},
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// สร้าง Map date->price สำหรับ lookup ตอน Export
  /// Key = "YYYY-MM-DD"
  Future<Map<String, double>> buildPriceLookup(
      DateTime start, DateTime end) async {
    final prices = await getPricesInRange(
      start.subtract(const Duration(days: 30)), // ดึงก่อนหน้าเพื่อ fallback
      end,
    );
    final map = <String, double>{};
    for (final p in prices) {
      final dateKey = p['effective_date']?.toString().substring(0, 10) ?? '';
      final price =
          double.tryParse(p['price_per_liter']?.toString() ?? '') ?? 0.0;
      if (dateKey.isNotEmpty) map[dateKey] = price;
    }
    return map;
  }

  /// ค้นหาราคาน้ำมัน ณ วันที่จาก lookup map (ใช้ราคาล่าสุดก่อนวันนั้น)
  static double resolvePriceFromLookup(
      Map<String, double> lookup, DateTime date) {
    if (lookup.isEmpty) return 0.0;
    final dateStr = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    // หาราคาล่าสุดที่ effective_date <= date
    final sortedKeys = lookup.keys.toList()..sort();
    String? bestKey;
    for (final k in sortedKeys) {
      if (k.compareTo(dateStr) <= 0) {
        bestKey = k;
      } else {
        break;
      }
    }
    return bestKey != null ? lookup[bestKey]! : 0.0;
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
