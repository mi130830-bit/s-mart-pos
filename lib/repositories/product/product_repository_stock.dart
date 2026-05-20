part of '../product_repository.dart';

extension ProductRepositoryStock on ProductRepository {
  Future<bool> updateStock(int productId, double quantityChange) async {
    try {
      return await StockRepository().adjustStock(
        productId: productId,
        quantityChange: quantityChange,
        type: 'ADJUST_FIX',
        note: 'Manual Update from ProductRepo',
      );
    } catch (e) {
      debugPrint('Error updating stock: $e');
      return false;
    }
  }

  Future<List<Product>> getLowStockProducts({int limit = 5000}) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    final results = await _dbService.query(
        'SELECT * FROM product WHERE trackStock = 1 AND reorderPoint > 0 AND stockQuantity <= reorderPoint ORDER BY stockQuantity ASC LIMIT :limit',
        {'limit': limit});
    return results.map((row) => Product.fromJson(row)).toList();
  }

  Future<List<Map<String, dynamic>>> getInventoryPerformance(
      {int days = 30}) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    final dateThreshold =
        DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final sql = '''
        SELECT p.id, p.name, p.stockQuantity, p.reorderPoint,
          COALESCE(SUM(oi.quantity), 0) as soldQty, MAX(o.createdAt) as lastSaleDate
        FROM product p
        LEFT JOIN orderitem oi ON p.id = oi.productId
        LEFT JOIN `order` o ON oi.orderId = o.id AND o.createdAt >= :date AND o.status = 'COMPLETED'
        GROUP BY p.id, p.name, p.stockQuantity, p.reorderPoint
        ORDER BY soldQty DESC;
      ''';
    return await _dbService.query(sql, {'date': dateThreshold});
  }
}
