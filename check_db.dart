import 'package:mysql_client_plus/mysql_client_plus.dart';

void main() async {
  print('Connecting to MySQL...');
  final conn = await MySQLConnection.createConnection(
    host: '127.0.0.1',
    port: 3306,
    userName: 'root',
    password: '', // Assuming empty password for root based on previous logs
    databaseName: 'sorborikan',
  );

  await conn.connect();
  print('Connected!');

  final result = await conn.execute('SELECT setting_key, setting_value FROM system_settings WHERE setting_key IN ("payment_qr_mode", "promptpay_id")');
  
  for (final row in result.rows) {
    print('\${row.colAt(0)}: \${row.colAt(1)}');
  }

  await conn.close();
}
