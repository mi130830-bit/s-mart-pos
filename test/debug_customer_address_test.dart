// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';

import 'package:mysql_client_plus/mysql_client_plus.dart';

void main() {
  test('Debug Customer Address', () async {
    print('Connecting to Database...');
    // Credentials from backend/.env
    final conn = await MySQLConnection.createConnection(
      host: '127.0.0.1',
      port: 3306,
      userName: 'admin',
      password: '1234',
      databaseName: 'sorborikan',
      secure: false,
    );

    await conn.connect();
    print('Connected!');

    // Query for the customer
    // The user mentioned "บริษัทวีวรรณกรุ๊ป"
    final results = await conn.execute(
      "SELECT id, firstName, lastName, address, shippingAddress FROM customer WHERE firstName LIKE '%วีวรรณ%' OR lastName LIKE '%วีวรรณ%'",
    );

    print('Found ${results.rows.length} customers.');

    for (var row in results.rows) {
      final data = row.assoc();
      print('--------------------------------------------------');
      print('ID: ${data['id']}');
      print('Name: ${data['firstName']} ${data['lastName']}');

      final addr = data['address'];
      print('Address (Raw): "$addr"');
      print('Address (IsNull): ${addr == null}');
      print('Address (IsEmpty): ${addr?.isEmpty}');
      if (addr != null) {
        print('Address (CodeUnits): ${addr.codeUnits}');
      }

      final shipAddr = data['shippingAddress'];
      print('Shipping Address (Raw): "$shipAddr"');
      print('Shipping Address (IsNull): ${shipAddr == null}');
      print('Shipping Address (IsEmpty): ${shipAddr?.isEmpty}');
      if (shipAddr != null) {
        print('Shipping Address (CodeUnits): ${shipAddr.codeUnits}');
      }
      print('--------------------------------------------------');
    }

    await conn.close();
  });
}
