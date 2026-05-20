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
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final results = await _dbService.query(
          'SELECT * FROM product_barcode WHERE barcode = :barcode LIMIT 1',
          {'barcode': barcode});
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      debugPrint('Error finding barcode $barcode: $e');
      return null;
    }
  }

  Future<void> updateProductBarcodes(
      int productId, List<ProductBarcode> barcodes) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    
    await _dbService.execute('START TRANSACTION;');
    
    try {
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
