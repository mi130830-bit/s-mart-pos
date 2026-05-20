part of '../product_repository.dart';

extension ProductRepositoryMutations on ProductRepository {
  Future<int> saveProduct(Product product) async {
    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }

    try {
      int savedId = 0;
      if (product.id == 0) {
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
        params.remove('id');

        final result = await _dbService.execute(sql, params);
        savedId = result.lastInsertID.toInt();
      } else {
        return await _updateProduct(product);
      }

      final savedProduct = product.copyWith(id: savedId);
      await _saveToIsar(savedProduct);

      return savedId;
    } catch (e) {
      debugPrint('Error saving product: $e');
      return 0;
    }
  }

  Future<int> _updateProduct(Product product) async {
    try {
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

      await _activityRepo.log(
        action: 'UPDATE_PRODUCT',
        details: 'แก้ไขสินค้า: ${product.name} (ID: ${product.id})',
      );

      await _saveToIsar(product);

      return product.id;
    } catch (e) {
      debugPrint('Error updating product: $e');
      rethrow;
    }
  }

  Future<int> addProduct(Product product) async {
    return await saveProduct(product);
  }

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
      'warehouse': product.isWarehouseItem ? 1 : 0,
    };
  }

  Future<void> _saveToIsar(Product product) async {
    try {
      await _isar.writeTxn(() async {
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
        p.stock = product.stockQuantity.toInt();
        p.imagePath = product.imageUrl;
        p.categoryId = product.categoryId?.toString();
        p.lastUpdated = DateTime.now();

        await _isar.productCollections.put(p);
      });
    } catch (e) {
      debugPrint('⚠️ Failed to update Isar cache: $e');
    }
  }
}
