import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/hr/advance_payment.dart';
import '../../repositories/hr/advance_repository.dart';
import '../../services/hr/advance_service.dart';

class AdvanceState {
  final List<AdvancePayment> pending;
  final List<AdvancePayment> outstanding; // For a specific employee
  final List<AdvancePayment> history;
  final bool isLoading;
  final String? error;

  AdvanceState({
    this.pending = const [],
    this.outstanding = const [],
    this.history = const [],
    this.isLoading = false,
    this.error,
  });

  AdvanceState copyWith({
    List<AdvancePayment>? pending,
    List<AdvancePayment>? outstanding,
    List<AdvancePayment>? history,
    bool? isLoading,
    String? error,
  }) {
    return AdvanceState(
      pending: pending ?? this.pending,
      outstanding: outstanding ?? this.outstanding,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final advanceProvider = AutoDisposeNotifierProvider<AdvanceNotifier, AdvanceState>(
  () => AdvanceNotifier(),
);

class AdvanceNotifier extends AutoDisposeNotifier<AdvanceState> {
  final AdvanceRepository _repo = AdvanceRepository();
  final AdvanceService _service = AdvanceService();

  @override
  AdvanceState build() {
    ref.keepAlive();
    Future.microtask(() {
      loadPending();
      loadAllHistory();
    });
    return AdvanceState(isLoading: true);
  }

  Future<void> loadPending() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final pending = await _repo.getPending();
      state = state.copyWith(pending: pending, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadAllHistory() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final history = await _repo.getAllHistory();
      state = state.copyWith(history: history, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadOutstanding(int employeeId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final outstanding = await _repo.getOutstanding(employeeId);
      state = state.copyWith(outstanding: outstanding, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> requestAdvance(int employeeId, double amount, String reason, {double? installmentAmount}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.requestAdvance(employeeId, amount, reason, installmentAmount: installmentAmount);
      await loadPending();
      await loadAllHistory();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> approve(int id, int approvedBy) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.approveAdvance(id, approvedBy);
      await loadPending();
      await loadAllHistory();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> reject(int id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.rejectAdvance(id);
      await loadPending();
      await loadAllHistory();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }
}
