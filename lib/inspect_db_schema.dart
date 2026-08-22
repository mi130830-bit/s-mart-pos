// ignore_for_file: avoid_print

// Read-only audit tool for identifying barcode collisions before adding a
// database-level unique registry. It never changes database data or schema.
import 'dart:convert';
import 'dart:io';

import 'package:mysql_client_plus/mysql_client_plus.dart';

const _reportFileName = 'duplicate_barcodes_report.txt';

Future<void> main() async {
  final config = await _loadDatabaseConfig();
  final reportPath = File('${Directory.current.path}${Platform.pathSeparator}'
      '$_reportFileName');
  MySQLConnection? connection;

  try {
    connection = await MySQLConnection.createConnection(
      host: config['host']!,
      port: int.parse(config['port']!),
      userName: config['user']!,
      password: config['password']!,
      databaseName: config['database']!,
    );
    await connection.connect();

    final primaryRows = await connection.execute('''
      SELECT id, barcode, name
      FROM product
      WHERE barcode IS NOT NULL AND TRIM(barcode) <> ''
      ORDER BY barcode, id
    ''');
    final extraRows = await connection.execute('''
      SELECT pb.id, pb.productId, pb.barcode, pb.unitName, p.name
      FROM product_barcode pb
      LEFT JOIN product p ON p.id = pb.productId
      WHERE pb.barcode IS NOT NULL AND TRIM(pb.barcode) <> ''
      ORDER BY pb.barcode, pb.id
    ''');

    final groups = <String, _BarcodeGroup>{};
    for (final row in primaryRows.rows) {
      final data = row.assoc();
      final barcode = data['barcode']!.trim();
      groups
          .putIfAbsent(_barcodeKey(barcode), () => _BarcodeGroup(barcode))
          .primary
          .add(_PrimaryBarcode(
            productId: data['id']!,
            productName: data['name'] ?? '(ไม่พบชื่อสินค้า)',
          ));
    }
    for (final row in extraRows.rows) {
      final data = row.assoc();
      final barcode = data['barcode']!.trim();
      groups
          .putIfAbsent(_barcodeKey(barcode), () => _BarcodeGroup(barcode))
          .extra
          .add(_ExtraBarcode(
            barcodeId: data['id']!,
            productId: data['productId']!,
            productName: data['name'] ?? '(ไม่พบสินค้า)',
            unitName: data['unitName'] ?? '-',
          ));
    }

    final collisions = groups.values
        .where((group) => group.isCollision)
        .toList()
      ..sort((a, b) => a.barcode.compareTo(b.barcode));

    await reportPath.writeAsString(
      _buildReport(collisions, primaryRows.rows.length, extraRows.rows.length),
      encoding: utf8,
    );
    print('Duplicate barcode report created: ${reportPath.path}');
    print('Colliding barcodes: ${collisions.length}');
  } catch (error) {
    // Do not print connection details or credentials.
    stderr.writeln('Could not create duplicate barcode report: $error');
    exitCode = 1;
  } finally {
    await connection?.close();
  }
}

Future<Map<String, String>> _loadDatabaseConfig() async {
  final values = <String, String>{
    'host': Platform.environment['DB_HOST'] ?? '127.0.0.1',
    'port': Platform.environment['DB_PORT'] ?? '3306',
    'user': Platform.environment['DB_USER'] ?? '',
    'password': Platform.environment['DB_PASS'] ?? '',
    'database': Platform.environment['DB_NAME'] ?? '',
  };
  final envFile =
      File('${Directory.current.path}${Platform.pathSeparator}.env');
  if (await envFile.exists()) {
    for (final line in await envFile.readAsLines()) {
      final separator = line.indexOf('=');
      if (separator <= 0 || line.trimLeft().startsWith('#')) continue;
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      if (key == 'DB_HOST' && values['host'] == '127.0.0.1') {
        values['host'] = value;
      }
      if (key == 'DB_PORT' && values['port'] == '3306') {
        values['port'] = value;
      }
      if (key == 'DB_USER' && values['user']!.isEmpty) {
        values['user'] = value;
      }
      if (key == 'DB_PASS' && values['password']!.isEmpty) {
        values['password'] = value;
      }
      if (key == 'DB_NAME' && values['database']!.isEmpty) {
        values['database'] = value;
      }
    }
  }
  if (values['user']!.isEmpty || values['database']!.isEmpty) {
    throw StateError(
        'Database configuration is missing. Set DB_USER and DB_NAME in .env or environment variables.');
  }
  return values;
}

String _barcodeKey(String barcode) => barcode.toUpperCase();

String _buildReport(
  List<_BarcodeGroup> collisions,
  int primaryCount,
  int extraCount,
) {
  final primaryOnly = collisions
      .where((group) => group.primary.length > 1 && group.extra.isEmpty)
      .length;
  final extraOnly = collisions
      .where((group) => group.extra.length > 1 && group.primary.isEmpty)
      .length;
  final crossTable = collisions
      .where((group) => group.primary.isNotEmpty && group.extra.isNotEmpty)
      .length;
  final buffer = StringBuffer()
    ..writeln('Duplicate Barcode Audit Report')
    ..writeln('Generated: ${DateTime.now().toIso8601String()}')
    ..writeln('Mode: READ-ONLY — no database data or schema was changed.')
    ..writeln()
    ..writeln('Summary')
    ..writeln('- Primary product barcode rows scanned: $primaryCount')
    ..writeln('- Extra/unit barcode rows scanned: $extraCount')
    ..writeln('- Distinct colliding barcodes: ${collisions.length}')
    ..writeln('- Primary-only duplicate groups: $primaryOnly')
    ..writeln('- Extra/unit-only duplicate groups: $extraOnly')
    ..writeln('- Primary ↔ extra/unit collision groups: $crossTable')
    ..writeln()
    ..writeln('Details');
  if (collisions.isEmpty) {
    buffer
        .writeln('No duplicate or cross-table barcode collisions were found.');
  }
  for (final group in collisions) {
    buffer
      ..writeln()
      ..writeln('Barcode: ${group.barcode}')
      ..writeln('Collision type: ${group.collisionType}');
    for (final item in group.primary) {
      buffer.writeln(
          '  - PRIMARY | productId=${item.productId} | name=${item.productName}');
    }
    for (final item in group.extra) {
      buffer.writeln(
          '  - EXTRA_UNIT | barcodeId=${item.barcodeId} | productId=${item.productId} | '
          'name=${item.productName} | unit=${item.unitName}');
    }
  }
  return buffer.toString();
}

class _BarcodeGroup {
  _BarcodeGroup(this.barcode);

  final String barcode;
  final List<_PrimaryBarcode> primary = [];
  final List<_ExtraBarcode> extra = [];

  bool get isCollision =>
      primary.length > 1 ||
      extra.length > 1 ||
      (primary.isNotEmpty && extra.isNotEmpty);

  String get collisionType {
    if (primary.isNotEmpty && extra.isNotEmpty) return 'PRIMARY ↔ EXTRA_UNIT';
    return primary.length > 1 ? 'PRIMARY duplicate' : 'EXTRA_UNIT duplicate';
  }
}

class _PrimaryBarcode {
  const _PrimaryBarcode({required this.productId, required this.productName});

  final String productId;
  final String productName;
}

class _ExtraBarcode {
  const _ExtraBarcode({
    required this.barcodeId,
    required this.productId,
    required this.productName,
    required this.unitName,
  });

  final String barcodeId;
  final String productId;
  final String productName;
  final String unitName;
}
