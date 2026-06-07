import 'package:mysql_client_plus/mysql_client_plus.dart';

void main() async {
  try {
    print('Connecting...');
    final conn = await MySQLConnection.createConnection(
      host: 'localhost',
      port: 3306,
      userName: 'root',
      password: 'password',
      databaseName: 's_mart_pos',
    );
    await conn.connect();
    print('Executing query...');
    await conn.execute('ALTER TABLE employee_profile ADD COLUMN sort_order INT DEFAULT 0;');
    print('Added sort_order column successfully.');
    await conn.close();
  } catch (e) {
    if (e.toString().contains('Duplicate column name')) {
      print('Column already exists.');
    } else {
      print('Error: $e');
    }
  }
}
