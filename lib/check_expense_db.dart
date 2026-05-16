// ignore_for_file: avoid_print
// Script ตรวจสอบตาราง expense ใน DB
// Run: dart run lib/check_expense_db.dart
import 'package:mysql_client_plus/mysql_client_plus.dart';

void main() async {
  print('🔍 Checking expense table...\n');

  try {
    final conn = await MySQLConnection.createConnection(
      host: '127.0.0.1',
      port: 3306,
      userName: 'admin',
      password: '1234',
      databaseName: 'sorborikan',
    );
    await conn.connect();
    print('✅ Connected to DB\n');

    // 1. ตรวจว่าตาราง expense มีอยู่ไหม
    final tables = await conn.execute(
      "SELECT table_name FROM information_schema.tables WHERE table_schema = 'sorborikan' AND table_name = 'expense'",
    );
    if (tables.numOfRows == 0) {
      print('❌ Table "expense" does NOT exist!');
      print('   → ต้อง initTable ก่อน (รัน app แล้วเข้าหน้า expense)');
      await conn.close();
      return;
    }
    print('✅ Table "expense" exists\n');

    // 2. ดู schema ของตาราง
    print('📋 Table structure:');
    final cols = await conn.execute('DESCRIBE expense');
    for (final row in cols.rows) {
      print('   ${row.assoc()}');
    }
    print('');

    // 3. นับ rows ทั้งหมด
    final count = await conn.execute('SELECT COUNT(*) as cnt FROM expense');
    final total = count.rows.first.colAt(0);
    print('📊 Total rows in expense: $total\n');

    // 4. ดู rows ล่าสุด 5 รายการ (raw data)
    final rows = await conn.execute('SELECT * FROM expense ORDER BY createdAt DESC LIMIT 5');
    if (rows.numOfRows == 0) {
      print('⚠️  ไม่มีข้อมูลในตาราง expense เลย');
      print('   → INSERT ไม่สำเร็จ หรือ ตารางว่าง');
    } else {
      print('📦 Latest 5 records:');
      for (final row in rows.rows) {
        final r = row.assoc();
        print('   id=${r['id']} | title=${r['title']} | amount=${r['amount']}');
        print('   expenseDate=${r['expenseDate']} | type=${r['type']}');
        print('');
      }
    }

    // 5. ทดสอบ INSERT
    print('🧪 Testing INSERT...');
    final insertResult = await conn.execute(
      "INSERT INTO expense (title, amount, category, expenseDate, note, type) "
      "VALUES ('TEST_DEBUG', 99.99, 'ทั่วไป', NOW(), 'test', 'EXPENSE')",
    );
    final newId = insertResult.lastInsertID.toInt();
    print('✅ INSERT OK! New id = $newId');

    // 6. ตรวจสอบวันที่ที่บันทึก
    final check = await conn.execute(
      'SELECT id, title, expenseDate FROM expense WHERE id = $newId',
    );
    if (check.numOfRows > 0) {
      final r = check.rows.first.assoc();
      print('📅 Stored date: ${r['expenseDate']}');
    }

    // 7. ทดสอบ SELECT ด้วย BETWEEN
    final now = DateTime.now();
    final firstDay = '${now.year}-${now.month.toString().padLeft(2,'0')}-01 00:00:00';
    final lastDay = '${now.year}-${now.month.toString().padLeft(2,'0')}-30 23:59:59';
    print('\n🔍 Testing BETWEEN $firstDay AND $lastDay');
    final betweenTest = await conn.execute(
      "SELECT COUNT(*) as cnt FROM expense WHERE expenseDate BETWEEN '$firstDay' AND '$lastDay'",
    );
    print('   Found: ${betweenTest.rows.first.colAt(0)} rows');

    // Cleanup test record
    await conn.execute('DELETE FROM expense WHERE id = $newId');
    print('\n🧹 Cleaned up test record');

    await conn.close();
    print('\n🏁 Done!');
  } catch (e) {
    print('❌ Error: $e');
  }
}
