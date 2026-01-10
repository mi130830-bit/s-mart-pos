import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';
import '../models/product_barcode.dart';
import '../models/product.dart';
import './activity_repository.dart';
import '../services/telegram_service.dart';

enum ProductSortOption { recent, nameAsc, stockAsc, stockDesc }

class ProductRepository {
  final MySQLService _dbService = MySQLService();
  final ActivityRepository _activityRepo = ActivityRepository();

  Future<List<Product>> getAllProducts() async {
    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }
    try {
      final results =
          await _dbService.query('SELECT * FROM product ORDER BY id DESC');
      // Use compute for heavy parsing
      return await compute(_parseProductList, results);
    } catch (e) {
      debugPrint('Error fetching products: $e');
      return [];
    }
  }

  // Lighter version for dropdowns/search where Image/Description is not needed
  Future<List<Product>> getAllProductsLight() async {
    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }
    try {
      // Select only necessary columns (Exclude imageUrl, etc.)
      const sql = '''
        SELECT 
          id, barcode, name, alias, productType, categoryId, unitId, supplierId,
          costPrice, retailPrice, wholesalePrice, memberRetailPrice, memberWholesalePrice,
          vatType, allowPriceEdit, stockQuantity, trackStock
        FROM product ORDER BY id DESC
      ''';
      final results = await _dbService.query(sql);
      return await compute(_parseProductList, results);
    } catch (e) {
      debugPrint('Error fetching products light: $e');
      return [];
    }
  }

  // Fetch additional barcodes for multi-unit support
  Future<List<Map<String, dynamic>>> getAllProductBarcodes() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      return await _dbService.query('SELECT * FROM product_barcode');
    } catch (e) {
      debugPrint('Error fetching product barcodes: $e');
      return [];
    }
  }

  Future<Product?> getProductById(int id) async {
    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }
    try {
      final results = await _dbService
          .query('SELECT * FROM product WHERE id = :id', {'id': id});
      if (results.isEmpty) return null;
      return Product.fromJson(results.first);
    } catch (e) {
      debugPrint('Error fetching product by id: $e');
      return null;
    }
  }

  Future<void> initTable() async {
    await ensureImageUrlColumn();
  }

  Future<void> ensureImageUrlColumn() async {
    try {
      final check =
          await _dbService.query("SHOW COLUMNS FROM product LIKE 'imageUrl'");
      if (check.isEmpty) {
        await _dbService
            .execute("ALTER TABLE product ADD COLUMN imageUrl TEXT");
      }
    } catch (_) {
      // Ignore errors if check or alter fails
    }
  }

  Future<int> saveProduct(Product product) async {
    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }

    try {
      if (product.id == 0) {
        // Check for existing barcode first to prevent 1062 Duplicate entry error
        if (product.barcode != null && product.barcode!.isNotEmpty) {
          final existing = await _dbService.query(
              'SELECT id FROM product WHERE barcode = :barcode',
              {'barcode': product.barcode});
          if (existing.isNotEmpty) {
            // Found existing product with same barcode -> Update it instead
            // FIX: Safe parsing of ID in case driver returns String
            final val = existing.first['id'];
            final existingId =
                (val is int) ? val : int.tryParse(val.toString()) ?? 0;

            // Update the product ID so the logic below falls into UPDATE block
            // We can't change product.id easily if it's final (it is not final in model usually, but let's see).
            // Better: Call update logic directly here or recursively call saveProduct with new ID.
            // But we need to be careful about object mutability.
            // Let's just create a new product object or switch to UPDATE logic.
            return await _updateProduct(product.copyWith(id: existingId));
          }
        }

        // Insert
        const sql = '''
          INSERT INTO product (
            barcode, name, alias, productType, categoryId, unitId, supplierId,
            costPrice, retailPrice, wholesalePrice, memberRetailPrice, memberWholesalePrice,
            vatType, allowPriceEdit, stockQuantity, trackStock,
            reorderPoint, overstockPoint, purchaseLimit, shelfLocation, warehousePattern,
            points, imageUrl, expiryDate
          ) VALUES (
            :barcode, :name, :alias, :type, :catId, :unitId, :supId,
            :cost, :retail, :wholesale, :memRetail, :memWholesale,
            :vat, :allowEdit, :stock, :track,
            :reorder, :overstock, :limit, :shelf, :pattern,
            :points, :img, :expiry
          )
        ''';
        final params = {
          'barcode': (product.barcode ?? '').length > 50
              ? (product.barcode ?? '').substring(0, 50)
              : (product.barcode ?? ''),
          'name': product.name.length > 200
              ? product.name.substring(0, 200)
              : product.name,
          'alias': (product.alias ?? '').length > 100
              ? (product.alias ?? '').substring(0, 100)
              : (product.alias ?? ''),
          'type': product.productType,
          'catId': (product.categoryId ?? 0) == 0 ? null : product.categoryId,
          'unitId': (product.unitId ?? 0) == 0 ? null : product.unitId,
          'supId': (product.supplierId ?? 0) == 0 ? null : product.supplierId,
          'cost': product.costPrice,
          'retail': product.retailPrice,
          'wholesale': product.wholesalePrice,
          'memRetail': product.memberRetailPrice,
          'memWholesale': product.memberWholesalePrice,
          'vat': product.vatType,
          'allowEdit': product.allowPriceEdit ? 1 : 0,
          'stock': product.stockQuantity,
          'track': product.trackStock ? 1 : 0,
          'reorder': product.reorderPoint,
          'overstock': product.overstockPoint,
          'limit': product.purchaseLimit,
          'shelf': product.shelfLocation,
          'pattern': product.warehousePattern,
          'points': product.points,
          'img': product.imageUrl,
          'expiry': product.expiryDate?.toIso8601String(),
        };
        final result = await _dbService.execute(sql, params);
        return result.lastInsertID.toInt();
      } else {
        // Update
        const sql = '''
          UPDATE product SET 
            barcode = :barcode, name = :name, alias = :alias, productType = :type,
            categoryId = :catId, unitId = :unitId, supplierId = :supId,
            costPrice = :cost, retailPrice = :retail, wholesalePrice = :wholesale,
            memberRetailPrice = :memRetail, memberWholesalePrice = :memWholesale,
            vatType = :vat, allowPriceEdit = :allowEdit, stockQuantity = :stock,
            trackStock = :track, reorderPoint = :reorder, overstockPoint = :overstock,
            purchaseLimit = :limit, shelfLocation = :shelf, warehousePattern = :pattern,
            points = :points, imageUrl = :img, expiryDate = :expiry
          WHERE id = :id
        ''';
        final params = {
          'id': product.id,
          'barcode': product.barcode,
          'name': product.name,
          'alias': product.alias,
          'type': product.productType,
          'catId': (product.categoryId ?? 0) == 0 ? null : product.categoryId,
          'unitId': (product.unitId ?? 0) == 0 ? null : product.unitId,
          'supId': (product.supplierId ?? 0) == 0 ? null : product.supplierId,
          'cost': product.costPrice,
          'retail': product.retailPrice,
          'wholesale': product.wholesalePrice,
          'memRetail': product.memberRetailPrice,
          'memWholesale': product.memberWholesalePrice,
          'vat': product.vatType,
          'allowEdit': product.allowPriceEdit ? 1 : 0,
          'stock': product.stockQuantity,
          'track': product.trackStock ? 1 : 0,
          'reorder': product.reorderPoint,
          'overstock': product.overstockPoint,
          'limit': product.purchaseLimit,
          'shelf': product.shelfLocation,
          'pattern': product.warehousePattern,
          'points': product.points,
          'img': product.imageUrl,
          'expiry': product.expiryDate?.toIso8601String(),
        };
        await _dbService.execute(sql, params);

        // Log Update
        await _activityRepo.log(
          action: 'UPDATE_PRODUCT',
          details: 'แก้ไขสินค้า: ${product.name} (ID: ${product.id})',
        );

        return product.id;
      }
    } catch (e) {
      debugPrint('Error saving product: $e');
      return 0; // Error
    }
  }

  Future<int> _updateProduct(Product product) async {
    try {
      // Update
      const sql = '''
        UPDATE product SET 
          barcode = :barcode, name = :name, alias = :alias, productType = :type,
          categoryId = :catId, unitId = :unitId, supplierId = :supId,
          costPrice = :cost, retailPrice = :retail, wholesalePrice = :wholesale,
          memberRetailPrice = :memRetail, memberWholesalePrice = :memWholesale,
          vatType = :vat, allowPriceEdit = :allowEdit, stockQuantity = :stock,
          trackStock = :track, reorderPoint = :reorder, overstockPoint = :overstock,
          purchaseLimit = :limit, shelfLocation = :shelf, warehousePattern = :pattern,
          points = :points, imageUrl = :img, expiryDate = :expiry
        WHERE id = :id
      ''';
      final params = {
        'id': product.id,
        'barcode': product.barcode,
        'name': product.name,
        'alias': product.alias,
        'type': product.productType,
        'catId': (product.categoryId ?? 0) == 0 ? null : product.categoryId,
        'unitId': (product.unitId ?? 0) == 0 ? null : product.unitId,
        'supId': (product.supplierId ?? 0) == 0 ? null : product.supplierId,
        'cost': product.costPrice,
        'retail': product.retailPrice,
        'wholesale': product.wholesalePrice,
        'memRetail': product.memberRetailPrice,
        'memWholesale': product.memberWholesalePrice,
        'vat': product.vatType,
        'allowEdit': product.allowPriceEdit ? 1 : 0,
        'stock': product.stockQuantity,
        'track': product.trackStock ? 1 : 0,
        'reorder': product.reorderPoint,
        'overstock': product.overstockPoint,
        'limit': product.purchaseLimit,
        'shelf': product.shelfLocation,
        'pattern': product.warehousePattern,
        'points': product.points,
        'img': product.imageUrl,
        'expiry': product.expiryDate?.toIso8601String(),
      };
      // 1. Fetch old stock for comparison
      double oldStock = 0.0;
      String productName = product.name;
      try {
        final oldData = await _dbService.query(
            'SELECT stockQuantity, name FROM product WHERE id = :id',
            {'id': product.id});
        if (oldData.isNotEmpty) {
          oldStock =
              double.tryParse(oldData.first['stockQuantity'].toString()) ?? 0.0;
          productName = oldData.first['name'];
        }
      } catch (_) {}

      // 2. Execute Update
      await _dbService.execute(sql, params);

      // 3. Check for Stock Change & Notify
      if (product.stockQuantity != oldStock) {
        final diff = product.stockQuantity - oldStock;
        try {
          final telegram = TelegramService();
          if (await telegram
              .shouldNotify(TelegramService.keyNotifyStockAdjust)) {
            final msg = '📦 *แก้ไขสต็อกสินค้า* (Manual Edit)\n'
                '━━━━━━━━━━━━━━━━━━\n'
                'สินค้า: $productName\n'
                'เดิม: $oldStock  ➜  ใหม่: ${product.stockQuantity}\n'
                'เปลี่ยนแปลง: ${diff > 0 ? '+' : ''}$diff\n'
                'โดย: (Manual Edit Form)\n'
                '━━━━━━━━━━━━━━━━━━';
            telegram.sendMessage(msg);
          }
        } catch (e) {
          debugPrint('Telegram Manual Edit Notify Error: $e');
        }
      }

      return product.id;
    } catch (e) {
      debugPrint('Error updating product: $e');
      rethrow;
    }
  }

  Future<bool> deleteProduct(int id) async {
    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }
    try {
      // 1. Get info before delete
      String productName = 'Unknown';
      try {
        final info = await _dbService
            .query('SELECT name FROM product WHERE id = :id', {'id': id});
        if (info.isNotEmpty) productName = info.first['name'];
      } catch (_) {}

      // 2. Delete
      await _dbService
          .execute('DELETE FROM product WHERE id = :id', {'id': id});

      // Log Delete
      await _activityRepo.log(
        action: 'DELETE_PRODUCT',
        details: 'ลบสินค้า ID: $id ($productName)',
      );

      // 3. Notify Telegram
      try {
        final telegram = TelegramService();
        if (await telegram
            .shouldNotify(TelegramService.keyNotifyDeleteProduct)) {
          final msg = '🗑️ *ลบสินค้า* (Product Deleted)\n'
              '━━━━━━━━━━━━━━━━━━\n'
              'สินค้า: $productName\n'
              'ID: $id\n'
              'โดย: (Admin/User)\n'
              '━━━━━━━━━━━━━━━━━━';
          telegram.sendMessage(msg);
        }
      } catch (e) {
        debugPrint('Telegram Delete Notify Error: $e');
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }

  // Method to support import screen if needed to be called from repository directly
  // But usually import screen logic is in the screen or a service.
  // We keep it clean here.

  Future<int> addProduct(Product product) async {
    return await saveProduct(product);
  }

  Future<List<Product>> getRecentProducts(int limit) async {
    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }
    try {
      final results = await _dbService.query(
          'SELECT * FROM product ORDER BY id DESC LIMIT :limit',
          {'limit': limit});
      return results.map((row) => Product.fromJson(row)).toList();
    } catch (e) {
      debugPrint('Error fetching recent products: $e');
      return [];
    }
  }

  Future<bool> updateStock(int productId, double quantityChange) async {
    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }
    try {
      await _dbService.execute(
        'UPDATE product SET stockQuantity = stockQuantity + :change WHERE id = :id',
        {'change': quantityChange, 'id': productId},
      );
      return true;
    } catch (e) {
      debugPrint('Error updating stock: $e');
      return false;
    }
  }

  Future<List<Product>> getProductsPaginated(int page, int pageSize,
      {String? searchTerm,
      ProductSortOption sortOption = ProductSortOption.recent}) async {
    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }
    try {
      final offset = (page - 1) * pageSize;
      String sql = 'SELECT * FROM product';
      final params = <String, dynamic>{
        'limit': pageSize,
        'offset': offset,
      };

      if (searchTerm != null && searchTerm.isNotEmpty) {
        sql +=
            ' WHERE name LIKE :term OR barcode LIKE :term OR alias LIKE :term';
        params['term'] = '%$searchTerm%';
      }

      String orderBy = 'id DESC';
      switch (sortOption) {
        case ProductSortOption.nameAsc:
          orderBy = 'name ASC';
          break;
        case ProductSortOption.stockAsc:
          orderBy = 'stockQuantity ASC';
          break;
        case ProductSortOption.stockDesc:
          orderBy = 'stockQuantity DESC';
          break;
        case ProductSortOption.recent:
          orderBy = 'id DESC';
          break;
      }

      sql += ' ORDER BY $orderBy LIMIT :limit OFFSET :offset';

      final results = await _dbService.query(sql, params);
      return results.map((row) => Product.fromJson(row)).toList();
    } catch (e) {
      debugPrint('Error fetching paginated products: $e');
      return [];
    }
  }

  Future<int> getProductCount({String? searchTerm}) async {
    // ... existing ...
    // re-paste existing code to be safe?
    // I can just append new methods before the end of class.
    // But `replace_file_content` needs `TargetContent`.
    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }
    try {
      String sql = 'SELECT COUNT(*) as count FROM product';
      final params = <String, dynamic>{};

      if (searchTerm != null && searchTerm.isNotEmpty) {
        sql +=
            ' WHERE name LIKE :term OR barcode LIKE :term OR alias LIKE :term';
        params['term'] = '%$searchTerm%';
      }

      final results = await _dbService.query(sql, params);
      if (results.isNotEmpty) {
        final val = results.first['count'];
        if (val == null) return 0;
        if (val is int) return val;
        if (val is String) return int.tryParse(val) ?? 0;
        // In case of BigInt or other types
        return int.tryParse(val.toString()) ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('Error fetching product count: $e');
      return 0;
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

  Future<void> updateProductBarcodes(
      int productId, List<ProductBarcode> barcodes) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // 1. Delete existing (Simplest strategy for linkage tables)
      await _dbService.execute(
          'DELETE FROM product_barcode WHERE productId = :id',
          {'id': productId});

      // 2. Insert new
      if (barcodes.isNotEmpty) {
        // Bulk insert or loop? Loop is generic enough.
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
    } catch (e) {
      debugPrint('Error updating product barcodes: $e');
      rethrow;
    }
  }

  Future<List<Product>> getLowStockProducts({int limit = 50}) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // Find products where stock <= reorderPoint
      // Also respect trackStock = 1
      final results = await _dbService.query(
          'SELECT * FROM product WHERE trackStock = 1 AND stockQuantity <= reorderPoint ORDER BY stockQuantity ASC LIMIT :limit',
          {'limit': limit});
      return results.map((row) => Product.fromJson(row)).toList();
    } catch (e) {
      debugPrint('Error fetching low stock: $e');
      return [];
    }
  }

  // --- Inventory Analysis Data ---
  Future<List<Map<String, dynamic>>> getInventoryPerformance(
      {int days = 30}) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final dateThreshold =
          DateTime.now().subtract(Duration(days: days)).toIso8601String();

      // Join Product with OrderItems (filtered by date)
      // We want: Product Name, Current Stock, Reorder Point, Units Sold in last 30 days, Last Sale Date
      final sql = '''
        SELECT 
          p.id, 
          p.name, 
          p.stockQuantity, 
          p.reorderPoint,
          COALESCE(SUM(oi.quantity), 0) as soldQty,
          MAX(o.createdAt) as lastSaleDate
        FROM product p
        LEFT JOIN orderitem oi ON p.id = oi.productId
        LEFT JOIN `order` o ON oi.orderId = o.id AND o.createdAt >= :date AND o.status = 'COMPLETED'
        GROUP BY p.id, p.name, p.stockQuantity, p.reorderPoint
        ORDER BY soldQty DESC;
      ''';

      return await _dbService.query(sql, {'date': dateThreshold});
    } catch (e) {
      debugPrint('Error fetching inventory performance: $e');
      return [];
    }
  }
}

// Top-level function for compute
List<Product> _parseProductList(List<Map<String, dynamic>> rows) {
  return rows.map((row) => Product.fromJson(row)).toList();
}
