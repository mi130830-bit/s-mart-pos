// [CRITICAL FIX] File: held_bill_manager.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:decimal/decimal.dart';
import '../mysql_service.dart';
import '../../models/order_item.dart';
import '../../models/customer.dart';
// import '../repositories/stock_repository.dart'; // ❌ ไม่ต้องใช้แล้ว

class HeldBill {
  final int? id;
  final DateTime timestamp;
  final Customer? customer;
  final List<OrderItem> items;
  final String note;

  HeldBill({
    this.id,
    required this.timestamp,
    this.customer,
    required this.items,
    this.note = '',
  });

  double get total => items
      .fold<Decimal>(Decimal.zero, (sum, item) => sum + item.total)
      .toDouble();
}

class HeldBillManager {
  final MySQLService _dbService;
  // final StockRepository _stockRepo; // ❌ ไม่ต้องใช้แล้ว

  HeldBillManager({MySQLService? dbService})
      : _dbService = dbService ?? MySQLService();

  Future<List<HeldBill>> loadHeldBills({int limit = 50}) async {
    try {
      if (!_dbService.isConnected()) {
        try {
          await _dbService.connect();
        } catch (e) {
          debugPrint('Error connecting DB in loadHeldBills: $e');
          return [];
        }
      }

      // ✅ Optimized: Limit results to prevent freeze
      final sql = '''
        SELECT h.id, h.createdAt, h.itemsJson, h.note, h.customerId,
               c.id as c_id, c.memberCode, c.firstName, c.lastName, c.phone, c.address, c.currentPoints
        FROM held_bills h
        LEFT JOIN customer c ON h.customerId = c.id
        ORDER BY h.createdAt DESC
        LIMIT :limit
      ''';

      final results = await _dbService.query(sql, {'limit': limit});

      // ... (rest of parsing logic is same)

      List<HeldBill> loadedBills = [];
      for (var row in results) {
        try {
          // Validate JSON
          final itemsRaw = row['itemsJson'];
          if (itemsRaw == null || itemsRaw.toString().isEmpty) {
            debugPrint(
                'Skipping HeldBill ID ${row['id']}: itemsJson is empty/null');
            continue;
          }

          final String itemsJson = itemsRaw.toString();
          final List<dynamic> itemsDecoded = jsonDecode(itemsJson);
          final List<OrderItem> items =
              itemsDecoded.map((i) => OrderItem.fromJson(i)).toList();

          Customer? customer;
          if (row['customerId'] != null && row['c_id'] != null) {
            // Reconstruct customer from JOIN result
            customer = Customer(
              id: int.tryParse(row['c_id'].toString()) ?? 0,
              memberCode: row['memberCode']?.toString() ?? '',
              firstName: row['firstName']?.toString() ?? '',
              lastName: row['lastName']?.toString(),
              phone: row['phone']?.toString(),
              address: row['address']?.toString(),
              currentPoints: int.tryParse(row['currentPoints'].toString()) ?? 0,
            );
          }

          loadedBills.add(HeldBill(
            id: int.tryParse(row['id'].toString()) ?? 0,
            timestamp: row['createdAt'] is DateTime
                ? row['createdAt'] as DateTime
                : DateTime.tryParse(row['createdAt'].toString()) ??
                    DateTime.now(),
            customer: customer,
            items: items,
            note: row['note']?.toString() ?? '',
          ));
        } catch (innerError) {
          debugPrint('Error parsing HeldBill ID ${row['id']}: $innerError');
          // Continue to next bill
        }
      }
      return loadedBills;
    } catch (e) {
      debugPrint('Error loading held bills (Connection/Query): $e');
      return [];
    }
  }

  Future<void> holdBill({
    required List<OrderItem> cart,
    required Customer? currentCustomer,
    String note = '',
  }) async {
    if (cart.isEmpty) return;
    try {
      if (!_dbService.isConnected()) await _dbService.connect();
      final String itemsJson =
          jsonEncode(cart.map((item) => item.toJson()).toList());
      await _dbService.execute(
          'INSERT INTO held_bills (customerId, itemsJson, note, createdAt) VALUES (:cid, :json, :note, NOW())',
          {
            'cid': currentCustomer?.id,
            'json': itemsJson,
            'note': note,
          });
      // ✅ [Fix Method A] Not calling stock repo here anymore.
    } catch (e) {
      debugPrint('Error holding bill: $e');
      rethrow;
    }
  }

  Future<void> deleteHeldBill(HeldBill bill) async {
    if (bill.id != null) {
      try {
        if (!_dbService.isConnected()) await _dbService.connect();

        // ❌ [Fix Method A] REMOVED Loop return stock
        // for (var item in bill.items) { ... }

        // Just delete the record
        await _dbService
            .execute('DELETE FROM held_bills WHERE id = :id', {'id': bill.id});
      } catch (e) {
        debugPrint('Error deleting held bill: $e');
      }
    }
  }

  Future<void> removeBillRecord(int id) async {
    try {
      if (!_dbService.isConnected()) await _dbService.connect();
      await _dbService
          .execute('DELETE FROM held_bills WHERE id = :id', {'id': id});
    } catch (e) {
      debugPrint('Error removing held bill record: $e');
    }
  }

  /// Clears held bills older than [days] days
  Future<int> clearOldHeldBills(int days) async {
    try {
      if (!_dbService.isConnected()) await _dbService.connect();

      // Calculate cutoff date
      // We use SQL interval logic or Dart calculation? Standard SQL is safer.
      // But MySQL Client param binding for Interval might be tricky.
      // Easiest is to calculate DateTime in Dart.
      final cutoff = DateTime.now().subtract(Duration(days: days));

      final result = await _dbService.execute(
        'DELETE FROM held_bills WHERE createdAt < :cutoff',
        {'cutoff': cutoff.toIso8601String()},
      );

      return result.affectedRows.toInt();
    } catch (e) {
      debugPrint('Error clearing old held bills: $e');
      return 0;
    }
  }

  /// Clear all held bills
  Future<void> clearAll() async {
    try {
      if (!_dbService.isConnected()) await _dbService.connect();
      await _dbService.execute('DELETE FROM held_bills');
    } catch (e) {
      debugPrint('Error clearing all held bills: $e');
    }
  }
}
