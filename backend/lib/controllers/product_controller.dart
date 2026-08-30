import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../db_config.dart';
import '../env_config.dart';
import 'dart:io';

class ProductController {
  Router get router {
    final router = Router();
    router.get('/', _getProducts);
    router.get('/categories', _getCategories);
    router.get('/search', _searchProducts);
    router.get('/id/<id>', _getProductById);
    router.post('/<id>/image', _updateProductImage);
    router.get('/<barcode>', _getProductByBarcode);
    router.put('/<id>', _updateProduct);
    return router;
  }

  String _getCategoryEmoji(String name) {
    if (name.contains('สีผสม') || name.contains('สี')) return '🎨';
    if (name.contains('หิน') || name.contains('ทราย')) return '🪨';
    if (name.contains('เหล็ก')) return '🏗️';
    if (name.contains('ท่อ') || name.contains('PVC') || name.contains('pvc')) return '🚿';
    if (name.contains('สายไฟ') || name.contains('หลอดไฟ') || name.contains('ไฟฟ้า')) return '💡';
    if (name.contains('ช่าง') || name.contains('เครื่องมือ')) return '🔧';
    if (name.contains('ตัด') || name.contains('เจีย')) return '⚙️';
    if (name.contains('ฝ้า') || name.contains('ผนัง') || name.contains('ปูน')) return '🧱';
    if (name.contains('ประตู') || name.contains('หน้าต่าง')) return '🚪';
    if (name.contains('ตะปู') || name.contains('สกรู') || name.contains('น็อต')) return '🔩';
    if (name.contains('ข้อต่อ') || name.contains('ก๊อก')) return '🚰';
    if (name.contains('กาว') || name.contains('ซิลิโคน')) return '🧴';
    if (name.contains('เกษตร') || name.contains('สวน')) return '🌾';
    if (name.contains('สุขภัณฑ์') || name.contains('ห้องน้ำ')) return '🚽';
    if (name.contains('ปั๊ม')) return '⚡';
    if (name.contains('ทาสี') || name.contains('แปรง')) return '🖌️';
    if (name.contains('เสา') || name.contains('คอนกรีต')) return '🏛️';
    if (name.contains('สังกะสี') || name.contains('รางน้ำ') || name.contains('เมทัลชีท')) return '🏠';
    return '📦';
  }

