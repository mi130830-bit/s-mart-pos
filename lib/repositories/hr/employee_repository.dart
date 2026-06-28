import '../../services/mysql_service.dart';
import '../../models/hr/employee_profile.dart';

class EmployeeRepository {
  final MySQLService _db = MySQLService();

  Future<void> initTable() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS employee_profile (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NULL,
        firebase_uid VARCHAR(128) NULL,
        employee_code VARCHAR(20) NULL,
        display_name VARCHAR(100) NULL,
        id_card VARCHAR(13) NULL,
        phone VARCHAR(20) NULL,
        position VARCHAR(50) NULL,
        role_type VARCHAR(50) DEFAULT 'OFFICE',
        wage_type VARCHAR(20) DEFAULT 'MONTHLY',
        daily_wage DECIMAL(10,2) DEFAULT 0,
        base_salary DECIMAL(10,2) DEFAULT 0,
        pay_cycle VARCHAR(20) DEFAULT 'MONTHLY',
        pay_day_of_week INT DEFAULT 1,
        trip_rate DECIMAL(10,2) DEFAULT 0,
        annual_sick_leave INT DEFAULT 30,
        annual_personal_leave INT DEFAULT 3,
        annual_vacation_leave INT DEFAULT 6,
        hire_date DATE NULL,
        resign_date DATE NULL,
        pin_code VARCHAR(100) DEFAULT '000000',
        is_active BOOLEAN DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    ''');

    // Auto-migrate schema changes (safe checks)
    final checkNickname = await _db.query("SHOW COLUMNS FROM employee_profile LIKE 'nickname'");
    if (checkNickname.isNotEmpty) {
      await _db.execute("ALTER TABLE employee_profile CHANGE nickname display_name VARCHAR(100) NULL");
    }

    final checkEmpType = await _db.query("SHOW COLUMNS FROM employee_profile LIKE 'employee_type'");
    if (checkEmpType.isNotEmpty) {
      await _db.execute("ALTER TABLE employee_profile CHANGE employee_type role_type VARCHAR(50) DEFAULT 'OFFICE'");
    }

    // Run migration if table exists from before
    try {
      await _db.execute('ALTER TABLE employee_profile MODIFY user_id INT NULL;');
    } catch (_) {}

    await _db.ensureColumn('employee_profile', 'firebase_uid', 'VARCHAR(128) NULL');
    await _db.ensureColumn('employee_profile', 'display_name_en', 'VARCHAR(100) NULL');
    await _db.ensureColumn('employee_profile', 'sort_order', 'INT DEFAULT 0');

    try {
      await _db.execute('UPDATE employee_profile SET pin_code = "000000" WHERE pin_code IS NULL;');
    } catch (_) {}

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS employee_fingerprint (
        id INT AUTO_INCREMENT PRIMARY KEY,
        employee_id INT NOT NULL,
        fingerprint_slot_id INT NOT NULL UNIQUE,
        finger_name VARCHAR(50) DEFAULT 'Right Index',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (employee_id) REFERENCES employee_profile(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<List<EmployeeProfile>> getAll({bool activeOnly = true}) async {
    String sql = '''
      SELECT e.*, u.displayName 
      FROM employee_profile e
      LEFT JOIN user u ON e.user_id = u.id
    ''';
    if (activeOnly) {
      sql += ' WHERE e.is_active = 1';
    }
    sql += ' ORDER BY e.sort_order ASC, e.display_name ASC';
    
    final results = await _db.query(sql);
    return results.map((row) => EmployeeProfile.fromJson(row)).toList();
  }

  Future<EmployeeProfile?> getById(int id) async {
    final results = await _db.query('''
      SELECT e.*, u.displayName 
      FROM employee_profile e
      LEFT JOIN user u ON e.user_id = u.id
      WHERE e.id = :id
    ''', {'id': id});

    if (results.isEmpty) return null;
    return EmployeeProfile.fromJson(results.first);
  }

  Future<EmployeeProfile?> getByUserId(int userId) async {
    final results = await _db.query('''
      SELECT e.*, u.displayName 
      FROM employee_profile e
      LEFT JOIN user u ON e.user_id = u.id
      WHERE e.user_id = :uid
    ''', {'uid': userId});

    if (results.isEmpty) return null;
    return EmployeeProfile.fromJson(results.first);
  }

  Future<EmployeeProfile?> getByFirebaseUid(String firebaseUid) async {
    final results = await _db.query('''
      SELECT e.*, u.displayName 
      FROM employee_profile e
      LEFT JOIN user u ON e.user_id = u.id
      WHERE e.firebase_uid = :fuid
    ''', {'fuid': firebaseUid});

    if (results.isEmpty) return null;
    return EmployeeProfile.fromJson(results.first);
  }

  Future<EmployeeProfile?> getByName(String name) async {
    final results = await _db.query('''
      SELECT e.*, u.displayName 
      FROM employee_profile e
      LEFT JOIN user u ON e.user_id = u.id
      WHERE e.display_name = :name
    ''', {'name': name});

    if (results.isEmpty) return null;
    return EmployeeProfile.fromJson(results.first);
  }

  Future<EmployeeProfile?> getByPin(String pinHash) async {
    // This isn't practical because we hash the PIN with BCrypt, 
    // so we can't look it up by hash easily.
    // Instead, the service will fetch all active employees with a pin and verify the hash.
    // This is just a placeholder or could be used if not using salted hashes.
    return null;
  }

  Future<int> create(EmployeeProfile emp) async {
    final result = await _db.execute('''
      INSERT INTO employee_profile (
        user_id, firebase_uid, employee_code, display_name, display_name_en, id_card, phone, position,
        role_type, wage_type, daily_wage, base_salary, pay_cycle,
        pay_day_of_week, trip_rate, annual_sick_leave, annual_personal_leave,
        annual_vacation_leave, hire_date, pin_code, is_active
      ) VALUES (
        :user_id, :firebase_uid, :code, :display_name, :display_name_en, :id_card, :phone, :pos,
        :role_type, :wage_type, :daily, :base, :pay_cycle,
        :pay_day, :trip, :sick, :personal,
        :vacation, :hire, :pin, :active
      )
    ''', {
      'user_id': emp.userId,
      'firebase_uid': emp.firebaseUid,
      'code': emp.employeeCode,
      'display_name': emp.displayName,
      'display_name_en': emp.displayNameEn,
      'id_card': emp.idCard,
      'phone': emp.phone,
      'pos': emp.position,
      'role_type': emp.roleType,
      'wage_type': emp.wageType,
      'daily': emp.dailyWage,
      'base': emp.baseSalary,
      'pay_cycle': emp.payCycle,
      'pay_day': emp.payDayOfWeek,
      'trip': emp.tripRate,
      'sick': emp.annualSickLeave,
      'personal': emp.annualPersonalLeave,
      'vacation': emp.annualVacationLeave,
      'hire': emp.hireDate?.toIso8601String().split('T')[0],
      'pin': emp.pinCode,
      'active': emp.isActive ? 1 : 0,
      'sort_order': emp.sortOrder,
    });
    return result.lastInsertID.toInt();
  }

  Future<void> update(EmployeeProfile emp) async {
    await _db.execute('''
      UPDATE employee_profile SET
        firebase_uid = :firebase_uid,
        employee_code = :code,
        display_name = :display_name,
        display_name_en = :display_name_en,
        id_card = :id_card,
        phone = :phone,
        position = :pos,
        role_type = :role_type,
        wage_type = :wage_type,
        daily_wage = :daily,
        base_salary = :base,
        pay_cycle = :pay_cycle,
        pay_day_of_week = :pay_day,
        trip_rate = :trip,
        annual_sick_leave = :sick,
        annual_personal_leave = :personal,
        annual_vacation_leave = :vacation,
        pin_code = :pin
      WHERE id = :id
    ''', {
      'id': emp.id,
      'firebase_uid': emp.firebaseUid,
      'code': emp.employeeCode,
      'display_name': emp.displayName,
      'display_name_en': emp.displayNameEn,
      'id_card': emp.idCard,
      'phone': emp.phone,
      'pos': emp.position,
      'role_type': emp.roleType,
      'wage_type': emp.wageType,
      'daily': emp.dailyWage,
      'base': emp.baseSalary,
      'pay_cycle': emp.payCycle,
      'pay_day': emp.payDayOfWeek,
      'trip': emp.tripRate,
      'sick': emp.annualSickLeave,
      'personal': emp.annualPersonalLeave,
      'vacation': emp.annualVacationLeave,
      'pin': emp.pinCode, // Service should only pass new hash if it changed
    });
  }

  Future<void> deactivate(int id) async {
    await _db.execute(
      'UPDATE employee_profile SET is_active = 0, resign_date = CURDATE() WHERE id = :id',
      {'id': id}
    );
  }

  Future<List<EmployeeProfile>> getDrivers() async {
    final results = await _db.query('''
      SELECT e.*, u.displayName 
      FROM employee_profile e
      LEFT JOIN user u ON e.user_id = u.id
      WHERE e.is_active = 1 AND e.role_type = 'DRIVER'
      ORDER BY e.sort_order ASC, e.display_name ASC
    ''');
    return results.map((row) => EmployeeProfile.fromJson(row)).toList();
  }

  Future<void> updateSortOrder(List<int> orderedIds) async {
    for (int i = 0; i < orderedIds.length; i++) {
      await _db.execute(
        'UPDATE employee_profile SET sort_order = :sort WHERE id = :id',
        {'sort': i, 'id': orderedIds[i]}
      );
    }
  }

  Future<int?> getEmployeeIdByFingerprint(int fingerprintSlotId) async {
    final results = await _db.query(
      'SELECT employee_id FROM employee_fingerprint WHERE fingerprint_slot_id = :slot_id LIMIT 1',
      {'slot_id': fingerprintSlotId}
    );
    if (results.isEmpty) return null;
    return int.tryParse(results.first['employee_id']?.toString() ?? '');
  }

  /// ดึง slot_id ตัวแรกที่ผูกกับพนักงาน (ใช้สำหรับ UI แสดงสถานะ)
  Future<int?> getFingerprintBaseSlotByEmployee(int employeeId) async {
    final results = await _db.query(
      'SELECT MIN(fingerprint_slot_id) as base_slot FROM employee_fingerprint WHERE employee_id = :employee_id',
      {'employee_id': employeeId}
    );
    if (results.isEmpty) return null;
    return int.tryParse(results.first['base_slot']?.toString() ?? '');
  }

  /// ดึง slot_id ทั้งหมดที่ผูกกับพนักงาน (เพื่อตรวจสอบว่าลงทะเบียนแล้ว)
  Future<int?> getFingerprintSlotIdByEmployee(int employeeId) async {
    return getFingerprintBaseSlotByEmployee(employeeId);
  }

  /// ผูก fingerprint slot กับพนักงาน (รองรับหลาย slots ต่อคน)
  /// ระบบใหม่ใช้ 4 slots ต่อคน: RIGHT_1, RIGHT_2, LEFT_1, LEFT_2
  Future<void> assignFingerprintToEmployee(
      int employeeId, int fingerprintSlotId, String fingerName) async {
    await _db.execute(
      'INSERT INTO employee_fingerprint (employee_id, fingerprint_slot_id, finger_name) '
      'VALUES (:employee_id, :slot_id, :finger_name) '
      'ON DUPLICATE KEY UPDATE employee_id = :employee_id, finger_name = :finger_name',
      {
        'employee_id': employeeId,
        'slot_id': fingerprintSlotId,
        'finger_name': fingerName
      }
    );
  }

  /// ลบข้อมูลลายนิ้วมือทั้งหมด (ทุก slots) ของพนักงานคนนั้น
  Future<void> removeFingerprint(int employeeId) async {
    await _db.execute(
      'DELETE FROM employee_fingerprint WHERE employee_id = :employee_id',
      {'employee_id': employeeId}
    );
  }
}
