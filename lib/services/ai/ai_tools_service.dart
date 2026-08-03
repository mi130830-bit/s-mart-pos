import 'package:google_generative_ai/google_generative_ai.dart';
import '../logger_service.dart';
import '../mysql_service.dart';

class AiToolsService {
  final MySQLService _db = MySQLService();

  // 1. กำหนด Functions ที่เปิดให้ AI เรียกใช้ได้
  final Tool aiTool = Tool(
    functionDeclarations: [
      FunctionDeclaration(
        'search_bills',
        'ค้นหาประวัติบิล/ใบเสร็จ (Orders) ของลูกค้า โดยใช้ชื่อ เบอร์โทร หรือเลขบิล',
        Schema(
          SchemaType.object,
          properties: {
            'keyword': Schema(SchemaType.string, description: 'ชื่อ, เบอร์โทร, หรือเลขบิลที่ต้องการค้นหา'),
            'limit': Schema(SchemaType.integer, description: 'จำนวนรายการสูงสุดที่ต้องการ (ค่าเริ่มต้น 5, สูงสุด 10)'),
          },
          requiredProperties: ['keyword'],
        ),
      ),
      FunctionDeclaration(
        'get_debtors',
        'ดึงข้อมูลสรุปลูกหนี้ที่มียอดค้างชำระ (currentDebt > 0) เรียงตามยอดค้างมากสุด',
        Schema(
          SchemaType.object,
          properties: {
            'limit': Schema(SchemaType.integer, description: 'จำนวนรายการสูงสุด (ค่าเริ่มต้น 10, สูงสุด 20)'),
          },
        ),
      ),
      FunctionDeclaration(
        'get_expenses',
        'ดึงข้อมูลประวัติรายจ่ายล่าสุด (Expenses)',
        Schema(
          SchemaType.object,
          properties: {
            'limit': Schema(SchemaType.integer, description: 'จำนวนรายการสูงสุด (ค่าเริ่มต้น 10, สูงสุด 20)'),
            'category': Schema(SchemaType.string, description: 'หมวดหมู่รายจ่ายที่ต้องการกรอง (ถ้ามี)'),
          },
        ),
      ),
      FunctionDeclaration(
        'search_products',
        'ค้นหาสินค้าเพื่อดูราคาทุน ราคาขาย และจำนวนสต็อกคงเหลือ',
        Schema(
          SchemaType.object,
          properties: {
            'keyword': Schema(SchemaType.string, description: 'ชื่อสินค้า หรือบาร์โค้ด'),
            'limit': Schema(SchemaType.integer, description: 'จำนวนรายการสูงสุด (ค่าเริ่มต้น 5)'),
          },
          requiredProperties: ['keyword'],
        ),
      ),
      FunctionDeclaration(
        'get_sales_summary',
        'สรุปยอดขาย รายจ่าย และกระแสเงินสด (Cash Flow) ตามช่วงวันที่กำหนด',
        Schema(
          SchemaType.object,
          properties: {
            'startDate': Schema(SchemaType.string, description: 'วันที่เริ่มต้น YYYY-MM-DD (เช่น 2026-01-01) ถ้าไม่ระบุจะใช้วันนี้'),
            'endDate': Schema(SchemaType.string, description: 'วันที่สิ้นสุด YYYY-MM-DD (เช่น 2026-08-01) ถ้าไม่ระบุจะใช้วันนี้'),
            'date': Schema(SchemaType.string, description: '(Deprecated) วันที่ในรูปแบบ YYYY-MM-DD'),
          },
        ),
      ),
      FunctionDeclaration(
        'get_top_selling_products',
        'ดึงข้อมูลสินค้าขายดีที่สุด (Best Sellers) ตามช่วงเวลาที่กำหนด',
        Schema(
          SchemaType.object,
          properties: {
            'startDate': Schema(SchemaType.string, description: 'วันที่เริ่มต้น YYYY-MM-DD (ถ้าไม่ระบุ จะดึงของเดือนปัจจุบัน)'),
            'endDate': Schema(SchemaType.string, description: 'วันที่สิ้นสุด YYYY-MM-DD (ถ้าไม่ระบุ จะดึงของเดือนปัจจุบัน)'),
            'limit': Schema(SchemaType.integer, description: 'จำนวนรายการสูงสุด (ค่าเริ่มต้น 10, สูงสุด 20)'),
          },
        ),
      ),
    ],
  );

