import 'package:mysql_client_plus/mysql_client_plus.dart';
// ignore_for_file: avoid_print


// Standalone diagnostic to check MySQL directly
void main() async {
  print('--- Ti (Ti) DB Diagnostic Start ---');

  final conn = await MySQLConnection.createConnection(
    host: '127.0.0.1',
    port: 3306,
    userName: 'admin',
    password: '1234',
    databaseName: 'sorborikan',
  );

  try {
    await conn.connect();
    print('[SUCCESS] Connected to MySQL');

    final customers = await conn.execute(
        "SELECT id, firstName, phone, line_user_id, firebaseUid, currentPoints FROM customer WHERE firstName LIKE '%\u0E15\u0E34%' OR phone = '0851377402'");

    print('\n[Customer Records Found]');
    if (customers.rows.isEmpty) {
      print('[FAIL] No customer found with name "Ti" or phone "0851377402"');
    }
    for (final row in customers.rows) {
      print(
          'ID: ${row.colAt(0)} | Name: ${row.colAt(1)} | Phone: ${row.colAt(2)} | LineID: ${row.colAt(3)} | FirebaseUID: ${row.colAt(4)} | Points: ${row.colAt(5)}');
    }

    final settings = await conn.execute(
        "SELECT * FROM system_settings WHERE setting_key IN ('api_url', 'line_channel_access_token')");

    print('\n[System Settings]');
    for (final row in settings.rows) {
      print('${row.colAt(0)}: ${row.colAt(1)}');
    }

    final logs = await conn.execute(
        "SELECT * FROM notification_logs WHERE line_user_id IS NOT NULL ORDER BY created_at DESC LIMIT 10");

    print('\n[Recent Notification Logs]');
    for (final row in logs.rows) {
      final data = row.assoc();
      print(
          'ID: ${data['id']} | Status: ${data['status']} | Type: ${data['message_type']} | Error: ${data['error_message']} | Time: ${data['created_at']}');
    }

    await conn.close();
  } catch (e) {
    print('[ERROR] Error: $e');
  }
}
