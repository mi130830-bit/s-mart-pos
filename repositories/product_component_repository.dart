import '../services/mysql_service.dart';
import '../models/product_component.dart';

class ProductComponentRepository {
  final MySQLService _db = MySQLService();

  Future<void> createTableIfNeeded() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS product_components (
        id INT AUTO_INCREMENT PRIMARY KEY,
        parent_product_id INT NOT NULL,
        child_product_id INT NOT NULL,
        quantity DOUBLE NOT NULL,
        FOREIGN KEY (parent_product_id) REFERENCES product(id) ON DELETE CASCADE,
        FOREIGN KEY (child_product_id) REFERENCES product(id) ON DELETE CASCADE
      )
    ''';
    await _db.execute(sql);
  }

  Future<List<ProductComponent>> getComponentsByParentId(int parentId) async {
    // Join with product table to get child product name/cost/unit
    const sql = '''
      SELECT pc.*, p.name as child_name, p.costPrice as child_cost, u.name as child_unit, p.stockQuantity as child_stock
      FROM product_components pc
      JOIN product p ON pc.child_product_id = p.id
      LEFT JOIN unit u ON p.unitId = u.id
      WHERE pc.parent_product_id = :parentId
    ''';

    final results = await _db.query(sql, {'parentId': parentId});
    return results.map((row) => ProductComponent.fromJson(row)).toList();
  }

  Future<void> updateComponents(
      int parentId, List<ProductComponent> components) async {
    // 1. Delete all existing components for this parent
    await _db.execute(
      'DELETE FROM product_components WHERE parent_product_id = :parentId',
      {'parentId': parentId},
    );

    // 2. Insert new components
    if (components.isNotEmpty) {
      for (var comp in components) {
        await _db.execute(
          'INSERT INTO product_components (parent_product_id, child_product_id, quantity) VALUES (:parentId, :childId, :qty)',
          {
            'parentId': parentId,
            'childId': comp.childProductId,
            'qty': comp.quantity,
          },
        );
      }
    }
  }
}
