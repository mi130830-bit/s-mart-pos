import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../db_config.dart';
import '../env_config.dart';
import '../services/line_service.dart';
import '../middlewares/liff_auth_middleware.dart';
import '../services/line_identity_service.dart';
import '../services/member_tier_service.dart';
import '../services/online_order_service.dart';

class ShopController {
  final MemberTierService _memberTierService = MemberTierService();
  final OnlineOrderService _onlineOrderService = OnlineOrderService();

  Router get adminRouter {
    final router = Router();
    router.get('/featured', _getAdminFeatured);
    router.put('/featured', _saveAdminFeatured);
    router.get('/orders', _listOrders);
    router.put('/orders/<id>/status', _updateOrderStatus);
    return router;
  }

  Router get publicRouter {
    final router = Router();
    router.get('/info', _getShopInfo);
    router.get('/products', _getProducts);
    router.get('/categories', _getCategories);
    router.get('/featured', _getFeaturedProducts);
    router.get('/paint-lookup', _lookupPaintProduct);
    router.get('/metal-sheet-options', _getMetalSheetOptions);
    router.post('/phone-login', optionalLiffAuthMiddleware()(_phoneLogin));
    router.post('/register', optionalLiffAuthMiddleware()(_registerMember));
    router.post('/change-pin', optionalLiffAuthMiddleware()(_changePin));
    router.post('/orders', optionalLiffAuthMiddleware()(_createOrder));
    router.post('/checkout', optionalLiffAuthMiddleware()(_createOrder));
    return router;
  }

  Router get memberRouter {
    final router = Router();
    router.get('/me', _getCustomerProfile);
    router.get('/orders', _getMemberOrders);
    return router;
  }

  File _featuredConfigFile() {
    final writableFile = File(
      '${EnvConfig().writableDir}/shop/featured_config.json',
    );
    if (!writableFile.existsSync()) {
      writableFile.parent.createSync(recursive: true);
      final legacyFile = _legacyFeaturedConfigFile();
      if (legacyFile != null) {
        writableFile.writeAsStringSync(legacyFile.readAsStringSync());
      } else {
        writableFile.writeAsStringSync('[]');
      }
    }
    return writableFile;
  }

  File? _legacyFeaturedConfigFile() {
    final candidatePaths = [
      'backend/public/shop/featured_config.json',
      'public/shop/featured_config.json',
      '${Directory.current.path}/backend/public/shop/featured_config.json',
      '${Directory.current.path}/public/shop/featured_config.json',
    ];
    for (final path in candidatePaths) {
      final file = File(path);
      if (file.existsSync()) return file;
    }
    return null;
  }

