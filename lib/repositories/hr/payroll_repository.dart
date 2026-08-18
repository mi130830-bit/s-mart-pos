import '../../services/mysql_service.dart';
import '../../models/hr/payroll_record.dart';

class PayrollRepository {
  final MySQLService _db = MySQLService();

  Future<void> initTable() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS payroll_record (
        id INT PRIMARY KEY AUTO_INCREMENT,
        employee_id INT NOT NULL,
        pay_cycle VARCHAR(20) NOT NULL,
        period_start DATE NOT NULL,
        period_end DATE NOT NULL,
        work_days DECIMAL(5,2) DEFAULT 0.00,
        absent_days INT DEFAULT 0,
        late_count INT DEFAULT 0,
        leave_days DECIMAL(5,2) DEFAULT 0.00,
        daily_wage_total DECIMAL(15,2) DEFAULT 0.00,
        base_salary DECIMAL(15,2) DEFAULT 0.00,
        trip_count INT DEFAULT 0,
        trip_total_fee DECIMAL(15,2) DEFAULT 0.00,
        overtime_hours DECIMAL(5,2) DEFAULT 0.00,
        overtime_pay DECIMAL(15,2) DEFAULT 0.00,
        bonus DECIMAL(15,2) DEFAULT 0.00,
        gross_pay DECIMAL(15,2) NOT NULL,
        advance_deductions DECIMAL(15,2) DEFAULT 0.00,
        social_security DECIMAL(15,2) DEFAULT 0.00,
        other_deductions DECIMAL(15,2) DEFAULT 0.00,
        total_deductions DECIMAL(15,2) NOT NULL,
        net_pay DECIMAL(15,2) NOT NULL,
        status VARCHAR(50) DEFAULT 'DRAFT',
        confirmed_by INT NULL,
        paid_at DATETIME NULL,
        note TEXT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (employee_id) REFERENCES employee_profile(id)
      )
    ''');

    // Migration: ensure work_days is DECIMAL if it was previously INT
    try {
      await _db.execute(
          'ALTER TABLE payroll_record MODIFY work_days DECIMAL(5,2) DEFAULT 0.00');
    } catch (e) {
      // Ignore if column is already modified or if syntax error (MySQL handles it differently, but this is safe)
    }
  }

  Future<int> create(PayrollRecord rec) async {
    final result = await _db.execute('''
      INSERT INTO payroll_record (
        employee_id, pay_cycle, period_start, period_end, work_days,
        absent_days, late_count, leave_days, daily_wage_total, base_salary,
        trip_count, trip_total_fee, overtime_hours, overtime_pay, bonus,
        gross_pay, advance_deductions, social_security, other_deductions,
        total_deductions, net_pay, status, note
      ) VALUES (
        :emp_id, :cycle, :start, :end, :w_days,
        :a_days, :late, :l_days, :wage, :base,
        :t_cnt, :t_fee, :ot_hrs, :ot_pay, :bonus,
        :gross, :adv, :ss, :other,
        :tot_ded, :net, :status, :note
      )
    ''', {
      'emp_id': rec.employeeId,
      'cycle': rec.payCycle,
      'start': rec.periodStart.toIso8601String().split('T')[0],
      'end': rec.periodEnd.toIso8601String().split('T')[0],
      'w_days': rec.workDays,
      'a_days': rec.absentDays,
      'late': rec.lateCount,
      'l_days': rec.leaveDays,
      'wage': rec.dailyWageTotal,
      'base': rec.baseSalary,
      't_cnt': rec.tripCount,
      't_fee': rec.tripTotalFee,
      'ot_hrs': rec.overtimeHours,
      'ot_pay': rec.overtimePay,
      'bonus': rec.bonus,
      'gross': rec.grossPay,
      'adv': rec.advanceDeductions,
      'ss': rec.socialSecurity,
      'other': rec.otherDeductions,
      'tot_ded': rec.totalDeductions,
      'net': rec.netPay,
      'status': rec.status,
      'note': rec.note,
    });
    return result.lastInsertID.toInt();
  }

  Future<void> update(PayrollRecord rec) async {
    await _db.execute('''
      UPDATE payroll_record SET
        work_days = :w_days,
        absent_days = :a_days,
        late_count = :late,
        leave_days = :l_days,
        daily_wage_total = :wage,
        base_salary = :base,
        trip_count = :t_cnt,
        trip_total_fee = :t_fee,
        overtime_hours = :ot_hrs,
        overtime_pay = :ot_pay,
        bonus = :bonus,
        gross_pay = :gross,
        advance_deductions = :adv,
        social_security = :ss,
        other_deductions = :other,
        total_deductions = :tot_ded,
        net_pay = :net,
        note = :note
      WHERE id = :id AND status = 'DRAFT'
    ''', {
      'id': rec.id,
      'w_days': rec.workDays,
      'a_days': rec.absentDays,
      'late': rec.lateCount,
      'l_days': rec.leaveDays,
      'wage': rec.dailyWageTotal,
      'base': rec.baseSalary,
      't_cnt': rec.tripCount,
      't_fee': rec.tripTotalFee,
      'ot_hrs': rec.overtimeHours,
      'ot_pay': rec.overtimePay,
      'bonus': rec.bonus,
      'gross': rec.grossPay,
      'adv': rec.advanceDeductions,
      'ss': rec.socialSecurity,
      'other': rec.otherDeductions,
      'tot_ded': rec.totalDeductions,
      'net': rec.netPay,
      'note': rec.note,
    });
  }

  /// The only command allowed to turn a draft payroll into CONFIRMED.
  /// It locks the payroll and its outstanding advances, creates the immutable
  /// deduction ledger, adjusts balances, and confirms in one MySQL transaction.
  Future<void> confirmWithAdvanceDeductions(int id, int confirmedBy) async {
    await _db.execute('START TRANSACTION');
    try {
      final payrollRows = await _db.query('''
        SELECT id, employee_id, period_end, advance_deductions, status
        FROM payroll_record WHERE id = :id FOR UPDATE
      ''', {'id': id});
      if (payrollRows.length != 1 || payrollRows.first['status'] != 'DRAFT') {
        throw StateError('ยืนยันได้เฉพาะสลิปเงินเดือนฉบับร่าง');
      }
      final payroll = payrollRows.first;
      final employeeId = int.parse(payroll['employee_id'].toString());
      final periodEnd = payroll['period_end'].toString().substring(0, 10);
      final planned =
          double.tryParse(payroll['advance_deductions'].toString()) ?? 0;
      if (planned < 0) throw StateError('ยอดหักเงินเบิกล่วงหน้าไม่ถูกต้อง');

      // Stable order prevents two payroll confirmations from deadlocking.
      final advances = await _db.query('''
        SELECT id, amount, remaining_amount, installment_amount
        FROM advance_payment
        WHERE employee_id = :employee_id
          AND remaining_amount > 0
          AND status IN ('APPROVED', 'PARTIAL')
          AND request_date <= :period_end
          AND approved_at < DATE_ADD(:period_end, INTERVAL 1 DAY)
        ORDER BY request_date ASC, id ASC
        FOR UPDATE
      ''', {'employee_id': employeeId, 'period_end': periodEnd});

      var left = planned;
      for (final advance in advances) {
        if (left <= 0) break;
        final advanceId = int.parse(advance['id'].toString());
        final remaining = double.parse(advance['remaining_amount'].toString());
        final installment = advance['installment_amount'] == null
            ? remaining
            : double.parse(advance['installment_amount'].toString());
        final deduction = left < remaining && left < installment
            ? left
            : (remaining < installment ? remaining : installment);
        if (deduction <= 0) continue;

        final ledger = await _db.execute('''
          INSERT INTO advance_deduction (advance_id, payroll_id, deducted_amount)
          VALUES (:advance_id, :payroll_id, :amount)
        ''', {'advance_id': advanceId, 'payroll_id': id, 'amount': deduction});
        if (ledger.affectedRows.toInt() != 1) {
          throw StateError('บันทึกรายการหักเงินเบิกล้มเหลว');
        }

        final updated = await _db.execute('''
          UPDATE advance_payment
          SET remaining_amount = remaining_amount - :amount,
              status = CASE WHEN remaining_amount - :amount = 0 THEN 'DEDUCTED' ELSE 'PARTIAL' END
          WHERE id = :id AND remaining_amount >= :amount
            AND status IN ('APPROVED', 'PARTIAL')
        ''', {'id': advanceId, 'amount': deduction});
        if (updated.affectedRows.toInt() != 1) {
          throw StateError('ยอดเงินเบิกล่วงหน้าเปลี่ยนระหว่างยืนยัน');
        }
        left -= deduction;
      }
      // Never silently confirm a payroll whose stored deduction can no longer
      // be satisfied; the user must recalculate the DRAFT after the rollback.
      if (left > 0.004) {
        throw StateError(
            'ยอดเงินเบิกล่วงหน้าคงเหลือไม่พอกับยอดหักในสลิป โปรดคำนวณใหม่');
      }
      final confirmed = await _db.execute('''
        UPDATE payroll_record SET status = 'CONFIRMED', confirmed_by = :by
        WHERE id = :id AND status = 'DRAFT'
      ''', {'id': id, 'by': confirmedBy});
      if (confirmed.affectedRows.toInt() != 1) {
        throw StateError('ไม่สามารถยืนยันสลิปเงินเดือนได้');
      }
      await _db.execute('COMMIT');
    } catch (_) {
      await _db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> markPaid(int id) async {
    final result = await _db.execute('''
      UPDATE payroll_record 
      SET status = 'PAID', paid_at = NOW() 
      WHERE id = :id AND status = 'CONFIRMED'
    ''', {'id': id});
    if (result.affectedRows.toInt() != 1) {
      throw StateError('บันทึกจ่ายได้เฉพาะสลิปที่ยืนยันแล้ว');
    }
  }

  Future<void> delete(int id) async {
    final result = await _db.execute('''
      DELETE FROM payroll_record
      WHERE id = :id AND status = 'DRAFT'
        AND NOT EXISTS (SELECT 1 FROM advance_deduction d WHERE d.payroll_id = payroll_record.id)
    ''', {'id': id});
    if (result.affectedRows.toInt() != 1) {
      throw StateError('ลบได้เฉพาะฉบับร่างที่ยังไม่มีรายการหักเงินเบิก');
    }
  }

  Future<int> deleteByPeriod(DateTime start, DateTime end) async {
    final result = await _db.execute('''
      DELETE FROM payroll_record 
      WHERE period_start = :start 
        AND period_end = :end 
        AND status = 'DRAFT'
    ''', {
      'start': start.toIso8601String().split('T')[0],
      'end': end.toIso8601String().split('T')[0],
    });
    return result.affectedRows.toInt();
  }

  Future<List<PayrollRecord>> getByPeriod(DateTime start, DateTime end) async {
    final results = await _db.query('''
      SELECT p.*, COALESCE(e.display_name, u.displayName) as employeeName
      FROM payroll_record p
      JOIN employee_profile e ON p.employee_id = e.id
      LEFT JOIN user u ON e.user_id = u.id
      WHERE p.period_start = :start AND p.period_end = :end
      ORDER BY u.displayName ASC
    ''', {
      'start': start.toIso8601String().split('T')[0],
      'end': end.toIso8601String().split('T')[0],
    });
    return results.map((row) => PayrollRecord.fromJson(row)).toList();
  }

  Future<bool> hasConfirmedOrPaidInPeriod(DateTime start, DateTime end) async {
    final results = await _db.query('''
      SELECT COUNT(*) as cnt
      FROM payroll_record
      WHERE period_start = :start AND period_end = :end
        AND status IN ('CONFIRMED', 'PAID')
    ''', {
      'start': start.toIso8601String().split('T')[0],
      'end': end.toIso8601String().split('T')[0],
    });
    if (results.isEmpty) return false;
    final cnt = int.tryParse(results.first['cnt']?.toString() ?? '0') ?? 0;
    return cnt > 0;
  }

  Future<List<PayrollRecord>> getUnpaidByPeriod(
      DateTime start, DateTime end) async {
    final results = await _db.query('''
      SELECT p.*, COALESCE(e.display_name, u.displayName) as employeeName
      FROM payroll_record p
      JOIN employee_profile e ON p.employee_id = e.id
      LEFT JOIN user u ON e.user_id = u.id
      WHERE p.period_start = :start AND p.period_end = :end
        AND p.status != 'PAID'
      ORDER BY u.displayName ASC
    ''', {
      'start': start.toIso8601String().split('T')[0],
      'end': end.toIso8601String().split('T')[0],
    });
    return results.map((row) => PayrollRecord.fromJson(row)).toList();
  }

  Future<List<PayrollRecord>> getByEmployee(int employeeId,
      {int limit = 12}) async {
    final results = await _db.query('''
      SELECT p.*, COALESCE(e.display_name, u.displayName) as employeeName
      FROM payroll_record p
      JOIN employee_profile e ON p.employee_id = e.id
      LEFT JOIN user u ON e.user_id = u.id
      WHERE p.employee_id = :emp_id
      ORDER BY p.period_end DESC
      LIMIT :limit
    ''', {
      'emp_id': employeeId,
      'limit': limit,
    });
    return results.map((row) => PayrollRecord.fromJson(row)).toList();
  }

  Future<int> markAllPaidForPeriod(DateTime start, DateTime end) async {
    final result = await _db.execute('''
      UPDATE payroll_record 
      SET status = 'PAID', paid_at = NOW() 
      WHERE period_start = :start 
        AND period_end = :end 
        AND status = 'CONFIRMED'
    ''', {
      'start': start.toIso8601String().split('T')[0],
      'end': end.toIso8601String().split('T')[0],
    });
    return result.affectedRows.toInt();
  }

  Future<List<PayrollRecord>> getHistory({
    required DateTime startDate,
    required DateTime endDate,
    int? employeeId,
  }) async {
    String sql = '''
      SELECT p.*, COALESCE(e.display_name, u.displayName) as employeeName
      FROM payroll_record p
      JOIN employee_profile e ON p.employee_id = e.id
      LEFT JOIN user u ON e.user_id = u.id
      WHERE p.status IN ('CONFIRMED', 'PAID')
        AND p.period_start <= :end
        AND p.period_end >= :start
    ''';
    final params = <String, dynamic>{
      'start': startDate.toIso8601String().split('T')[0],
      'end': endDate.toIso8601String().split('T')[0],
    };
    if (employeeId != null) {
      sql += ' AND p.employee_id = :emp_id';
      params['emp_id'] = employeeId;
    }
    sql += ' ORDER BY p.period_end DESC, p.employee_id ASC';
    final results = await _db.query(sql, params);
    return results.map((row) => PayrollRecord.fromJson(row)).toList();
  }

  Future<List<Map<String, dynamic>>> getPeriodSummaries({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final results = await _db.query('''
      SELECT 
        period_start,
        period_end,
        COUNT(*) as employee_count,
        SUM(gross_pay) as total_gross,
        SUM(total_deductions) as total_deductions,
        SUM(net_pay) as total_net,
        MIN(status) as min_status,
        MAX(paid_at) as last_paid_at
      FROM payroll_record
      WHERE status IN ('CONFIRMED', 'PAID')
        AND period_start <= :end
        AND period_end >= :start
      GROUP BY period_start, period_end
      ORDER BY period_end DESC
    ''', {
      'start': startDate.toIso8601String().split('T')[0],
      'end': endDate.toIso8601String().split('T')[0],
    });
    return results;
  }

  Future<int> getDriverTrips(
      String nickname, DateTime start, DateTime end) async {
    if (nickname.isEmpty) return 0;

    // We adjust the end date to include the full day
    final endNextDay = end.add(const Duration(days: 1));

    final results = await _db.query('''
      SELECT COUNT(*) as trip_count 
      FROM delivery_history 
      WHERE driverName LIKE CONCAT('%', :name, '%') 
        AND status = 'completed'
        AND completedAt >= :start 
        AND completedAt < :end
    ''', {
      'name': nickname,
      'start': start.toIso8601String().split('T')[0],
      'end': endNextDay.toIso8601String().split('T')[0],
    });

    if (results.isEmpty) return 0;
    return int.tryParse(results.first['trip_count']?.toString() ?? '0') ?? 0;
  }
}
