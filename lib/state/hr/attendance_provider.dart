import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/hr/attendance_log.dart';
import '../../models/hr/employee_profile.dart';
import '../../models/hr/leave_request.dart';
import '../../models/hr/special_holiday.dart';
import '../../repositories/hr/attendance_repository.dart';
import '../../repositories/hr/leave_repository.dart';
import '../../repositories/hr/special_holiday_repository.dart';
import '../../services/hr/attendance_service.dart';

class AttendanceState {
  final List<AttendanceLog> todayAttendance;
  final List<LeaveRequest> openTempLeaves;
  final List<SpecialHoliday> specialHolidays;
  final List<LeaveRequest> todayApprovedLeaves;
  final bool isLoading;
  final String? error;

  AttendanceState({
    this.todayAttendance = const [],
    this.openTempLeaves = const [],
    this.specialHolidays = const [],
    this.todayApprovedLeaves = const [],
    this.isLoading = false,
    this.error,
  });

  AttendanceState copyWith({
    List<AttendanceLog>? todayAttendance,
    List<LeaveRequest>? openTempLeaves,
    List<SpecialHoliday>? specialHolidays,
    List<LeaveRequest>? todayApprovedLeaves,
    bool? isLoading,
    String? error,
  }) {
    return AttendanceState(
      todayAttendance: todayAttendance ?? this.todayAttendance,
      openTempLeaves: openTempLeaves ?? this.openTempLeaves,
      specialHolidays: specialHolidays ?? this.specialHolidays,
      todayApprovedLeaves: todayApprovedLeaves ?? this.todayApprovedLeaves,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final attendanceProvider = AutoDisposeNotifierProvider<AttendanceNotifier, AttendanceState>(
  () => AttendanceNotifier(),
);

class AttendanceNotifier extends AutoDisposeNotifier<AttendanceState> {
  final AttendanceRepository _repo = AttendanceRepository();
  final LeaveRepository _leaveRepo = LeaveRepository();
  final AttendanceService _service = AttendanceService();
  final SpecialHolidayRepository _holidayRepo = SpecialHolidayRepository();

  @override
  AttendanceState build() {
    ref.keepAlive();
    Future.microtask(() => loadToday());
    return AttendanceState(isLoading: true);
  }

  Future<void> loadToday() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final logs = await _repo.getTodayAttendance();
      final tempLeaves = await _leaveRepo.getTodayOpenTempLeaves();
      final holidays = await _holidayRepo.getAllHolidays();
      // Fetch approved leaves for today (start_date <= today and end_date >= today)
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day, 0, 0, 0);
      
      // Let's query approved leave requests that overlap with today
      final results = await _leaveRepo.getApprovedLeavesForDate(startOfToday);

      state = state.copyWith(
        todayAttendance: logs, 
        openTempLeaves: tempLeaves,
        specialHolidays: holidays,
        todayApprovedLeaves: results,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> clearAllLogs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.clearAll();
      await loadToday();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<EmployeeProfile?> clockInWithPin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final emp = await _service.clockInWithPin(pin);
      await loadToday();
      return emp;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> clockInOverride(int employeeId, int overrideBy, TimeOfDay overrideTime, String reason) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, overrideTime.hour, overrideTime.minute);
      await _service.clockInOverride(employeeId, overrideBy, reason, dt);
      await loadToday();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> clockOutOverride(int employeeId, int overrideBy, TimeOfDay overrideTime, String reason) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, overrideTime.hour, overrideTime.minute);
      await _service.clockOutOverride(employeeId, overrideBy, reason, dt);
      await loadToday();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> startTempLeaveOverride(int employeeId, int overrideBy, TimeOfDay overrideTime, String reason) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, overrideTime.hour, overrideTime.minute);
      await _service.startTempLeaveOverride(employeeId, overrideBy, reason, dt);
      await loadToday();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> endTempLeaveOverride(int employeeId, int overrideBy, TimeOfDay overrideTime, String reason) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, overrideTime.hour, overrideTime.minute);
      await _service.endTempLeaveOverride(employeeId, overrideBy, reason, dt);
      await loadToday();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> clockOut(int employeeId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.clockOut(employeeId);
      await loadToday();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> clockOutWithPin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.clockOutWithPin(pin);
      await loadToday();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<EmployeeProfile?> startTempLeaveWithPin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final emp = await _service.startTempLeaveWithPin(pin);
      await loadToday();
      return emp;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<EmployeeProfile?> endTempLeaveWithPin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final emp = await _service.endTempLeaveWithPin(pin);
      await loadToday();
      return emp;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> deleteTodayLog(int employeeId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.deleteTodayLog(employeeId);
      await loadToday();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Emergency Close Shop
  // ---------------------------------------------------------------------------

  /// ปิดร้านฉุกเฉิน: Clock Out พนักงานทุกคนที่ยังเข้างานอยู่ ให้คืนเวลาปัจจุบัน
  /// [reason] หมายเหตุการปิด เช่น 'ไฟดับ' 'ปิดร้านตั้งแต่ต้น' เป็นต้น
  /// คืนค่า: จำนวนพนักงานที่ถูก Clock Out
  Future<int> emergencyCloseShop(String reason, {int? overrideBy}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final count = await _repo.emergencyClockOutAll(reason: reason, overrideBy: overrideBy);
      await loadToday();
      return count;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Special Holiday Management
  // ---------------------------------------------------------------------------

  /// เพิ่มวันหยุดพิเศษ — พนักงานรายเดือนไม่ถูกนับว่าขาดงาน
  Future<void> addSpecialHoliday(DateTime date, String name) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _holidayRepo.addHoliday(date, name);
      await loadToday();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  /// ลบวันหยุดพิเศษ
  Future<void> removeSpecialHoliday(DateTime date) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _holidayRepo.removeHoliday(date);
      await loadToday();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }
}
