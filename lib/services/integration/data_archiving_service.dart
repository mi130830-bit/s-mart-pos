import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../services/mysql_service.dart';

class DataArchivingService {
  final MySQLService _db = MySQLService();

  /// สร้างตารางสรุปยอดสำหรับเก็บข้อมูลที่ Rollup แล้ว
  Future<void> initArchiveTable() async {
    try {
      await _db.execute('''
        CREATE TABLE IF NOT EXISTS historical_summary (
          id INT AUTO_INCREMENT PRIMARY KEY,
          summaryMonth VARCHAR(7) NOT NULL, -- e.g., '2015-01'
          totalSales DECIMAL(15,2) DEFAULT 0.0,
          totalProfit DECIMAL(15,2) DEFAULT 0.0,
          totalFuelCost DECIMAL(15,2) DEFAULT 0.0,
          archivedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
          UNIQUE KEY idx_month (summaryMonth)
        )
      ''');
      debugPrint('✅ [DataArchivingService] Table historical_summary initialized.');
    } catch (e) {
      debugPrint('⚠️ [DataArchivingService] Error init archive table: $e');
    }
  }

  /// ค้นหาและลบข้อมูลที่อายุเกิน 10 ปี (อิงตามที่สรรพากรขอตรวจสอบ) 
  /// และรวมยอด (Rollup) ไปเก็บในตาราง historical_summary เพื่อลดขนาด Database
  Future<void> archiveTenYearsOldData() async {
    await initArchiveTable();
    
    // วันที่ย้อนหลังไป 10 ปี
    final tenYearsAgo = DateTime.now().subtract(const Duration(days: 365 * 10));
    final tenYearsAgoStr = DateFormat('yyyy-MM-dd 00:00:00').format(tenYearsAgo);

    debugPrint('🔍 [DataArchivingService] Scanning for data older than: $tenYearsAgoStr');

    try {
      // 1. ดึงบิลเก่าเกิน 10 ปี
      final oldOrders = await _db.query('''
        SELECT id, createdAt, total, profit
        FROM `order` 
        WHERE createdAt < :date
      ''', {'date': tenYearsAgoStr});

      // ดึงงานส่งของเก่าเกิน 10 ปี
      final oldDeliveries = await _db.query('''
        SELECT completedAt, fuelCostEstimate
        FROM delivery_history
        WHERE completedAt < :date
      ''', {'date': tenYearsAgoStr});

      if (oldOrders.isEmpty && oldDeliveries.isEmpty) {
        debugPrint('✅ [DataArchivingService] No data older than 10 years to archive.');
        return;
      }

      // 2. ประมวลผล Rollup ยอดรายเดือน
      Map<String, Map<String, double>> rollups = {};
      
      for (var row in oldOrders) {
        final dtStr = row['createdAt']?.toString() ?? '';
        if (dtStr.isEmpty) continue;
        final dt = DateTime.tryParse(dtStr);
        if (dt == null) continue;
        
        final monthKey = DateFormat('yyyy-MM').format(dt);
        if (!rollups.containsKey(monthKey)) {
          rollups[monthKey] = {'sales': 0.0, 'profit': 0.0, 'fuel': 0.0};
        }
        
        final sales = double.tryParse(row['total']?.toString() ?? '0') ?? 0.0;
        final profit = double.tryParse(row['profit']?.toString() ?? '0') ?? 0.0;
        
        rollups[monthKey]!['sales'] = rollups[monthKey]!['sales']! + sales;
        rollups[monthKey]!['profit'] = rollups[monthKey]!['profit']! + profit;
      }

      for (var row in oldDeliveries) {
        final dtStr = row['completedAt']?.toString() ?? '';
        if (dtStr.isEmpty) continue;
        final dt = DateTime.tryParse(dtStr);
        if (dt == null) continue;
        
        final monthKey = DateFormat('yyyy-MM').format(dt);
        if (!rollups.containsKey(monthKey)) {
          rollups[monthKey] = {'sales': 0.0, 'profit': 0.0, 'fuel': 0.0};
        }
        
        final fuel = double.tryParse(row['fuelCostEstimate']?.toString() ?? '0') ?? 0.0;
        rollups[monthKey]!['fuel'] = rollups[monthKey]!['fuel']! + fuel;
      }

      // 3. บันทึกข้อมูล Rollup ลงตาราง historical_summary
      for (var entry in rollups.entries) {
        final month = entry.key;
        final sales = entry.value['sales']!;
        final profit = entry.value['profit']!;
        final fuel = entry.value['fuel']!;
        
        await _db.execute('''
          INSERT INTO historical_summary (summaryMonth, totalSales, totalProfit, totalFuelCost)
          VALUES (:month, :sales, :profit, :fuel)
          ON DUPLICATE KEY UPDATE 
            totalSales = totalSales + VALUES(totalSales),
            totalProfit = totalProfit + VALUES(totalProfit),
            totalFuelCost = totalFuelCost + VALUES(totalFuelCost)
        ''', {
          'month': month,
          'sales': sales,
          'profit': profit,
          'fuel': fuel
        });
      }

      // 4. ลบข้อมูลดิบเก่าทิ้งเพื่อคืนพื้นที่
      // ลบรายการสินค้าย่อยก่อน (เพื่อป้องกัน Foreign Key error)
      await _db.execute('''
        DELETE FROM order_item 
        WHERE orderId IN (SELECT id FROM `order` WHERE createdAt < :date)
      ''', {'date': tenYearsAgoStr});

      // ลบบิลหลัก
      await _db.execute('''
        DELETE FROM `order` WHERE createdAt < :date
      ''', {'date': tenYearsAgoStr});

      // ลบประวัติจัดส่ง
      await _db.execute('''
        DELETE FROM delivery_history WHERE completedAt < :date OR createdAt < :date
      ''', {'date': tenYearsAgoStr});

      debugPrint('✅ [DataArchivingService] Archiving and cleanup completed successfully.');
    } catch (e) {
      debugPrint('⚠️ [DataArchivingService] Error archiving old data: $e');
    }
  }
}
