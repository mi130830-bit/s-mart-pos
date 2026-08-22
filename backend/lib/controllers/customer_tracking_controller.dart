import 'dart:convert';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db_config.dart';
import 'gps_controller.dart';

/// Capability-link API for a customer to view one active delivery only.
/// It deliberately never exposes the all-vehicles GPS feed.
class CustomerTrackingController {
  // Add a vehicle only after its ESP GPS tracker is provisioned with the
  // same canonical vehicle key, so customers never receive an unusable link.
  static const Set<String> _customerTrackableVehicleKeys = {'รถเครน', 'ดั้มเล็ก', 'ดั้มใหญ่'};

  static final Random _random = Random.secure();
  static Future<void>? _schemaReady;

  Router get router {
    final router = Router();
    router.get('/<token>', _getTracking);
    return router;
  }

  static Future<void> _ensureSchema() {
    return _schemaReady ??= () async {
      final conn = await DbConfig().connection;
      await conn.execute('''
        CREATE TABLE IF NOT EXISTS delivery_tracking_links (
          orderId BIGINT NOT NULL PRIMARY KEY,
          token VARCHAR(96) NOT NULL UNIQUE,
          vehicleKey VARCHAR(128) NOT NULL,
          active TINYINT(1) NOT NULL DEFAULT 1,
          createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          revokedAt DATETIME NULL
        )
      ''');
    }();
  }

  static String _newToken() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    return List.generate(48, (_) => alphabet[_random.nextInt(alphabet.length)])
        .join();
  }

  static Future<String?> issue({
    required int orderId,
    required String vehicleKey,
  }) async {
    if (orderId <= 0 || !canTrackVehicle(vehicleKey)) return null;
    await _ensureSchema();
    final conn = await DbConfig().connection;
    final existing = await conn.execute(
      'SELECT token FROM delivery_tracking_links WHERE orderId = :orderId AND active = 1 LIMIT 1',
      {'orderId': orderId},
    );
    if (existing.numOfRows > 0) return existing.rows.first.colAt(0)?.toString();

    final token = _newToken();
    await conn.execute('''
      INSERT INTO delivery_tracking_links (orderId, token, vehicleKey, active, revokedAt)
      VALUES (:orderId, :token, :vehicleKey, 1, NULL)
      ON DUPLICATE KEY UPDATE token = VALUES(token), vehicleKey = VALUES(vehicleKey),
        active = 1, revokedAt = NULL, createdAt = CURRENT_TIMESTAMP
    ''', {'orderId': orderId, 'token': token, 'vehicleKey': vehicleKey.trim()});
    return token;
  }

  static bool canTrackVehicle(String vehicleKey) =>
      _customerTrackableVehicleKeys.contains(vehicleKey.trim());

  static Future<void> revoke(int orderId) async {
    if (orderId <= 0) return;
    await _ensureSchema();
    final conn = await DbConfig().connection;
    await conn.execute(
      'UPDATE delivery_tracking_links SET active = 0, revokedAt = CURRENT_TIMESTAMP WHERE orderId = :orderId AND active = 1',
      {'orderId': orderId},
    );
  }

  Future<Response> _getTracking(Request request, String token) async {
    await _ensureSchema();
    final conn = await DbConfig().connection;
    final result = await conn.execute(
      'SELECT vehicleKey FROM delivery_tracking_links WHERE token = :token AND active = 1 LIMIT 1',
      {'token': token},
    );
    if (result.numOfRows == 0) {
      return Response.notFound(jsonEncode({'active': false}),
          headers: {'content-type': 'application/json', 'cache-control': 'no-store'});
    }
    final vehicleKey = result.rows.first.colAt(0)?.toString() ?? '';
    final location = GpsController.latestVehicle(vehicleKey);
    return Response.ok(
      jsonEncode({
        'active': true,
        'vehicle': vehicleKey,
        'location': location == null
            ? null
            : {
                'lat': location['lat'],
                'lng': location['lng'],
                'speed': location['speed'],
                'time': location['time'],
                'status': location['status'],
              },
      }),
      headers: {'content-type': 'application/json', 'cache-control': 'no-store'},
    );
  }
}
