import 'package:mysql_client_plus/mysql_client_plus.dart';
// ignore_for_file: avoid_print

//import 'package:flutter_secure_storage/flutter_secure_storage.dart';
//import 'dart:io';

void main() async {
  try {
    // Hardcode connection based on local environment (since we can't read flutter secure storage easily in a standalone dart script, wait...
    // Let's just connect using typical local developer credentials.
    final conn = await MySQLConnection.createConnection(
      host: '127.0.0.1',
      port: 3306,
      userName: 'root',
      password: '',
      databaseName: 'pos_system',
    );
    await conn.connect();

    final res = await conn.execute('SHOW TRIGGERS;');
    for (var row in res.rows) {
      final map = row.assoc();
      print('Trigger: ${map['Trigger']}');
      print('Event: ${map['Event']}');
      print('Table: ${map['Table']}');
      print('Statement: \n${map['Statement']}');
      print('---');
    }

    await conn.close();
  } catch (e) {
    print('Failed: \$e');
  }
}
