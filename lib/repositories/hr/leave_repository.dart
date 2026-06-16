import '../../services/mysql_service.dart';
//import 'package:flutter/foundation.dart';
import '../../models/hr/leave_request.dart';

class LeaveRepository {
  final MySQLService _db = MySQLService();

  Future<void> initTable() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS leave_request (
        id INT PRIMARY KEY AUTO_INCREMENT,
        employee_id INT NOT NULL,
        leave_type VARCHAR(50) NOT NULL,
        leave_format VARCHAR(50) DEFAULT 'FULL_DAY',
        start_date DATETIME NOT NULL,
        end_date DATETIME NOT NULL,
        total_days DECIMAL(5,2) NOT NULL,
        reason TEXT NULL,
        status VARCHAR(50) DEFAULT 'PENDING',
        approved_by INT NULL,
        approved_at DATETIME NULL,
        reject_reason TEXT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (employee_id) REFERENCES employee_profile(id)
      )
    ''');
    
    // Auto-migrate: Add leave_format column if it doesn't exist
    await _db.ensureColumn('leave_request', 'leave_format', "VARCHAR(50) DEFAULT 'FULL_DAY' AFTER leave_type");
  }

  Future<int> create(LeaveRequest req) async {
    final result = await _db.execute('''
      INSERT INTO leave_request (
        employee_id, leave_type, leave_format, start_date, end_date, total_days, reason, status
      ) VALUES (
        :emp_id, :type, :format, :start, :end, :days, :reason, :status
      )
    ''', {
      'emp_id': req.employeeId,
      'type': req.leaveType,
      'format': req.leaveFormat,
      'start': req.startDate.toIso8601String().replaceAll('T', ' ').substring(0, 19),
      'end': req.endDate.toIso8601String().replaceAll('T', ' ').substring(0, 19),
      'days': req.totalDays,
      'reason': req.reason,
      'status': req.status,
    });
    return result.lastInsertID.toInt();
  }

  Future<void> approve(int id, int approvedBy) async {
    await _db.execute('''
      UPDATE leave_request 
      SET status = 'APPROVED', approved_by = :by, approved_at = NOW() 
      WHERE id = :id
    ''', {'id': id, 'by': approvedBy});
  }

  Future<void> reject(int id, String reason) async {
    await _db.execute('''
      UPDATE leave_request 
      SET status = 'REJECTED', reject_reason = :reason 
      WHERE id = :id
    ''', {'id': id, 'reason': reason});
  }

  Future<void> cancel(int id) async {
    await _db.execute(
      "UPDATE leave_request SET status = 'CANCELLED' WHERE id = :id",
      {'id': id}
    );
  }

  Future<List<LeaveRequest>> getPending() async {
    final results = await _db.query('''
      SELECT l.*, COALESCE(e.display_name, u.displayName) as employeeName
      FROM leave_request l
      JOIN employee_profile e ON l.employee_id = e.id
      LEFT JOIN user u ON e.user_id = u.id
      WHERE l.status = 'PENDING'
      ORDER BY l.created_at DESC
    ''');
    return results.map((row) => LeaveRequest.fromJson(row)).toList();
  }

  Future<List<LeaveRequest>> getByEmployee(int employeeId, {int? year}) async {
    String sql = '''
      SELECT l.*, COALESCE(e.display_name, u.displayName) as employeeName
      FROM leave_request l
      JOIN employee_profile e ON l.employee_id = e.id
      LEFT JOIN user u ON e.user_id = u.id
      WHERE l.employee_id = :emp_id
    ''';
    
    Map<String, dynamic> params = {'emp_id': employeeId};

    if (year != null) {
      sql += ' AND YEAR(l.start_date) = :yr';
      params['yr'] = year;
    }

    sql += ' ORDER BY l.start_date DESC';

    final results = await _db.query(sql, params);
    return results.map((row) => LeaveRequest.fromJson(row)).toList();
  }

  Future<List<LeaveRequest>> getApprovedInRange(int employeeId, DateTime start, DateTime end) async {
    final results = await _db.query('''
      SELECT * FROM leave_request 
      WHERE employee_id = :emp_id 
        AND status = 'APPROVED'
        AND start_date <= :end 
        AND end_date >= :start
    ''', {
      'emp_id': employeeId,
      'start': start.toIso8601String().replaceAll('T', ' ').substring(0, 19),
      'end': end.toIso8601String().replaceAll('T', ' ').substring(0, 19),
    });
    return results.map((row) => LeaveRequest.fromJson(row)).toList();
  }

  Future<double> getUsedLeaveDays(int employeeId, String leaveType, int year) async {
    final results = await _db.query('''
      SELECT SUM(total_days) as used
      FROM leave_request 
      WHERE employee_id = :emp_id 
        AND leave_type = :type
        AND YEAR(start_date) = :yr
        AND status = 'APPROVED'
    ''', {
      'emp_id': employeeId,
      'type': leaveType,
      'yr': year,
    });
    
    if (results.isEmpty || results.first['used'] == null) return 0.0;
    return double.tryParse(results.first['used'].toString()) ?? 0.0;
  }

  // --- Temporary Leave (Real-time HOURLY leave) ---
  Future<void> startTempLeave(int employeeId) async {
    // Create an hourly leave that starts and ends at the same time (placeholder)
    // with total_days = 0. It will be updated when they return.
    await _db.execute('''
      INSERT INTO leave_request (
        employee_id, leave_type, leave_format, start_date, end_date, total_days, reason, status
      ) VALUES (
        :emp_id, 'PERSONAL', 'HOURLY', NOW(), NOW(), 0, 'ออกชั่วคราวระหว่างวัน', 'APPROVED'
      )
    ''', {
      'emp_id': employeeId,
    });
  }

  Future<void> endTempLeave(int employeeId) async {
    // Update the most recent open hourly leave for today
    await _db.execute('''
      UPDATE leave_request
      SET end_date = NOW(),
          total_days = ROUND(TIMESTAMPDIFF(MINUTE, start_date, NOW()) / 60.0 / 8.0, 2)
      WHERE employee_id = :emp_id
        AND leave_format = 'HOURLY'
        AND total_days = 0
        AND DATE(start_date) = CURDATE()
      ORDER BY id DESC
      LIMIT 1
    ''', {
      'emp_id': employeeId,
    });
  }

  Future<bool> isCurrentlyOnTempLeave(int employeeId) async {
    final results = await _db.query('''
      SELECT 1 FROM leave_request
      WHERE employee_id = :emp_id
        AND leave_format = 'HOURLY'
        AND total_days = 0
        AND DATE(start_date) = CURDATE()
      LIMIT 1
    ''', {
      'emp_id': employeeId,
    });
    return results.isNotEmpty;
  }

  Future<List<LeaveRequest>> getTodayOpenTempLeaves() async {
    final results = await _db.query('''
      SELECT l.*, COALESCE(e.display_name, u.displayName) as employeeName
      FROM leave_request l
      JOIN employee_profile e ON l.employee_id = e.id
      LEFT JOIN user u ON e.user_id = u.id
      WHERE l.leave_format = 'HOURLY'
        AND l.total_days = 0
        AND DATE(l.start_date) = CURDATE()
    ''');
    return results.map((row) => LeaveRequest.fromJson(row)).toList();
  }
}
