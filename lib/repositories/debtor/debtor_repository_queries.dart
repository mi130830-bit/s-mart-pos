part of '../debtor_repository.dart';

extension DebtorRepositoryQueries on DebtorRepository {
  // 4. ดึงประวัติลูกหนี้รายคน
  Future<List<DebtorTransaction>> getDebtorHistory(int customerId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      const sql = '''
        SELECT * FROM debtor_transaction 
        WHERE customerId = :id AND (isDeleted = 0 OR isDeleted IS NULL)
        ORDER BY createdAt DESC;
      ''';
      final results = await _dbService.query(sql, {'id': customerId});
      return results.map((r) => DebtorTransaction.fromJson(r)).toList();
    } catch (e) {
      debugPrint('Error fetching debtor history: $e');
      return [];
    }
  }

  // 5. ดึงรายชื่อลูกหนี้ทั้งหมด (ที่มีหนี้ค้าง > 0)
  Future<List<Customer>> getActiveDebtors() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // ดึงลูกค้าที่มีหนี้มากกว่า 0 (0.01 เพื่อกัน Error ทศนิยม)
      // ดึงลูกค้าที่มีหนี้ > 0 และเรียงตามความเคลื่อนไหวล่าสุด
      const sql = '''
        SELECT c.*, MAX(dt.createdAt) as latestActivity
        FROM customer c
        LEFT JOIN debtor_transaction dt ON c.id = dt.customerId
        WHERE c.currentDebt > 0.01 AND (dt.isDeleted = 0 OR dt.isDeleted IS NULL)
        GROUP BY c.id
        ORDER BY latestActivity DESC;
      ''';
      final results = await _dbService.query(sql);
      return results.map((r) => Customer.fromJson(r)).toList();
    } catch (e) {
      debugPrint('Error fetching active debtors: $e');
      return [];
    }
  }

  // 6. ดึงรายการขายเชื่อทั้งหมด (สำหรับแสดงผลแบบ List บิล)
  // เน้นเฉพาะลูกค้าที่มีหนี้ค้างอยู่
  // ปรับปรุง: ดึงจากตาราง order โดยตรงตามคำขอ (Bills with remaining > 0)
  Future<List<OutstandingBill>> getOutstandingCreditSales() async {
    if (!_dbService.isConnected()) await _dbService.connect();

    try {
      // Query Order Table directly
      // Logic: Bills where received < grandTotal AND status is not VOID
      const sql = '''
        SELECT 
          o.id as orderId,
          o.customerId,
          o.grandTotal as amount,
          o.received as received,
          (o.grandTotal - o.received) as remaining,
          o.createdAt,
          IFNULL(c.firstName, 'ลูกค้าทั่วไป') as firstName,
          IFNULL(c.lastName, '') as lastName,
          IFNULL(c.phone, '-') as phone,
          c.line_user_id as lineUserId,
          IFNULL(c.currentDebt, 0) as currentDebt,
          'CREDIT' as status
        FROM `order` o
        LEFT JOIN customer c ON o.customerId = c.id
        WHERE (o.grandTotal - o.received) > 0.5 
          AND o.status != 'VOID' 
          AND o.customerId > 0
        ORDER BY o.createdAt DESC;
      ''';

      final results = await _dbService.query(sql);
      debugPrint(
          'DebtorRepository: Found ${results.length} items (Source: Order Table)');

      return results.map((r) => OutstandingBill.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error fetching outstanding orders: $e');
      return [];
    }
  }

  // 8. ดึงรายการบิลค้างชำระ (คำนวณจาก Transaction History)
  Future<List<OutstandingBill>> getPendingBills(int customerId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      debugPrint('Fetching pending bills for Customer ID: $customerId');

      // 1. Fetch ALL Credit Sales
      const sqlCredit = '''
        SELECT 
          dt.orderId,
          dt.amount,
          dt.createdAt,
          o.grandTotal,
          o.received
        FROM debtor_transaction dt
        LEFT JOIN `order` o ON dt.orderId = o.id
        WHERE dt.customerId = :cid
          AND dt.transactionType = 'CREDIT_SALE'
          AND (dt.isDeleted = 0 OR dt.isDeleted IS NULL)
        ORDER BY dt.createdAt ASC;
      ''';

      // 2. Fetch ALL Payments that are linked to specific orders
      const sqlPayments = '''
        SELECT orderId, amount 
        FROM debtor_transaction 
        WHERE customerId = :cid 
          AND transactionType = 'DEBT_PAYMENT'
          AND orderId IS NOT NULL
          AND (isDeleted = 0 OR isDeleted IS NULL);
      ''';

      final creditResults =
          await _dbService.query(sqlCredit, {'cid': customerId});
      final paymentResults =
          await _dbService.query(sqlPayments, {'cid': customerId});

      // Map OrderID -> Total Paid specifically for that order
      final Map<int, double> paidMap = {};
      for (var p in paymentResults) {
        final oid = int.tryParse(p['orderId'].toString());
        final amt = double.tryParse(p['amount'].toString())?.abs() ?? 0.0;
        if (oid != null) {
          paidMap[oid] = (paidMap[oid] ?? 0.0) + amt;
        }
      }

      final List<OutstandingBill> bills = [];

      for (var row in creditResults) {
        final int? oId = int.tryParse(row['orderId'].toString());
        // If no Order ID, we can't track it individually easily, skip or treat as general debt
        if (oId == null) continue;

        final double grandTotal =
            double.tryParse(row['grandTotal'].toString()) ??
                double.tryParse(row['amount'].toString()) ??
                0.0;

        // Received from Order Table (might be partial deposit)
        final double orderReceived =
            double.tryParse(row['received'].toString()) ?? 0.0;

        final double remaining = grandTotal - orderReceived;

        if (remaining > 0.01) {
          final Map<String, dynamic> map = {
            'orderId': oId,
            'customerId': customerId,
            'amount': grandTotal,
            'remaining': remaining,
            'received': orderReceived,
            'createdAt': row['createdAt'],
            'status': 'CREDIT',
            'firstName': '', // Dummy
            'lastName': '', // Dummy
          };
          bills.add(OutstandingBill.fromMap(map));
        }
      }

      return bills;
    } catch (e) {
      debugPrint('Error fetching pending bills: $e');
      return [];
    }
  }
}