  // 2. จัดการเมื่อ AI ขอเรียกใช้ Function
  Future<Map<String, Object?>> handleFunctionCall(FunctionCall call) async {
    LoggerService.info('AiToolsService', 'AI is calling function: \${call.name} with args: \${call.args}');
    try {
      switch (call.name) {
        case 'search_bills':
          return await _searchBills(call.args);
        case 'get_debtors':
          return await _getDebtors(call.args);
        case 'get_expenses':
          return await _getExpenses(call.args);
        case 'search_products':
          return await _searchProducts(call.args);
        case 'get_sales_summary':
          return await _getSalesSummary(call.args);
        case 'get_top_selling_products':
          return await _getTopSellingProducts(call.args);
        default:
          return {'error': 'Function \${call.name} not found'};
      }
    } catch (e) {
      LoggerService.error('AiToolsService', 'Error executing \${call.name}', e);
      return {'error': 'Failed to execute \${call.name}: \$e'};
    }
  }

  // --- Implementation Methods ---

  Future<Map<String, Object?>> _searchBills(Map<String, Object?> args) async {
    final keyword = args['keyword']?.toString() ?? '';
    final limit = (args['limit'] as num?)?.toInt() ?? 5;
    
    final sql = '''
      SELECT o.id as orderId, o.grandTotal, o.received, o.paymentMethod, o.createdAt,
             c.firstName, c.lastName, c.phone
      FROM `order` o
      LEFT JOIN customer c ON o.customerId = c.id
      WHERE o.id = :kw OR c.firstName LIKE :kw_like OR c.phone LIKE :kw_like
      ORDER BY o.createdAt DESC
      LIMIT :limit
    ''';
    
    final res = await _db.query(sql, {
      'kw': keyword,
      'kw_like': '%\$keyword%',
      'limit': limit.clamp(1, 10),
    });
    
    return {'results': res};
  }

  Future<Map<String, Object?>> _getDebtors(Map<String, Object?> args) async {
    final limit = (args['limit'] as num?)?.toInt() ?? 10;
    
    final sql = '''
      SELECT id, firstName, lastName, phone, currentDebt
      FROM customer
      WHERE currentDebt > 0
      ORDER BY currentDebt DESC
      LIMIT :limit
    ''';
    
    final res = await _db.query(sql, {
      'limit': limit.clamp(1, 20),
    });
    
    return {'results': res};
  }

  Future<Map<String, Object?>> _getExpenses(Map<String, Object?> args) async {
    final limit = (args['limit'] as num?)?.toInt() ?? 10;
    final category = args['category']?.toString();
    
    String sql = '''
      SELECT title, amount, category, expenseDate, note
      FROM expense
    ''';
    
    Map<String, dynamic> params = {'limit': limit.clamp(1, 20)};
    if (category != null && category.isNotEmpty) {
      sql += ' WHERE category = :cat';
      params['cat'] = category;
    }
    
    sql += ' ORDER BY expenseDate DESC LIMIT :limit';
    
    final res = await _db.query(sql, params);
    return {'results': res};
  }

  Future<Map<String, Object?>> _searchProducts(Map<String, Object?> args) async {
    final keyword = args['keyword']?.toString() ?? '';
    final limit = (args['limit'] as num?)?.toInt() ?? 5;
    
    final sql = '''
      SELECT id, name, price, costPrice, stock, stockMin
      FROM product
      WHERE name LIKE :kw_like OR id IN (SELECT productId FROM product_barcode WHERE barcode = :kw)
      LIMIT :limit
    ''';
    
    final res = await _db.query(sql, {
      'kw': keyword,
      'kw_like': '%\$keyword%',
      'limit': limit.clamp(1, 10),
    });
    
    return {'results': res};
  }