  /// GET /api/v1/products/categories
  /// Authoritative POS product types (22 clean categories) for internal tools such as Shop Admin.
  Future<Response> _getCategories(Request request) async {
    try {
      final conn = await DbConfig().connection;
      final result = await conn.execute('''
        SELECT pt.id, pt.name, COUNT(p.id) AS productCount
        FROM product_type pt
        INNER JOIN product p ON (p.productType = pt.id OR p.categoryId = pt.id) AND p.isActive = 1
        GROUP BY pt.id, pt.name
        HAVING COUNT(p.id) > 0
        ORDER BY pt.name ASC
      ''');
      final categories = result.rows.map((row) {
        final data = row.assoc();
        final name = data['name'] ?? 'ไม่ระบุหมวด';
        return {
          'id': data['id'],
          'name': name,
          'emoji': _getCategoryEmoji(name),
          'productCount': int.tryParse(data['productCount'] ?? '0') ?? 0,
        };
      }).toList();
      return Response.ok(
        jsonEncode({'data': categories}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch POS categories: $e'}),
      );
    }
  }

  /// POST /api/v1/products/:id/image
  /// Stores an optional product photo and keeps only its public URL in MySQL.
  Future<Response> _updateProductImage(Request request, String id) async {
    try {
      final productId = int.tryParse(id);
      if (productId == null || productId <= 0) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Invalid product id'}),
        );
      }

      final payload = jsonDecode(await request.readAsString());
      final encoded = payload is Map ? payload['image']?.toString() ?? '' : '';
      if (encoded.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'No image data'}),
        );
      }

      final bytes = base64Decode(encoded);
      if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Image is empty or too large'}),
        );
      }

      final conn = await DbConfig().connection;
      final product = await conn.execute(
        'SELECT id FROM product WHERE id = :id LIMIT 1',
        {'id': productId},
      );
      if (product.rows.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Product not found'}));
      }

      final directory = Directory('${EnvConfig().writableDir}/products');
      if (!directory.existsSync()) directory.createSync(recursive: true);
      final fileName =
          'product_${productId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);
      final relativeUrl = '/public/products/$fileName';

      await conn.execute('UPDATE product SET imageUrl = :url WHERE id = :id', {
        'url': relativeUrl,
        'id': productId,
      });

      return Response.ok(
        jsonEncode({'success': true, 'url': relativeUrl}),
        headers: {'content-type': 'application/json'},
      );
    } on FormatException {
      return Response.badRequest(
        body: jsonEncode({'error': 'Invalid image data'}),
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Image upload failed: $e'}),
      );
    }
  }

  // Helper to standardise Product JSON for Frontend (camelCase)
  Map<String, dynamic> _mapProduct(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'barcode': data['barcode'],
      'name': data['name'],
      'description': data['description'],
      'productType': data['productType'] ?? data['product_type'] ?? 0,
      // Handle Price variations (snake_case vs camelCase vs raw price)
      'price':
          double.tryParse(
            data['retailPrice']?.toString() ??
                data['retail_price']?.toString() ??
                data['price']?.toString() ??
                '0',
          ) ??
          0.0,
      'retailPrice':
          double.tryParse(
            data['retailPrice']?.toString() ??
                data['retail_price']?.toString() ??
                data['price']?.toString() ??
                '0',
          ) ??
          0.0,
      'wholesalePrice':
          double.tryParse(
            data['wholesalePrice']?.toString() ??
                data['wholesale_price']?.toString() ??
                '0',
          ) ??
          0.0,
      // Handle Image: Frontend uses 'imageUrl'
      'imageUrl':
          data['imageUrl'] ??
          data['image_url'] ??
          data['image'] ??
          '', // Default to empty string instead of null
      // Handle Stock (MySQL quirks: lowercase keys depending on driver/query)
      'stockQuantity':
          (double.tryParse(
                    data['stockQuantity']?.toString() ??
                        data['stock_quantity']?.toString() ??
                        data['stockquantity']?.toString() ??
                        data['qty']?.toString() ??
                        '0',
                  ) ??
                  0.0)
              .toInt(),
      'category_id': data['productType'] ?? data['categoryId'] ?? data['category_id'],
    };
  }

  // GET /api/v1/products?page=1&limit=50&category_id=x
  Future<Response> _getProducts(Request request) async {
    try {
      final params = request.url.queryParameters;
      final int page = int.tryParse(params['page'] ?? '1') ?? 1;
      final int limit = int.tryParse(params['limit'] ?? '50') ?? 50;
      final int offset = (page - 1) * limit;
      final String? categoryId = params['category_id'];
      final String? keyword = params['q']?.trim();

      // Log for Manual Verification
      stdout.writeln(
        '📦 API: Fetching products (Page: $page, Limit: $limit)...',
      );

      final conn = await DbConfig().connection;

      // Build Query
      String sql = 'SELECT * FROM product';
      Map<String, dynamic> queryParams = {'limit': limit, 'offset': offset};
      final whereClauses = <String>[];

      if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
        whereClauses.add('(productType = :catId OR categoryId = :catId)');
        queryParams['catId'] = categoryId;
      }
      if (keyword != null && keyword.isNotEmpty) {
        whereClauses.add(
          '(name LIKE :keyword OR barcode LIKE :keyword OR alias LIKE :keyword)',
        );
        queryParams['keyword'] = '%$keyword%';
      }
      whereClauses.add('isActive = 1');
      if (whereClauses.isNotEmpty) {
        sql += ' WHERE ${whereClauses.join(' AND ')}';
      }

      sql += ' ORDER BY name LIMIT :limit OFFSET :offset';

      final result = await conn.execute(sql, queryParams);

      final List<Map<String, dynamic>> products = result.rows
          .map((row) => _mapProduct(row.assoc()))
          .toList();

      return Response.ok(
        jsonEncode(products),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch products: $e'}),
      );
    }
  }

  // GET /api/v1/products/search?q=keyword
  Future<Response> _searchProducts(Request request) async {
    try {
      final q = request.url.queryParameters['q'] ?? '';
      stdout.writeln('🔍 API: Searching products with keyword: "$q"'); // Log

      if (q.isEmpty) return Response.ok('[]');

      final conn = await DbConfig().connection;
      // Search by Name or Barcode
      final sql = '''
        SELECT * FROM product 
        WHERE name LIKE :q OR barcode LIKE :q OR alias LIKE :q
        LIMIT 50
      ''';

      final result = await conn.execute(sql, {'q': '%$q%'});

      final List<Map<String, dynamic>> products = result.rows
          .map((row) => _mapProduct(row.assoc()))
          .toList();

      return Response.ok(
        jsonEncode(products),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Search failed: $e'}),
      );
    }
  }

  // GET /api/v1/products/:barcode
  Future<Response> _getProductByBarcode(Request request, String barcode) async {
    try {
      // Decode barcode in case it contains special characters
      final decodedBarcode = Uri.decodeComponent(barcode);
      stdout.writeln('🔎 API: Fetching product by Barcode: $decodedBarcode');

      final conn = await DbConfig().connection;
      final result = await conn.execute(
        'SELECT * FROM product WHERE barcode = :b LIMIT 1',
        {'b': decodedBarcode},
      );

      if (result.rows.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Product not found'}));
      }

      final product = _mapProduct(result.rows.first.assoc());

      return Response.ok(
        jsonEncode(product),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Fetch by barcode failed: $e'}),
      );
    }
  }

  // GET /api/v1/products/id/:id
  Future<Response> _getProductById(Request request, String idStr) async {
    try {
      stdout.writeln('🆔 API: Fetching product by ID: $idStr'); // Log
      final id = int.tryParse(idStr);
      if (id == null) {
        return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      }

      final conn = await DbConfig().connection;
      final result = await conn.execute(
        'SELECT * FROM product WHERE id = :id LIMIT 1',
        {'id': id},
      );

      if (result.rows.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Product not found'}));
      }

      final product = _mapProduct(result.rows.first.assoc());

      return Response.ok(
        jsonEncode(product),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Fetch by ID failed: $e'}),
      );
    }
  }
}

