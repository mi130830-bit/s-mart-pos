import 'package:flutter/foundation.dart';
import '../mysql_service.dart';

class CleanDatabaseService {
  final MySQLService _db = MySQLService();

  // --------------------------------------------------------------------------
  // 1. ล้างข้อมูลทั้งหมด (Clear All Data)
  // --------------------------------------------------------------------------
  Future<void> clearAllData() async {
    try {
      if (!_db.isConnected()) await _db.connect();

      try {
        await _db.execute('SET FOREIGN_KEY_CHECKS = 0;');
      } catch (_) {}

      final tablesInOrder = [
        'billing_note_items',
        'order_payment',
        'stockledger',
        'orderitem',
        'delivery_jobs',
        'debtor_transaction',
        'customer_ledger',
        'purchase_order_item',
        'activity_log',
        'held_bills',
        'billing_notes',
        '`order`',
        'purchase_order',
        'product_barcode',
        'product',
        'customer',
        'supplier',
        'expense',
        'category',
        'unit'
      ];

      for (var t in tablesInOrder) {
        try {
          await _db.execute('DELETE FROM $t');
          try {
            await _db.execute('ALTER TABLE $t AUTO_INCREMENT = 1');
          } catch (_) {}
        } catch (e) {
          debugPrint('⚠️ Warning clearing table $t: $e');
        }
      }

      debugPrint('✅ All data cleared successfully.');
    } catch (e) {
      debugPrint('❌ Critical Error clearAllData: $e');
      rethrow;
    } finally {
      try {
        await _db.execute('SET FOREIGN_KEY_CHECKS = 1;');
      } catch (_) {}
    }
  }

  // --------------------------------------------------------------------------
  // 2. ลบรายการขาย (ORDERS) - แบบ Batch (ทีละชุด)
  // --------------------------------------------------------------------------

  // 2.1 ฟังก์ชันหลัก: รับ List ID แล้วลบ
  Future<int> deleteSelectedOrders(List<int> ids) async {
    if (ids.isEmpty) return 0;
    int count = 0;

    try {
      if (!_db.isConnected()) await _db.connect();
      try {
        await _db.execute('SET FOREIGN_KEY_CHECKS = 0;');
      } catch (_) {}

      int chunkSize = 50; // ลบทีละ 50 รายการ
      for (var i = 0; i < ids.length; i += chunkSize) {
        List<int> chunk = ids.sublist(
            i, (i + chunkSize < ids.length) ? i + chunkSize : ids.length);

        if (chunk.isEmpty) continue;
        String idsString = "(${chunk.join(',')})";

        try {
          debugPrint('🗑️ Deleting chunk of ${chunk.length} orders...');

          // ลบตารางลูก
          try {
            await _db.execute(
                'DELETE FROM delivery_jobs WHERE orderId IN $idsString');
          } catch (_) {}
          try {
            await _db
                .execute('DELETE FROM orderitem WHERE orderId IN $idsString');
          } catch (_) {}
          try {
            await _db
                .execute('DELETE FROM stockledger WHERE orderId IN $idsString');
          } catch (_) {}
          try {
            await _db.execute(
                'DELETE FROM customer_ledger WHERE orderId IN $idsString');
          } catch (_) {}
          try {
            await _db.execute(
                'DELETE FROM order_payment WHERE orderId IN $idsString');
          } catch (_) {}
          try {
            await _db.execute(
                'DELETE FROM debtor_transaction WHERE orderId IN $idsString');
          } catch (_) {}

          // ลบตารางแม่
          final res =
              await _db.execute('DELETE FROM `order` WHERE id IN $idsString');
          count += int.parse(res.affectedRows.toString());
        } catch (e) {
          debugPrint('⚠️ Error deleting chunk: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error deleteSelectedOrders: $e');
      rethrow;
    } finally {
      try {
        await _db.execute('SET FOREIGN_KEY_CHECKS = 1;');
      } catch (_) {}
    }
    return count;
  }

  // 2.2 ฟังก์ชันหา ID ตามวันที่ แล้วส่งไปลบ (Legacy Support)
  Future<int> deleteOldSales(DateTime olderThan, {bool isAll = false}) async {
    try {
      if (!_db.isConnected()) await _db.connect();

      String sql = isAll
          ? 'SELECT id FROM `order`'
          : 'SELECT id FROM `order` WHERE DATE(createdAt) <= :date';

      final dateStr = olderThan.toIso8601String().substring(0, 10);
      final results = await _db.query(sql, isAll ? null : {'date': dateStr});

      if (results.isEmpty) return 0;

      List<int> ids =
          results.map((r) => int.parse(r['id'].toString())).toList();
      return await deleteSelectedOrders(ids);
    } catch (e) {
      debugPrint('Error getting old sales: $e');
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // 3. ลบใบวางบิล (BILLING NOTES) - แบบ Batch (แก้ Error ตรงนี้)
  // --------------------------------------------------------------------------

  // 3.1 ฟังก์ชันหลัก: รับ List ID ใบวางบิล แล้วลบ
  Future<int> deleteSelectedBillings(List<int> ids) async {
    if (ids.isEmpty) return 0;
    int count = 0;

    try {
      if (!_db.isConnected()) await _db.connect();
      try {
        await _db.execute('SET FOREIGN_KEY_CHECKS = 0;');
      } catch (_) {}

      int chunkSize = 50;
      for (var i = 0; i < ids.length; i += chunkSize) {
        List<int> chunk = ids.sublist(
            i, (i + chunkSize < ids.length) ? i + chunkSize : ids.length);

        if (chunk.isEmpty) continue;
        String idsString = "(${chunk.join(',')})";

        try {
          // ลบรายการในใบวางบิล
          await _db.execute(
              'DELETE FROM billing_note_items WHERE billingNoteId IN $idsString');

          // ลบหัวใบวางบิล
          final res = await _db
              .execute('DELETE FROM billing_notes WHERE id IN $idsString');
          count += int.parse(res.affectedRows.toString());
        } catch (e) {
          debugPrint('⚠️ Error deleting billing chunk: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error deleteSelectedBillings: $e');
      rethrow;
    } finally {
      try {
        await _db.execute('SET FOREIGN_KEY_CHECKS = 1;');
      } catch (_) {}
    }
    return count;
  }

  // 3.2 ฟังก์ชันหา ID ใบวางบิลตามวันที่ (Legacy Support - แก้ Error ที่เรียกหาตัวนี้)
  Future<int> deleteOldBilling(DateTime olderThan, {bool isAll = false}) async {
    try {
      if (!_db.isConnected()) await _db.connect();

      String sql = isAll
          ? 'SELECT id FROM billing_notes'
          : 'SELECT id FROM billing_notes WHERE DATE(issueDate) <= :date';

      final dateStr = olderThan.toIso8601String().substring(0, 10);
      final results = await _db.query(sql, isAll ? null : {'date': dateStr});

      if (results.isEmpty) return 0;

      List<int> ids =
          results.map((r) => int.parse(r['id'].toString())).toList();
      return await deleteSelectedBillings(ids);
    } catch (e) {
      debugPrint('Error getting old billing: $e');
      rethrow;
    }
  }
}
