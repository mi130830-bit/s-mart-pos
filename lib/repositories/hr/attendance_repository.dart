import '../../services/mysql_service.dart';
import '../../models/hr/attendance_log.dart';
import '../../services/hr/attendance_calculation_service.dart';
import 'special_holiday_repository.dart';

class AttendanceRepository {
  final MySQLService _db = MySQLService();

  Future<void> initTable() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_log (
        id INT PRIMARY KEY AUTO_INCREMENT,
        employee_id INT NOT NULL,
        date DATE NOT NULL,
        clock_in DATETIME NULL,
        clock_out DATETIME NULL,
        temp_out DATETIME NULL,
        back_to_work DATETIME NULL,
        method VARCHAR(50) DEFAULT 'PIN',
        device_info VARCHAR(255) NULL,
        latitude DOUBLE NULL,
        longitude DOUBLE NULL,
        status VARCHAR(50) DEFAULT 'ON_TIME',
        override_reason TEXT NULL,
        override_by INT NULL,
        note TEXT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (employee_id) REFERENCES employee_profile(id),
        UNIQUE KEY idx_emp_date (employee_id, date)
      )
    ''');
    await _db.ensureColumn('attendance_log', 'temp_out', 'DATETIME NULL');
    await _db.ensureColumn('attendance_log', 'back_to_work', 'DATETIME NULL');
    // สร้างตาราง special_holiday ด้วยถ้ายังไม่มี
    await SpecialHolidayRepository().initTable();
  }

  Future<int> clockIn(int employeeId, String method, {
    String? deviceInfo,
    String? overrideReason,
    int? overrideBy,
    DateTime? overrideTime,
    String status = 'ON_TIME', // คำนวณแล้วส่งมาจาก AttendanceService
  }) async {
    final now = overrideTime ?? DateTime.now();
    final timeStr = overrideTime != null ? ':override_time' : 'NOW()';
    final sql = '''
      INSERT INTO attendance_log (employee_id, date, clock_in, method, device_info, status, override_reason, override_by)
      VALUES (:employee_id, CURDATE(), $timeStr, :method, :device_info, :status, :override_reason, :override_by)
      ON DUPLICATE KEY UPDATE
        clock_in = IF(clock_in IS NULL, VALUES(clock_in), clock_in),
        method = IFNULL(VALUES(method), method),
        device_info = IFNULL(VALUES(device_info), device_info),
        status = IFNULL(VALUES(status), status),
        override_reason = IFNULL(VALUES(override_reason), override_reason),
        override_by = IFNULL(VALUES(override_by), override_by)
    ''';
    final params = {
      'employee_id': employeeId,
      'method': method,
      'device_info': deviceInfo,
      'status': status,
      'override_reason': overrideReason,
      'override_by': overrideBy,
    };
    if (overrideTime != null) {
      params['override_time'] = now.toIso8601String().replaceAll('T', ' ').split('.')[0];
    }
    final result = await _db.execute(sql, params);
    return result.lastInsertID.toInt();
  }

  Future<void> clockOut(int employeeId, {String? method, String? overrideReason, int? overrideBy, DateTime? overrideTime}) async {
    final now = overrideTime ?? DateTime.now();
    await _db.execute('''
      UPDATE attendance_log 
      SET clock_out = :time, method = IFNULL(:method, method), override_reason = IFNULL(:reason, override_reason), override_by = IFNULL(:by, override_by)
      WHERE employee_id = :emp_id 
        AND date = CURDATE() 
        AND clock_out IS NULL
    ''', {
      'emp_id': employeeId,
      'time': now.toIso8601String().replaceAll('T', ' ').substring(0, 19),
      'method': method,
      'reason': overrideReason,
      'by': overrideBy,
    });
  }

  Future<void> startTempLeave(int employeeId, {String? method, String? overrideReason, int? overrideBy, DateTime? overrideTime}) async {
    final now = overrideTime ?? DateTime.now();
    await _db.execute('''
      UPDATE attendance_log 
      SET temp_out = :time, method = IFNULL(:method, method), override_reason = IFNULL(:reason, override_reason), override_by = IFNULL(:by, override_by)
      WHERE employee_id = :emp_id 
        AND date = CURDATE() 
        AND temp_out IS NULL
    ''', {
      'emp_id': employeeId,
      'time': now.toIso8601String().replaceAll('T', ' ').substring(0, 19),
      'method': method,
      'reason': overrideReason,
      'by': overrideBy,
    });
  }

  Future<void> endTempLeave(int employeeId, {String? method, String? overrideReason, int? overrideBy, DateTime? overrideTime}) async {
    final now = overrideTime ?? DateTime.now();
    await _db.execute('''
      UPDATE attendance_log 
      SET back_to_work = :time, method = IFNULL(:method, method), override_reason = IFNULL(:reason, override_reason), override_by = IFNULL(:by, override_by)
      WHERE employee_id = :emp_id 
        AND date = CURDATE() 
        AND back_to_work IS NULL
    ''', {
      'emp_id': employeeId,
      'time': now.toIso8601String().replaceAll('T', ' ').substring(0, 19),
      'method': method,
      'reason': overrideReason,
      'by': overrideBy,
    });
  }

  Future<List<AttendanceLog>> getTodayAttendance() async {
    final results = await _db.query('''
      SELECT a.*, COALESCE(e.display_name, u.displayName) as employeeName
      FROM attendance_log a
      JOIN employee_profile e ON a.employee_id = e.id
      LEFT JOIN user u ON e.user_id = u.id
      WHERE a.date = CURDATE()
      ORDER BY a.clock_in DESC
    ''');
    return results.map((row) => AttendanceLog.fromJson(row)).toList();
  }

  Future<List<AttendanceLog>> getByDateRange(DateTime start, DateTime end, {int? employeeId}) async {
    String sql = '''
      SELECT a.*, COALESCE(e.display_name, u.displayName) as employeeName
      FROM attendance_log a
      JOIN employee_profile e ON a.employee_id = e.id
      LEFT JOIN user u ON e.user_id = u.id
      WHERE a.date >= :start AND a.date <= :end
    ''';
    
    Map<String, dynamic> params = {
      'start': start.toIso8601String().split('T')[0],
      'end': end.toIso8601String().split('T')[0],
    };

    if (employeeId != null) {
      sql += ' AND a.employee_id = :emp_id';
      params['emp_id'] = employeeId;
    }

    sql += ' ORDER BY a.date DESC';

    final results = await _db.query(sql, params);
    return results.map((row) => AttendanceLog.fromJson(row)).toList();
  }

  Future<double> countWorkDays(int employeeId, DateTime start, DateTime end) async {
    // ดึง roleType ของพนักงาน เพื่อใช้คำนวณเวลากะเข้างานที่ถูกต้อง
    final empResult = await _db.query(
      'SELECT role_type FROM employee_profile WHERE id = :id LIMIT 1',
      {'id': employeeId},
    );
    final roleType = empResult.isNotEmpty
        ? (empResult.first['role_type']?.toString() ?? 'REQUESTER')
        : 'REQUESTER';

    final results = await _db.query('''
      SELECT *
      FROM attendance_log 
      WHERE employee_id = :emp_id 
        AND date >= :start 
        AND date <= :end
        AND clock_in IS NOT NULL
    ''', {
      'emp_id': employeeId,
      'start': start.toIso8601String().split('T')[0],
      'end': end.toIso8601String().split('T')[0],
    });
    
    if (results.isEmpty) return 0.0;

    // ดึงรายการวันหยุดพิเศษในช่วงเวลานั้น เพื่อข้ามออกจากการนับวันทำงาน
    final holidays = await SpecialHolidayRepository().getHolidaysInRange(start, end);
    final holidayDates = holidays.map((h) => h.date.toIso8601String().split('T')[0]).toSet();
    
    double totalDays = 0.0;
    for (var row in results) {
      final log = AttendanceLog.fromJson(row);
      final logDateStr = log.date.toIso8601String().split('T')[0];
      if (holidayDates.contains(logDateStr)) continue;
      bool isFinalDay = log.date.year == end.year &&
          log.date.month == end.month &&
          log.date.day == end.day;
      totalDays += AttendanceCalculationService.calculateFractionalDays(
        log,
        isFinalDay: isFinalDay,
        roleType: roleType,
      );
    }
    
    return totalDays;
  }

  /// Emergency Close: Clock Out พนักงานทุกคนที่ยังเข้างานอยู่ในวันนี้
  /// ใช้เมื่อปิดร้านฉุกเฉิน หรือไฟดับ
  Future<int> emergencyClockOutAll({String reason = 'EMERGENCY_CLOSE', int? overrideBy}) async {
    final now = DateTime.now();
    final timeStr = now.toIso8601String().replaceAll('T', ' ').substring(0, 19);
    final result = await _db.execute('''
      UPDATE attendance_log
      SET clock_out = :time,
          method = 'EMERGENCY',
          override_reason = :reason,
          override_by = :by
      WHERE date = CURDATE()
        AND clock_in IS NOT NULL
        AND clock_out IS NULL
    ''', {
      'time': timeStr,
      'reason': reason,
      'by': overrideBy,
    });
    return result.affectedRows.toInt();
  }

  Future<bool> hasClockInToday(int employeeId) async {
    final results = await _db.query('''
      SELECT 1 FROM attendance_log 
      WHERE employee_id = :emp_id AND date = CURDATE() AND clock_in IS NOT NULL
      LIMIT 1
    ''', {'emp_id': employeeId});
    return results.isNotEmpty;
  }

  Future<void> syncAttendance(AttendanceLog log) async {
    // Upsert logic for attendance from S-Link
    final sql = '''
      INSERT INTO attendance_log (
        employee_id, date, clock_in, clock_out, temp_out, back_to_work, method, latitude, longitude, status
      ) VALUES (
        :employee_id, :date, :clock_in, :clock_out, :temp_out, :back_to_work, :method, :latitude, :longitude, :status
      )
      ON DUPLICATE KEY UPDATE 
        clock_in = IF(VALUES(clock_in) IS NOT NULL, VALUES(clock_in), clock_in),
        clock_out = IF(VALUES(clock_out) IS NOT NULL, VALUES(clock_out), clock_out),
        temp_out = IF(VALUES(temp_out) IS NOT NULL, VALUES(temp_out), temp_out),
        back_to_work = IF(VALUES(back_to_work) IS NOT NULL, VALUES(back_to_work), back_to_work),
        latitude = IF(VALUES(latitude) IS NOT NULL, VALUES(latitude), latitude),
        longitude = IF(VALUES(longitude) IS NOT NULL, VALUES(longitude), longitude)
    ''';
    
    await _db.execute(sql, {
      'employee_id': log.employeeId,
      'date': log.date.toIso8601String().split('T')[0],
      'clock_in': log.clockIn?.toIso8601String().replaceAll('T', ' ').split('.')[0],
      'clock_out': log.clockOut?.toIso8601String().replaceAll('T', ' ').split('.')[0],
      'temp_out': log.tempOut?.toIso8601String().replaceAll('T', ' ').split('.')[0],
      'back_to_work': log.backToWork?.toIso8601String().replaceAll('T', ' ').split('.')[0],
      'method': log.method,
      'latitude': log.latitude,
      'longitude': log.longitude,
      'status': log.status,
    });
  }

  Future<List<Map<String, dynamic>>> getDashboardSummary(String filter) async {
    String dateCondition = '';
    String leaveCondition = '';
    
    if (filter == 'DAY') {
      dateCondition = 'date = CURDATE()';
      leaveCondition = 'DATE(start_date) <= CURDATE() AND DATE(end_date) >= CURDATE()';
    } else if (filter == 'WEEK') {
      dateCondition = 'YEARWEEK(date, 1) = YEARWEEK(CURDATE(), 1)';
      leaveCondition = 'YEARWEEK(start_date, 1) = YEARWEEK(CURDATE(), 1)';
    } else { // MONTH
      dateCondition = 'MONTH(date) = MONTH(CURDATE()) AND YEAR(date) = YEAR(CURDATE())';
      leaveCondition = 'MONTH(start_date) = MONTH(CURDATE()) AND YEAR(start_date) = YEAR(CURDATE())';
    }

    final sql = '''
      SELECT 
        e.id as employee_id,
        e.role_type,
        COALESCE(e.display_name, u.displayName) as employeeName,
        (SELECT clock_in FROM attendance_log WHERE employee_id = e.id AND date = CURDATE() ORDER BY clock_in DESC LIMIT 1) as today_in,
        (SELECT clock_out FROM attendance_log WHERE employee_id = e.id AND date = CURDATE() ORDER BY clock_in DESC LIMIT 1) as today_out,
        (SELECT temp_out FROM attendance_log WHERE employee_id = e.id AND date = CURDATE() ORDER BY clock_in DESC LIMIT 1) as today_temp_out,
        (SELECT back_to_work FROM attendance_log WHERE employee_id = e.id AND date = CURDATE() ORDER BY clock_in DESC LIMIT 1) as today_back_to_work,
        0.0 as total_present,
        (SELECT COALESCE(SUM(total_days), 0) FROM leave_request WHERE employee_id = e.id AND $leaveCondition AND status = 'APPROVED') as total_leave
      FROM employee_profile e
      LEFT JOIN user u ON e.user_id = u.id
      WHERE e.is_active = 1
      ORDER BY e.display_name ASC
    ''';
    
    final employees = await _db.query(sql);
    
    // สร้าง map: employee_id → role_type เพื่อใช้ในการคำนวณ calculateFractionalDays
    final Map<int, String> roleTypeMap = {};
    for (var emp in employees) {
      final id = int.tryParse(emp['employee_id']?.toString() ?? '0') ?? 0;
      roleTypeMap[id] = emp['role_type']?.toString() ?? 'REQUESTER';
    }

    final logsSql = 'SELECT * FROM attendance_log WHERE $dateCondition AND clock_in IS NOT NULL';
    final logsResult = await _db.query(logsSql);
    
    final Map<int, double> presentDaysMap = {};
    for (var row in logsResult) {
      final log = AttendanceLog.fromJson(row);
      final roleType = roleTypeMap[log.employeeId] ?? 'REQUESTER';
      final days = AttendanceCalculationService.calculateFractionalDays(log, roleType: roleType);
      presentDaysMap[log.employeeId] = (presentDaysMap[log.employeeId] ?? 0.0) + days;
    }
    
    // คำนวณ temp_leave_minutes รวมสำหรับแต่ละพนักงาน
    final Map<int, int> tempLeaveMinutesMap = {};
    for (var row in logsResult) {
      final log = AttendanceLog.fromJson(row);
      if (log.tempOut != null && log.backToWork != null) {
        final mins = log.backToWork!.difference(log.tempOut!).inMinutes;
        tempLeaveMinutesMap[log.employeeId] = (tempLeaveMinutesMap[log.employeeId] ?? 0) + mins;
      }
    }

    return employees.map((emp) {
      final empMap = Map<String, dynamic>.from(emp);
      final int eId = int.tryParse(empMap['employee_id']?.toString() ?? '0') ?? 0;
      empMap['total_present'] = presentDaysMap[eId] ?? 0.0;
      empMap['temp_leave_minutes'] = tempLeaveMinutesMap[eId] ?? 0;
      return empMap;
    }).toList();
  }

  Future<int> clearAll() async {
    final result = await _db.execute('DELETE FROM attendance_log');
    return result.affectedRows.toInt();
  }

  Future<int> deleteTodayLog(int employeeId) async {
    final result = await _db.execute('''
      DELETE FROM attendance_log 
      WHERE employee_id = :emp_id AND date = CURDATE()
    ''', {'emp_id': employeeId});
    return result.affectedRows.toInt();
  }

  Future<AttendanceLog?> getTodayLogByEmployee(int employeeId) async {
    final results = await _db.query('''
      SELECT * FROM attendance_log 
      WHERE employee_id = :emp_id AND date = CURDATE()
      LIMIT 1
    ''', {'emp_id': employeeId});
    if (results.isEmpty) return null;
    return AttendanceLog.fromJson(results.first);
  }
}
