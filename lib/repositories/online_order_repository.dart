import 'dart:async';
import '../models/online_order_model.dart';
import '../services/mysql_service.dart';
import '../services/logger_service.dart';

class OnlineOrderTransitionRules {
  static const Set<String> _statuses = {
    'PENDING',
    'CONFIRMED',
    'PREPARING',
    'READY',
    'DISPATCHED',
    'SHIPPING',
    'PAID',
    'COMPLETED',
    'CANCELLED',
    'REJECTED',
  };
  static const Map<String, Set<String>> _allowed = {
    'PENDING': {'CONFIRMED', 'COMPLETED', 'CANCELLED', 'REJECTED'},
    'CONFIRMED': {
      'PREPARING',
      'DISPATCHED',
      'COMPLETED',
      'CANCELLED',
      'REJECTED'
    },
    'PREPARING': {'READY', 'DISPATCHED', 'COMPLETED', 'CANCELLED'},
    'READY': {'DISPATCHED', 'COMPLETED', 'CANCELLED'},
    'DISPATCHED': {'SHIPPING', 'COMPLETED', 'CANCELLED'},
    'SHIPPING': {'COMPLETED', 'CANCELLED'},
    'PAID': {'COMPLETED', 'CANCELLED'},
  };

  static bool canTransition(String current, String target) {
    final from = current.trim().toUpperCase();
    final to = target.trim().toUpperCase();
    if (!_statuses.contains(from) || !_statuses.contains(to)) return false;
    if (from == to) return true;
    return _allowed[from]?.contains(to) ?? false;
  }
}

class OnlineOrderRepository {
  final MySQLService _db = MySQLService();

  Future<void> _ensureTable() async {
    try {
      await _db.execute('''
        CREATE TABLE IF NOT EXISTS online_orders (
          id INT AUTO_INCREMENT PRIMARY KEY,
          orderNumber VARCHAR(50) NOT NULL,
          customerId INT NULL,
          customerName VARCHAR(255) NOT NULL,
          customerPhone VARCHAR(50) NOT NULL,
          lineUserId VARCHAR(100) NULL,
          lineDisplayName VARCHAR(255) NULL,
          deliveryType VARCHAR(20) NOT NULL DEFAULT 'pickup',
          deliveryAddress TEXT NULL,
          gpsLocation VARCHAR(255) NULL,
          distanceKm DOUBLE NOT NULL DEFAULT 0,
          deliveryFee DOUBLE NOT NULL DEFAULT 0,
          totalAmount DOUBLE NOT NULL DEFAULT 0,
          grandTotal DOUBLE NOT NULL DEFAULT 0,
          itemsJson LONGTEXT NOT NULL,
          notes TEXT NULL,
          status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
          confirmedBy VARCHAR(100) NULL,
          couponCode VARCHAR(20) NULL,
          couponDiscount DECIMAL(12,2) NULL,
          couponReservedUntil DATETIME NULL,
          posOrderId INT NULL,
          createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          INDEX idx_status (status),
          INDEX idx_created (createdAt)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
      ''');
    } catch (e) {
      LoggerService.error('OnlineOrderRepo', 'Ensure table error: $e');
    }
  }

  Future<List<OnlineOrder>> getOrders({String? status, int limit = 50}) async {
    await _ensureTable();
    try {
      final supportsReservation = await _supportsCouponReservation();
      String sql = supportsReservation
          ? '''SELECT o.*, rc.status AS couponReservationStatus
               FROM online_orders o
               LEFT JOIN reward_coupon rc
                 ON rc.reserved_online_order_id = o.id
                AND rc.coupon_code = o.couponCode
               WHERE 1=1'''
          : 'SELECT o.* FROM online_orders o WHERE 1=1';
      Map<String, dynamic> params = {'limit': limit.clamp(1, 200)};

      if (status != null && status.isNotEmpty && status != 'ALL') {
        sql += ' AND o.status = :status';
        params['status'] = status;
      }
      sql += ' ORDER BY o.id DESC LIMIT :limit';

      final rows = await _db.query(sql, params);
      return rows.map((r) => OnlineOrder.fromJson(r)).toList();
    } catch (e) {
      LoggerService.error('OnlineOrderRepo', 'Failed to fetch orders: $e');
      return [];
    }
  }

  Future<int> getPendingCount() async {
    await _ensureTable();
    try {
      final rows = await _db.query(
        "SELECT COUNT(*) as cnt FROM online_orders WHERE status = 'PENDING'",
      );
      if (rows.isNotEmpty) {
        return int.tryParse(rows.first['cnt']?.toString() ?? '0') ?? 0;
      }
    } catch (e) {
      LoggerService.error('OnlineOrderRepo', 'Failed to get pending count: $e');
    }
    return 0;
  }

  Future<bool> updateStatus(int orderId, String newStatus,
      {String? staffName}) async {
    await _ensureTable();
    try {
      final target = newStatus.trim().toUpperCase();
      return await _db.runExclusiveTransaction(() async {
        await _db.execute('START TRANSACTION');
        try {
          final rows = await _db.query(
            'SELECT status FROM online_orders WHERE id = :id FOR UPDATE',
            {'id': orderId},
          );
          if (rows.isEmpty ||
              !OnlineOrderTransitionRules.canTransition(
                  rows.first['status']?.toString() ?? '', target)) {
            throw StateError('ไม่สามารถเปลี่ยนสถานะออเดอร์ตามลำดับนี้ได้');
          }
          await _db.execute(
            '''UPDATE online_orders
               SET status = :status, confirmedBy = :by, updatedAt = NOW()
               WHERE id = :id''',
            {
              'status': target,
              'by': staffName ?? 'Staff',
              'id': orderId,
            },
          );
          if ((target == 'CANCELLED' || target == 'REJECTED') &&
              await _supportsCouponReservation()) {
            await _db.execute(
              '''UPDATE reward_coupon
                 SET status = CASE WHEN expires_at > NOW()
                                   THEN 'ACTIVE' ELSE 'EXPIRED' END,
                     reserved_online_order_id = NULL,
                     reserved_until = NULL
                 WHERE reserved_online_order_id = :id
                   AND status = 'RESERVED' ''',
              {'id': orderId},
            );
          }
          await _db.execute('COMMIT');
          return true;
        } catch (_) {
          await _db.execute('ROLLBACK');
          rethrow;
        }
      });
    } catch (e) {
      LoggerService.error(
          'OnlineOrderRepo', 'Failed to update order status: $e');
      return false;
    }
  }

  Future<bool> _supportsCouponReservation() async {
    final rows = await _db.query('''
      SELECT COUNT(*) AS count
      FROM information_schema.columns
      WHERE table_schema = DATABASE()
        AND table_name = 'reward_coupon'
        AND column_name IN ('reserved_online_order_id', 'reserved_until')
    ''');
    return int.tryParse(rows.first['count']?.toString() ?? '0') == 2;
  }
}
