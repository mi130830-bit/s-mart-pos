import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../services/mysql_service.dart';

class DeliveryHistoryRepository {
  final MySQLService _db;

  DeliveryHistoryRepository({MySQLService? db}) : _db = db ?? MySQLService();

  Future<void> initTable() async {
    try {
      await _db.execute('''
        CREATE TABLE IF NOT EXISTS delivery_history (
          id INT AUTO_INCREMENT PRIMARY KEY,
          orderId INT NOT NULL DEFAULT 0,
          firebaseJobId VARCHAR(255) NULL,
          driverName VARCHAR(255) NULL,
          vehiclePlate VARCHAR(100) NULL,
          customerName VARCHAR(255) NULL,
          customerAddress TEXT NULL,
          customerPhone VARCHAR(50) NULL,
          totalAmount DECIMAL(15,2) DEFAULT 0.00,
          status VARCHAR(50) DEFAULT 'COMPLETED',
          jobType VARCHAR(50) DEFAULT 'delivery',
          note TEXT NULL,
          locationUrl TEXT NULL,
          billImageUrl TEXT NULL,
          destinationLat DECIMAL(10,7) NULL,
          destinationLng DECIMAL(10,7) NULL,
          distanceKm DECIMAL(8,2) DEFAULT 0.0,
          fuelCostEstimate DECIMAL(10,2) DEFAULT 0.0,
          createdAt DATETIME NULL,
          completedAt DATETIME NULL,
          INDEX idx_delivery_history_order (orderId),
          INDEX idx_delivery_history_date (completedAt),
          INDEX idx_delivery_history_vehicle (vehiclePlate),
          INDEX idx_delivery_history_firebase (firebaseJobId)
        )
      ''');

      // Attempt schema upgrades for existing tables
      try { await _db.execute('ALTER TABLE delivery_history ADD COLUMN locationUrl TEXT NULL'); } catch (_) {}
      try { await _db.execute('ALTER TABLE delivery_history ADD COLUMN customerPhone VARCHAR(50) NULL'); } catch (_) {}
      try { await _db.execute('ALTER TABLE delivery_history ADD COLUMN distanceKm DECIMAL(8,2) DEFAULT 0.0'); } catch (_) {}
      try { await _db.execute('ALTER TABLE delivery_history ADD COLUMN fuelCostEstimate DECIMAL(10,2) DEFAULT 0.0'); } catch (_) {}
      // ✅ New columns for full data capture from S-Link
      try { await _db.execute('ALTER TABLE delivery_history ADD COLUMN billImageUrl TEXT NULL'); } catch (_) {}
      try { await _db.execute('ALTER TABLE delivery_history ADD COLUMN destinationLat DECIMAL(10,7) NULL'); } catch (_) {}
      try { await _db.execute('ALTER TABLE delivery_history ADD COLUMN destinationLng DECIMAL(10,7) NULL'); } catch (_) {}

      debugPrint('✅ [DeliveryHistoryRepository] Table initialized.');
    } catch (e) {
      debugPrint('⚠️ [DeliveryHistoryRepository] Init table error: $e');
    }
  }

