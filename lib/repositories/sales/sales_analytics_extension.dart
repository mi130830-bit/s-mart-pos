part of '../sales_repository.dart';

extension SalesAnalyticsExtension on SalesRepository {
  // --- 7. Analytics & Schema ---

  // ✅ New Method for Credit Sales Summary
  Future<Map<String, dynamic>> getCreditStats(
      DateTime start, DateTime end) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      const sql = '''
        SELECT SUM(grandTotal) as totalAmount, COUNT(id) as billCount
        FROM `order`
        WHERE createdAt BETWEEN :start AND :end
          AND status IN ('UNPAID') -- Count only currently unpaid bills
      ''';
      final res = await _dbService.query(sql, {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      });

      if (res.isNotEmpty) {
        return {
          'amount': double.tryParse(res.first['totalAmount'].toString()) ?? 0.0,
          'count': int.tryParse(res.first['billCount'].toString()) ?? 0,
        };
      }
      return {'amount': 0.0, 'count': 0};
    } catch (e) {
      LoggerService.error('SalesRepository', 'Error getting credit stats', e);
      return {'amount': 0.0, 'count': 0};
    }
  }

  Future<List<Map<String, dynamic>>> getSalesStatsByDateRange(
      DateTime start, DateTime end, String periodType) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      String groupByFormat = periodType == 'DAILY'
          ? '%Y-%m-%d'
          : (periodType == 'MONTHLY' ? '%Y-%m' : '%Y');

      // 1. Sales Query (Cash-Basis) - Count sales only for COMPLETED and DEBT_PAYMENT
      final sqlSales = '''
        SELECT label, SUM(sales) as totalSales, SUM(orders) as orderCount FROM (
          SELECT DATE_FORMAT(createdAt, '$groupByFormat') as label, 
                 CASE WHEN status = 'COMPLETED' AND LOWER(paymentMethod) != 'credit' THEN grandTotal ELSE 0 END as sales,
                 1 as orders
          FROM `order`
          WHERE createdAt BETWEEN :start AND :end AND status IN ('COMPLETED', 'UNPAID')
          
          UNION ALL
          
          SELECT DATE_FORMAT(createdAt, '$groupByFormat') as label, 
                 ABS(amount) as sales,
                 0 as orders
          FROM debtor_transaction
          WHERE createdAt BETWEEN :start AND :end 
            AND transactionType = 'DEBT_PAYMENT' 
            AND (isDeleted = 0 OR isDeleted IS NULL)
        ) combined
        GROUP BY label ORDER BY label ASC;
      ''';
      final salesRes = await _dbService.query(sqlSales,
          {'start': start.toIso8601String(), 'end': end.toIso8601String()});

      // 2. Cost Query (From Items) - Correct calculation of Cost with Fallback to Current Product Cost
      final sqlCost = '''
        SELECT DATE_FORMAT(o.createdAt, '$groupByFormat') as label, 
               SUM(
                 (CASE WHEN oi.costPrice > 0 THEN oi.costPrice ELSE COALESCE(p.costPrice, 0) END) 
                 * oi.quantity
               ) as totalCost
        FROM `order` o 
        JOIN orderitem oi ON o.id = oi.orderId
        LEFT JOIN product p ON oi.productId = p.id
        WHERE o.createdAt BETWEEN :start AND :end AND o.status IN ('COMPLETED', 'UNPAID')
        GROUP BY label ORDER BY label ASC;
      ''';
      final costRes = await _dbService.query(sqlCost,
          {'start': start.toIso8601String(), 'end': end.toIso8601String()});

      // 3. Merge Data
      Map<String, Map<String, dynamic>> merged = {};

      for (var row in salesRes) {
        String label = row['label'].toString();
        merged[label] = {
          'label': label,
          'totalSales': double.tryParse(row['totalSales'].toString()) ?? 0.0,
          'orderCount': int.tryParse(row['orderCount'].toString()) ?? 0,
          'totalCost': 0.0,
        };
      }

      for (var row in costRes) {
        String label = row['label'].toString();
        double cost = double.tryParse(row['totalCost'].toString()) ?? 0.0;
        if (merged.containsKey(label)) {
          merged[label]!['totalCost'] = cost;
        } else {
          // If there's cost but no sales (unlikely but possible if logic changes), default sales to 0
          merged[label] = {
            'label': label,
            'totalSales': 0.0,
            'orderCount': 0,
            'totalCost': cost,
          };
        }
      }

      return merged.values.toList();
    } catch (e) {
      LoggerService.error('SalesRepository', 'Error getting sales stats', e);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTopProductsByDateRange(
      DateTime start, DateTime end,
      {int limit = 10}) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final sql = '''
        SELECT oi.productName as name, SUM(oi.quantity) as qty, SUM(oi.total) as totalSales
        FROM orderitem oi JOIN `order` o ON oi.orderId = o.id
        WHERE o.createdAt BETWEEN :start AND :end AND o.status IN ('COMPLETED', 'UNPAID')
        GROUP BY oi.productId, oi.productName ORDER BY qty DESC LIMIT $limit;
      ''';
      return await _dbService.query(sql,
          {'start': start.toIso8601String(), 'end': end.toIso8601String()});
    } catch (e) {
      LoggerService.error('SalesRepository', 'Error in getTopProductsByDateRange', e);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDetailedOrdersForExport(
      DateTime start, DateTime end) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      const sql = '''
        SELECT o.id as orderId, o.createdAt, c.id as customerId, c.memberCode, c.firstName as customerName,
               oi.productName, oi.quantity, oi.price as unitPrice, oi.total as amount
        FROM `order` o JOIN orderitem oi ON o.id = oi.orderId LEFT JOIN customer c ON o.customerId = c.id
        WHERE o.createdAt BETWEEN :start AND :end AND o.status IN ('COMPLETED', 'UNPAID')
        ORDER BY o.createdAt DESC;
      ''';
      return await _dbService.query(sql,
          {'start': start.toIso8601String(), 'end': end.toIso8601String()});
    } catch (e) {
      LoggerService.error('SalesRepository', 'Error in getDetailedOrdersForExport', e);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPaymentMethodStats(
      DateTime start, DateTime end) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      const sql = '''
        SELECT op.paymentMethod as method, SUM(op.amount) as total, COUNT(DISTINCT o.id) as count
        FROM order_payment op JOIN `order` o ON op.orderId = o.id
        WHERE o.createdAt BETWEEN :start AND :end AND o.status IN ('COMPLETED', 'UNPAID')
        GROUP BY op.paymentMethod ORDER BY total DESC;
      ''';
      return await _dbService.query(sql,
          {'start': start.toIso8601String(), 'end': end.toIso8601String()});
    } catch (e) {
      LoggerService.error('SalesRepository', 'Error in getPaymentMethodStats', e);
      return [];
    }
  }


}
