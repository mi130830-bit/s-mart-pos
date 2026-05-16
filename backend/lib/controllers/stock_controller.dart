import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../db_config.dart';

class StockController {
  Router get router {
    final router = Router();
    // POST /api/v1/stock/adjust
    router.post('/adjust', _handleStockAdjustment);
    // POST /api/v1/stock/increase
    router.post('/increase', _handleStockIncrease);
    return router;
  }

  // POST /api/v1/stock/adjust
  // Body: { "productId": 123, "quantity": 50, "note": "Checked via S-Link App", "user": "Driver1" }
  Future<Response> _handleStockAdjustment(Request request) async {
    try {
      final payload = await request.readAsString();
      final Map<String, dynamic> data = jsonDecode(payload);

      final int? productId = data['productId']; // or handle barcode if passed
      final double? actualQty = double.tryParse(data['quantity'].toString());
      final String note = data['note'] ?? 'Check from S-Link App';
      final String user = data['user'] ?? 'S-Link User';

      if (productId == null || actualQty == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Missing productId or quantity'}),
        );
      }

      final conn = await DbConfig().connection;

      // 1. Get Current Stock
      final res = await conn.execute(
        'SELECT stockQuantity FROM product WHERE id = :id',
        {'id': productId},
      );

      if (res.rows.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Product not found'}));
      }

      final double currentStock =
          double.tryParse(res.rows.first.assoc()['stockQuantity'].toString()) ??
          0.0;
      final double diff = actualQty - currentStock;

      // 2. Insert Ledger (Even if diff is 0, we verify)
      await conn.execute(
        '''
        INSERT INTO stockledger (productId, transactionType, quantityChange, note, createdAt)
        VALUES (:pid, :type, :change, :note, NOW())
        ''',
        {
          'pid': productId,
          'type': 'ADJUST_FIX_APP', // Use specific type ending in _APP
          'change': diff,
          'note': '$note (by $user)',
        },
      );

      // 3. Update Product Stock (If changed)
      if (diff != 0) {
        await conn.execute(
          'UPDATE product SET stockQuantity = :qty WHERE id = :id',
          {'qty': actualQty, 'id': productId},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Stock adjusted successfully',
          'diff': diff,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Stock Adjustment Failed: $e'}),
      );
    }
  }

  // POST /api/v1/stock/increase
  // Body: { "productId": 123, "quantity": 10, "note": "Stock In via App", "user": "Admin" }
  Future<Response> _handleStockIncrease(Request request) async {
    try {
      final payload = await request.readAsString();
      final Map<String, dynamic> data = jsonDecode(payload);

      final int? productId = data['productId'];
      final double? qtyToAdd = double.tryParse(data['quantity'].toString());
      final String note = data['note'] ?? 'Stock In from S-Link App';
      final String user = data['user'] ?? 'S-Link User';

      if (productId == null || qtyToAdd == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Missing productId or quantity'}),
        );
      }

      final conn = await DbConfig().connection;

      // 1. ตรวจสอบสินค้าก่อน
      final res = await conn.execute(
        'SELECT stockQuantity FROM product WHERE id = :id',
        {'id': productId},
      );

      if (res.rows.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Product not found'}));
      }

      // 2. INSERT Ledger
      await conn.execute(
        '''
        INSERT INTO stockledger (productId, transactionType, quantityChange, note, createdAt)
        VALUES (:pid, 'STOCK_IN_APP', :change, :note, NOW())
        ''',
        {'pid': productId, 'change': qtyToAdd, 'note': '$note (by $user)'},
      );

      // 3. UPDATE Stock (Relative)
      await conn.execute(
        'UPDATE product SET stockQuantity = stockQuantity + :qty WHERE id = :id',
        {'qty': qtyToAdd, 'id': productId},
      );

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Stock increased successfully',
          'added': qtyToAdd,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Stock Increase Failed: $e'}),
      );
    }
  }
}
