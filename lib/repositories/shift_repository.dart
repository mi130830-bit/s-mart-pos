import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';

class ShiftSummary {
  final int? id;
  final DateTime openedAt;
  final DateTime closedAt;
  final String? closedBy;
  final double openingCash;
  final double expectedCash;
  final double actualCash;
  final double difference;
  final double totalSales;
  final double totalCash;
  final double totalTransfer;
  final double totalCredit;
  final double expenseAmount;
  final String note;

  ShiftSummary({
    this.id,
    required this.openedAt,
    required this.closedAt,
    this.closedBy,
    required this.openingCash,
    required this.expectedCash,
    required this.actualCash,
    required this.difference,
    required this.totalSales,
    required this.totalCash,
    required this.totalTransfer,
    required this.totalCredit,
    required this.expenseAmount,
    this.note = '',
  });
}

class ShiftRepository {
  final MySQLService _db = MySQLService();

  /// ดึงข้อมูลการปิดกะล่าสุด (ถ้าไม่มีให้คืนค่าเป็นต้นวันหรือ null)
  Future<DateTime?> getLastShiftClosingTime() async {
    if (!_db.isConnected()) await _db.connect();
    
    try {
      final res = await _db.query('SELECT closedAt FROM shift_summary ORDER BY closedAt DESC LIMIT 1');
      if (res.isNotEmpty) {
        return DateTime.parse(res.first['closedAt'].toString());
      }
    } catch (e) {
      debugPrint('Error getting last shift closing time: $e');
    }
    
    // ถ้าไม่มีให้คืนค่า start of day ของวันนี้
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 0, 0, 0);
  }

  /// คำนวณรายรับทั้งหมดตั้งแต่เวลาที่เปิดกะ (หรือหลังจากกะล่าสุด)
  Future<Map<String, double>> getShiftTotals(DateTime start) async {
    if (!_db.isConnected()) await _db.connect();

    double totalSales = 0.0;
    double totalCash = 0.0;
    double totalTransfer = 0.0;
    double totalCredit = 0.0;
    
    // 1. ดึงข้อมูลจากตาราง order
    try {
      final orderRes = await _db.query(
        '''
        SELECT grandTotal, paymentMethod 
        FROM `order` 
        WHERE createdAt >= :start AND status IN ('COMPLETED', 'UNPAID')
        ''',
        {'start': start.toIso8601String()}
      );
      
      for (var row in orderRes) {
        double amount = double.tryParse(row['grandTotal'].toString()) ?? 0.0;
        String method = row['paymentMethod'].toString().toUpperCase();
        
        // UNPAID หรือ 'CREDIT' คือขายเชื่อ
        if (method == 'CREDIT' || method == 'UNPAID') {
          totalCredit += amount;
          totalSales += amount; // รวมเป็นยอดขาย
        } else if (method == 'CASH') {
          totalCash += amount;
          totalSales += amount;
        } else {
          // หากเป็น QR, TRANSFER, CARD ให้ปัดเป็น Transfer หมด
          totalTransfer += amount;
          totalSales += amount;
        }
      }
    } catch (e) {
      debugPrint('Error calculating shift order totals: $e');
    }

    // 2. ดึงข้อมูลจากตารางชำระหนี้ (debtor_transaction)
    // การรับชำระหนี้จะถือเป็นการรับเงินสดเข้าลิ้นชัก (แต่ไม่นับเป็นยอดขายซ้ำ)
    try {
      final debtRes = await _db.query(
        '''
        SELECT amount
        FROM debtor_transaction
        WHERE createdAt >= :start 
          AND transactionType = 'DEBT_PAYMENT' 
          AND (isDeleted = 0 OR isDeleted IS NULL)
        ''',
        {'start': start.toIso8601String()}
      );
      
      for (var row in debtRes) {
        double amount = (double.tryParse(row['amount'].toString()) ?? 0.0).abs();
        totalCash += amount; // การจ่ายหนี้มักจะเป็นเงินสด ถ้าให้แน่นอนสามารถแยกตารางได้ แต่ปกติโอน/สด จะเข้ามาลิ้นชัก
      }
    } catch (e) {
      debugPrint('Error calculating shift debt totals: $e');
    }

    return {
      'totalSales': totalSales,
      'totalCash': totalCash,
      'totalTransfer': totalTransfer,
      'totalCredit': totalCredit,
    };
  }

  /// บันทึกข้อมูลปิดกะใหม่ลงตาราง shift_summary
  Future<bool> closeShift(ShiftSummary summary) async {
    if (!_db.isConnected()) await _db.connect();

    try {
      const sql = '''
        INSERT INTO shift_summary (
          openedAt, closedAt, closedBy, 
          openingCash, expectedCash, actualCash, difference, 
          totalSales, totalCash, totalTransfer, totalCredit, 
          expenseAmount, note, createdAt
        ) VALUES (
          :openedAt, :closedAt, :closedBy,
          :openingCash, :expectedCash, :actualCash, :difference,
          :totalSales, :totalCash, :totalTransfer, :totalCredit,
          :expenseAmount, :note, NOW()
        )
      ''';
      
      await _db.execute(sql, {
        'openedAt': summary.openedAt.toIso8601String(),
        'closedAt': summary.closedAt.toIso8601String(),
        'closedBy': summary.closedBy, // User ID or null
        'openingCash': summary.openingCash,
        'expectedCash': summary.expectedCash,
        'actualCash': summary.actualCash,
        'difference': summary.difference,
        'totalSales': summary.totalSales,
        'totalCash': summary.totalCash,
        'totalTransfer': summary.totalTransfer,
        'totalCredit': summary.totalCredit,
        'expenseAmount': summary.expenseAmount,
        'note': summary.note,
      });
      return true;
    } catch (e) {
      debugPrint('Error closing shift: $e');
      return false;
    }
  }
}
