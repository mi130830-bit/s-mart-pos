import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../db_config.dart';
import 'dart:io';

class ProductController {
  Router get router {
    final router = Router();
    router.get('/', _getProducts);
    router.get('/search', _searchProducts);
    router.get('/id/<id>', _getProductById);
    router.get('/<barcode>', _getProductByBarcode);
    router.put('/<id>', _updateProduct);
    return router;
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
      'category_id': data['category_id'] ?? data['categoryId'],
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

      // Log for Manual Verification
      stdout.writeln(
        '📦 API: Fetching products (Page: $page, Limit: $limit)...',
      );

      final conn = await DbConfig().connection;

      // Build Query
      String sql = 'SELECT * FROM product';
      Map<String, dynamic> queryParams = {'limit': limit, 'offset': offset};

      if (categoryId != null) {
        sql += ' WHERE categoryId = :catId';
        queryParams['catId'] = categoryId;
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
