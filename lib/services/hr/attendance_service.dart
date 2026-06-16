import 'package:dbcrypt/dbcrypt.dart';
import '../../models/hr/employee_profile.dart';
import '../../repositories/hr/attendance_repository.dart';
import '../../repositories/hr/employee_repository.dart';
import 'attendance_calculation_service.dart';

class AttendanceService {
  final AttendanceRepository _attendanceRepo = AttendanceRepository();
  final EmployeeRepository _employeeRepo = EmployeeRepository();

  Future<EmployeeProfile> _verifyPin(String pin) async {
    final employees = await _employeeRepo.getAll(activeOnly: true);
    for (var emp in employees) {
      if (emp.pinCode != null && emp.pinCode!.isNotEmpty) {
        try {
          if (DBCrypt().checkpw(pin, emp.pinCode!)) {
            return emp;
          }
        } catch (e) {
          // Ignore invalid hash formats
        }
      }
    }
    throw Exception('PIN ไม่ถูกต้อง หรือไม่พบข้อมูลพนักงาน');
  }

  Future<EmployeeProfile?> clockInWithPin(String pin) async {
    final matchedEmployee = await _verifyPin(pin);

    // 2. Check if already clocked in today
    final alreadyIn = await _attendanceRepo.hasClockInToday(matchedEmployee.id);
    if (alreadyIn) {
      throw Exception('พนักงานลงเวลาเข้างานไปแล้วสำหรับวันนี้');
    }

    // 3. คำนวณสถานะ LATE/ON_TIME ตาม role ของพนักงาน
    final status = AttendanceCalculationService.isLate(DateTime.now(), matchedEmployee.roleType)
        ? 'LATE'
        : 'ON_TIME';

    // 4. Clock In
    await _attendanceRepo.clockIn(matchedEmployee.id, 'PIN', status: status);
    return matchedEmployee;
  }

  Future<void> clockInOverride(int employeeId, int overrideByUserId, String reason, DateTime overrideTime) async {
    // 1. Check if already clocked in today
    final alreadyIn = await _attendanceRepo.hasClockInToday(employeeId);
    if (alreadyIn) {
      throw Exception('พนักงานลงเวลาเข้างานไปแล้วสำหรับวันนี้');
    }

    // 2. ดึง roleType เพื่อคำนวณสถานะ
    final employees = await _employeeRepo.getAll(activeOnly: false);
    final emp = employees.where((e) => e.id == employeeId).firstOrNull;
    final status = emp != null &&
            AttendanceCalculationService.isLate(overrideTime, emp.roleType)
        ? 'LATE'
        : 'ON_TIME';

    // 3. Clock In
    await _attendanceRepo.clockIn(
      employeeId,
      'ADMIN_OVERRIDE',
      overrideReason: reason,
      overrideBy: overrideByUserId,
      overrideTime: overrideTime,
      status: status,
    );
  }

  Future<void> clockOutWithPin(String pin) async {
    final emp = await _verifyPin(pin);
    await _attendanceRepo.clockOut(emp.id);
  }

  Future<void> clockOut(int employeeId) async {
    await _attendanceRepo.clockOut(employeeId);
  }

  Future<void> clockOutOverride(int employeeId, int overrideByUserId, String reason, DateTime overrideTime) async {
    await _attendanceRepo.clockOut(
      employeeId,
      method: 'ADMIN_OVERRIDE',
      overrideReason: reason,
      overrideBy: overrideByUserId,
      overrideTime: overrideTime,
    );
  }

  // --- Temporary Leave Flow (Migrated to AttendanceLog) ---
  Future<EmployeeProfile> startTempLeaveWithPin(String pin) async {
    final emp = await _verifyPin(pin);
    await _attendanceRepo.startTempLeave(emp.id, method: 'PIN');
    return emp;
  }

  Future<EmployeeProfile> endTempLeaveWithPin(String pin) async {
    final emp = await _verifyPin(pin);
    await _attendanceRepo.endTempLeave(emp.id, method: 'PIN');
    return emp;
  }

  Future<void> startTempLeaveOverride(int employeeId, int overrideByUserId, String reason, DateTime overrideTime) async {
    await _attendanceRepo.startTempLeave(
      employeeId,
      method: 'ADMIN_OVERRIDE',
      overrideReason: reason,
      overrideBy: overrideByUserId,
      overrideTime: overrideTime,
    );
  }

  Future<void> endTempLeaveOverride(int employeeId, int overrideByUserId, String reason, DateTime overrideTime) async {
    await _attendanceRepo.endTempLeave(
      employeeId,
      method: 'ADMIN_OVERRIDE',
      overrideReason: reason,
      overrideBy: overrideByUserId,
      overrideTime: overrideTime,
    );
  }

  /// ตรวจสอบว่าเข้างานสายตาม role ของพนักงาน
  /// ใช้ [AttendanceCalculationService.isLate] ที่แมป roleType → เวลากะ
  bool isLate(DateTime clockInTime, String roleType) {
    return AttendanceCalculationService.isLate(clockInTime, roleType);
  }
}
