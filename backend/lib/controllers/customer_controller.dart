import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../db_config.dart';
import 'dart:io';

class CustomerController {
  Router get router {
    final router = Router();
    router.get('/', _getCustomers);
    router.get('/search', _searchCustomers);
    return router;
  }

  // Helper to standardize Customer JSON
  Map<String, dynamic> _mapCustomer(Map<String, dynamic> data) {
    // Helper to safely get string from multiple possible keys
    String getString(List<String> keys) {
      for (final key in keys) {
        if (data[key] != null) return data[key].toString();
      }
      return '';
    }

    final fname = getString(['firstName', 'first_name', 'firstname']);
    final lname = getString(['lastName', 'last_name', 'lastname']);
    String fullName = '$fname $lname'.trim();

    final lineName = getString([
      'lineDisplayName',
      'line_display_name',
      'linedisplayname',
    ]);

    // Fallback: If no name, use Line Display Name
    if (fullName.isEmpty && lineName.isNotEmpty) {
      fullName = lineName;
    }

    return {
      'id': data['id'],
      'code': getString(['memberCode', 'member_code', 'membercode']),
      'firstName': fname,
      'lastName': lname,
      'name': fullName.isEmpty ? 'Unknown' : fullName,
      'phone': getString(['phone']),
      'address': getString(['address']),
      'lineUserId': getString(['lineUserId', 'line_user_id', 'lineuserid']),
      'lineDisplayName': lineName,
      'linePictureUrl': getString([
        'linePictureUrl',
        'line_picture_url',
        'linepictureurl',
      ]),
    };
  }

  // GET /api/v1/customers?page=1&limit=20
  Future<Response> _getCustomers(Request request) async {
    try {
      final params = request.url.queryParameters;
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '20') ?? 20;
      final offset = (page - 1) * limit;

      final conn = await DbConfig().connection;

      // Updated SQL to include Line Display Name & Picture
      final sql =
          '''
        SELECT id, memberCode, firstName, lastName, phone, address, 
               line_user_id, line_display_name, line_picture_url
        FROM customer 
        WHERE isDeleted = 0
        ORDER BY firstName 
        LIMIT $limit OFFSET $offset
      ''';

      stdout.writeln('🔍 API: Fetching customers (Page $page)...');
      final result = await conn.execute(sql);

      final List<Map<String, dynamic>> customers = result.rows
          .map((row) => _mapCustomer(row.assoc()))
          .toList();

      return Response.ok(
        jsonEncode(customers),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stack) {
      stdout.writeln('❌ API Error (Get Customers): $e');
      stdout.writeln(stack);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch customers: $e'}),
      );
    }
  }

  // GET /api/v1/customers/search?q=keyword
  Future<Response> _searchCustomers(Request request) async {
    try {
      final params = request.url.queryParameters;
      final query = params['q'] ?? '';

      if (query.isEmpty) {
        return Response.ok(
          jsonEncode([]),
          headers: {'content-type': 'application/json'},
        );
      }

      final conn = await DbConfig().connection;
      // Search by firstName, lastName, phone, memberCode OR Line Display Name
      final sql = '''
        SELECT id, memberCode, firstName, lastName, phone, address, 
               line_user_id, line_display_name, line_picture_url
        FROM customer 
        WHERE isDeleted = 0 
        AND (
          firstName LIKE :q OR 
          lastName LIKE :q OR 
          phone LIKE :q OR 
          memberCode LIKE :q OR 
          line_display_name LIKE :q
        )
        LIMIT 20
      ''';

      stdout.writeln('🔍 API: Searching customers for "$query"...');
      final result = await conn.execute(sql, {'q': '%$query%'});

      final List<Map<String, dynamic>> customers = result.rows
          .map((row) => _mapCustomer(row.assoc()))
          .toList();

      return Response.ok(
        jsonEncode(customers),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stack) {
      stdout.writeln('❌ API Error (Search Customers): $e');
      stdout.writeln(stack);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Search failed: $e'}),
      );
    }
  }
}