// PUT /api/v1/products/:id
Future<Response> _updateProduct(Request request, String idStr) async {
  try {
    final id = int.tryParse(idStr);
    if (id == null) {
      return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
    }

    final payload = await request.readAsString();
    final Map<String, dynamic> data = jsonDecode(payload);

    stdout.writeln('✏️ API: Updating product ID: $id');

    final conn = await DbConfig().connection;

    // Build Dynamic Update Query
    List<String> updates = [];
    Map<String, dynamic> params = {'id': id};

    if (data.containsKey('name')) {
      updates.add('name = :name');
      params['name'] = data['name'];
    }
    if (data.containsKey('barcode')) {
      updates.add('barcode = :barcode');
      params['barcode'] = data['barcode'];
    }
    if (data.containsKey('retailPrice')) {
      updates.add('retailPrice = :retailPrice');
      params['retailPrice'] = data['retailPrice'];
    }
    if (data.containsKey('wholesalePrice')) {
      updates.add('wholesalePrice = :wholesalePrice');
      params['wholesalePrice'] = data['wholesalePrice'];
    }
    if (data.containsKey('price')) {
      // Alias for retailPrice
      updates.add('retailPrice = :price');
      params['price'] = data['price'];
    }

    if (updates.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'No fields to update'}),
      );
    }

    final sql = 'UPDATE product SET ${updates.join(', ')} WHERE id = :id';

    final result = await conn.execute(sql, params);

    if (result.affectedRows > BigInt.zero) {
      return Response.ok(
        jsonEncode({
          'message': 'Product updated successfully',
          'success': true,
        }),
        headers: {'content-type': 'application/json'},
      );
    } else {
      // Check if product exists if no rows affected
      final check = await conn.execute(
        'SELECT id FROM product WHERE id = :id',
        {'id': id},
      );
      if (check.rows.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Product not found'}));
      }
      // Exists but nothing changed
      return Response.ok(
        jsonEncode({'message': 'No changes made', 'success': true}),
        headers: {'content-type': 'application/json'},
      );
    }
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': 'Update failed: $e'}),
    );
  }
}
