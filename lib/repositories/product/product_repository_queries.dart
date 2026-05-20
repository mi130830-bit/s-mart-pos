part of '../product_repository.dart';

extension ProductRepositoryQueries on ProductRepository {
  Future<List<Product>> getAllProducts({bool forceRefresh = false}) async {
    if (!_dbService.isConnected()) {
      try {
        await _dbService.connect();
      } catch (_) {}
    }

    if (_dbService.isConnected()) {
      try {
        final rows =
            await _dbService.query('SELECT * FROM product WHERE isActive = 1');
        final products = rows.map((r) => Product.fromJson(r)).toList();

        await _isar.writeTxn(() async {
          for (var product in products) {
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
          }
        });

        return products;
      } catch (e) {
        debugPrint('⚠️ [getAllProducts] MySQL failed, falling back to Isar: $e');
      }
    }

    try {
      final collection = await _isar.productCollections.where().findAll();
      if (collection.isNotEmpty) {
        debugPrint(
            '📦 [getAllProducts] Using Isar cache (${collection.length} products) — offline mode');
        return collection.map(_mapToProduct).toList();
      }
    } catch (e) {
      debugPrint('⚠️ [getAllProducts] Isar fallback failed: $e');
    }

    return [];
  }

  Future<List<Product>> getAllProductsLight() async {
    return getAllProducts();
  }

  Future<Product?> getProductById(int id, {bool forceRefresh = false}) async {
    try {
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
          
          final enhanced = await _applyProductEnhancements([p]);
          final finalProduct = enhanced.isNotEmpty ? enhanced.first : p;

          await _saveToIsar(finalProduct);
          return finalProduct;
        }
      }

      if (!forceRefresh) {
        final p = await _isar.productCollections
            .filter()
            .remoteIdEqualTo(id)
            .findFirst();
        if (p != null) return _mapToProduct(p);
      }

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
      List<Product> results = [];
      List<int> remainingIds = List.from(ids);

      if (!_dbService.isConnected()) {
        try {
          await _dbService.connect();
        } catch (_) {}
      }

      if (_dbService.isConnected()) {
        try {
          final idsStr = remainingIds.join(',');
          final rows = await _dbService
              .query('SELECT * FROM product WHERE id IN ($idsStr)');
          final fromMySql = rows.map((r) => Product.fromJson(r)).toList();
          
          final enhanced = await _applyProductEnhancements(fromMySql);
          
          for (var p in enhanced) {
            results.add(p);
            remainingIds.remove(p.id);
            await _saveToIsar(p);
          }
        } catch (e) {
          debugPrint('MySQL Batch Fetch Error: $e');
        }
      }

      if (remainingIds.isNotEmpty) {
        final fromIsar = await _isar.productCollections
            .filter()
            .anyOf(remainingIds, (q, int id) => q.remoteIdEqualTo(id))
            .findAll();
        results.addAll(fromIsar.map(_mapToProduct));
      }

