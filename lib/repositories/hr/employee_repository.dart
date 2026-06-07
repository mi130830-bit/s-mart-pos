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

    // Auto-migrate schema changes
    try {
      await _db.execute("ALTER TABLE employee_profile CHANGE nickname display_name VARCHAR(100) NULL");
    } catch (_) {}
    try {
      await _db.execute("ALTER TABLE employee_profile CHANGE employee_type role_type VARCHAR(50) DEFAULT 'OFFICE'");
    } catch (_) {}

    // Run migration if table exists from before
    try {
      await _db.execute('ALTER TABLE employee_profile MODIFY user_id INT NULL;');
    } catch (_) {}
    try {
      await _db.execute('ALTER TABLE employee_profile ADD COLUMN firebase_uid VARCHAR(128) NULL;');
    } catch (_) {}
    try {
      await _db.execute('ALTER TABLE employee_profile ADD COLUMN sort_order INT DEFAULT 0;');
    } catch (_) {}
    try {
      await _db.execute('UPDATE employee_profile SET pin_code = "000000" WHERE pin_code IS NULL;');
    } catch (_) {}
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
        user_id, firebase_uid, employee_code, display_name, id_card, phone, position,
        role_type, wage_type, daily_wage, base_salary, pay_cycle,
        pay_day_of_week, trip_rate, annual_sick_leave, annual_personal_leave,
        annual_vacation_leave, hire_date, pin_code, is_active
      ) VALUES (
        :user_id, :firebase_uid, :code, :display_name, :id_card, :phone, :pos,
        :role_type, :wage_type, :daily, :base, :pay_cycle,
        :pay_day, :trip, :sick, :personal,
        :vacation, :hire, :pin, :active
      )
    ''', {
      'user_id': emp.userId,
      'firebase_uid': emp.firebaseUid,
      'code': emp.employeeCode,
      'display_name': emp.displayName,
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
}
