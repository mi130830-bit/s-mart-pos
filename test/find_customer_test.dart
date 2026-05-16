// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_desktop/services/mysql_service.dart';

void main() {
  test('Find Customer', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final db = MySQLService();
    await db.connect();

    final phone = '0851377402';
    final name = 'ติ';

    print('🔎 Searching for Customer ($name, $phone)...');

    final res = await db.query(
        "SELECT id, name, phoneNumber, line_user_id FROM customer WHERE phoneNumber LIKE '%$phone%' OR name LIKE '%$name%' LIMIT 5");

    if (res.isEmpty) {
      print('❌ Customer Not Found!');
    } else {
      for (var row in res) {
        print(
            '✅ Found: ID=${row['id']} Name=${row['name']} Phone=${row['phoneNumber']} LineID=${row['line_user_id']}');
      }
    }
  });
}
