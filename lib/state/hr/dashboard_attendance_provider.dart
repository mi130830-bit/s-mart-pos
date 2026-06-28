import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/hr/dashboard_attendance_summary.dart';
import '../../repositories/hr/attendance_repository.dart';

final dashboardAttendanceFilterProvider = StateProvider<String>((ref) => 'WEEK');

final dashboardAttendanceProvider = FutureProvider.autoDispose<List<DashboardAttendanceSummary>>((ref) async {
  final filter = ref.watch(dashboardAttendanceFilterProvider);
  final repo = AttendanceRepository();
  final results = await repo.getDashboardSummary(filter);
  return results.map((e) => DashboardAttendanceSummary.fromJson(e)).toList();
});
