import 'package:mysql_client_plus/mysql_client_plus.dart';
// ignore_for_file: avoid_print

void main() async {
  final conn = await MySQLConnection.createConnection(
    host: '127.0.0.1',
    port: 3306,
    userName: 'admin',
    password: '1234',
    databaseName: 'sorborikan',
  );

  try {
    await conn.connect();
    print('[OK] Connected');

    // 1. ตรวจว่ามีข้อมูลใน delivery_history ไหม
    final count = await conn.execute('SELECT COUNT(*) as c FROM delivery_history');
    print('Total rows: ${count.rows.first.colAt(0)}');

    // 2. ดู 5 แถวล่าสุด — เน้น vehiclePlate, locationUrl, driverName
    final rows = await conn.execute('''
      SELECT id, orderId, vehiclePlate, locationUrl, driverName, completedAt
      FROM delivery_history
      ORDER BY completedAt DESC LIMIT 5
    ''');

    print('\n--- 5 rows (latest) ---');
    for (final r in rows.rows) {
      final m = r.assoc();
      print('id=${m['id']} | order=${m['orderId']} | plate=[${m['vehiclePlate']}] | driver=[${m['driverName']}] | gps=[${m['locationUrl']}] | at=${m['completedAt']}');
    }

    // 3. สรุปว่ามีกี่แถวที่มี vehiclePlate / locationUrl
    final stats = await conn.execute('''
      SELECT
        SUM(CASE WHEN vehiclePlate IS NOT NULL AND vehiclePlate != '' THEN 1 ELSE 0 END) as hasPlate,
        SUM(CASE WHEN locationUrl   IS NOT NULL AND locationUrl   != '' THEN 1 ELSE 0 END) as hasGPS,
        COUNT(*) as total
      FROM delivery_history
    ''');
    final s = stats.rows.first.assoc();
    print('\n--- Summary ---');
    print('มีทะเบียนรถ: ${s['hasPlate']} / ${s['total']}');
    print('มี GPS URL:  ${s['hasGPS']} / ${s['total']}');

    await conn.close();
  } catch (e) {
    print('ERROR: $e');
  }
}
