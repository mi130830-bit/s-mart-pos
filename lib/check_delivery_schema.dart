// ignore_for_file: avoid_print
import 'package:mysql_client_plus/mysql_client_plus.dart';
import 'dart:io';

void main() async {
  final conn = await MySQLConnection.createConnection(
    host: '127.0.0.1',
    port: 3306,
    userName: 'admin',
    password: '1234',
    databaseName: 'sorborikan',
  );
  await conn.connect();
  
  final res = await conn.execute("DESCRIBE delivery_history");
  print('--- delivery_history Schema ---');
  for (var r in res.rows) {
    print('${r.colAt(0)} | ${r.colAt(1)}');
  }

  await conn.close();
  exit(0);
}