  // ✅ Check duplicate by Firebase Job ID before inserting
  Future<bool> existsByFirebaseId(String firebaseJobId) async {
    try {
      final res = await _db.query(
        'SELECT id FROM delivery_history WHERE firebaseJobId = :fid LIMIT 1',
        {'fid': firebaseJobId},
      );
      return res.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<int> archiveJob({
    required int orderId,
    String? firebaseJobId,
    String? driverName,
    String? vehiclePlate,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    required double totalAmount,
    required String status,
    required String jobType,
    String? note,
    String? locationUrl,
    String? billImageUrl,        // ✅ ลิ้งรูปใบเสร็จจาก S-Link
    double? destinationLat,     // ✅ GPS ปลายทาง (latitude)
    double? destinationLng,     // ✅ GPS ปลายทาง (longitude)
    double distanceKm = 0.0,
    double fuelCostEstimate = 0.0,
    DateTime? createdAt,
    DateTime? completedAt,
  }) async {
    try {
      // ✅ Update if already archived (Fixes missing distance/drivers from S-Link API inserts)
      if (firebaseJobId != null && firebaseJobId.isNotEmpty) {
        if (await existsByFirebaseId(firebaseJobId)) {
          debugPrint('🔄 [DeliveryHistoryRepository] Updating existing job: $firebaseJobId');
          final sqlUpdate = '''
            UPDATE delivery_history SET 
              driverName = :driver,
              vehiclePlate = :vehicle,
              locationUrl = :locUrl,
              billImageUrl = :billUrl,
              destinationLat = :destLat,
              destinationLng = :destLng,
              distanceKm = :dist,
              fuelCostEstimate = :fuel
            WHERE firebaseJobId = :fid
          ''';
          await _db.execute(sqlUpdate, {
            'driver': driverName,
            'vehicle': vehiclePlate,
            'locUrl': locationUrl,
            'billUrl': billImageUrl,
            'destLat': destinationLat,
            'destLng': destinationLng,
            'dist': distanceKm,
            'fuel': fuelCostEstimate,
            'fid': firebaseJobId,
          });
          return -1; // Already exists, but we updated it
        }
      }

      final sql = '''
        INSERT INTO delivery_history (
          orderId, firebaseJobId, driverName, vehiclePlate,
          customerName, customerPhone, customerAddress, totalAmount, status, jobType,
          note, locationUrl, billImageUrl, destinationLat, destinationLng,
          distanceKm, fuelCostEstimate, createdAt, completedAt
        ) VALUES (
          :oid, :fid, :driver, :vehicle,
          :cname, :cphone, :caddr, :total, :status, :jtype,
          :note, :locUrl, :billUrl, :destLat, :destLng,
          :dist, :fuel, :cat, :comp
        )
      ''';

      final res = await _db.execute(sql, {
        'oid': orderId,
        'fid': firebaseJobId,
        'driver': driverName,
        'vehicle': vehiclePlate,
        'cname': customerName,
        'cphone': customerPhone,
        'caddr': customerAddress,
        'total': totalAmount,
        'status': status,
        'jtype': jobType,
        'note': note,
        'locUrl': locationUrl,
        'billUrl': billImageUrl,
        'destLat': destinationLat,
        'destLng': destinationLng,
        'dist': distanceKm,
        'fuel': fuelCostEstimate,
        'cat': createdAt != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(createdAt) : null,
        'comp': completedAt != null
            ? DateFormat('yyyy-MM-dd HH:mm:ss').format(completedAt)
            : DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      });

      return res.lastInsertID.toInt();
    } catch (e) {
      debugPrint('⚠️ [DeliveryHistoryRepository] Archive error: $e');
      return 0;
    }
  }

  // ✅ Get delivery records in date range
  Future<List<Map<String, dynamic>>> getHistoryByDateRange(
      DateTime start, DateTime end) async {
    try {
      final sql = '''
        SELECT 
          dh.id, dh.orderId, dh.firebaseJobId, dh.driverName, dh.vehiclePlate,
          dh.customerName, dh.customerPhone, dh.customerAddress, dh.totalAmount,
          dh.status, dh.jobType, dh.note, dh.locationUrl, dh.billImageUrl,
          dh.destinationLat, dh.destinationLng, dh.fuelCostEstimate, dh.createdAt, dh.completedAt,
          IF(dh.distanceKm > 0, dh.distanceKm, COALESCE(c.distanceKm, 0.0)) as distanceKm
        FROM delivery_history dh
        LEFT JOIN `order` o ON o.id = dh.orderId
        LEFT JOIN customer c ON c.id = o.customerId
        WHERE dh.completedAt >= :start AND dh.completedAt <= :end
        ORDER BY dh.completedAt DESC
      ''';

      final res = await _db.query(sql, {
        'start': DateFormat('yyyy-MM-dd HH:mm:ss').format(start),
        'end': DateFormat('yyyy-MM-dd HH:mm:ss').format(end),
      });

      return res.toList();
    } catch (e) {
      debugPrint('⚠️ [DeliveryHistoryRepository] Query error: $e');
      return [];
    }
  }

  // ✅ Get stats (count & total amount) for a date range
  Future<Map<String, dynamic>> getStats(DateTime start, DateTime end) async {
    try {
      final sql = '''
        SELECT 
          COUNT(*) as jobCount,
          COALESCE(SUM(totalAmount), 0) as totalAmount
        FROM delivery_history
        WHERE completedAt >= :start AND completedAt <= :end
          AND status != 'cancelled'
      ''';

      final res = await _db.query(sql, {
        'start': DateFormat('yyyy-MM-dd HH:mm:ss').format(start),
        'end': DateFormat('yyyy-MM-dd HH:mm:ss').format(end),
      });

      if (res.isEmpty) return {'jobCount': 0, 'totalAmount': 0.0};
      final row = res.first;
      return {
        'jobCount': int.tryParse(row['jobCount'].toString()) ?? 0,
        'totalAmount': double.tryParse(row['totalAmount'].toString()) ?? 0.0,
      };
    } catch (e) {
      debugPrint('⚠️ [DeliveryHistoryRepository] Stats error: $e');
      return {'jobCount': 0, 'totalAmount': 0.0};
    }
  }

  // ✅ Get distinct vehicle plates used in date range
  Future<List<String>> getDistinctVehicles(DateTime start, DateTime end) async {
    try {
      final sql = '''
        SELECT DISTINCT vehiclePlate FROM delivery_history
        WHERE completedAt >= :start AND completedAt <= :end
          AND vehiclePlate IS NOT NULL AND vehiclePlate != ''
        ORDER BY vehiclePlate
      ''';

      final res = await _db.query(sql, {
        'start': DateFormat('yyyy-MM-dd HH:mm:ss').format(start),
        'end': DateFormat('yyyy-MM-dd HH:mm:ss').format(end),
      });

      return res.map((r) => r['vehiclePlate'].toString()).toList();
    } catch (e) {
      debugPrint('⚠️ [DeliveryHistoryRepository] Vehicle query error: $e');
      return [];
    }
  }

  // ✅ Get history filtered by vehicle plate
  Future<List<Map<String, dynamic>>> getHistoryByVehicle(
      DateTime start, DateTime end, String? vehiclePlate) async {
    try {
      String sql;
      Map<String, dynamic> params;

      if (vehiclePlate == null || vehiclePlate.isEmpty) {
        // All vehicles
        sql = '''
          SELECT 
            dh.id, dh.orderId, dh.firebaseJobId, dh.driverName, dh.vehiclePlate,
            dh.customerName, dh.customerPhone, dh.customerAddress, dh.totalAmount,
            dh.status, dh.jobType, dh.note, dh.locationUrl, dh.billImageUrl,
            dh.destinationLat, dh.destinationLng, dh.fuelCostEstimate, dh.createdAt, dh.completedAt,
            IF(dh.distanceKm > 0, dh.distanceKm, COALESCE(c.distanceKm, 0.0)) as distanceKm
          FROM delivery_history dh
          LEFT JOIN `order` o ON o.id = dh.orderId
          LEFT JOIN customer c ON c.id = o.customerId
          WHERE dh.completedAt >= :start AND dh.completedAt <= :end
          ORDER BY dh.completedAt DESC
        ''';
        params = {
          'start': DateFormat('yyyy-MM-dd HH:mm:ss').format(start),
          'end': DateFormat('yyyy-MM-dd HH:mm:ss').format(end),
        };
      } else {
        sql = '''
          SELECT 
            dh.id, dh.orderId, dh.firebaseJobId, dh.driverName, dh.vehiclePlate,
            dh.customerName, dh.customerPhone, dh.customerAddress, dh.totalAmount,
            dh.status, dh.jobType, dh.note, dh.locationUrl, dh.billImageUrl,
            dh.destinationLat, dh.destinationLng, dh.fuelCostEstimate, dh.createdAt, dh.completedAt,
            IF(dh.distanceKm > 0, dh.distanceKm, COALESCE(c.distanceKm, 0.0)) as distanceKm
          FROM delivery_history dh
          LEFT JOIN `order` o ON o.id = dh.orderId
          LEFT JOIN customer c ON c.id = o.customerId
          WHERE dh.completedAt >= :start AND dh.completedAt <= :end
            AND dh.vehiclePlate = :vehicle
          ORDER BY dh.completedAt DESC
        ''';
        params = {
          'start': DateFormat('yyyy-MM-dd HH:mm:ss').format(start),
          'end': DateFormat('yyyy-MM-dd HH:mm:ss').format(end),
          'vehicle': vehiclePlate,
        };
      }

      final res = await _db.query(sql, params);
      return res.toList();
    } catch (e) {
      debugPrint('⚠️ [DeliveryHistoryRepository] Vehicle filter error: $e');
      return [];
    }
  }

  // ✅ Search by customer name / address
  Future<List<Map<String, dynamic>>> searchHistory(String keyword,
      {DateTime? start, DateTime? end}) async {
    try {
      final kw = '%$keyword%';
      String sql;
      Map<String, dynamic> params;

      if (start != null && end != null) {
        sql = '''
          SELECT 
            dh.id, dh.orderId, dh.firebaseJobId, dh.driverName, dh.vehiclePlate,
            dh.customerName, dh.customerPhone, dh.customerAddress, dh.totalAmount,
            dh.status, dh.jobType, dh.note, dh.locationUrl, dh.billImageUrl,
            dh.destinationLat, dh.destinationLng, dh.fuelCostEstimate, dh.createdAt, dh.completedAt,
            IF(dh.distanceKm > 0, dh.distanceKm, COALESCE(c.distanceKm, 0.0)) as distanceKm
          FROM delivery_history dh
          LEFT JOIN `order` o ON o.id = dh.orderId
          LEFT JOIN customer c ON c.id = o.customerId
          WHERE (dh.customerName LIKE :kw OR dh.customerAddress LIKE :kw OR dh.driverName LIKE :kw)
            AND dh.completedAt >= :start AND dh.completedAt <= :end
          ORDER BY dh.completedAt DESC
          LIMIT 200
        ''';
        params = {
          'kw': kw,
          'start': DateFormat('yyyy-MM-dd HH:mm:ss').format(start),
          'end': DateFormat('yyyy-MM-dd HH:mm:ss').format(end),
        };
      } else {
        sql = '''
          SELECT 
            dh.id, dh.orderId, dh.firebaseJobId, dh.driverName, dh.vehiclePlate,
            dh.customerName, dh.customerPhone, dh.customerAddress, dh.totalAmount,
            dh.status, dh.jobType, dh.note, dh.locationUrl, dh.billImageUrl,
            dh.destinationLat, dh.destinationLng, dh.fuelCostEstimate, dh.createdAt, dh.completedAt,
            IF(dh.distanceKm > 0, dh.distanceKm, COALESCE(c.distanceKm, 0.0)) as distanceKm
          FROM delivery_history dh
          LEFT JOIN `order` o ON o.id = dh.orderId
          LEFT JOIN customer c ON c.id = o.customerId
          WHERE dh.customerName LIKE :kw OR dh.customerAddress LIKE :kw OR dh.driverName LIKE :kw
          ORDER BY dh.completedAt DESC
          LIMIT 200
        ''';
        params = {'kw': kw};
      }

      final res = await _db.query(sql, params);
      return res.toList();
    } catch (e) {
      debugPrint('⚠️ [DeliveryHistoryRepository] Search error: $e');
      return [];
    }
  }

  // ✅ Get last N months of data for monthly stats
  Future<List<Map<String, dynamic>>> getMonthlyStats(int months) async {
    try {
      final sql = '''
        SELECT 
          DATE_FORMAT(completedAt, '%Y-%m') as month,
          COUNT(*) as jobCount,
          COALESCE(SUM(totalAmount), 0) as totalAmount,
          vehiclePlate
        FROM delivery_history
        WHERE completedAt >= DATE_SUB(NOW(), INTERVAL :months MONTH)
          AND status != 'cancelled'
        GROUP BY DATE_FORMAT(completedAt, '%Y-%m'), vehiclePlate
        ORDER BY month DESC
      ''';

      final res = await _db.query(sql, {'months': months});
      return res.toList();
    } catch (e) {
      debugPrint('⚠️ [DeliveryHistoryRepository] Monthly stats error: $e');
      return [];
    }
  }

  /// ✅ ย้อนหลัง: แยก GPS จาก locationUrl สำหรับ record เก่าที่ไม่มี destinationLat/Lng
  /// คืนค่าจำนวน record ที่อัปเดต
  Future<int> backfillDestinationCoords() async {
    try {
      final rows = await _db.query('''
        SELECT id, locationUrl
        FROM delivery_history
        WHERE destinationLat IS NULL
          AND locationUrl IS NOT NULL
          AND locationUrl LIKE '%?q=%'
        LIMIT 500
      ''');

      int updated = 0;
      for (final row in rows) {
        final id = row['id'];
        final url = row['locationUrl']?.toString() ?? '';
        if (!url.contains('?q=')) continue;

        final coordStr = url.split('?q=').last.split('&').first;
        final parts = coordStr.split(',');
        if (parts.length < 2) continue;

        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat == null || lng == null) continue;

        await _db.execute(
          'UPDATE delivery_history SET destinationLat = :lat, destinationLng = :lng WHERE id = :id',
          {'lat': lat, 'lng': lng, 'id': id},
        );
        updated++;
      }
      debugPrint('✅ [Backfill] Updated coordinates for $updated records.');
      return updated;
    } catch (e) {
      debugPrint('⚠️ [Backfill] backfillDestinationCoords error: $e');
      return 0;
    }
  }

  /// ✅ ย้อนหลัง: อัปเดต distanceKm และ fuelCostEstimate สำหรับ record ที่มี GPS แต่ไม่มีระยะทาง
  /// ต้องการ shopLat, shopLng, fuelRate, และ OSRM calculator function ส่งเข้ามา
  Future<int> backfillDistanceAndFuel({
    required double shopLat,
    required double shopLng,
    required double fuelRate,
    required Future<double> Function(double, double, double, double) calcRoadDistance,
  }) async {
    if (shopLat == 0.0 || shopLng == 0.0) {
      debugPrint('⚠️ [Backfill] Shop GPS not configured. Skipping backfill.');
      return 0;
    }

    try {
      final rows = await _db.query('''
        SELECT id, destinationLat, destinationLng
        FROM delivery_history
        WHERE (distanceKm IS NULL OR distanceKm = 0)
          AND destinationLat IS NOT NULL
          AND destinationLng IS NOT NULL
        LIMIT 200
      ''');

      int updated = 0;
      for (final row in rows) {
        final id = row['id'];
        final dLat = double.tryParse(row['destinationLat']?.toString() ?? '') ?? 0.0;
        final dLng = double.tryParse(row['destinationLng']?.toString() ?? '') ?? 0.0;
        if (dLat == 0.0 || dLng == 0.0) continue;

        try {
          final dist = await calcRoadDistance(shopLat, shopLng, dLat, dLng);
          final fuel = dist * fuelRate;
          await _db.execute(
            'UPDATE delivery_history SET distanceKm = :dist, fuelCostEstimate = :fuel WHERE id = :id',
            {'dist': dist, 'fuel': fuel, 'id': id},
          );
          updated++;
        } catch (e) {
          debugPrint('⚠️ [Backfill] Skipping id=$id: $e');
        }
      }
      debugPrint('✅ [Backfill] Recalculated distance for $updated records.');
      return updated;
    } catch (e) {
      debugPrint('⚠️ [Backfill] backfillDistanceAndFuel error: $e');
      return 0;
    }
  }
}
