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
    await _db.ensureColumn('advance_payment', 'installment_amount',
        'DECIMAL(15,2) NULL AFTER remaining_amount');

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

    // A payroll may deduct a particular advance only once.  Do not try to
    // "clean up" duplicates here: historical duplicates are an audit issue
    // and must be reviewed before a unique key can safely be added.
    final duplicatePairs = await _db.query('''
      SELECT advance_id, payroll_id FROM advance_deduction
      GROUP BY advance_id, payroll_id HAVING COUNT(*) > 1 LIMIT 1
    ''');
    if (duplicatePairs.isEmpty) {
      try {
        await _db.execute(
            'ALTER TABLE advance_deduction ADD UNIQUE KEY uq_advance_deduction_payroll (advance_id, payroll_id)');
      } catch (_) {
        // Existing installations may already have the key.
      }
    }
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
      // Requests must never inherit a caller supplied terminal status.
      'status': 'PENDING',
    });
    return result.lastInsertID.toInt();
  }

  Future<void> approve(int id, int approvedBy) async {
    // When approved, remaining_amount becomes the full amount requested
    final result = await _db.execute('''
      UPDATE advance_payment 
      SET status = 'APPROVED', 
          approved_by = :by, 
          approved_at = NOW(),
          remaining_amount = amount
      WHERE id = :id AND status = 'PENDING'
    ''', {'id': id, 'by': approvedBy});
    if (result.affectedRows.toInt() != 1) {
      throw StateError('อนุมัติได้เฉพาะคำขอที่รออนุมัติเท่านั้น');
    }
  }

  Future<void> reject(int id) async {
    final result = await _db.execute(
        "UPDATE advance_payment SET status = 'REJECTED' WHERE id = :id AND status = 'PENDING'",
        {'id': id});
    if (result.affectedRows.toInt() != 1) {
      throw StateError('ปฏิเสธได้เฉพาะคำขอที่รออนุมัติเท่านั้น');
    }
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

  /// When [eligibleThrough] is supplied, only advances requested and approved
  /// on or before that payroll period end are eligible. This prevents a new
  /// advance from being applied to an already-ended historical pay period.
  Future<List<AdvancePayment>> getOutstanding(int employeeId,
      {DateTime? eligibleThrough}) async {
    final params = <String, dynamic>{'emp_id': employeeId};
    var eligibilitySql = '';
    if (eligibleThrough != null) {
      final cutoff = eligibleThrough.toIso8601String().split('T')[0];
      params['cutoff'] = cutoff;
      eligibilitySql = '''
        AND a.request_date <= :cutoff
        AND a.approved_at < DATE_ADD(:cutoff, INTERVAL 1 DAY)
      ''';
    }
    final results = await _db.query('''
      SELECT a.*, COALESCE(e.display_name, u.displayName) as employeeName
      FROM advance_payment a
      JOIN employee_profile e ON a.employee_id = e.id
      LEFT JOIN user u ON e.user_id = u.id
      WHERE a.employee_id = :emp_id 
        AND a.remaining_amount > 0 
        AND a.status IN ('APPROVED', 'PARTIAL')
        $eligibilitySql
      ORDER BY a.request_date ASC
    ''', params);
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

  Future<List<AdvancePayment>> getAllHistory(
      {int limit = 100, int offset = 0}) async {
    final results = await _db.query('''
      SELECT a.*, COALESCE(e.display_name, u.displayName) as employeeName
      FROM advance_payment a
      JOIN employee_profile e ON a.employee_id = e.id
      LEFT JOIN user u ON e.user_id = u.id
      ORDER BY a.request_date DESC, a.created_at DESC
      LIMIT :limit OFFSET :offset
    ''', {'limit': limit, 'offset': offset});
    return results.map((row) => AdvancePayment.fromJson(row)).toList();
  }

  Future<List<Map<String, dynamic>>> getDeductionsForAdvance(
      int advanceId) async {
    final results = await _db.query('''
      SELECT d.*, p.period_start, p.period_end, p.pay_cycle
      FROM advance_deduction d
      JOIN payroll_record p ON d.payroll_id = p.id
      WHERE d.advance_id = :adv_id
      ORDER BY d.deducted_at DESC
    ''', {'adv_id': advanceId});
    return results;
  }

  /// Read-only audit list. Nothing calls this automatically, so ambiguous
  /// historical records stay visible for an administrator to investigate.
  Future<List<Map<String, dynamic>>> getDeductedWithoutConfirmedPayroll() {
    return _db.query('''
      SELECT a.*
      FROM advance_payment a
      WHERE a.status = 'DEDUCTED'
        AND NOT EXISTS (
          SELECT 1
          FROM advance_deduction d
          JOIN payroll_record p ON p.id = d.payroll_id
          WHERE d.advance_id = a.id
            AND p.status IN ('CONFIRMED', 'PAID')
        )
      ORDER BY a.created_at ASC
    ''');
  }

  /// Repairs only the exact orphan pattern reported above.  It deliberately
  /// refuses rows with any deduction ledger or a confirmed/paid payroll.
  Future<void> repairExactOrphanDeducted(int advanceId) async {
    await _db.execute('START TRANSACTION');
    try {
      final rows = await _db.query('''
        SELECT a.id
        FROM advance_payment a
        WHERE a.id = :id AND a.status = 'DEDUCTED'
          AND NOT EXISTS (SELECT 1 FROM advance_deduction d WHERE d.advance_id = a.id)
        FOR UPDATE
      ''', {'id': advanceId});
      if (rows.length != 1) {
        throw StateError(
            'รายการนี้ไม่ใช่รายการหักครบที่ซ่อมอัตโนมัติได้อย่างปลอดภัย');
      }
      final changed = await _db.execute('''
        UPDATE advance_payment
        SET remaining_amount = amount, status = 'APPROVED'
        WHERE id = :id AND status = 'DEDUCTED' AND remaining_amount = 0
      ''', {'id': advanceId});
      if (changed.affectedRows.toInt() != 1) {
        throw StateError('รายการถูกแก้ไขระหว่างซ่อม');
      }
      await _db.execute('COMMIT');
    } catch (_) {
      await _db.execute('ROLLBACK');
      rethrow;
    }
  }
}
