import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/hr/attendance_log.dart';
import '../../models/hr/employee_profile.dart';
import '../../models/hr/leave_request.dart';
import '../../repositories/hr/attendance_repository.dart';
import '../../repositories/hr/leave_repository.dart';
import '../../services/hr/attendance_service.dart';

class AttendanceState {
  final List<AttendanceLog> todayAttendance;
  final List<LeaveRequest> openTempLeaves;
  final bool isLoading;
  final String? error;

  AttendanceState({
    this.todayAttendance = const [],
    this.openTempLeaves = const [],
    this.isLoading = false,
    this.error,
  });

  AttendanceState copyWith({
    List<AttendanceLog>? todayAttendance,
    List<LeaveRequest>? openTempLeaves,
    bool? isLoading,
    String? error,
  }) {
    return AttendanceState(
      todayAttendance: todayAttendance ?? this.todayAttendance,
      openTempLeaves: openTempLeaves ?? this.openTempLeaves,
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
      state = state.copyWith(
        todayAttendance: logs, 
        openTempLeaves: tempLeaves,
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
}
