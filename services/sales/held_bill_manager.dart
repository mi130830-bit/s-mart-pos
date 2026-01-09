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

  Future<List<HeldBill>> loadHeldBills() async {
    try {
      if (!_dbService.isConnected()) await _dbService.connect();
      final results = await _dbService
          .query('SELECT * FROM held_bills ORDER BY createdAt DESC');

      List<HeldBill> loadedBills = [];
      for (var row in results) {
        final itemsJson = row['itemsJson'] as String;
        final List<dynamic> itemsDecoded = jsonDecode(itemsJson);
        final List<OrderItem> items =
            itemsDecoded.map((i) => OrderItem.fromJson(i)).toList();

        Customer? customer;
        if (row['customerId'] != null) {
          final custRes = await _dbService.query(
              'SELECT * FROM customer WHERE id = :id',
              {'id': row['customerId']});
          if (custRes.isNotEmpty) {
            customer = Customer.fromJson(custRes.first);
          }
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
      }
      return loadedBills;
    } catch (e) {
      debugPrint('Error loading held bills: $e');
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
}
