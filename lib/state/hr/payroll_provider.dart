import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/hr/payroll_record.dart';
import '../../repositories/hr/payroll_repository.dart';
import '../../services/hr/payroll_calculation_service.dart';
import '../../services/hr/advance_service.dart';
import '../../repositories/activity_repository.dart';
import '../auth_provider.dart';

class PayrollState {
  final List<PayrollRecord> records; // Currently loaded records (e.g. for a period)
  final List<PayrollRecord> historyRecords;
  final List<Map<String, dynamic>> periodSummaries;
  final bool isLoading;
  final String? error;

  PayrollState({
    this.records = const [],
    this.historyRecords = const [],
    this.periodSummaries = const [],
    this.isLoading = false,
    this.error,
  });

  PayrollState copyWith({
    List<PayrollRecord>? records,
    List<PayrollRecord>? historyRecords,
    List<Map<String, dynamic>>? periodSummaries,
    bool? isLoading,
    String? error,
  }) {
    return PayrollState(
      records: records ?? this.records,
      historyRecords: historyRecords ?? this.historyRecords,
      periodSummaries: periodSummaries ?? this.periodSummaries,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final payrollProvider = AutoDisposeNotifierProvider<PayrollNotifier, PayrollState>(
  () => PayrollNotifier(),
);

class PayrollNotifier extends AutoDisposeNotifier<PayrollState> {
  final PayrollRepository _repo = PayrollRepository();
  final PayrollCalculationService _service = PayrollCalculationService();

  @override
  PayrollState build() {
    ref.keepAlive();
    return PayrollState();
  }

  Future<void> loadByPeriod(DateTime start, DateTime end) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final records = await _repo.getByPeriod(start, end);
      state = state.copyWith(records: records, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> calculateForPeriod(DateTime start, DateTime end) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 1. Calculate drafts
      final calculatedDrafts = await _service.calculateAllForPeriod(start, end);
      
      // 2. See if existing DRAFTs exist, update them or insert new
      final existingRecords = await _repo.getByPeriod(start, end);
      
      for (var draft in calculatedDrafts) {
        final existing = existingRecords.where((r) => r.employeeId == draft.employeeId).firstOrNull;
        
        if (existing == null) {
          await _repo.create(draft);
        } else if (existing.status == 'DRAFT') {
          // Update the existing draft
          final updatedDraft = PayrollRecord(
            id: existing.id,
            employeeId: draft.employeeId,
            payCycle: draft.payCycle,
            periodStart: draft.periodStart,
            periodEnd: draft.periodEnd,
            workDays: draft.workDays,
            absentDays: draft.absentDays,
            lateCount: draft.lateCount,
            leaveDays: draft.leaveDays,
            dailyWageTotal: draft.dailyWageTotal,
            baseSalary: draft.baseSalary,
            tripCount: draft.tripCount,
            tripTotalFee: draft.tripTotalFee,
            overtimeHours: draft.overtimeHours,
            overtimePay: draft.overtimePay,
            bonus: draft.bonus,
            grossPay: draft.grossPay,
            advanceDeductions: draft.advanceDeductions,
            socialSecurity: draft.socialSecurity,
            otherDeductions: draft.otherDeductions,
            totalDeductions: draft.totalDeductions,
            netPay: draft.netPay,
            status: draft.status,
            note: draft.note,
          );
          await _repo.update(updatedDraft);
        }
      }
      
      // Reload
      await loadByPeriod(start, end);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> confirm(int id, int confirmedBy) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final payrollRecord = state.records.firstWhere((r) => r.id == id);

      // Record the advance_deduction in the advance repo
      if (payrollRecord.advanceDeductions > 0) {
        final advanceService = AdvanceService();
        await advanceService.deductFromPayroll(
          payrollRecord.employeeId,
          id,
          payrollRecord.advanceDeductions,
        );
      }

      await _repo.confirm(id, confirmedBy);
      
      // Reload state by finding the record and updating it locally (faster) or just leave it to caller to reload
      final updatedRecords = state.records.map((r) {
        if (r.id == id) {
          return PayrollRecord(
            id: r.id, employeeId: r.employeeId, payCycle: r.payCycle, periodStart: r.periodStart, periodEnd: r.periodEnd,
            workDays: r.workDays, absentDays: r.absentDays, lateCount: r.lateCount, leaveDays: r.leaveDays,
            dailyWageTotal: r.dailyWageTotal, baseSalary: r.baseSalary, tripCount: r.tripCount, tripTotalFee: r.tripTotalFee,
            overtimeHours: r.overtimeHours, overtimePay: r.overtimePay, bonus: r.bonus, grossPay: r.grossPay,
            advanceDeductions: r.advanceDeductions, socialSecurity: r.socialSecurity, otherDeductions: r.otherDeductions,
            totalDeductions: r.totalDeductions, netPay: r.netPay, status: 'CONFIRMED', confirmedBy: confirmedBy,
            paidAt: r.paidAt, note: r.note, createdAt: r.createdAt, employeeName: r.employeeName,
          );
        }
        return r;
      }).toList();
      
      state = state.copyWith(records: updatedRecords, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> markPaid(int id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.markPaid(id);
      
      ActivityRepository().log(
        userId: ref.read(authProvider).currentUser?.id,
        action: 'PAY_PAYROLL',
        details: 'Marked payroll record ID $id as paid.',
      );
      
      final updatedRecords = state.records.map((r) {
        if (r.id == id) {
          return PayrollRecord(
            id: r.id, employeeId: r.employeeId, payCycle: r.payCycle, periodStart: r.periodStart, periodEnd: r.periodEnd,
            workDays: r.workDays, absentDays: r.absentDays, lateCount: r.lateCount, leaveDays: r.leaveDays,
            dailyWageTotal: r.dailyWageTotal, baseSalary: r.baseSalary, tripCount: r.tripCount, tripTotalFee: r.tripTotalFee,
            overtimeHours: r.overtimeHours, overtimePay: r.overtimePay, bonus: r.bonus, grossPay: r.grossPay,
            advanceDeductions: r.advanceDeductions, socialSecurity: r.socialSecurity, otherDeductions: r.otherDeductions,
            totalDeductions: r.totalDeductions, netPay: r.netPay, status: 'PAID', confirmedBy: r.confirmedBy,
            paidAt: DateTime.now(), note: r.note, createdAt: r.createdAt, employeeName: r.employeeName,
          );
        }
        return r;
      }).toList();
      
      state = state.copyWith(records: updatedRecords, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> deleteRecord(int id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.delete(id);
      
      final updatedRecords = state.records.where((r) => r.id != id).toList();
      state = state.copyWith(records: updatedRecords, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<int> deleteAllDraftsForPeriod(DateTime start, DateTime end) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final count = await _repo.deleteByPeriod(start, end);
      // Keep only non-DRAFT records in state
      final updatedRecords = state.records.where((r) => r.status != 'DRAFT').toList();
      state = state.copyWith(records: updatedRecords, isLoading: false);
      return count;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> loadHistory({
    required DateTime startDate,
    required DateTime endDate,
    int? employeeId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final records = await _repo.getHistory(
        startDate: startDate,
        endDate: endDate,
        employeeId: employeeId,
      );
      state = state.copyWith(historyRecords: records, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadPeriodSummaries({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final summaries = await _repo.getPeriodSummaries(
        startDate: startDate,
        endDate: endDate,
      );
      state = state.copyWith(periodSummaries: summaries, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<int> markAllPaidForPeriod(DateTime start, DateTime end) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final count = await _repo.markAllPaidForPeriod(start, end);
      // Update local state
      final updatedRecords = state.records.map((r) {
        return PayrollRecord(
          id: r.id, employeeId: r.employeeId, payCycle: r.payCycle,
          periodStart: r.periodStart, periodEnd: r.periodEnd,
          workDays: r.workDays, absentDays: r.absentDays, lateCount: r.lateCount,
          leaveDays: r.leaveDays, dailyWageTotal: r.dailyWageTotal,
          baseSalary: r.baseSalary, tripCount: r.tripCount, tripTotalFee: r.tripTotalFee,
          overtimeHours: r.overtimeHours, overtimePay: r.overtimePay, bonus: r.bonus,
          grossPay: r.grossPay, advanceDeductions: r.advanceDeductions,
          socialSecurity: r.socialSecurity, otherDeductions: r.otherDeductions,
          totalDeductions: r.totalDeductions, netPay: r.netPay,
          status: 'PAID', confirmedBy: r.confirmedBy,
          paidAt: DateTime.now(), note: r.note,
          createdAt: r.createdAt, employeeName: r.employeeName,
        );
      }).toList();
      state = state.copyWith(records: updatedRecords, isLoading: false);
      return count;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }
}
