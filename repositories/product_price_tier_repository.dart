import '../services/mysql_service.dart';
import '../models/product_price_tier.dart';

class ProductPriceTierRepository {
  final MySQLService _db = MySQLService();

  Future<void> createTableIfNeeded() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS product_price_tiers (
        id INT AUTO_INCREMENT PRIMARY KEY,
        product_id INT NOT NULL,
        min_quantity DOUBLE NOT NULL,
        price DOUBLE NOT NULL,
        note VARCHAR(255),
        FOREIGN KEY (product_id) REFERENCES product(id) ON DELETE CASCADE
      )
    ''';
    await _db.execute(sql);
  }

  Future<List<ProductPriceTier>> getTiersByProductId(int productId) async {
    await createTableIfNeeded();
    const sql = '''
      SELECT * FROM product_price_tiers 
      WHERE product_id = :productId 
      ORDER BY min_quantity ASC
    ''';

    final results = await _db.query(sql, {'productId': productId});
    return results.map((row) => ProductPriceTier.fromJson(row)).toList();
  }

  Future<void> updateTiers(int productId, List<ProductPriceTier> tiers) async {
    await createTableIfNeeded();
    // 1. Delete all existing tiers for this product
    await _db.execute(
      'DELETE FROM product_price_tiers WHERE product_id = :productId',
      {'productId': productId},
    );

    // 2. Insert new tiers
    if (tiers.isNotEmpty) {
      for (var tier in tiers) {
        await _db.execute(
          'INSERT INTO product_price_tiers (product_id, min_quantity, price, note) VALUES (:productId, :minQty, :price, :note)',
          {
            'productId': productId,
            'minQty': tier.minQuantity,
            'price': tier.price,
            'note': tier.note,
          },
        );
      }
    }
  }
}
