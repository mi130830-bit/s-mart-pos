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
      await _db.execute('ALTER TABLE payroll_record MODIFY work_days DECIMAL(5,2) DEFAULT 0.00');
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

  Future<void> confirm(int id, int confirmedBy) async {
    await _db.execute('''
      UPDATE payroll_record 
      SET status = 'CONFIRMED', confirmed_by = :by 
      WHERE id = :id
    ''', {'id': id, 'by': confirmedBy});
  }

  Future<void> markPaid(int id) async {
    await _db.execute('''
      UPDATE payroll_record 
      SET status = 'PAID', paid_at = NOW() 
      WHERE id = :id
    ''', {'id': id});
  }

  Future<void> delete(int id) async {
    await _db.execute('DELETE FROM payroll_record WHERE id = :id', {'id': id});
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

  Future<List<PayrollRecord>> getUnpaidByPeriod(DateTime start, DateTime end) async {
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

  Future<List<PayrollRecord>> getByEmployee(int employeeId, {int limit = 12}) async {
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
        AND status IN ('DRAFT', 'CONFIRMED')
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

  Future<int> getDriverTrips(String nickname, DateTime start, DateTime end) async {
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
