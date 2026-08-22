part of '../product_repository.dart';

extension ProductRepositoryBarcodes on ProductRepository {
  Future<List<Map<String, dynamic>>> getAllProductBarcodes() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      return await _dbService.query('SELECT * FROM product_barcode');
    } catch (e) {
      debugPrint('Error fetching product barcodes: $e');
      return [];
    }
  }

  Future<List<ProductBarcode>> getProductBarcodesByProductId(int id) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final results = await _dbService.query(
          'SELECT * FROM product_barcode WHERE productId = :id', {'id': id});
      return results.map((row) => ProductBarcode.fromJson(row)).toList();
    } catch (e) {
      debugPrint('Error fetching barcodes for product $id: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> findProductBarcode(String barcode) async {
    try {
      if (!_dbService.isConnected()) await _dbService.connect();
      if (_dbService.isConnected()) {
        final results = await _dbService.query(
            'SELECT * FROM product_barcode WHERE barcode = :barcode LIMIT 1',
            {'barcode': barcode});
        if (results.isNotEmpty) return results.first;
      }
    } catch (e) {
      debugPrint('Error finding barcode $barcode in MySQL: $e, trying Isar...');
    }

    try {
      // Fallback to Isar
      final isarDoc = await _isar.productBarcodeCollections
          .filter()
          .barcodeEqualTo(barcode)
          .findFirst();
      if (isarDoc != null) {
        return {
          'id': isarDoc.id,
          'productId': isarDoc.productId,
          'barcode': isarDoc.barcode,
          'unitName': isarDoc.unitName,
          'price': isarDoc.price,
          'quantity': isarDoc.quantity,
        };
      }
    } catch (e) {
      debugPrint('Error finding barcode $barcode in Isar: $e');
    }
    return null;
  }

  /// Finds a barcode owned by another product, whether it is the product's
  /// primary barcode or a barcode for a sale unit/package.
  Future<Map<String, dynamic>?> findBarcodeConflict(
    String barcode, {
    int? excludingProductId,
  }) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final excludedId = excludingProductId ?? 0;
      final results = await _dbService.query(
        '''SELECT id AS productId, name, 'primary' AS source
             FROM product
           WHERE barcode = :barcode AND id != :excludedId
           UNION ALL
           SELECT p.id AS productId, p.name, 'unit' AS source
             FROM product_barcode pb
             JOIN product p ON p.id = pb.productId
           WHERE pb.barcode = :barcode AND p.id != :excludedId
           LIMIT 1''',
        {'barcode': code, 'excludedId': excludedId},
      );
      return results.isEmpty ? null : results.first;
    } catch (e) {
      debugPrint('Error checking barcode conflict: $e');
      rethrow;
    }
  }

  Future<void> updateProductBarcodes(
      int productId, List<ProductBarcode> barcodes) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    await _dbService.execute('START TRANSACTION;');

    try {
      final seen = <String>{};
      final primary = await _dbService.query(
        'SELECT barcode FROM product WHERE id = :id LIMIT 1',
        {'id': productId},
      );
      final primaryBarcode = primary.isEmpty
          ? ''
          : primary.first['barcode']?.toString().trim() ?? '';
      for (final barcode in barcodes) {
        final code = barcode.barcode.trim();
        if (code.isEmpty || code == primaryBarcode || !seen.add(code)) {
          throw StateError('พบบาร์โค้ดหน่วยสินค้าซ้ำ: $code');
        }
        final conflict = await findBarcodeConflict(
          code,
          excludingProductId: productId,
        );
        if (conflict != null) {
          throw StateError(
              'บาร์โค้ด $code ถูกใช้โดยสินค้า ${conflict['name']}');
        }
      }
      await _dbService.execute(
          'DELETE FROM product_barcode WHERE productId = :id',
          {'id': productId});
      if (barcodes.isNotEmpty) {
        for (var b in barcodes) {
          await _dbService.execute(
              'INSERT INTO product_barcode (productId, barcode, unitName, price, quantity) VALUES (:pid, :bc, :unit, :price, :qty)',
              {
                'pid': productId,
                'bc': b.barcode,
                'unit': b.unitName,
                'price': b.price,
                'qty': b.quantity
              });
        }
      }
      await _dbService.execute('COMMIT;');
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      rethrow;
    }
  }
}
