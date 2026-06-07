import 'package:dbcrypt/dbcrypt.dart';
import '../../models/hr/employee_profile.dart';
import '../../repositories/hr/attendance_repository.dart';
import '../../repositories/hr/employee_repository.dart';

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

    // 3. Clock In
    await _attendanceRepo.clockIn(matchedEmployee.id, 'PIN');
    return matchedEmployee;
  }

  Future<void> clockInOverride(int employeeId, int overrideByUserId, String reason, DateTime overrideTime) async {
    // 1. Check if already clocked in today
    final alreadyIn = await _attendanceRepo.hasClockInToday(employeeId);
    if (alreadyIn) {
      throw Exception('พนักงานลงเวลาเข้างานไปแล้วสำหรับวันนี้');
    }

    // 2. Clock In
    await _attendanceRepo.clockIn(
      employeeId, 
      'ADMIN_OVERRIDE', 
      overrideReason: reason,
      overrideBy: overrideByUserId,
      overrideTime: overrideTime,
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

  bool isLate(DateTime clockInTime) {
    // Default config: 08:30 is late. Could be moved to settings table later.
    final lateTime = DateTime(clockInTime.year, clockInTime.month, clockInTime.day, 8, 30);
    return clockInTime.isAfter(lateTime);
  }
}
