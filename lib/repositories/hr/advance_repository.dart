import '../../services/mysql_service.dart';
import '../../models/hr/advance_payment.dart';

class AdvanceRepository {
  final MySQLService _db = MySQLService();

  Future<void> initTable() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS advance_payment (
        id INT PRIMARY KEY AUTO_INCREMENT,
        employee_id INT NOT NULL,
        amount DECIMAL(15,2) NOT NULL,
        request_date DATE NOT NULL,
        reason TEXT NULL,
        status VARCHAR(50) DEFAULT 'PENDING',
        approved_by INT NULL,
        approved_at DATETIME NULL,
        remaining_amount DECIMAL(15,2) DEFAULT 0.00,
        installment_amount DECIMAL(15,2) NULL,
        note TEXT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (employee_id) REFERENCES employee_profile(id)
      )
    ''');
    
    // Auto-migrate
    await _db.ensureColumn('advance_payment', 'installment_amount', 'DECIMAL(15,2) NULL AFTER remaining_amount');

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS advance_deduction (
        id INT PRIMARY KEY AUTO_INCREMENT,
        advance_id INT NOT NULL,
        payroll_id INT NOT NULL,
        deducted_amount DECIMAL(15,2) NOT NULL,
        deducted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (advance_id) REFERENCES advance_payment(id)
        -- payroll_id will reference payroll_record(id), but we create that separately
      )
    ''');
  }

  Future<int> create(AdvancePayment advance) async {
    final sql = '''
      INSERT INTO advance_payment (employee_id, amount, request_date, reason, installment_amount, status)
      VALUES (:employee_id, :amount, :request_date, :reason, :installment, :status)
    ''';
    final result = await _db.execute(sql, {
      'employee_id': advance.employeeId,
      'amount': advance.amount,
      'request_date': advance.requestDate.toIso8601String().split('T')[0],
      'reason': advance.reason,
      'installment': advance.installmentAmount,
      'status': advance.status,
    });
    return result.lastInsertID.toInt();
  }

  Future<void> approve(int id, int approvedBy) async {
    // When approved, remaining_amount becomes the full amount requested
    await _db.execute('''
      UPDATE advance_payment 
      SET status = 'APPROVED', 
          approved_by = :by, 
          approved_at = NOW(),
          remaining_amount = amount
      WHERE id = :id
    ''', {'id': id, 'by': approvedBy});
  }

  Future<void> reject(int id) async {
    await _db.execute(
      "UPDATE advance_payment SET status = 'REJECTED' WHERE id = :id",
      {'id': id}
    );
  }

  Future<List<AdvancePayment>> getPending() async {
    final results = await _db.query('''
      SELECT a.*, COALESCE(e.display_name, u.displayName) as employeeName
      FROM advance_payment a
      JOIN employee_profile e ON a.employee_id = e.id
      LEFT JOIN user u ON e.user_id = u.id
      WHERE a.status = 'PENDING'
      ORDER BY a.created_at DESC
    ''');
    return results.map((row) => AdvancePayment.fromJson(row)).toList();
  }

  Future<List<AdvancePayment>> getOutstanding(int employeeId) async {
    final results = await _db.query('''
      SELECT a.*, COALESCE(e.display_name, u.displayName) as employeeName
      FROM advance_payment a
      JOIN employee_profile e ON a.employee_id = e.id
      LEFT JOIN user u ON e.user_id = u.id
      WHERE a.employee_id = :emp_id 
        AND a.remaining_amount > 0 
        AND a.status IN ('APPROVED', 'PARTIAL')
      ORDER BY a.request_date ASC
    ''', {'emp_id': employeeId});
    return results.map((row) => AdvancePayment.fromJson(row)).toList();
  }

  Future<double> getTotalOutstanding(int employeeId) async {
    final results = await _db.query('''
      SELECT SUM(remaining_amount) as total
      FROM advance_payment 
      WHERE employee_id = :emp_id 
        AND status IN ('APPROVED', 'PARTIAL')
    ''', {'emp_id': employeeId});
    
    if (results.isEmpty || results.first['total'] == null) return 0.0;
    return double.tryParse(results.first['total'].toString()) ?? 0.0;
  }

  Future<void> recordDeduction(int advanceId, int payrollId, double amount) async {
    // 1. Insert deduction record
    await _db.execute('''
      INSERT INTO advance_deduction (advance_id, payroll_id, deducted_amount)
      VALUES (:adv_id, :pay_id, :amt)
    ''', {
      'adv_id': advanceId,
      'pay_id': payrollId,
      'amt': amount,
    });

    // 2. Update remaining amount and status
    await _db.execute('''
      UPDATE advance_payment 
      SET remaining_amount = remaining_amount - :amt,
          status = CASE 
            WHEN remaining_amount - :amt <= 0 THEN 'DEDUCTED'
            ELSE 'PARTIAL'
          END
      WHERE id = :adv_id
    ''', {'adv_id': advanceId, 'amt': amount});
  }

  Future<List<AdvancePayment>> getHistory(int employeeId) async {
    final results = await _db.query('''
      SELECT a.*, COALESCE(e.display_name, u.displayName) as employeeName
      FROM advance_payment a
      JOIN employee_profile e ON a.employee_id = e.id
      LEFT JOIN user u ON e.user_id = u.id
      WHERE a.employee_id = :emp_id
      ORDER BY a.request_date DESC
    ''', {'emp_id': employeeId});
    return results.map((row) => AdvancePayment.fromJson(row)).toList();
  }

  Future<void> revertDeductionsForPayroll(int payrollId) async {
    final deductions = await _db.query('''
      SELECT * FROM advance_deduction WHERE payroll_id = :pay_id
    ''', {'pay_id': payrollId});

    for (var d in deductions) {
      final advId = d['advance_id'];
      final amt = d['deducted_amount'];
      
      await _db.execute('''
        UPDATE advance_payment
        SET remaining_amount = remaining_amount + :amt,
            status = CASE 
              WHEN remaining_amount + :amt >= amount THEN 'APPROVED'
              ELSE 'PARTIAL'
            END
        WHERE id = :adv_id
      ''', {'adv_id': advId, 'amt': amt});
    }

    await _db.execute('''
      DELETE FROM advance_deduction WHERE payroll_id = :pay_id
    ''', {'pay_id': payrollId});
  }

  Future<List<AdvancePayment>> getAllHistory() async {
    final results = await _db.query('''
      SELECT a.*, COALESCE(e.display_name, u.displayName) as employeeName
      FROM advance_payment a
      JOIN employee_profile e ON a.employee_id = e.id
      LEFT JOIN user u ON e.user_id = u.id
      ORDER BY a.request_date DESC, a.created_at DESC
    ''');
    return results.map((row) => AdvancePayment.fromJson(row)).toList();
  }

  Future<List<Map<String, dynamic>>> getDeductionsForAdvance(int advanceId) async {
    final results = await _db.query('''
      SELECT d.*, p.period_start, p.period_end, p.pay_cycle
      FROM advance_deduction d
      JOIN payroll_record p ON d.payroll_id = p.id
      WHERE d.advance_id = :adv_id
      ORDER BY d.deducted_at DESC
    ''', {'adv_id': advanceId});
    return results;
  }
}
