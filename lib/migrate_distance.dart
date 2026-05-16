// ignore_for_file: avoid_print
// Migration v2: คำนวณ distanceKm (OSRM ถนนจริง ไปกลับ) + fuelCostEstimate
// อัพเดต ทุก record ที่มี locationUrl (overwrite ค่าเดิม)
//
// Run: dart run lib/migrate_distance.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:mysql_client_plus/mysql_client_plus.dart';

// ── ตั้งค่าตรงนี้ ──────────────────────────────────────────────────
const double shopLat = 16.160189;
const double shopLng = 100.802307;
// fuelRate จะดึงจาก system_settings ใน DB (ถ้าไม่มีใช้ค่า default นี้)
const double fuelRateFallback = 3.0;
// ──────────────────────────────────────────────────────────────────

void main() async {
  print('🚀 Starting Distance Migration v2 (OSRM Round-Trip)...');
  print('📍 Shop GPS: $shopLat, $shopLng');
  print('');

  try {
    final conn = await MySQLConnection.createConnection(
      host: '127.0.0.1',
      port: 3306,
      userName: 'admin',
      password: '1234',
      databaseName: 'sorborikan',
    );
    await conn.connect();
    print('✅ Connected to DB');

    // ── ดึง fuelRate จาก system_settings ──────────────────────────
    double fuelRate = fuelRateFallback;
    try {
      final settingRow = await conn.execute(
        "SELECT setting_value FROM system_settings WHERE setting_key = 'fuel_cost_per_km' LIMIT 1",
      );
      if (settingRow.rows.isNotEmpty) {
        fuelRate = double.tryParse(settingRow.rows.first.colAt(0) ?? '') ?? fuelRateFallback;
      }
    } catch (_) {}
    print('⛽ Fuel rate from DB: ฿$fuelRate / km');
    print('');

    // ── ดึงทุก record ที่มี locationUrl (FORCE overwrite) ──────────
    final rows = await conn.execute('''
      SELECT id, locationUrl 
      FROM delivery_history 
      WHERE locationUrl IS NOT NULL 
        AND locationUrl != ''
        AND locationUrl LIKE '%?q=%'
    ''');

    print('📦 Found ${rows.rows.length} records to update...\n');

    int updated = 0;
    int skipped = 0;

    for (final row in rows.rows) {
      final id = row.colAt(0);
      final locationUrl = row.colAt(1) ?? '';

      try {
        final coordStr = locationUrl.split('?q=').last.split('&').first;
        final parts = coordStr.split(',');
        if (parts.length < 2) { skipped++; continue; }

        final destLat = double.tryParse(parts[0].trim()) ?? 0.0;
        final destLng = double.tryParse(parts[1].trim()) ?? 0.0;
        if (destLat == 0.0 || destLng == 0.0) { skipped++; continue; }

        // ── OSRM: ระยะทางถนนจริง ไปกลับ ──────────────────────────
        final dist = await getRoadDistanceRoundTrip(shopLat, shopLng, destLat, destLng);
        final fuel = dist * fuelRate;

        await conn.execute(
          'UPDATE delivery_history SET distanceKm = :dist, fuelCostEstimate = :fuel WHERE id = :id',
          {'dist': dist.toStringAsFixed(4), 'fuel': fuel.toStringAsFixed(4), 'id': id},
        );

        print('  ✅ #$id → ${dist.toStringAsFixed(2)} km (RT) | ฿${fuel.toStringAsFixed(2)}');
        updated++;

        // หน่วงเล็กน้อยเพื่อไม่ spam OSRM
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        print('  ⚠️ #$id skipped: $e');
        skipped++;
      }
    }

    print('\n─────────────────────────────');
    print('✅ Updated : $updated records');
    print('⏭️  Skipped : $skipped records');
    print('─────────────────────────────');

    await conn.close();
    print('\n🏁 Migration complete!');
  } catch (e) {
    print('❌ DB Connection Error: $e');
  }
}

/// ดึงระยะทางถนนจริง (OSRM) × 2 สำหรับไปกลับ
/// Fallback: Haversine × 1.4 × 2 ถ้า OSRM ไม่ตอบ
Future<double> getRoadDistanceRoundTrip(
    double lat1, double lon1, double lat2, double lon2) async {
  try {
    // OSRM ใช้ลำดับ lon,lat
    final url =
        'http://router.project-osrm.org/route/v1/driving/$lon1,$lat1;$lon2,$lat2?overview=false';

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set('User-Agent', 'POS-Migration/2.0');
    final response = await request.close();

    if (response.statusCode == 200) {
      final body = await response.transform(const Utf8Decoder()).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final routes = json['routes'] as List?;
      if (routes != null && routes.isNotEmpty) {
        final distanceM = (routes[0]['distance'] as num).toDouble();
        final oneWayKm = distanceM / 1000.0;
        print('     📡 OSRM: ${oneWayKm.toStringAsFixed(2)} km × 2 = ${(oneWayKm * 2).toStringAsFixed(2)} km');
        return oneWayKm * 2;
      }
    }
  } catch (e) {
    print('     ⚠️ OSRM failed: $e — using Haversine fallback');
  }
  // Fallback
  final straight = haversine(lat1, lon1, lat2, lon2);
  return straight * 1.4 * 2;
}

double haversine(double lat1, double lon1, double lat2, double lon2) {
  const double R = 6371.0;
  final dLat = deg2rad(lat2 - lat1);
  final dLon = deg2rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(deg2rad(lat1)) * cos(deg2rad(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

double deg2rad(double deg) => deg * (pi / 180.0);
