// ignore_for_file: avoid_print
import 'package:mysql_client_plus/mysql_client_plus.dart';

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

    // Describe Table
    final res = await conn.execute('DESCRIBE delivery_history');
    print('\n--- Table Schema: delivery_history ---');
    for (final r in res.rows) {
      final m = r.assoc();
      print('${m['Field']} | ${m['Type']} | ${m['Null']} | ${m['Key']} | ${m['Default']}');
    }

    // Check last 5 rows data
    final rows = await conn.execute('SELECT * FROM delivery_history ORDER BY id DESC LIMIT 5');
    print('\n--- Last 5 Data Rows ---');
    for (final r in rows.rows) {
      final m = r.assoc();
      print('id=${m['id']} | order=${m['orderId']} | fid=${m['firebaseJobId']} | driver=${m['driverName']} | plate=${m['vehiclePlate']}');
    }

    await conn.close();
  } catch (e) {
    print('ERROR: $e');
  }
}
