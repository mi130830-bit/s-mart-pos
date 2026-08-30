import '../services/mysql_service.dart';
import '../services/logger_service.dart';

class DeadStockFilter {
  final int? daysInactive; // null = never moved, 30, 60, 90, 180, 365
  final int? categoryId; // null = all
  final String stockFilter; // 'has_stock', 'zero_stock', 'all'
  final String searchQuery;

  const DeadStockFilter({
    this.daysInactive,
    this.categoryId,
    this.stockFilter = 'has_stock',
    this.searchQuery = '',
  });

  DeadStockFilter copyWith({
    int? daysInactive,
    bool clearDaysInactive = false,
    int? categoryId,
    bool clearCategory = false,
    String? stockFilter,
    String? searchQuery,
  }) {
    return DeadStockFilter(
      daysInactive: clearDaysInactive ? null : (daysInactive ?? this.daysInactive),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      stockFilter: stockFilter ?? this.stockFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class DeadStockSummary {
  final int totalItems;
  final double totalQuantity;
  final double totalCapital;

  const DeadStockSummary({
    required this.totalItems,
    required this.totalQuantity,
    required this.totalCapital,
  });
}

class DeadStockRepository {
  final MySQLService _db;

  DeadStockRepository({MySQLService? db}) : _db = db ?? MySQLService();

  /// ดึงหมวดหมู่สินค้าทั้งหมดสำหรับ Dropdown
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final sql = '''
        SELECT id, name 
        FROM product_type 
        ORDER BY name ASC
      ''';
      return await _db.query(sql);
    } catch (e, stack) {
      LoggerService.error('DeadStockRepo', 'Failed to load product types', e, stack);
      return [];
    }
  }

  /// ดึงข้อมูลสินค้าที่ไม่มีการเคลื่อนไหวตาม Filter
  Future<List<Map<String, dynamic>>> getDeadStockProducts(DeadStockFilter filter) async {
    try {
      final List<String> whereClauses = ['p.isActive = 1'];
      final Map<String, dynamic> params = {};

      // 1. Inactivity Filter
      if (filter.daysInactive == null) {
        // Never moved at all (neither sold nor adjusted)
        whereClauses.add('''
          p.id NOT IN (SELECT DISTINCT productId FROM orderitem WHERE productId IS NOT NULL)
          AND p.id NOT IN (SELECT DISTINCT productId FROM stockledger WHERE productId IS NOT NULL)
        ''');
      } else {
        // No sales or stock adjustments within the specified number of days
        final cutoffDate = DateTime.now()
            .subtract(Duration(days: filter.daysInactive!))
            .toIso8601String()
            .substring(0, 10);
        params['cutoffDate'] = cutoffDate;

        whereClauses.add('''
          p.id NOT IN (
            SELECT DISTINCT oi.productId 
            FROM orderitem oi
            JOIN `order` o ON oi.orderId = o.id
            WHERE oi.productId IS NOT NULL 
              AND o.createdAt >= :cutoffDate 
              AND (o.status IS NULL OR o.status != 'cancelled')
          )
          AND p.id NOT IN (
            SELECT DISTINCT sl.productId 
            FROM stockledger sl 
            WHERE sl.productId IS NOT NULL 
              AND sl.createdAt >= :cutoffDate
          )
        ''');
      }

      // 2. Category Filter
      if (filter.categoryId != null) {
        whereClauses.add('p.productType = :categoryId');
        params['categoryId'] = filter.categoryId;
      }

      // 3. Stock Filter
      if (filter.stockFilter == 'has_stock') {
        whereClauses.add('p.stockQuantity > 0');
      } else if (filter.stockFilter == 'zero_stock') {
        whereClauses.add('p.stockQuantity <= 0');
      }

      // 4. Search Filter
      if (filter.searchQuery.trim().isNotEmpty) {
        final query = '%${filter.searchQuery.trim()}%';
        whereClauses.add('(p.name LIKE :search OR p.barcode LIKE :search)');
        params['search'] = query;
      }

      final sql = '''
        SELECT 
          p.id, 
          p.barcode, 
          p.name, 
          p.productType, 
          COALESCE(pt.name, 'ทั่วไป') as categoryName,
          COALESCE(u.name, 'ชิ้น') as unitName,
          p.stockQuantity, 
          p.costPrice, 
          p.retailPrice,
          (p.stockQuantity * IF(p.costPrice > 0, p.costPrice, p.retailPrice)) as totalCapital,
          p.createdAt as productCreatedAt,
          (
            SELECT MAX(sl.createdAt) 
            FROM stockledger sl 
            WHERE sl.productId = p.id
          ) as lastStockAdjustmentDate,
          (
            SELECT MAX(o.createdAt)
            FROM orderitem oi
            JOIN `order` o ON oi.orderId = o.id
            WHERE oi.productId = p.id AND (o.status IS NULL OR o.status != 'cancelled')
          ) as lastSaleDate
        FROM product p
        LEFT JOIN product_type pt ON p.productType = pt.id
        LEFT JOIN unit u ON p.unitId = u.id
        WHERE ${whereClauses.join(' AND ')}
        ORDER BY totalCapital DESC, p.stockQuantity DESC
      ''';

      return await _db.query(sql, params);
    } catch (e, stack) {
      LoggerService.error('DeadStockRepo', 'Failed to query dead stock products', e, stack);
      return [];
    }
  }

  /// คำนวณยอดสรุป KPI จากรายการสินค้า
  DeadStockSummary computeSummary(List<Map<String, dynamic>> records) {
    int totalItems = records.length;
    double totalQty = 0.0;
    double totalCapital = 0.0;

    for (var r in records) {
      final qty = double.tryParse(r['stockQuantity']?.toString() ?? '0') ?? 0.0;
      final capital = double.tryParse(r['totalCapital']?.toString() ?? '0') ?? 0.0;
      totalQty += qty;
      totalCapital += capital;
    }

    return DeadStockSummary(
      totalItems: totalItems,
      totalQuantity: totalQty,
      totalCapital: totalCapital,
    );
  }
}
