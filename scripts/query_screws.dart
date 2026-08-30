import 'dart:io';
import 'package:mysql_client_plus/mysql_client_plus.dart';

Future<void> main() async {
  final conn = await MySQLConnection.createConnection(
    host: '127.0.0.1',
    port: 3306,
    userName: 'admin',
    password: '1234',
    databaseName: 'sorborikan',
  );

  try {
    await conn.connect();
    stdout.writeln('Connected!');

    stdout.writeln('\n--- Product Types (Categories) ---');
    var typesResult = await conn.execute("SELECT * FROM product_type");
    int? screwTypeId;
    for (final row in typesResult.rows) {
      final id = int.parse(row.colByName("id")!);
      final name = row.colByName("name")!;
      stdout.writeln('ID: $id, Name: $name');
      if (name.trim() == 'สกรู') {
        screwTypeId = id;
      }
    }

    if (screwTypeId != null) {
      stdout.writeln('Found existing "สกรู" type with ID: $screwTypeId');
    } else {
      stdout.writeln('"สกรู" type NOT found in product_type.');
    }

  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    await conn.close();
  }
}
