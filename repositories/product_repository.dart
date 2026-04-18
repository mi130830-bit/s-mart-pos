import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../services/local_db_service.dart';
import '../models/schema/product_collection.dart';
import '../services/mysql_service.dart';
import '../services/api_service.dart';
import '../models/product_barcode.dart';
import '../models/product.dart';
import './activity_repository.dart';
import '../services/telegram_service.dart';

enum ProductSortOption { recent, nameAsc, stockAsc, stockDesc }

class ProductRepository {
  final MySQLService _dbService = MySQLService();
  final ActivityRepository _activityRepo = ActivityRepository();

  // ตัวช่วยเข้าถึง Isar (Local DB)
  Isar get _isar => LocalDbService().db;

  Future<List<Product>> getAllProducts({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh) {
        // อ่านจาก Isar โหมดปกติ (ถ้ามี Cache ก็ใช้เลย)
        final collection = await _isar.productCollections.where().findAll();
        if (collection.isNotEmpty) {
          return collection.map(_mapToProduct).toList();
        }
      }

      // ถ้า Isar ว่าง ให้ลองดึงจาก MySQL
      if (!_dbService.isConnected()) {
        try {
          await _dbService.connect();
        } catch (_) {}
      }

      if (_dbService.isConnected()) {
        final rows =
            await _dbService.query('SELECT * FROM product WHERE isActive = 1');
        // อาจจะบันทึกลง Isar ด้วยเพื่อซ่อมแซมตัวเอง (Self-heal)
        final products = rows.map((r) => Product.fromJson(r)).toList();

        // ✅ Batch Save Optimization
        await _isar.writeTxn(() async {
          for (var product in products) {
            // Find existing schema object by remoteId
            final existing = await _isar.productCollections
                .filter()
                .remoteIdEqualTo(product.id)
                .findFirst();
            final p = existing ?? ProductCollection();

            p.remoteId = product.id;
            p.barcode = product.barcode ?? '';
            p.name = product.name;
            p.price = product.retailPrice;
            p.costPrice = product.costPrice;
            p.stock =
                product.stockQuantity.toInt(); // Isar stock is int per schema
            p.imagePath = product.imageUrl;
            p.categoryId = product.categoryId?.toString();
            p.lastUpdated = DateTime.now();

            await _isar.productCollections.put(p);
          }
        });

        return products;
      }

      return [];
    } catch (e) {
      debugPrint('Error fetching products from Isar/MySQL: $e');
      return [];
    }
  }

  // เวอร์ชันเบา (เหมือนกับตัวปกติสำหรับ Isar เพราะเร็วอยู่แล้ว)
  Future<List<Product>> getAllProductsLight() async {
    return getAllProducts();
  }

  // ดึงรหัสบาร์โค้ดเพิ่มเติม (สำหรับสินค้าหลายหน่วย)

  Future<List<Map<String, dynamic>>> getAllProductBarcodes() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      return await _dbService.query('SELECT * FROM product_barcode');
    } catch (e) {
      debugPrint('Error fetching product barcodes: $e');
      return [];
    }
  }

  Future<Product?> getProductById(int id, {bool forceRefresh = false}) async {
    try {
      // ✅ Strategy: Online-First for Slaves (Always get latest price if connected)
      if (!_dbService.isConnected()) {
        try {
          await _dbService.connect();
        } catch (_) {}
      }

      if (_dbService.isConnected()) {
        final rows = await _dbService
            .query('SELECT * FROM product WHERE id = :id', {'id': id});
        if (rows.isNotEmpty) {
          final p = Product.fromJson(rows.first);
          // ✅ Self-heal: Update Isar cache with latest info from MySQL
          await _saveToIsar(p);
          return p;
        }
      }

      // 2. สำรองผ่าน Isar (ถ้าออฟไลน์ หรือ MySQL ไม่พบ)
      if (!forceRefresh) {
        final p = await _isar.productCollections
            .filter()
            .remoteIdEqualTo(id)
            .findFirst();
        if (p != null) return _mapToProduct(p);
      }

      // 3. สำรองผ่าน API (ถ้ามีระบุไว้)
      try {
        final response = await ApiService().get('/products/id/$id');
        final p = Product.fromJson(response);
        await _saveToIsar(p);
        return p;
      } catch (_) {}

      return null;
    } catch (e) {
      debugPrint('⚠️ ProductById Error: $e');
      return null;
    }
  }

  Future<List<Product>> getProductsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    try {
      // 1. Isar Batch
      final fromIsar = await _isar.productCollections
          .filter()
          .anyOf(ids, (q, int id) => q.remoteIdEqualTo(id))
          .findAll();

      List<Product> results = fromIsar.map(_mapToProduct).toList();

      // 2. Fallback Missing (If critical and online?)
      if (results.length < ids.length) {
        final foundIds = results.map((p) => p.id).toSet();
        final missingIds = ids.where((id) => !foundIds.contains(id)).toList();

        if (missingIds.isNotEmpty) {
          if (!_dbService.isConnected()) {
            try {
              await _dbService.connect();
            } catch (e) {
              debugPrint('⚠️ Auto-connect failed in batch fetch: $e');
            }
          }

          if (_dbService.isConnected()) {
            try {
              final idsStr = missingIds.join(',');
              final rows = await _dbService
                  .query('SELECT * FROM product WHERE id IN ($idsStr)');
              results.addAll(rows.map((r) => Product.fromJson(r)));
            } catch (e) {
              debugPrint('MySQL Batch Fallback Error: $e');
            }
          }
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error batch fetching: $e');
      return [];
    }
  }

  // ✅ New Batch Barcode Lookup (Optimized for QuickMenu)
  Future<List<Product>> getProductsByBarcodes(List<String> barcodes) async {
    if (barcodes.isEmpty) return [];
    try {
      List<Product> results = [];
      List<String> remainingBarcodes = List.from(barcodes);

      // ✅ 1. Online-First (MySQL) เพื่อให้ได้ราคาล่าสุดเสมอ
      if (!_dbService.isConnected()) {
        try {
          await _dbService.connect();
        } catch (_) {}
      }

      if (_dbService.isConnected()) {
        final codesStr = remainingBarcodes.map((c) => "'$c'").join(',');
        final rows = await _dbService
            .query("SELECT * FROM product WHERE barcode IN ($codesStr)");
        final fromMySql = rows.map((r) => Product.fromJson(r)).toList();
        
        for (var p in fromMySql) {
          results.add(p);
          remainingBarcodes.remove(p.barcode);
          // ✅ Self-heal cache
          await _saveToIsar(p);
        }
      }

      // 2. Fallback to Isar (ถ้าออฟไลน์ หรือ MySQL ไม่พบบางตัว)
      if (remainingBarcodes.isNotEmpty) {
        final fromIsar = await _isar.productCollections
            .filter()
            .anyOf(remainingBarcodes, (q, String bc) => q.barcodeEqualTo(bc))
            .findAll();
        results.addAll(fromIsar.map(_mapToProduct));
      }

      return results;
    } catch (e) {
      debugPrint('Error batch fetching barcodes: $e');
      return [];
    }
  }

  Future<void> initTable() async {
    await ensureImageUrlColumn();
  }

  Future<void> ensureImageUrlColumn() async {
    // Migration logic usually handled by Isar schema automatically
  }

  Future<int> saveProduct(Product product) async {
    // Strategy: Write to API/MySQL -> Then Cache to Isar
    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }

    try {
      int savedId = 0;
      if (product.id == 0) {
        // ... (Keep existing INSERT logic for API/MySQL) ...
        // For brevity, I am keeping the logic but compacting it or reusing existing
        // Since I can't access `super`, I have to replicate the MySQL insert here?
        // Wait, I am REPLACING the file content, so I must provide the Full Implementation.

        // Insert Logic (MySQL)
        // Check for existing barcode
        if (product.barcode != null && product.barcode!.isNotEmpty) {
          final existing = await _dbService.query(
              'SELECT id FROM product WHERE barcode = :barcode',
              {'barcode': product.barcode});
          if (existing.isNotEmpty) {
            final val = existing.first['id'];
            final existingId =
                (val is int) ? val : int.tryParse(val.toString()) ?? 0;
            return await _updateProduct(product.copyWith(id: existingId));
          }
        }

        const sql = '''
          INSERT INTO product (
            barcode, name, alias, productType, categoryId, unitId, supplierId,
            costPrice, retailPrice, wholesalePrice, memberRetailPrice, memberWholesalePrice,
            vatType, allowPriceEdit, stockQuantity, trackStock,
            reorderPoint, overstockPoint, purchaseLimit, shelfLocation, warehousePattern,
            points, imageUrl, expiryDate, isActive, isWarehouseItem
          ) VALUES (
            :barcode, :name, :alias, :type, :catId, :unitId, :supId,
            :cost, :retail, :wholesale, :memRetail, :memWholesale,
            :vat, :allowEdit, :stock, :track,
            :reorder, :overstock, :limit, :shelf, :pattern,
            :points, :img, :expiry, :active, :warehouse
          )
        ''';
        final params = _buildParams(product);
        // Remove 'id' from params for INSERT
        params.remove('id');

        final result = await _dbService.execute(sql, params);
        savedId = result.lastInsertID.toInt();
      } else {
        return await _updateProduct(product);
      }

      // ✅ Update Isar Cache
      final savedProduct = product.copyWith(id: savedId);
      await _saveToIsar(savedProduct);

      return savedId;
    } catch (e) {
      debugPrint('Error saving product: $e');
      return 0; // Error
    }
  }

  Future<int> _updateProduct(Product product) async {
    try {
      // Update MySQL
      const sql = '''
        UPDATE product SET 
          barcode = :barcode, name = :name, alias = :alias, productType = :type,
          categoryId = :catId, unitId = :unitId, supplierId = :supId,
          costPrice = :cost, retailPrice = :retail, wholesalePrice = :wholesale,
          memberRetailPrice = :memRetail, memberWholesalePrice = :memWholesale,
          vatType = :vat, allowPriceEdit = :allowEdit, stockQuantity = :stock,
          trackStock = :track, reorderPoint = :reorder, overstockPoint = :overstock,
          purchaseLimit = :limit, shelfLocation = :shelf, warehousePattern = :pattern,
          points = :points, imageUrl = :img, expiryDate = :expiry, isActive = :active, isWarehouseItem = :warehouse
        WHERE id = :id
      ''';
      await _dbService.execute(sql, _buildParams(product));

      // Log Update
      await _activityRepo.log(
        action: 'UPDATE_PRODUCT',
        details: 'แก้ไขสินค้า: ${product.name} (ID: ${product.id})',
      );

      // ✅ Update Isar Cache
      await _saveToIsar(product);

      return product.id;
    } catch (e) {
      debugPrint('Error updating product: $e');
      rethrow;
    }
  }

  // Helper to construct params
  Map<String, dynamic> _buildParams(Product product) {
    return {
      'id': product.id,
      'barcode': (product.barcode != null && product.barcode!.isNotEmpty)
          ? ((product.barcode!.length > 50)
              ? product.barcode!.substring(0, 50)
              : product.barcode)
          : null,
      'name': product.name.length > 200
          ? product.name.substring(0, 200)
          : product.name,
      'alias': (product.alias ?? '').limit(100),
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
      'active': product.isActive ? 1 : 0,
      'warehouse': product.isWarehouseItem ? 1 : 0, // ✅ New Param
    };
  }

  Future<void> _saveToIsar(Product product) async {
    try {
      await _isar.writeTxn(() async {
        // Find existing schema object by remoteId
        final existing = await _isar.productCollections
            .filter()
            .remoteIdEqualTo(product.id)
            .findFirst();
        final p = existing ?? ProductCollection();

        p.remoteId = product.id;
        p.barcode = product.barcode ?? '';
        p.name = product.name;
        p.price = product.retailPrice;
        p.costPrice = product.costPrice;
        p.stock = product.stockQuantity.toInt(); // Isar stock is int per schema
        p.imagePath = product.imageUrl;
        p.categoryId = product.categoryId?.toString();
        p.lastUpdated = DateTime.now();

        await _isar.productCollections.put(p);
      });
    } catch (e) {
      debugPrint('⚠️ Failed to update Isar cache: $e');
    }
  }

  Future<bool> deleteProduct(int id, {String reason = ''}) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // 0. Fetch info for notification (before delete)
      String productName = 'Unknown';
      try {
        final p = await getProductById(id);
        if (p != null) productName = p.name;
      } catch (_) {}

      // 1. Soft Delete MySQL
      await _dbService.execute(
        'UPDATE product SET isActive = 0, deleteReason = :reason, deletedAt = NOW() WHERE id = :id',
        {'id': id, 'reason': reason},
      );

      // 2. Delete/Hide in Isar (Ideally update isActive, but deletion is safer for query filtering if isActive not in schema)
      // Actually schema HAS isActive defaulting to true.
      await _isar.writeTxn(() async {
        // Option A: Delete from Isar (Force re-fetch if restored) -> Simple
        await _isar.productCollections.filter().remoteIdEqualTo(id).deleteAll();
      });

      // Log Delete
      await _activityRepo.log(
          action: 'DELETE_PRODUCT',
          details: 'ลบสินค้า ID: $id (Soft Delete) สาเหตุ: $reason');

      // ✅ Notify Telegram
      if (await TelegramService()
          .shouldNotify(TelegramService.keyNotifyDeleteProduct)) {
        TelegramService().sendMessage('🗑️ *ลบสินค้า* (Delete Product)\n'
            '━━━━━━━━━━━━━━━━━━\n'
            '📦 สินค้า: $productName\n'
            '🆔 รหัส: $id\n'
            '📝 สาเหตุ: $reason\n'
            '━━━━━━━━━━━━━━━━━━');
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }

  Future<bool> restoreProduct(int id) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      await _dbService.execute(
        'UPDATE product SET isActive = 1, deletedAt = NULL, deleteReason = NULL WHERE id = :id',
        {'id': id},
      );

      // Log Restore
      await _activityRepo.log(
          action: 'RESTORE_PRODUCT', details: 'กู้คืนสินค้า ID: $id');

      // Refresh Isar by fetching specific product again (Self-heal)
      final p = await getProductById(id);
      if (p != null) await _saveToIsar(p);

      return true;
    } catch (e) {
      debugPrint('Error restoring product: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getDeletedProducts() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final sql = '''
         SELECT * FROM product 
         WHERE isActive = 0 
           AND deletedAt IS NOT NULL 
           AND deletedAt >= DATE_SUB(NOW(), INTERVAL 15 DAY)
         ORDER BY deletedAt DESC
       ''';
      return await _dbService.query(sql);
    } catch (e) {
      debugPrint('Error fetching deleted products: $e');
      return [];
    }
  }

  Future<void> cleanOldDeletedProducts() async {
    // Auto-Empty Recycle Bin > 15 Days
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // ✅ Update: Only delete products that are NOT used in stockledger or orderitem
      // to avoid Foreign Key Constraint Fails [1451]
      final sql = '''
        DELETE FROM product 
        WHERE isActive = 0 
          AND deletedAt < DATE_SUB(NOW(), INTERVAL 15 DAY)
          AND id NOT IN (SELECT DISTINCT productId FROM stockledger)
          AND id NOT IN (SELECT DISTINCT productId FROM orderitem)
      ''';
      final res = await _dbService.execute(sql);
      if (res.affectedRows.toInt() > 0) {
        debugPrint(
            '🧹 Auto-Cleaned ${res.affectedRows} old products (Unused ones only).');
        await _activityRepo.log(
            action: 'AUTO_CLEAN',
            details:
                'ลบสินค้าถาวร ${res.affectedRows} รายการ (เฉพาะที่ไม่ถูกใช้งาน)');
      }
    } catch (e) {
      debugPrint('Error auto-cleaning products: $e');
    }
  }

  Future<int> addProduct(Product product) async {
    return await saveProduct(product);
  }

  Future<List<Product>> getRecentProducts(int limit) async {
    try {
      // final collection =
      // await _isar.productCollections.where().limit(limit).findAll();
      // Sort by id desc (proxy by lastUpdated or actually Isar ID?)
      // Isar ID is auto-increment local. Remote ID is also indicative.
      // Let's sort by remoteId desc
      // But Isar query `.sortByRemoteIdDesc()` is better.
      // Re-query:
      final sorted = await _isar.productCollections
          .where()
          .sortByRemoteIdDesc()
          .limit(limit)
          .findAll();
      return sorted.map(_mapToProduct).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> updateStock(int productId, double quantityChange) async {
    // Critical: Update Isar AND MySQL
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      await _dbService.execute(
        'UPDATE product SET stockQuantity = stockQuantity + :change WHERE id = :id',
        {'change': quantityChange, 'id': productId},
      );

      // Update Isar
      await _isar.writeTxn(() async {
        final p = await _isar.productCollections
            .filter()
            .remoteIdEqualTo(productId)
            .findFirst();
        if (p != null) {
          p.stock = (p.stock + quantityChange).toInt();
          await _isar.productCollections.put(p);
        }
      });
      return true;
    } catch (e) {
      debugPrint('Error updating stock: $e');
      return false;
    }
  }

  Future<List<Product>> getProductsPaginated(int page, int pageSize,
      {String? searchTerm,
      int? productTypeId, // ✅ Added Filter
      ProductSortOption sortOption = ProductSortOption.recent}) async {
    // ✅ กลยุทธ์ Online-First (ตามที่ผู้ใช้ร้องขอ)
    // 1. ลองดึงจาก MySQL ก่อน (ข้อมูลล่าสุด Realtime)
    // 2. ถ้าไม่ได้ ให้ดึงจาก Isar (Offline)

    try {
      if (!_dbService.isConnected()) await _dbService.connect();

      // สร้าง Query สำหรับ MySQL
      String sql = 'SELECT * FROM product WHERE isActive = 1';
      Map<String, dynamic> params = {};

      if (searchTerm != null && searchTerm.isNotEmpty) {
        sql +=
            ' AND (name LIKE :term OR barcode LIKE :term OR alias LIKE :term)';
        params['term'] = '%$searchTerm%';
      }

      // ✅ Filter by Type
      if (productTypeId != null && productTypeId > 0) {
        sql += ' AND productType = :typeId';
        params['typeId'] = productTypeId;
      }

      // เรียงตามชื่อ ก-ฮ (Name ASC) เพื่อให้หาสินค้าง่ายขึ้น
      // เรียงตามเงื่อนไขที่กำหนด
      if (sortOption == ProductSortOption.nameAsc) {
        sql += ' ORDER BY name ASC LIMIT :limit OFFSET :offset';
      } else if (sortOption == ProductSortOption.stockAsc) {
        sql +=
            ' ORDER BY stockQuantity ASC, name ASC LIMIT :limit OFFSET :offset';
      } else if (sortOption == ProductSortOption.stockDesc) {
        sql +=
            ' ORDER BY stockQuantity DESC, name ASC LIMIT :limit OFFSET :offset';
      } else {
        // Recent (Latest) -> Newest ID first
        sql += ' ORDER BY id DESC LIMIT :limit OFFSET :offset';
      }

      params['limit'] = pageSize;
      params['offset'] = (page - 1) * pageSize;

      final rows = await _dbService.query(sql, params);

      List<Product> products =
          rows.map((row) => Product.fromJson(row)).toList();

      // ✅ คำนวณสต็อกเสมือนสำหรับสินค้าประกอบ (Composite / Linkage)
      if (products.isNotEmpty) {
        final productIds = products.map((p) => p.id).toList();

        // ดึงข้อมูลส่วนประกอบของสินค้าเหล่านี้
        if (productIds.isNotEmpty) {
          final idsStr = productIds.join(',');
          final compSql = '''
             SELECT pc.parent_product_id, pc.quantity, p.stockQuantity as child_stock
             FROM product_components pc
             JOIN product p ON pc.child_product_id = p.id
             WHERE pc.parent_product_id IN ($idsStr)
           ''';

          try {
            final comps = await _dbService.query(compSql);

            // จัดกลุ่มตาม Parent ID
            Map<int, List<Map<String, dynamic>>> parentComps = {};
            for (var c in comps) {
              int pid = int.tryParse(c['parent_product_id'].toString()) ?? 0;
              if (!parentComps.containsKey(pid)) parentComps[pid] = [];
              parentComps[pid]!.add(c);
            }

            // คำนวณสต็อกที่สามารถขายได้ (Craftable Stock)
            List<Product> fixedProducts = [];
            for (var p in products) {
              if (parentComps.containsKey(p.id)) {
                // เป็นสินค้าประกอบ
                final myComps = parentComps[p.id]!;
                double maxCraftable = double.infinity;

                for (var c in myComps) {
                  double req = double.tryParse(c['quantity'].toString()) ?? 0;
                  double stock =
                      double.tryParse(c['child_stock'].toString()) ?? 0;

                  if (req > 0) {
                    double canMake = stock / req;
                    if (canMake < maxCraftable) maxCraftable = canMake;
                  }
                }

                if (maxCraftable == double.infinity) maxCraftable = 0;
                fixedProducts.add(p.copyWith(
                  stockQuantity: maxCraftable,
                  hasComponents: true, // ✅ Set flag
                ));
              } else {
                fixedProducts.add(p);
              }
            }
            products = fixedProducts;
          } catch (e) {
            debugPrint('Error calculating composite stock: $e');
            // กรณี Error ให้ใช้ข้อมูลเดิมไปก่อน
          }

          // ✅ NEW: Check Tiers and Extra Units in Batch
          try {
            // Price Tiers
            final tiersSql = 'SELECT DISTINCT product_id as productId FROM product_price_tiers WHERE product_id IN ($idsStr)';
            final tiersRows = await _dbService.query(tiersSql);
            final Set<int> tierProductIds = tiersRows.map((r) => int.tryParse(r['productId'].toString()) ?? 0).toSet();

            // Extra Units (Barcodes)
            final bcSql = 'SELECT DISTINCT productId FROM product_barcode WHERE productId IN ($idsStr)';
            final bcRows = await _dbService.query(bcSql);
            final Set<int> bcProductIds = bcRows.map((r) => int.tryParse(r['productId'].toString()) ?? 0).toSet();

            if (tierProductIds.isNotEmpty || bcProductIds.isNotEmpty) {
              products = products.map((p) {
                return p.copyWith(
                  hasPriceTiers: tierProductIds.contains(p.id),
                  hasExtraUnits: bcProductIds.contains(p.id),
                );
              }).toList();
            }
          } catch (e) {
            debugPrint('Error checking tiers/barcodes batch: $e');
          }
        }
      }

      // ถ้ามีข้อมูล ให้คืนค่ากลับไป
      if (products.isNotEmpty || (page == 1 && products.isEmpty)) {
        return products;
      }
    } catch (e) {
      debugPrint('⚠️ Online Fetch Failed: $e. Falling back to Cache...');
    }

    // ⚠️ Fallback: Offline Cache (Isar)
    try {
      // Create Base Query
      QueryBuilder<ProductCollection, ProductCollection, QAfterFilterCondition>
          query;

      if (searchTerm != null && searchTerm.isNotEmpty) {
        query = _isar.productCollections
            .filter()
            .nameContains(searchTerm, caseSensitive: false)
            .or()
            .barcodeContains(searchTerm, caseSensitive: false);
      } else {
        query = _isar.productCollections.filter().idGreaterThan(0); // All
      }

      // Apply Sorting & Pagination
      QueryBuilder<ProductCollection, ProductCollection, QAfterSortBy>
          sortedQuery;

      if (sortOption == ProductSortOption.nameAsc) {
        sortedQuery = query.sortByName();
      } else if (sortOption == ProductSortOption.stockAsc) {
        sortedQuery = query.sortByStock().thenByName();
      } else if (sortOption == ProductSortOption.stockDesc) {
        sortedQuery = query.sortByStockDesc().thenByName();
      } else {
        // Recent
        sortedQuery = query.sortByRemoteIdDesc();
      }

      return await sortedQuery
          .offset((page - 1) * pageSize)
          .limit(pageSize)
          .findAll()
          .then((list) => list.map(_mapToProduct).toList());
    } catch (e) {
      debugPrint('⚠️ Isar Read Error: $e');
      return [];
    }
  }

  Future<List<Product>> getProductsPaginatedLight(int page, int pageSize,
      {String? searchTerm,
      ProductSortOption sortOption = ProductSortOption.recent}) async {
    // Isar is fast, no need for "Light" columns projection optimization usually
    return getProductsPaginated(page, pageSize,
        searchTerm: searchTerm,
        productTypeId: null, // Default
        sortOption: sortOption);
  }

  Future<int> getProductCount({String? searchTerm, int? productTypeId}) async {
    // ✅ 1. Try MySQL First (for consistent pagination with getProductsPaginated)
    try {
      if (!_dbService.isConnected()) await _dbService.connect();

      String sql = 'SELECT COUNT(*) as count FROM product WHERE isActive = 1';
      Map<String, dynamic> params = {};

      if (searchTerm != null && searchTerm.isNotEmpty) {
        sql +=
            ' AND (name LIKE :term OR barcode LIKE :term OR alias LIKE :term)';
        params['term'] = '%$searchTerm%'; // partial match
      }

      // ✅ Filter by Type
      if (productTypeId != null && productTypeId > 0) {
        sql += ' AND productType = :typeId';
        params['typeId'] = productTypeId;
      }

      final rows = await _dbService.query(sql, params);
      if (rows.isNotEmpty) {
        return int.tryParse(rows.first['count'].toString()) ?? 0;
      }
    } catch (e) {
      debugPrint('⚠️ MySQL Count Failed: $e. Falling back to Isar...');
    }

    // ⚠️ 2. Fallback: Isar
    if (searchTerm != null && searchTerm.isNotEmpty) {
      return await _isar.productCollections
          .filter()
          .nameContains(searchTerm, caseSensitive: false)
          .or()
          .barcodeContains(searchTerm, caseSensitive: false)
          .count();
    }
    return await _isar.productCollections.count();
  }

  Future<List<ProductBarcode>> getProductBarcodesByProductId(int id) async {
    // Keep MySQL for barcodes for now
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

  // ✅ New method for optimization
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
    // Keep MySQL
    if (!_dbService.isConnected()) await _dbService.connect();
    // ... (Keep existing implementation for brevity, or full replace) ...
    // Since I must replace, I insert the full logic:
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
    } catch (e) {
      rethrow;
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
    // Complex Join -> Keep MySQL
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

  // Mapper
  Product _mapToProduct(ProductCollection p) {
    return Product(
      id: p.remoteId ?? p.id, // Use remote ID if synced
      barcode: p.barcode,
      name: p.name,
      retailPrice: p.price,
      costPrice: p.costPrice ?? 0,
      stockQuantity: p.stock.toDouble(),
      imageUrl: p.imagePath,
      categoryId: int.tryParse(p.categoryId ?? '0'),
      // Defaults for fields missing in Isar schema (Phase 5 simplification)
      productType: 0, // 0 = standard
      trackStock: true,
      allowPriceEdit: false,
      points: 0,
      isActive: true, // Default true for Isar
      isWarehouseItem: false, // Isar Schema not updated yet
    );
  }
}

// Extension to substring safe
extension StringExt on String {
  String limit(int length) => length > length ? substring(0, length) : this;
}
