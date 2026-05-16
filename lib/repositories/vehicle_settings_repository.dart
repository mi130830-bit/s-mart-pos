import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';

class VehicleSettingsRepository {
  final MySQLService _db = MySQLService();

  static const double defaultEfficiency = 7.0; // กม./ลิตร

  /// สร้างตาราง vehicle_settings ถ้ายังไม่มี
  Future<void> initTable() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS vehicle_settings (
        id INT PRIMARY KEY AUTO_INCREMENT,
        vehicle_plate VARCHAR(50) NOT NULL,
        fuel_efficiency DECIMAL(8,2) DEFAULT 7.0,
        vehicle_type VARCHAR(50) NULL,
        note VARCHAR(200) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uq_vehicle_plate (vehicle_plate)
      )
    ''');
    debugPrint('✅ [VehicleSettingsRepository] Table ready.');
  }

  /// ดึงการตั้งค่ารถทั้งหมด
  Future<List<Map<String, dynamic>>> getAllVehicles() async {
    final rows = await _db.query(
      'SELECT * FROM vehicle_settings ORDER BY vehicle_plate ASC',
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// ดึงอัตราสิ้นเปลืองของรถคันนั้น (กม./ลิตร)
  /// ถ้าไม่พบ ใช้ค่า default = 7.0
  Future<double> getEfficiency(String vehiclePlate) async {
    if (vehiclePlate.trim().isEmpty) return defaultEfficiency;
    final plate = vehiclePlate.trim().toUpperCase();
    final rows = await _db.query(
      'SELECT fuel_efficiency FROM vehicle_settings WHERE vehicle_plate = :p',
      {'p': plate},
    );
    if (rows.isEmpty) return defaultEfficiency;
    return double.tryParse(rows.first['fuel_efficiency']?.toString() ?? '') ??
        defaultEfficiency;
  }

  /// ดึง efficiency ของหลายคันพร้อมกัน (Map plate -> km/L)
  Future<Map<String, double>> getEfficiencyMap() async {
    final rows = await _db.query(
      'SELECT vehicle_plate, fuel_efficiency FROM vehicle_settings',
    );
    final map = <String, double>{};
    for (final r in rows) {
      final plate = r['vehicle_plate']?.toString() ?? '';
      final eff = double.tryParse(r['fuel_efficiency']?.toString() ?? '') ??
          defaultEfficiency;
      if (plate.isNotEmpty) map[plate] = eff;
    }
    return map;
  }

  /// เพิ่มหรืออัปเดตการตั้งค่ารถ (Upsert)
  Future<void> upsertVehicle({
    required String vehiclePlate,
    required double fuelEfficiency,
    String? vehicleType,
    String? note,
  }) async {
    final plate = vehiclePlate.trim().toUpperCase();
    await _db.execute(
      '''
      INSERT INTO vehicle_settings (vehicle_plate, fuel_efficiency, vehicle_type, note)
      VALUES (:plate, :eff, :type, :note)
      ON DUPLICATE KEY UPDATE 
        fuel_efficiency = :eff,
        vehicle_type = :type,
        note = :note,
        updated_at = CURRENT_TIMESTAMP
      ''',
      {
        'plate': plate,
        'eff': fuelEfficiency,
        'type': vehicleType ?? '',
        'note': note ?? '',
      },
    );
    debugPrint(
        '✅ [VehicleSettingsRepository] Upserted $plate @ ${fuelEfficiency}km/L');
  }

  /// ลบรถออกจาก settings
  Future<void> deleteVehicle(int id) async {
    await _db.execute(
      'DELETE FROM vehicle_settings WHERE id = :id',
      {'id': id},
    );
  }

  /// Auto-sync: ดึงทะเบียนรถทั้งหมดที่เคยส่งของ แล้วเพิ่มเข้า vehicle_settings
  /// ถ้ายังไม่มี (ใช้ค่า default efficiency)
  Future<int> syncVehiclesFromHistory() async {
    final histRows = await _db.query('''
      SELECT DISTINCT TRIM(UPPER(vehiclePlate)) AS plate
      FROM delivery_history
      WHERE vehiclePlate IS NOT NULL AND vehiclePlate != ''
    ''');

    int added = 0;
    for (final row in histRows) {
      final plate = row['plate']?.toString() ?? '';
      if (plate.isEmpty) continue;
      try {
        await _db.execute(
          'INSERT IGNORE INTO vehicle_settings (vehicle_plate, fuel_efficiency) VALUES (:p, :e)',
          {'p': plate, 'e': defaultEfficiency},
        );
        added++;
      } catch (e) {
        debugPrint('⚠️ Sync vehicle $plate: $e');
      }
    }
    debugPrint(
        '✅ [VehicleSettingsRepository] Synced $added vehicles from history');
    return added;
  }
}