  Future<Map<String, Object?>> _getSalesSummary(Map<String, Object?> args) async {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    String startDateStr = args['startDate']?.toString() ?? todayStr;
    String endDateStr = args['endDate']?.toString() ?? todayStr;
    
    // Fallback for old 'date' param if AI still uses it
    if (args.containsKey('date') && args['date'] != null && args['startDate'] == null) {
      startDateStr = args['date'].toString();
      endDateStr = args['date'].toString();
    }
    
    final salesSql = '''
      SELECT 
        COUNT(id) as totalBills, 
        SUM(grandTotal) as totalSales, 
        SUM(received) as totalReceived,
        SUM(CASE WHEN status = 'UNPAID' THEN 1 ELSE 0 END) as unpaidBills,
        SUM(CASE WHEN status = 'UNPAID' THEN grandTotal - received ELSE 0 END) as unpaidAmount
      FROM `order`
      WHERE DATE(createdAt) BETWEEN :start AND :end
    ''';
    
    final expenseSql = '''
      SELECT SUM(amount) as totalExpenses
      FROM expense
      WHERE DATE(expenseDate) BETWEEN :start AND :end
    ''';
    
    final poSql = '''
      SELECT SUM(totalAmount) as totalPurchases
      FROM purchase_order
      WHERE DATE(createdAt) BETWEEN :start AND :end
        AND isPaid = 1
    ''';
    
    final salesRes = await _db.query(salesSql, {'start': startDateStr, 'end': endDateStr});
    final expenseRes = await _db.query(expenseSql, {'start': startDateStr, 'end': endDateStr});
    final poRes = await _db.query(poSql, {'start': startDateStr, 'end': endDateStr});
    
    double sales = double.tryParse(salesRes.first['totalSales']?.toString() ?? '0') ?? 0.0;
    double generalExpenses = double.tryParse(expenseRes.first['totalExpenses']?.toString() ?? '0') ?? 0.0;
    double purchases = double.tryParse(poRes.isNotEmpty ? poRes.first['totalPurchases']?.toString() ?? '0' : '0') ?? 0.0;
    
    double totalExpenses = generalExpenses + purchases;
    double cashflow = sales - totalExpenses;

    return {
      'period': '$startDateStr to $endDateStr',
      'salesSummary': salesRes.isNotEmpty ? salesRes.first : {},
      'expenseSummary': {
        'generalExpenses': generalExpenses,
        'paidPurchases': purchases,
        'totalExpenses': totalExpenses,
      },
      'cashflow': cashflow,
    };
  }

  Future<Map<String, Object?>> _getTopSellingProducts(Map<String, Object?> args) async {
    final now = DateTime.now();
    final firstDayOfMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}-01";
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    String startDateStr = args['startDate']?.toString() ?? firstDayOfMonth;
    String endDateStr = args['endDate']?.toString() ?? todayStr;
    final limit = (args['limit'] as num?)?.toInt() ?? 10;
    
    final sql = '''
      SELECT oi.productName as name, SUM(oi.quantity) as totalQtySold, SUM(oi.total) as totalSales
      FROM orderitem oi 
      JOIN `order` o ON oi.orderId = o.id
      WHERE DATE(o.createdAt) BETWEEN :start AND :end 
        AND o.status IN ('COMPLETED', 'UNPAID')
      GROUP BY oi.productId, oi.productName 
      ORDER BY totalQtySold DESC 
      LIMIT :limit
    ''';
    
    final res = await _db.query(sql, {
      'start': startDateStr,
      'end': endDateStr,
      'limit': limit.clamp(1, 20),
    });
    
    return {
      'period': '\$startDateStr to \$endDateStr',
      'results': res,
    };
  }
}
