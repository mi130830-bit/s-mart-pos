import 'dart:io';
import 'package:mysql_client_plus/mysql_client_plus.dart';
import 'package:dotenv/dotenv.dart';

Future<void> main() async {
  var env = DotEnv(includePlatformEnvironment: true)..load();
  final host = env['DB_HOST'] ?? '127.0.0.1';
  final port = int.tryParse(env['DB_PORT'] ?? '3306') ?? 3306;
  final user = env['DB_USER'] ?? 'root';
  final pass = env['DB_PASS'] ?? '';
  final db = env['DB_NAME'] ?? 'pos_data';

  stdout.writeln('Connecting to DB: $host:$port ($db)...');

  final conn = await MySQLConnection.createConnection(
    host: host,
    port: port,
    userName: user,
    password: pass,
    databaseName: db.isEmpty ? null : db,
    secure: false,
  );

  try {
    await conn.connect();
    stdout.writeln('Connected!');

    stdout.writeln('\n--- Describe product ---');
    var descProd = await conn.execute("DESCRIBE product");
    for (final row in descProd.rows) {
      stdout.writeln('${row.colAt(0)} | ${row.colAt(1)} | ${row.colAt(2)} | ${row.colAt(3)}');
    }

    stdout.writeln('\n--- Describe stockledger ---');
    var descLedger = await conn.execute("DESCRIBE stockledger");
    for (final row in descLedger.rows) {
      stdout.writeln('${row.colAt(0)} | ${row.colAt(1)} | ${row.colAt(2)} | ${row.colAt(3)}');
    }

    stdout.writeln('\n--- Products matching Barcodes or Name ---');
    var prodResult = await conn.execute(
      "SELECT id, barcode, name, stockQuantity FROM product WHERE barcode IN ('254495', '946009', '120931', '620575', '27965189', '28007879') OR name LIKE 'ท่อหด%'"
    );
    for (final row in prodResult.rows) {
      stdout.writeln('ID: ${row.colByName("id")} | Barcode: ${row.colByName("barcode")} | Name: ${row.colByName("name")} | Stock: ${row.colByName("stockQuantity")}');
    }

    stdout.writeln('\n--- Orphaned product_components ---');
    var orphans = await conn.execute(
      "SELECT parent_product_id, child_product_id, quantity FROM product_components WHERE parent_product_id NOT IN (SELECT id FROM product) OR child_product_id NOT IN (SELECT id FROM product)"
    );
    if (orphans.rows.isEmpty) {
      stdout.writeln('No orphaned components found.');
    } else {
      for (final row in orphans.rows) {
        stdout.writeln('ParentID: ${row.colByName("parent_product_id")} | ChildID: ${row.colByName("child_product_id")} | Qty: ${row.colByName("quantity")}');
      }
    }

  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    await conn.close();
  }
}