      return results;
    } catch (e) {
      debugPrint('Error batch fetching: $e');
      return [];
    }
  }

  Future<List<Product>> getProductsByBarcodes(List<String> barcodes) async {
    if (barcodes.isEmpty) return [];
    try {
      List<Product> results = [];
      List<String> remainingBarcodes = List.from(barcodes);

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
        
        final enhanced = await _applyProductEnhancements(fromMySql);
        
        for (var p in enhanced) {
          results.add(p);
          remainingBarcodes.remove(p.barcode);
          await _saveToIsar(p);
        }
      }

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

  Future<List<Product>> getProductsPaginated(int page, int pageSize,
      {String? searchTerm,
      int? productTypeId,
      ProductSortOption sortOption = ProductSortOption.recent}) async {
    try {
      if (!_dbService.isConnected()) await _dbService.connect();

      String sql = 'SELECT * FROM product WHERE isActive = 1';
      Map<String, dynamic> params = {};

      if (searchTerm != null && searchTerm.isNotEmpty) {
        sql +=
            ' AND (name LIKE :term OR barcode LIKE :term OR alias LIKE :term)';
        params['term'] = '%$searchTerm%';
        params['exactTerm'] = searchTerm;
        params['startTerm'] = '$searchTerm%';
      }

      if (productTypeId != null && productTypeId > 0) {
        sql += ' AND productType = :typeId';
        params['typeId'] = productTypeId;
      }

      if (searchTerm != null && searchTerm.isNotEmpty) {
        sql += '''
 ORDER BY
   CASE
     WHEN barcode = :exactTerm THEN 0
     WHEN name = :exactTerm    THEN 1
     WHEN name LIKE :startTerm THEN 2
     ELSE 3
   END ASC,
   LENGTH(name) ASC,
   name ASC
 LIMIT :limit OFFSET :offset''';
      } else if (sortOption == ProductSortOption.nameAsc) {
        sql += ' ORDER BY LENGTH(name) ASC, name ASC LIMIT :limit OFFSET :offset';
      } else if (sortOption == ProductSortOption.stockAsc) {
        sql +=
            ' ORDER BY stockQuantity ASC, name ASC LIMIT :limit OFFSET :offset';
      } else if (sortOption == ProductSortOption.stockDesc) {
        sql +=
            ' ORDER BY stockQuantity DESC, name ASC LIMIT :limit OFFSET :offset';
      } else {
        sql += ' ORDER BY id DESC LIMIT :limit OFFSET :offset';
      }

      params['limit'] = pageSize;
      params['offset'] = (page - 1) * pageSize;

      final rows = await _dbService.query(sql, params);

      List<Product> products =
          rows.map((row) => Product.fromJson(row)).toList();

      if (products.isNotEmpty) {
        final productIds = products.map((p) => p.id).toList();

        if (productIds.isNotEmpty) {
          products = await _applyProductEnhancements(products);
        }
      }

      if (products.isNotEmpty || (page == 1 && products.isEmpty)) {
        return products;
      }
    } catch (e) {
      debugPrint('⚠️ Online Fetch Failed: $e. Falling back to Cache...');
    }

    try {
      QueryBuilder<ProductCollection, ProductCollection, QAfterFilterCondition>
          query;

      if (searchTerm != null && searchTerm.isNotEmpty) {
        query = _isar.productCollections
            .filter()
            .nameContains(searchTerm, caseSensitive: false)
            .or()
            .barcodeContains(searchTerm, caseSensitive: false);
      } else {
        query = _isar.productCollections.filter().idGreaterThan(0);
      }

      QueryBuilder<ProductCollection, ProductCollection, QAfterSortBy>
          sortedQuery;

      if (sortOption == ProductSortOption.nameAsc) {
        sortedQuery = query.sortByName();
      } else if (sortOption == ProductSortOption.stockAsc) {
        sortedQuery = query.sortByStock().thenByName();
      } else if (sortOption == ProductSortOption.stockDesc) {
        sortedQuery = query.sortByStockDesc().thenByName();
      } else {
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
    return getProductsPaginated(page, pageSize,
        searchTerm: searchTerm,
        productTypeId: null,
        sortOption: sortOption);
  }

  Future<int> getProductCount({String? searchTerm, int? productTypeId}) async {
    try {
      if (!_dbService.isConnected()) await _dbService.connect();

      String sql = 'SELECT COUNT(*) as count FROM product WHERE isActive = 1';
      Map<String, dynamic> params = {};

      if (searchTerm != null && searchTerm.isNotEmpty) {
        sql +=
            ' AND (name LIKE :term OR barcode LIKE :term OR alias LIKE :term)';
        params['term'] = '%$searchTerm%';
      }

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

  Future<List<Product>> getRecentProducts(int limit) async {
    try {
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

  Product _mapToProduct(ProductCollection p) {
    return Product(
      id: p.remoteId ?? p.id,
      barcode: p.barcode,
      name: p.name,
      retailPrice: p.price,
      costPrice: p.costPrice ?? 0,
      stockQuantity: p.stock.toDouble(),
      imageUrl: p.imagePath,
      categoryId: int.tryParse(p.categoryId ?? '0'),
      productType: 0,
      trackStock: true,
      allowPriceEdit: false,
      points: 0,
      isActive: true,
      isWarehouseItem: false,
    );
  }

  Future<List<Product>> _applyProductEnhancements(List<Product> products) async {
    if (products.isEmpty) return products;
    if (!_dbService.isConnected()) return products;

    try {
      final productIds = products.map((p) => p.id).toList();
      final idsStr = productIds.join(',');

      final compSql = '''
         SELECT pc.parent_product_id, pc.quantity, p.stockQuantity as child_stock
         FROM product_components pc
         JOIN product p ON pc.child_product_id = p.id
         WHERE pc.parent_product_id IN ($idsStr)
       ''';

      final comps = await _dbService.query(compSql);

      Map<int, List<Map<String, dynamic>>> parentComps = {};
      for (var c in comps) {
        int pid = int.tryParse(c['parent_product_id'].toString()) ?? 0;
        if (!parentComps.containsKey(pid)) parentComps[pid] = [];
        parentComps[pid]!.add(c);
      }

      List<Product> fixedProducts = [];
      for (var p in products) {
        if (parentComps.containsKey(p.id)) {
          final myComps = parentComps[p.id]!;
          double maxCraftable = double.infinity;

          for (var c in myComps) {
            double req = double.tryParse(c['quantity'].toString()) ?? 0;
            double stock = double.tryParse(c['child_stock'].toString()) ?? 0;

            if (req > 0) {
              double canMake = stock / req;
              if (canMake < maxCraftable) maxCraftable = canMake;
            }
          }

          if (maxCraftable == double.infinity) maxCraftable = 0;
          fixedProducts.add(p.copyWith(
            stockQuantity: maxCraftable,
            hasComponents: true,
          ));
        } else {
          fixedProducts.add(p);
        }
      }
      products = fixedProducts;

      final tiersSql = 'SELECT DISTINCT product_id as productId FROM product_price_tiers WHERE product_id IN ($idsStr)';
      final tiersRows = await _dbService.query(tiersSql);
      final Set<int> tierProductIds = tiersRows.map((r) => int.tryParse(r['productId'].toString()) ?? 0).toSet();

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
      debugPrint('Error applying product enhancements: $e');
    }

    return products;
  }
}
