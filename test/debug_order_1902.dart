// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';

import 'package:mysql_client_plus/mysql_client_plus.dart';

void main() {
  test('Debug Order 1902', () async {
    print('Connecting to Database...');
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

    // 1. Get Order info
    print('--- Order 1902 ---');
    final orderRes = await conn.execute(
        "SELECT id, customerId, paymentMethod, total, grandTotal FROM `order` WHERE id = 1902");

    if (orderRes.rows.isEmpty) {
      print('Order 1902 not found!');
    } else {
      final order = orderRes.rows.first.assoc();
      print('Order Data: $order');
      final customerId = order['customerId'];
      print('CustomerId in Order: $customerId');

      // 2. If customerId exists, fetch customer
      if (customerId != null) {
        final custRes = await conn.execute(
            "SELECT id, firstName, lastName, address, shippingAddress FROM customer WHERE id = :id",
            {'id': customerId});
        if (custRes.rows.isNotEmpty) {
          final cust = custRes.rows.first.assoc();
          print('Customer Data from DB: $cust');

          // Check address raw bytes
          final addr = cust['address'];
          if (addr != null && addr is String) {
            print('Address String: "$addr"');
          } else if (addr != null) {
            print('Address Type: ${addr.runtimeType}');
            print('Address Bytes: $addr');
          }
        } else {
          print('Customer ID $customerId NOT FOUND in customer table!');
        }
      }
    }

    await conn.close();
  });
}