  Map<String, dynamic> _readFeaturedConfig() {
    final defaultCategories = [
      {'id': 'sand_rock_cement', 'name': 'หิน ทราย ปูน', 'emoji': '🪨'},
      {'id': 'steel', 'name': 'เหล็ก', 'emoji': '🏗️'},
      {'id': 'pipe_pvc', 'name': 'ท่อ & PVC', 'emoji': '🚰'},
      {'id': 'electric', 'name': 'อุปกรณ์ไฟฟ้า', 'emoji': '⚡'},
      {'id': 'roof_tile', 'name': 'ไม้อัด & แผ่นบอร์ด', 'emoji': '🏠'},
      {'id': 'drainage', 'name': 'วงบ่อท่อระบายน้ำ', 'emoji': '🪨'},
      {'id': 'poles', 'name': 'เสา', 'emoji': '🏗️'},
      {'id': 'tools', 'name': 'เครื่องมือช่าง', 'emoji': '🔨'},
      {'id': 'fasteners', 'name': 'ตะปู+สกรู', 'emoji': '🔩'},
    ];

    try {
      final file = _featuredConfigFile();
      if (!file.existsSync()) {
        return {'categories': defaultCategories, 'items': []};
      }
      final content = file.readAsStringSync();
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        final rawCategories = decoded['categories'];
        final rawItems = decoded['items'];
        final List<Map<String, dynamic>> categories = [];
        if (rawCategories is List) {
          for (final c in rawCategories) {
            if (c is Map &&
                c['name'] != null &&
                c['name'].toString().trim().isNotEmpty) {
              categories.add({
                'id':
                    c['id']?.toString() ??
                    'cat_${DateTime.now().millisecondsSinceEpoch}',
                'name': c['name'].toString(),
                'emoji': c['emoji']?.toString() ?? '📦',
              });
            }
          }
        }
        final List<Map<String, dynamic>> items = [];
        if (rawItems is List) {
          for (final item in rawItems) {
            if (item is Map && item['productId'] != null) {
              items.add({
                'productId': item['productId'].toString(),
                'categoryId': item['categoryId']?.toString() ?? '',
                'categoryName': item['categoryName']?.toString() ?? '',
                'tag': item['tag']?.toString() ?? '⭐ สินค้าแนะนำ',
                'badgeColor': item['badgeColor']?.toString() ?? '#168a68',
              });
            }
          }
        }
        return {
          'categories': categories.isNotEmpty ? categories : defaultCategories,
          'items': items,
        };
      } else if (decoded is List) {
        final List<Map<String, dynamic>> items = [];
        final Map<String, String> categoryNames = {};
        for (final item in decoded) {
          if (item is Map && item['productId'] != null) {
            final cid = item['categoryId']?.toString() ?? '';
            final cname = item['categoryName']?.toString() ?? '';
            if (cid.isNotEmpty && cname.isNotEmpty) {
              categoryNames[cid] = cname;
            }
            items.add({
              'productId': item['productId'].toString(),
              'categoryId': cid,
              'categoryName': cname,
              'tag': item['tag']?.toString() ?? '⭐ สินค้าแนะนำ',
              'badgeColor': item['badgeColor']?.toString() ?? '#168a68',
            });
          }
        }
        final List<Map<String, dynamic>> categories = [];
        for (final defCat in defaultCategories) {
          categories.add(Map<String, dynamic>.from(defCat));
        }
        for (final entry in categoryNames.entries) {
          if (!categories.any((c) => c['id'] == entry.key)) {
            categories.add({
              'id': entry.key,
              'name': entry.value,
              'emoji': '📦',
            });
          }
        }
        return {'categories': categories, 'items': items};
      }
    } catch (e) {
      stderr.writeln('⚠️ Error reading featured config: $e');
    }
    return {'categories': defaultCategories, 'items': []};
  }

  bool _isAdmin(Request request) {
    final user = request.context['user'];
    if (user is! Map) return false;
    final role = user['role']?.toString().toLowerCase();
    return role == 'admin' ||
        role == 'manager' ||
        role == 'owner' ||
        role == 'cashier' ||
        role == 'staff' ||
        role == 'supervisor';
  }

  Future<Response> _getAdminFeatured(Request request) async {
    if (!_isAdmin(request)) {
      return Response.forbidden(
        jsonEncode({'status': 'error', 'message': 'Admin access required'}),
      );
    }
    try {
      final config = _readFeaturedConfig();
      final List rawItems = (config['items'] as List?) ?? [];

      if (rawItems.isNotEmpty) {
        final productIds = rawItems
            .map((it) => int.tryParse(it['productId']?.toString() ?? ''))
            .whereType<int>()
            .toList();

        if (productIds.isNotEmpty) {
          final conn = await DbConfig().connection;
          final idList = productIds.join(',');
          final productsRes = await conn.execute(
            'SELECT id, barcode, name, retailPrice, stockQuantity, imageUrl FROM product WHERE id IN ($idList)',
          );
          final Map<int, Map<String, dynamic>> productMap = {};
          for (var row in productsRes.rows) {
            final a = row.assoc();
            final id = int.parse(a['id']!);
            productMap[id] = a;
          }

          for (var it in rawItems) {
            final pid = int.tryParse(it['productId']?.toString() ?? '');
            if (pid != null && productMap.containsKey(pid)) {
              final p = productMap[pid]!;
              it['name'] = p['name'] ?? '';
              it['barcode'] = p['barcode'] ?? '';
              it['price'] =
                  double.tryParse(p['retailPrice']?.toString() ?? '0') ?? 0.0;
              it['retailPrice'] =
                  double.tryParse(p['retailPrice']?.toString() ?? '0') ?? 0.0;
              it['stockQuantity'] =
                  (double.tryParse(p['stockQuantity']?.toString() ?? '0') ??
                          0.0)
                      .toInt();
              it['imageUrl'] = p['imageUrl'] ?? '';
            }
          }
        }
      }

      return Response.ok(
        jsonEncode({'status': 'success', 'data': config}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<Response> _saveAdminFeatured(Request request) async {
    if (!_isAdmin(request)) {
      return Response.forbidden(
        jsonEncode({'status': 'error', 'message': 'Admin access required'}),
      );
    }
    try {
      final payload = await request.readAsString();
      final body = jsonDecode(payload);

      List<Map<String, dynamic>> cleanCategories = [];
      List<Map<String, dynamic>> cleanItems = [];

      if (body is Map) {
        final rawCategories = body['categories'];
        if (rawCategories is List) {
          for (final c in rawCategories) {
            if (c is Map &&
                c['name'] != null &&
                c['name'].toString().trim().isNotEmpty) {
              final id = c['id']?.toString().trim().isNotEmpty == true
                  ? c['id'].toString().trim()
                  : 'cat_${DateTime.now().millisecondsSinceEpoch}';
              cleanCategories.add({
                'id': id,
                'name': c['name'].toString().trim(),
                'emoji': c['emoji']?.toString().trim().isNotEmpty == true
                    ? c['emoji'].toString().trim()
                    : '📦',
              });
            }
          }
        }
        final rawItems = body['items'];
        if (rawItems is List) {
          for (final item in rawItems) {
            if (item is Map && item['productId'] != null) {
              cleanItems.add({
                'productId': item['productId'].toString().trim(),
                'categoryId': item['categoryId']?.toString().trim() ?? '',
                'categoryName': item['categoryName']?.toString().trim() ?? '',
                'tag': item['tag']?.toString().trim() ?? '⭐ สินค้าแนะนำ',
                'badgeColor':
                    item['badgeColor']?.toString().trim() ?? '#168a68',
              });
            }
          }
        }
      } else if (body is List) {
        for (final item in body) {
          if (item is Map && item['productId'] != null) {
            cleanItems.add({
              'productId': item['productId'].toString().trim(),
              'categoryId': item['categoryId']?.toString().trim() ?? '',
              'categoryName': item['categoryName']?.toString().trim() ?? '',
              'tag': item['tag']?.toString().trim() ?? '⭐ สินค้าแนะนำ',
              'badgeColor': item['badgeColor']?.toString().trim() ?? '#168a68',
            });
          }
        }
        final existingConfig = _readFeaturedConfig();
        cleanCategories = (existingConfig['categories'] as List)
            .cast<Map<String, dynamic>>();
      }

      final savedData = {'categories': cleanCategories, 'items': cleanItems};

      final jsonContent = const JsonEncoder.withIndent('  ').convert(savedData);
      final file = _featuredConfigFile();
      await file.writeAsString(jsonContent);

      // Also sync to other candidate locations so runtime & source stay in sync
      final altPaths = [
        'public/shop/featured_config.json',
        'backend/public/shop/featured_config.json',
        '${Directory.current.path}/public/shop/featured_config.json',
        '${Directory.current.path}/backend/public/shop/featured_config.json',
        'C:/Users/msiri/AppData/Local/Programs/S_Mart POS/backend/public/shop/featured_config.json',
      ];
      for (final p in altPaths) {
        try {
          final f = File(p);
          if (f.existsSync()) {
            await f.writeAsString(jsonContent);
          }
        } catch (_) {}
      }

      return Response.ok(
        jsonEncode({'status': 'success', 'data': savedData}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      stderr.writeln('❌ Error saving admin featured: $e');
      return Response.badRequest(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
      );
    }
  }

  Map<String, dynamic> _mapProduct(Map<String, dynamic> data) {
    final price =
        double.tryParse(
          data['retailPrice']?.toString() ??
              data['retail_price']?.toString() ??
              data['price']?.toString() ??
              '0',
        ) ??
        0.0;

    final stock =
        (double.tryParse(
                  data['stockQuantity']?.toString() ??
                      data['stock_quantity']?.toString() ??
                      data['qty']?.toString() ??
                      '0',
                ) ??
                0.0)
            .toInt();

    return {
      'id': data['id'],
      'barcode': data['barcode'] ?? '',
      'name': data['name'] ?? '',
      'retailPrice': price,
      'price': price,
      'stockQuantity': stock,
      'imageUrl': data['imageUrl'] ?? data['image_url'] ?? '',
      'categoryId': data['categoryId'] ?? data['category_id'],
      'categoryName': data['categoryName'] ?? data['category_name'] ?? 'ทั่วไป',
    };
  }

  String _getCategorySqlClause(
    String catId,
    Map<String, dynamic> queryParameters,
  ) {
    if (catId == 'sand_rock_cement' ||
        catId == 'หิน ทราย ปูน' ||
        catId == 'หินทราย') {
      return '''(
        c.name = 'หินทราย' OR p.categoryId = 64 
        OR p.name LIKE '%ปูน%' OR p.name LIKE '%ทราย%' OR p.name LIKE '%หิน%' OR p.name LIKE '%อิฐ%' 
        OR p.name LIKE '%วงบ่อ%' OR p.name LIKE '%ฝาวงบ่อ%' OR p.name LIKE '%ท่อระบายน้ำ%' OR p.name LIKE '%บ่อพัก%'
      )''';
    } else if (catId == 'steel' || catId == 'เหล็ก') {
      return '''(
        c.name = 'เหล็ก' OR p.categoryId = 44 
        OR p.name LIKE '%เหล็ก%' OR p.name LIKE '%ลวด%' OR p.name LIKE '%ซีลาย%' 
        OR p.name LIKE '%ฉาก%' OR p.name LIKE '%ข้ออ้อย%' OR p.name LIKE '%ทีเมน%' OR p.name LIKE '%ทีซอย%'
      )''';
    } else if (catId == 'pipe_pvc' ||
        catId == 'ท่อ & PVC' ||
        catId == 'ท่อ pvc' ||
        catId == 'pvc') {
      return '''(
        (c.name = 'pvc' OR p.categoryId = 41 OR p.name LIKE '%pvc%') 
        AND p.name NOT LIKE '%เหลือง%' AND p.name NOT LIKE '%ขาว%'
      )''';
    } else if (catId == 'electric' || catId == 'อุปกรณ์ไฟฟ้า') {
      return '''(
        c.name LIKE '%ไฟฟ้า%' OR p.categoryId = 17 
        OR p.name LIKE '%ท่อเหลือง%' OR p.name LIKE '%ท่อขาว%' OR p.name LIKE '%เฟล็ก%'
      )''';
    } else if (catId == 'roof_tile' ||
        catId == 'ไม้อัด & แผ่นบอร์ด' ||
        catId == 'กระเบื้อง & หลังคา' ||
        catId == 'กระเบื้อง') {
      return '''(
        c.name = 'กระเบื้อง' OR p.categoryId = 69 
        OR p.name LIKE '%ไม้อัด%' OR p.name LIKE '%สมาร์ทบอร์ด%' OR p.name LIKE '%ยิบซั่ม%' OR p.name LIKE '%ยิปซัม%'
      )''';
    } else if (catId == 'drainage' ||
        catId == 'วงบ่อท่อระบายน้ำ' ||
        catId == 'วงบ่อ' ||
        catId == 'ท่อระบายน้ำ') {
      return '''(
        c.name = 'เสาและคอนกรีตหล่อ'
        OR p.name LIKE '%วงบ่อ%' OR p.name LIKE '%ฝาวงบ่อ%'
        OR p.name LIKE '%ท่อระบายน้ำ%' OR p.name LIKE '%บ่อพัก%'
      )''';
    } else if (catId == 'poles' || catId == 'เสา') {
      return '''(
        c.name = 'เสาและคอนกรีตหล่อ'
        OR p.name LIKE '%เสาปูน%' OR p.name LIKE '%เสารั้ว%'
        OR p.name LIKE '%เสาบ่า%' OR p.name LIKE '%เสาเหล็ก%'
      )''';
    } else if (catId == 'fasteners' ||
        catId == 'ตะปู+สกรู' ||
        catId == 'ตะปู สกรู') {
      return '''(
        c.name = 'ตะปู สกรู'
        OR p.name LIKE '%ตะปู%' OR p.name LIKE '%สกรู%'
        OR p.name LIKE '%น็อต%' OR p.name LIKE '%พุก%' OR p.name LIKE '%รีเวท%'
      )''';
    } else if (catId == 'cutting_disc' || catId == 'ใบตัด') {
      return '(p.categoryId = 6 OR p.name LIKE "%ใบตัด%" OR p.name LIKE "%ใบเจีย%")';
    } else if (catId == 'paint' || catId == 'สี & เคมีภัณฑ์' || catId == 'สี') {
      return '''(
        p.categoryId IN (SELECT id FROM category WHERE name IN ('สี', 'สีสเปรย์', 'แปรงทาสี', 'กาว', 'เคมีภัณฑ์'))
        OR p.name LIKE '%สี%' OR p.name LIKE '%กาว%' OR p.name LIKE '%ทินเนอร์%'
      )''';
    } else if (catId == 'tools' || catId == 'เครื่องมือช่าง') {
      return '''(
        p.categoryId IN (SELECT id FROM category WHERE name IN ('เครื่องมือช่าง', 'อุปกรณ์ช่าง', 'ดอกสว่าน', 'กระดาษทราย'))
        OR p.name LIKE '%สว่าน%' OR p.name LIKE '%ค้อน%' OR p.name LIKE '%ตลับเมตร%'
      )''';
    }
    final numericId = int.tryParse(catId);
    if (numericId != null && numericId > 0) {
      queryParameters['categoryId'] = numericId;
      return 'p.categoryId = :categoryId';
    }
    queryParameters['customCatName'] = '%$catId%';
    return '(c.name LIKE :customCatName OR p.name LIKE :customCatName)';
  }

  // GET /api/v1/shop/products?page=1&limit=80&category_id=x&q=keyword&all=1
  Future<Response> _getProducts(Request request) async {
    try {
      final params = request.url.queryParameters;
      final bool isFullCatalog =
          params['all'] == '1' || params['all'] == 'true';
      final int page = (int.tryParse(params['page'] ?? '1') ?? 1)
          .clamp(1, 10000)
          .toInt();
      final int maxLimit = isFullCatalog ? 500 : 100;
      final int limit =
          (int.tryParse(params['limit'] ?? (isFullCatalog ? '500' : '80')) ??
                  (isFullCatalog ? 500 : 80))
              .clamp(1, maxLimit)
              .toInt();
      final int offset = (page - 1) * limit;
      final String? categoryId = params['category_id']?.trim() ?? params['category']?.trim();
      final String? query = params['q']?.trim() ?? params['search']?.trim() ?? params['keyword']?.trim();
      if ((categoryId?.length ?? 0) > 100 || (query?.length ?? 0) > 100) {
        throw const OnlineOrderException(
          400,
          'INVALID_CATALOG_FILTER',
          'Invalid catalog filter',
        );
      }

      final conn = await DbConfig().connection;
      List<Map<String, dynamic>> products = [];
      final queryParams = <String, dynamic>{'limit': limit, 'offset': offset};

      if (isFullCatalog || (query != null && query.isNotEmpty)) {
        // Full database search / Admin catalog mode
        String whereClause = 'p.isActive = 1';
        if (!isFullCatalog) {
          whereClause += " AND p.name NOT LIKE 'สีผสม %' AND p.barcode NOT LIKE 'BEGER-2IN1%'";
        }
        if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
          whereClause += ' AND (${_getCategorySqlClause(categoryId, queryParams)})';
        }
        if (query != null && query.isNotEmpty) {
          queryParams['q'] = '%$query%';
          whereClause += ' AND (p.name LIKE :q OR p.barcode LIKE :q)';
        }

        final sql = '''
          SELECT p.id, p.barcode, p.name, p.retailPrice, p.stockQuantity, p.imageUrl, p.categoryId, c.name as categoryName 
          FROM product p
          LEFT JOIN category c ON p.categoryId = c.id
          WHERE $whereClause
          ORDER BY p.name ASC
          LIMIT :limit OFFSET :offset
        ''';
        final result = await conn.execute(sql, queryParams);
        products = result.rows.map((row) => _mapProduct(row.assoc())).toList();
      } else {
        // Customer storefront: Load products curated by Store in featured_config.json
        final config = _readFeaturedConfig();
        final items = (config['items'] as List).cast<Map<String, dynamic>>();
        final List<String> targetProductIds = [];

        for (final item in items) {
          final pid = item['productId']?.toString();
          final cid = item['categoryId']?.toString();
          if (pid != null && pid.isNotEmpty) {
            if (categoryId == null ||
                categoryId.isEmpty ||
                categoryId == 'all' ||
                cid == categoryId) {
              targetProductIds.add(pid);
            }
          }
        }

        if (targetProductIds.isNotEmpty) {
          final pageIds = targetProductIds.skip(offset).take(limit).toList();
          if (pageIds.isNotEmpty) {
            final placeholders = pageIds
                .map((id) => int.tryParse(id) ?? 0)
                .where((id) => id > 0)
                .toList();
            if (placeholders.isNotEmpty) {
              final inClause = placeholders.join(',');
              final sql = '''
                SELECT p.id, p.barcode, p.name, p.retailPrice, p.stockQuantity, p.imageUrl, p.categoryId, c.name as categoryName 
                FROM product p
                LEFT JOIN category c ON p.categoryId = c.id
                WHERE p.id IN ($inClause) AND p.isActive = 1 AND p.name NOT LIKE 'สีผสม %' AND p.barcode NOT LIKE 'BEGER-2IN1%'
                ORDER BY FIELD(p.id, $inClause)
              ''';
              final result = await conn.execute(sql);
              products = result.rows
                  .map((row) => _mapProduct(row.assoc()))
                  .toList();
            }
          }
        } else {
          // Fallback if category has no items in featured_config: query active category products
          String whereClause = "p.isActive = 1 AND p.name NOT LIKE 'สีผสม %' AND p.barcode NOT LIKE 'BEGER-2IN1%'";
          if (categoryId != null && categoryId != 'all') {
            whereClause += ' AND (${_getCategorySqlClause(categoryId, queryParams)})';
          }
          final sql = '''
            SELECT p.id, p.barcode, p.name, p.retailPrice, p.stockQuantity, p.imageUrl, p.categoryId, c.name as categoryName 
            FROM product p
            LEFT JOIN category c ON p.categoryId = c.id
            WHERE $whereClause
            ORDER BY p.name ASC
            LIMIT :limit OFFSET :offset
          ''';
          final result = await conn.execute(sql, queryParams);
          products = result.rows.map((row) => _mapProduct(row.assoc())).toList();
        }
      }

      return Response.ok(
        jsonEncode({'status': 'success', 'page': page, 'data': products}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } on OnlineOrderException catch (error) {
      return Response(
        error.statusCode,
        body: jsonEncode({
          'status': 'error',
          'code': error.code,
          'message': error.message,
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (error) {
      stderr.writeln('❌ Error fetching shop products: $error');
      return Response.internalServerError(
        body: jsonEncode({
          'status': 'error',
          'message': 'Unable to load products',
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }

  // GET /api/v1/shop/info
  Future<Response> _getShopInfo(Request request) async {
    try {
      final conn = await DbConfig().connection;
      final result = await conn.execute(
        "SELECT setting_key, setting_value FROM system_settings WHERE setting_key LIKE 'shop_%'",
      );
      final Map<String, String> map = {};
      for (final row in result.rows) {
        final d = row.assoc();
        final k = d['setting_key']?.toString();
        final v = d['setting_value']?.toString() ?? '';
        if (k != null) map[k] = v;
      }
      return Response.ok(
        jsonEncode({
          'status': 'success',
          'data': {
            'name': map['shop_name'] ?? 'ร้าน ส.บริการ ท่าข้าม',
            'shortName': map['shop_short_name'] ?? 'ร้าน ส.บริการ',
            'address': map['shop_address'] ?? 'จำหน่ายวัสดุก่อสร้าง อุปกรณ์ไฟฟ้าและประปา',
            'shortAddress': map['shop_short_address'] ?? '',
            'phone': map['shop_phone'] ?? '085-1377402, 086-1991923',
            'taxId': map['shop_tax_id'] ?? '',
            'footer': map['shop_footer'] ?? 'ขอบคุณที่ใช้บริการ',
            'latitude': double.tryParse(map['shop_latitude'] ?? '') ?? 16.160189,
            'longitude': double.tryParse(map['shop_longitude'] ?? '') ?? 100.802307,
          },
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.ok(
        jsonEncode({
          'status': 'success',
          'data': {
            'name': 'ร้าน ส.บริการ ท่าข้าม',
            'shortName': 'ร้าน ส.บริการ',
            'address': 'จำหน่ายวัสดุก่อสร้าง อุปกรณ์ไฟฟ้าและประปา',
            'shortAddress': '',
            'phone': '085-1377402, 086-1991923',
            'taxId': '',
            'footer': 'ขอบคุณที่ใช้บริการ',
          },
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }

  // GET /api/v1/shop/categories
  Future<Response> _getCategories(Request request) async {
    try {
      final showAll =
          request.url.queryParameters['all'] == 'true' ||
          request.url.queryParameters['all'] == '1';

      final config = _readFeaturedConfig();
      final List<Map<String, dynamic>> allCategories =
          (config['categories'] as List).cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> items = (config['items'] as List)
          .cast<Map<String, dynamic>>();

      if (showAll) {
        return Response.ok(
          jsonEncode({'status': 'success', 'data': allCategories}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      // Check which categories have selected products in featured_config.json
      final selectedCategoryIds = items
          .map((i) => i['categoryId']?.toString())
          .whereType<String>()
          .toSet();

      final activeCategories = allCategories
          .where((c) => selectedCategoryIds.contains(c['id']?.toString()))
          .toList();

      return Response.ok(
        jsonEncode({
          'status': 'success',
          'data': activeCategories.isNotEmpty
              ? activeCategories
              : allCategories,
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (error) {
      stderr.writeln('❌ Error fetching shop categories: $error');
      return Response.internalServerError(
        body: jsonEncode({
          'status': 'error',
          'message': 'Unable to load categories',
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }

  // GET /api/v1/shop/featured
  Future<Response> _getFeaturedProducts(Request request) async {
    try {
      final List<Map<String, dynamic>> featuredItems = [];

      final config = _readFeaturedConfig();
      final list = (config['items'] as List).cast<Map<String, dynamic>>();
      if (list.isNotEmpty) {
        final productIds = <String>[];
        final tagsByPid = <String, String>{};
        final badgeColors = <String, String>{};

        for (final item in list) {
          final pid = item['productId']?.toString();
          if (pid != null && pid.isNotEmpty) {
            productIds.add(pid);
            if (item['tag'] != null) {
              tagsByPid[pid] = item['tag'].toString();
            }
            if (item['badgeColor'] != null) {
              badgeColors[pid] = item['badgeColor'].toString();
            }
          }
        }

        if (productIds.isNotEmpty) {
          final conn = await DbConfig().connection;
          final ids = productIds
              .map((id) => int.tryParse(id))
              .whereType<int>()
              .where((id) => id > 0)
              .toList();
          final parameters = <String, dynamic>{};
          final placeholders = <String>[];
          for (var i = 0; i < ids.length; i++) {
            final key = 'product$i';
            parameters[key] = ids[i];
            placeholders.add(':$key');
          }
          if (placeholders.isEmpty) {
            return Response.ok(
              jsonEncode({'status': 'success', 'data': featuredItems}),
              headers: {'Content-Type': 'application/json; charset=utf-8'},
            );
          }
          final sql =
              '''
              SELECT p.id, p.barcode, p.name, p.retailPrice, p.stockQuantity, p.imageUrl, p.categoryId, c.name as categoryName 
              FROM product p
              LEFT JOIN category c ON p.categoryId = c.id
              WHERE p.id IN (${placeholders.join(',')}) AND p.isActive = 1
            ''';
          final result = await conn.execute(sql, parameters);
          for (final row in result.rows) {
            final map = _mapProduct(row.assoc());
            final pid = map['id']?.toString() ?? '';
            if (tagsByPid.containsKey(pid)) {
              map['tag'] = tagsByPid[pid];
            }
            if (badgeColors.containsKey(pid)) {
              map['badgeColor'] = badgeColors[pid];
            }
            featuredItems.add(map);
          }
        }
      }

      return Response.ok(
        jsonEncode({'status': 'success', 'data': featuredItems}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (error) {
      stderr.writeln('❌ Error fetching featured products: $error');
      return Response.internalServerError(
        body: jsonEncode({
          'status': 'error',
          'message': 'Unable to load featured products',
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }

  // GET /api/v1/shop-member/me (verified LIFF identity only)
  Future<Response> _getCustomerProfile(Request request) async {
    try {
      final identity = request.context[lineIdentityContextKey];
      if (identity is! LineIdentity) {
        return Response.unauthorized(
          jsonEncode({'status': 'error', 'message': 'Authentication required'}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }
      final customer = await _memberTierService.memberProfile(identity.subject);
      if (customer == null) {
        return Response.ok(
          jsonEncode({'status': 'success', 'exists': false}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      return Response.ok(
        jsonEncode({'status': 'success', 'exists': true, 'customer': customer}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      stderr.writeln('❌ Error fetching customer profile: $e');
      return Response.internalServerError(
        body: jsonEncode({
          'status': 'error',
          'message': 'Unable to load member profile',
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }

  // GET /api/v1/shop-member/orders (verified LIFF identity only)
  Future<Response> _getMemberOrders(Request request) async {
    try {
      final identity = request.context[lineIdentityContextKey];
      if (identity is! LineIdentity) {
        return Response.unauthorized(
          jsonEncode({'status': 'error', 'message': 'Authentication required'}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }
      final limit = MemberTierRules.memberOrderLimit(
        request.url.queryParameters['limit'],
      );
      final status = MemberTierRules.memberOrderStatus(
        request.url.queryParameters['status'],
      );
      final orders = await _memberTierService.memberOrders(
        lineSubject: identity.subject,
        limit: limit,
        status: status,
      );
      return Response.ok(
        jsonEncode({'status': 'success', 'data': orders}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } on MemberTierValidationException catch (error) {
      return Response.badRequest(
        body: jsonEncode({
          'status': 'error',
          'code': error.code,
          'message': error.message,
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (error) {
      stderr.writeln('❌ Error fetching member orders: $error');
      return Response.internalServerError(
        body: jsonEncode({
          'status': 'error',
          'message': 'Unable to load member orders',
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }

  // POST /api/v1/shop/orders
  Future<Response> _createOrder(Request request) async {
    try {
      final decoded = jsonDecode(await request.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const OnlineOrderException(
          400,
          'INVALID_ORDER_DATA',
          'Invalid order data',
        );
      }
      final input = OnlineOrderRules.parseInput(decoded);
      final contextIdentity = request.context[lineIdentityContextKey];
      final identity = contextIdentity is LineIdentity ? contextIdentity : null;
      final result = await _onlineOrderService.create(
        input: input,
        identity: identity,
      );
      if (identity != null && !result.isReplay) {
        await _sendOrderNotification(identity.subject, result);
      }
      return Response.ok(
        jsonEncode({
          'status': 'success',
          'message':
              'บันทึกคำขอแล้ว ยอดทั้งหมดเป็นประมาณการและรอเจ้าหน้าที่ยืนยัน',
          'orderId': result.id,
          'orderNumber': result.orderNumber,
          'clientRequestId': input.clientRequestId,
          'isReplay': result.isReplay,
          'estimate': true,
          'statusCode': 'PENDING_CONFIRMATION',
          'totalAmount': result.totalAmount,
          'couponDiscount': result.couponDiscount,
          'deliveryFee': result.deliveryFee,
          'distanceKm': result.distanceKm,
          'grandTotal': result.grandTotal,
          'couponReservation': result.couponCode == null
              ? null
              : {
                  'status': 'RESERVED',
                  'discount': result.couponDiscount,
                  'reservedUntil': result.couponReservedUntil,
                },
          'itemCount': result.items.length,
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } on OnlineOrderException catch (error) {
      return Response(
        error.statusCode,
        body: jsonEncode({
          'status': 'error',
          'code': error.code,
          'message': error.message,
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } on FormatException {
      return Response.badRequest(
        body: jsonEncode({
          'status': 'error',
          'code': 'INVALID_ORDER_DATA',
          'message': 'Invalid order data',
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (error) {
      stderr.writeln('❌ Error creating shop order: $error');
      return Response.internalServerError(
        body: jsonEncode({
          'status': 'error',
          'message': 'Unable to create order request',
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }

  Future<void> _sendOrderNotification(
    String lineUserId,
    OnlineOrderResult result,
  ) async {
    try {
      final items = result.items
          .map(
            (item) =>
                '• ${item['name']} x ${item['quantity']} (฿${(item['subtotal'] as double).toStringAsFixed(2)})',
          )
          .join('\n');
      final delivery = result.deliveryType == 'delivery'
          ? '🛵 จัดส่งถึงที่'
          : '🏪 รับเองที่ร้าน';
      final coupon = result.couponDiscount > 0
          ? '\n🎟️ ส่วนลดคูปองที่จองไว้: ฿${result.couponDiscount.toStringAsFixed(2)}'
          : '';
      final message =
          '🎉 ทางร้านได้รับคำขอสั่งซื้อของคุณแล้ว\n\n'
          '📋 เลขที่ออเดอร์: ${result.orderNumber}\n'
          '📋 รายละเอียด:\n$items\n\n'
          '💰 ยอดสินค้า: ฿${result.totalAmount.toStringAsFixed(2)}$coupon\n'
          '🛵 รูปแบบ: $delivery\n'
          '🚚 ค่าจัดส่ง (ประมาณการตามระยะทาง): ฿${result.deliveryFee.toStringAsFixed(2)}\n'
          '💵 ยอดรวมประมาณการ: ฿${result.grandTotal.toStringAsFixed(2)}\n\n'
          'ℹ️ *หมายเหตุ: ค่าจัดส่งเป็นการประเมินเบื้องต้นตามระยะทาง GPS อาจมีการปรับลดหรือยืดหยุ่นได้ตามรอบรถจริง เจ้าหน้าที่จะติดต่อยืนยันยอดสุดท้ายอีกครั้งครับ';
      await LineService().pushMessage(lineUserId, message);
    } catch (error) {
      stdout.writeln('⚠️ Line Push warning: $error');
    }
  }

  // GET /api/v1/shop/orders?status=PENDING&limit=50
  Future<Response> _listOrders(Request request) async {
    try {
      final status =
          request.url.queryParameters['status']?.trim().toUpperCase() ?? 'ALL';
      final parsedLimit = int.tryParse(
        request.url.queryParameters['limit'] ?? '50',
      );
      if (parsedLimit == null || parsedLimit < 1) {
        throw const OnlineOrderException(
          400,
          'INVALID_ORDER_FILTER',
          'Invalid order filter',
        );
      }
      if (status != 'ALL' &&
          !OnlineOrderRules.allowedStatuses.contains(status)) {
        throw const OnlineOrderException(
          400,
          'INVALID_ORDER_FILTER',
          'Invalid order filter',
        );
      }
      final limit = parsedLimit.clamp(1, 200).toInt();

      final conn = await DbConfig().connection;

      // Ensure online_orders table exists
      await conn.execute('''
        CREATE TABLE IF NOT EXISTS online_orders (
          id INT AUTO_INCREMENT PRIMARY KEY,
          orderNumber VARCHAR(50) NOT NULL,
          customerId INT NULL,
          customerName VARCHAR(255) NOT NULL,
          customerPhone VARCHAR(50) NOT NULL,
          lineUserId VARCHAR(100) NULL,
          lineDisplayName VARCHAR(255) NULL,
          deliveryType VARCHAR(20) NOT NULL DEFAULT 'pickup',
          deliveryAddress TEXT NULL,
          gpsLocation VARCHAR(255) NULL,
          distanceKm DOUBLE NOT NULL DEFAULT 0,
          deliveryFee DOUBLE NOT NULL DEFAULT 0,
          totalAmount DOUBLE NOT NULL DEFAULT 0,
          grandTotal DOUBLE NOT NULL DEFAULT 0,
          itemsJson LONGTEXT NOT NULL,
          notes TEXT NULL,
          status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
          confirmedBy VARCHAR(100) NULL,
          createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          INDEX idx_status (status),
          INDEX idx_created (createdAt)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
      ''');

      String sql = 'SELECT * FROM online_orders WHERE 1=1';
      final params = <String, dynamic>{'limit': limit};

      if (status != 'ALL') {
        sql += ' AND status = :status';
        params['status'] = status;
      }
      sql += ' ORDER BY id DESC LIMIT :limit';

      final result = await conn.execute(sql, params);
      final orders = result.rows.map((row) {
        final data = row.assoc();
        dynamic parsedItems = [];
        try {
          parsedItems = jsonDecode(data['itemsJson']?.toString() ?? '[]');
        } catch (_) {}

        return {
          'id': data['id'],
          'orderNumber': data['orderNumber'] ?? '',
          'customerId': data['customerId'],
          'customerName': data['customerName'] ?? '',
          'customerPhone': data['customerPhone'] ?? '',
          'lineUserId': data['lineUserId'] ?? '',
          'lineDisplayName': data['lineDisplayName'] ?? '',
          'deliveryType': data['deliveryType'] ?? 'pickup',
          'deliveryAddress': data['deliveryAddress'] ?? '',
          'gpsLocation': data['gpsLocation'] ?? '',
          'distanceKm':
              double.tryParse(data['distanceKm']?.toString() ?? '0') ?? 0.0,
          'deliveryFee':
              double.tryParse(data['deliveryFee']?.toString() ?? '0') ?? 0.0,
          'totalAmount':
              double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0.0,
          'grandTotal':
              double.tryParse(data['grandTotal']?.toString() ?? '0') ?? 0.0,
          'items': parsedItems,
          'notes': data['notes'] ?? '',
          'status': data['status'] ?? 'PENDING',
          'confirmedBy': data['confirmedBy'] ?? '',
          'createdAt': data['createdAt']?.toString() ?? '',
          'updatedAt': data['updatedAt']?.toString() ?? '',
        };
      }).toList();

      return Response.ok(
        jsonEncode({'status': 'success', 'data': orders}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } on OnlineOrderException catch (error) {
      return Response(
        error.statusCode,
        body: jsonEncode({
          'status': 'error',
          'code': error.code,
          'message': error.message,
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (error) {
      stderr.writeln('❌ Error listing online orders: $error');
      return Response.internalServerError(
        body: jsonEncode({
          'status': 'error',
          'message': 'Unable to load online orders',
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }

  // PUT /api/v1/shop/orders/<id>/status
  Future<Response> _updateOrderStatus(Request request, String id) async {
    try {
      final orderId = int.tryParse(id);
      final decoded = jsonDecode(await request.readAsString());
      if (orderId == null || orderId <= 0 || decoded is! Map<String, dynamic>) {
        throw const OnlineOrderException(
          400,
          'INVALID_STATUS',
          'Invalid order status',
        );
      }
      final user = request.context['user'];
      final actor = user is Map
          ? (user['employee_name'] ?? user['username'] ?? user['id'])
                ?.toString()
                .trim()
          : null;
      if (actor == null || actor.isEmpty) {
        throw const OnlineOrderException(
          401,
          'AUTH_REQUIRED',
          'Authentication required',
        );
      }
      final result = await _onlineOrderService.updateStatus(
        orderId: orderId,
        targetStatus: decoded['status']?.toString() ?? '',
        actor: actor,
      );

      return Response.ok(
        jsonEncode({
          'status': 'success',
          'message': 'Updated order status',
          'data': result,
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } on OnlineOrderException catch (error) {
      return Response(
        error.statusCode,
        body: jsonEncode({
          'status': 'error',
          'code': error.code,
          'message': error.message,
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } on FormatException {
      return Response.badRequest(
        body: jsonEncode({
          'status': 'error',
          'code': 'INVALID_STATUS',
          'message': 'Invalid order status',
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (error) {
      stderr.writeln('❌ Error updating online order status: $error');
      return Response.internalServerError(
        body: jsonEncode({
          'status': 'error',
          'message': 'Unable to update order status',
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }

  // GET /api/v1/shop/paint-lookup?code=141-4&size=2.5gl&brand=beger_cool_2in1
  Future<Response> _lookupPaintProduct(Request req) async {
    final code = (req.url.queryParameters['code'] ?? '').trim();
    final size = (req.url.queryParameters['size'] ?? '1gl').toLowerCase().trim();

    if (code.isEmpty) {
      return Response.ok(
        jsonEncode({'status': 'success', 'found': false, 'product': null}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }

    try {
      final conn = await DbConfig().connection;

      final cleanCode = code.replaceAll(' ', '');
      final altCodeWithSpace = code.replaceAll('-', ' ');
      final altCodeNoHyphen = code.replaceAll('-', '');

      List<String> sizeKeywords = [];
      List<String> sizeExcludeKeywords = [];
      if (size.contains('0.25') || size.contains('quarter') || size.contains('1/4')) {
        sizeKeywords = ['1/4', '0.9', '0.85', '0.94', 'กระป๋อง'];
      } else if (size.contains('2.5') || size.contains('9')) {
        sizeKeywords = ['2.5', '9l', '9 l', '9ลิตร', '9 ลิตร', '2.5กล', '2.5 กล'];
      } else {
        sizeKeywords = ['1กล', '1 กล', '3.5', '3.785', '1gl'];
        sizeExcludeKeywords = ['2.5', '9l', '9 l', '9ลิตร', '1/4', '0.9'];
      }

      final sql = """
        SELECT id, barcode, name, retailPrice, stockQuantity, unitId
        FROM product
        WHERE isActive = 1 
          AND retailPrice > 0
          AND (name LIKE '%เบเยอร์%' OR name LIKE '%beger%' OR name LIKE '%Beger%')
          AND (name LIKE '%2in1%' OR name LIKE '%2 in 1%' OR name LIKE '%ทูอินวัน%')
          AND (
            LOWER(name) LIKE :code1 
            OR LOWER(name) LIKE :code2 
            OR LOWER(name) LIKE :code3 
            OR barcode = :exactCode
          )
        ORDER BY 
          (LOWER(name) LIKE '%2in1%') DESC,
          (LOWER(name) LIKE '%คูล2in1%' OR LOWER(name) LIKE '%cool 2in1%') DESC,
          stockQuantity DESC,
          id DESC
        LIMIT 20
      """;

      final results = await conn.execute(sql, {
        'code1': '%${cleanCode.toLowerCase()}%',
        'code2': '%${altCodeWithSpace.toLowerCase()}%',
        'code3': '%${altCodeNoHyphen.toLowerCase()}%',
        'exactCode': code,
      });

      Map<String, dynamic>? matchedProduct;

      for (final row in results.rows) {
        final m = row.assoc();
        final nameLower = (m['name'] ?? '').toLowerCase();

        bool matchesSize = false;
        if (sizeKeywords.isNotEmpty) {
          for (final kw in sizeKeywords) {
            if (nameLower.contains(kw.toLowerCase())) {
              matchesSize = true;
              break;
            }
          }
        } else {
          matchesSize = true;
        }

        if (matchesSize && sizeExcludeKeywords.isNotEmpty) {
          for (final ex in sizeExcludeKeywords) {
            if (nameLower.contains(ex.toLowerCase())) {
              matchesSize = false;
              break;
            }
          }
        }

        if (matchesSize) {
          matchedProduct = {
            'id': int.parse(m['id']!),
            'barcode': m['barcode'] ?? '',
            'name': m['name'] ?? '',
            'price': double.tryParse(m['retailPrice']?.toString() ?? '0') ?? 0.0,
            'stock': double.tryParse(m['stockQuantity']?.toString() ?? '0') ?? 0.0,
          };
          break;
        }
      }

      if (matchedProduct != null && matchedProduct['price'] > 0) {
        return Response.ok(
          jsonEncode({
            'status': 'success',
            'found': true,
            'product': matchedProduct,
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      return Response.ok(
        jsonEncode({
          'status': 'success',
          'found': false,
          'product': null,
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      stderr.writeln('❌ Paint lookup error: $e');
      return Response.ok(
        jsonEncode({
          'status': 'error',
          'found': false,
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }

  // GET /api/v1/shop/metal-sheet-options
  Future<Response> _getMetalSheetOptions(Request request) async {
    try {
      final conn = await DbConfig().connection;
      final results = await conn.execute(
        "SELECT id, barcode, name, retailPrice, stockQuantity "
        "FROM product "
        "WHERE barcode IN ('MS-760-AZ030', 'MS-760-AZ035', 'MS-760-COL035', 'MS-760-COL040', 'MS-OPT-PE5MM', 'MS-OPT-PU25MM') "
        "  AND isActive = 1 "
        "ORDER BY id ASC"
      );

      final Map<String, dynamic> options = {};
      for (final row in results.rows) {
        final m = row.assoc();
        final barcode = m['barcode'] ?? '';
        final price = double.tryParse(m['retailPrice']?.toString() ?? '0') ?? 0.0;
        options[barcode] = {
          'id': int.parse(m['id']!),
          'barcode': barcode,
          'name': m['name'],
          'price': price,
          'stock': double.tryParse(m['stockQuantity']?.toString() ?? '0') ?? 0.0,
        };
      }

      return Response.ok(
        jsonEncode({
          'status': 'success',
          'data': options,
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      stderr.writeln('❌ Metal sheet options error: $e');
      return Response.internalServerError(
        body: jsonEncode({
          'status': 'error',
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }

  // POST /api/v1/shop/phone-login
  Future<Response> _phoneLogin(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final rawPhone = (data['phone'] ?? '').toString().trim();
      final inputPin = (data['pin'] ?? '').toString().trim();
      final cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');

      if (cleanPhone.length < 8) {
        return Response.badRequest(
          body: jsonEncode({
            'status': 'error',
            'message': 'กรุณาระบุเบอร์โทรศัพท์ให้ถูกต้อง',
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      if (inputPin.isEmpty) {
        return Response.ok(
          jsonEncode({
            'status': 'error',
            'code': 'PIN_REQUIRED',
            'message': 'กรุณากรอกรหัส PIN (รหัสเริ่มต้นคือเลขท้าย 4 ตัวของเบอร์โทรศัพท์)',
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      final conn = await DbConfig().connection;
      final results = await conn.execute(
        '''SELECT c.id, c.memberCode, c.firstName, c.lastName, c.phone,
                  c.address, c.shippingAddress, c.line_display_name,
                  c.line_picture_url, c.tierId, c.pin_code,
                  COALESCE(t.name, 'ลูกค้าทั่วไป') AS member_tier,
                  COALESCE(t.loyaltySegment, 'CUSTOMER') AS loyalty_segment
           FROM customer c
           LEFT JOIN member_tier t ON c.tierId = t.id
           WHERE (REPLACE(REPLACE(c.phone, '-', ''), ' ', '') LIKE :phone OR c.phone = :rawPhone)
             AND (c.isDeleted = 0 OR c.isDeleted IS NULL)
           ORDER BY c.id DESC LIMIT 1''',
        {
          'phone': '%$cleanPhone%',
          'rawPhone': rawPhone,
        },
      );

      if (results.rows.isEmpty) {
        return Response.ok(
          jsonEncode({
            'status': 'success',
            'exists': false,
            'message': 'ไม่พบข้อมูลสมาชิกร้านจากเบอร์โทรนี้',
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      final row = results.rows.first.assoc();
      final savedPin = (row['pin_code'] ?? '').toString().trim();
      final defaultPin = cleanPhone.length >= 4
          ? cleanPhone.substring(cleanPhone.length - 4)
          : cleanPhone;
      final expectedPin = savedPin.isNotEmpty ? savedPin : defaultPin;

      if (inputPin != expectedPin) {
        return Response.ok(
          jsonEncode({
            'status': 'error',
            'code': 'INVALID_PIN',
            'message': 'รหัส PIN ไม่ถูกต้อง (รหัสเริ่มต้นคือเลขท้าย 4 ตัวของเบอร์โทรศัพท์ครับ)',
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      final customerId = int.parse(row['id']!);

      // 🔗 Auto-Link LINE Account with this Customer Record if present
      final identity = request.context[lineIdentityContextKey];
      final lineSubject = (identity is LineIdentity)
          ? identity.subject
          : ((data['lineUserId'] ?? '').toString().trim());
      final lineDisplayName = (data['lineDisplayName'] ?? '').toString().trim();
      final linePictureUrl = (data['linePictureUrl'] ?? '').toString().trim();

      if (lineSubject.isNotEmpty) {
        try {
          await conn.execute(
            '''INSERT INTO customer_identity_owner (provider, subject, customer_id)
               VALUES ('LINE', :subject, :customerId)
               ON DUPLICATE KEY UPDATE customer_id = :customerId''',
            {'subject': lineSubject, 'customerId': customerId},
          );
          await conn.execute(
            '''UPDATE customer 
               SET line_user_id = :subject,
                   line_display_name = COALESCE(NULLIF(:displayName, ''), line_display_name),
                   line_picture_url = COALESCE(NULLIF(:picUrl, ''), line_picture_url)
               WHERE id = :customerId''',
            {
              'subject': lineSubject,
              'displayName': lineDisplayName,
              'picUrl': linePictureUrl,
              'customerId': customerId,
            },
          );
          stderr.writeln('🔗 [ShopController] Successfully linked LINE ($lineSubject) to Customer #$customerId (${row['firstName']})');
        } catch (linkErr) {
          stderr.writeln('⚠️ [ShopController] Failed to auto-link LINE: $linkErr');
        }
      }

      final customer = await _memberTierService.memberProfileByCustomerId(
        customerId,
        connection: conn,
      );

      if (customer == null) {
        return Response.ok(
          jsonEncode({
            'status': 'success',
            'exists': false,
            'message': 'ไม่พบข้อมูลสมาชิกร้าน',
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      return Response.ok(
        jsonEncode({
          'status': 'success',
          'exists': true,
          'customer': customer,
          'linkedLine': lineSubject.isNotEmpty,
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      stderr.writeln('❌ Phone login error: $e');
      return Response.internalServerError(
        body: jsonEncode({
          'status': 'error',
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }

  // POST /api/v1/shop/register
  Future<Response> _registerMember(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().trim();
      final rawPhone = (data['phone'] ?? '').toString().trim();
      final cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
      final rawPin = (data['pin'] ?? '').toString().trim();
      final address = (data['address'] ?? '').toString().trim();

      if (name.isEmpty) {
        return Response.ok(
          jsonEncode({
            'status': 'error',
            'code': 'NAME_REQUIRED',
            'message': 'กรุณาระบุชื่อ-นามสกุล',
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      if (cleanPhone.length < 9) {
        return Response.ok(
          jsonEncode({
            'status': 'error',
            'code': 'INVALID_PHONE',
            'message': 'กรุณาระบุเบอร์โทรศัพท์ให้ถูกต้อง (9-10 หลัก)',
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      final conn = await DbConfig().connection;

      // 1. Check if phone already exists
      final existing = await conn.execute(
        '''SELECT id, firstName, phone FROM customer
           WHERE (REPLACE(REPLACE(phone, '-', ''), ' ', '') LIKE :phone OR phone = :rawPhone)
             AND (isDeleted = 0 OR isDeleted IS NULL)
           LIMIT 1''',
        {'phone': '%$cleanPhone%', 'rawPhone': rawPhone},
      );

      if (existing.rows.isNotEmpty) {
        final exRow = existing.rows.first.assoc();
        return Response.ok(
          jsonEncode({
            'status': 'error',
            'code': 'PHONE_EXISTS',
            'message': 'เบอร์โทรนี้เคยลงทะเบียนไว้แล้วในชื่อ "${exRow['firstName']}" ครับ กรุณาเลือก "เชื่อมโยงเบอร์เดิม" เพื่อเข้าสู่ระบบได้ทันที',
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      // 2. Generate Member Code
      final lastCust = await conn.execute(
        'SELECT id FROM customer ORDER BY id DESC LIMIT 1',
      );
      int nextId = 1;
      if (lastCust.rows.isNotEmpty) {
        nextId = (int.tryParse(lastCust.rows.first.assoc()['id']?.toString() ?? '') ?? 0) + 1;
      }
      final memberCode = 'MB${nextId.toString().padLeft(5, '0')}';
      final defaultPin = cleanPhone.length >= 4
          ? cleanPhone.substring(cleanPhone.length - 4)
          : '1234';
      final pinToSave = rawPin.isNotEmpty ? rawPin : defaultPin;

      // 3. Extract LINE info if present
      final identity = request.context[lineIdentityContextKey];
      final lineSubject = (identity is LineIdentity)
          ? identity.subject
          : ((data['lineUserId'] ?? '').toString().trim());
      final lineDisplayName = (data['lineDisplayName'] ?? '').toString().trim();
      final linePictureUrl = (data['linePictureUrl'] ?? '').toString().trim();

      // 4. Insert Customer Record
      final insertRes = await conn.execute(
        '''INSERT INTO customer (
             memberCode, firstName, lastName, phone, address,
             tierId, pin_code, line_user_id, line_display_name, line_picture_url,
             createdAt, updatedAt, isDeleted
           ) VALUES (
             :code, :name, '', :phone, :address,
             1, :pin, :lineId, :lineName, :linePic,
             NOW(), NOW(), 0
           )''',
        {
          'code': memberCode,
          'name': name,
          'phone': rawPhone,
          'address': address,
          'pin': pinToSave,
          'lineId': lineSubject.isNotEmpty ? lineSubject : null,
          'lineName': lineDisplayName.isNotEmpty ? lineDisplayName : null,
          'linePic': linePictureUrl.isNotEmpty ? linePictureUrl : null,
        },
      );

      final newCustomerId = insertRes.lastInsertID.toInt();

      // 5. Link Identity Owner if LINE ID is present
      if (lineSubject.isNotEmpty && newCustomerId > 0) {
        await conn.execute(
          '''INSERT INTO customer_identity_owner (provider, subject, customer_id)
             VALUES ('LINE', :subject, :customerId)
             ON DUPLICATE KEY UPDATE customer_id = :customerId''',
          {'subject': lineSubject, 'customerId': newCustomerId},
        );
      }

      final customer = await _memberTierService.memberProfileByCustomerId(
        newCustomerId,
        connection: conn,
      );

      return Response.ok(
        jsonEncode({
          'status': 'success',
          'exists': true,
          'message': 'สมัครสมาชิกและเชื่อมโยงบัญชีเรียบร้อยแล้ว',
          'customer': customer,
          'linkedLine': lineSubject.isNotEmpty,
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      stderr.writeln('❌ Register member error: $e');
      return Response.internalServerError(
        body: jsonEncode({
          'status': 'error',
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }

  // POST /api/v1/shop/change-pin
  Future<Response> _changePin(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final rawPhone = (data['phone'] ?? '').toString().trim();
      final cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
      final currentPin = (data['currentPin'] ?? '').toString().trim();
      final newPin = (data['newPin'] ?? '').toString().trim();

      if (cleanPhone.length < 8) {
        return Response.badRequest(
          body: jsonEncode({'status': 'error', 'message': 'กรุณาระบุเบอร์โทรศัพท์ให้ถูกต้อง'}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      if (!RegExp(r'^[0-9]{4,6}$').hasMatch(newPin)) {
        return Response.ok(
          jsonEncode({
            'status': 'error',
            'code': 'INVALID_NEW_PIN_FORMAT',
            'message': 'รหัส PIN ใหม่ต้องเป็นตัวเลข 4 ถึง 6 หลักครับ',
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      final conn = await DbConfig().connection;
      final results = await conn.execute(
        '''SELECT id, phone, pin_code FROM customer
           WHERE (REPLACE(REPLACE(phone, '-', ''), ' ', '') LIKE :phone OR phone = :rawPhone)
             AND (isDeleted = 0 OR isDeleted IS NULL)
           ORDER BY id DESC LIMIT 1''',
        {'phone': '%$cleanPhone%', 'rawPhone': rawPhone},
      );

      if (results.rows.isEmpty) {
        return Response.ok(
          jsonEncode({'status': 'error', 'message': 'ไม่พบข้อมูลสมาชิกในระบบ'}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      final row = results.rows.first.assoc();
      final savedPin = (row['pin_code'] ?? '').toString().trim();
      final defaultPin = cleanPhone.length >= 4 ? cleanPhone.substring(cleanPhone.length - 4) : cleanPhone;
      final expectedPin = savedPin.isNotEmpty ? savedPin : defaultPin;

      // ตรวจสอบ currentPin ถ้าส่งมา (ยกเว้นถ้าล็อกอินผ่าน LINE Verified)
      final identity = request.context[lineIdentityContextKey];
      final isLineVerified = identity is LineIdentity;

      if (!isLineVerified && currentPin != expectedPin) {
        return Response.ok(
          jsonEncode({
            'status': 'error',
            'code': 'INVALID_CURRENT_PIN',
            'message': 'รหัส PIN เดิมไม่ถูกต้องครับ',
          }),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }

      final customerId = int.parse(row['id']!);
      await conn.execute(
        'UPDATE customer SET pin_code = :newPin WHERE id = :id',
        {'newPin': newPin, 'id': customerId},
      );

      return Response.ok(
        jsonEncode({
          'status': 'success',
          'message': 'เปลี่ยนรหัส PIN เรียบร้อยแล้วครับ สามารถใช้รหัสใหม่ล็อกอินได้ทันที',
        }),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      stderr.writeln('❌ Change PIN error: $e');
      return Response.internalServerError(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }
  }
}


