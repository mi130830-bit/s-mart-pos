import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/hr/leave_request.dart';
import '../../repositories/hr/leave_repository.dart';

class LeaveState {
  final List<LeaveRequest> pending;
  final List<LeaveRequest> history; // For a specific employee
  final bool isLoading;
  final String? error;

  LeaveState({
    this.pending = const [],
    this.history = const [],
    this.isLoading = false,
    this.error,
  });

  LeaveState copyWith({
    List<LeaveRequest>? pending,
    List<LeaveRequest>? history,
    bool? isLoading,
    String? error,
  }) {
    return LeaveState(
      pending: pending ?? this.pending,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final leaveProvider = AutoDisposeNotifierProvider<LeaveNotifier, LeaveState>(
  () => LeaveNotifier(),
);

class LeaveNotifier extends AutoDisposeNotifier<LeaveState> {
  final LeaveRepository _repo = LeaveRepository();

  @override
  LeaveState build() {
    ref.keepAlive();
    Future.microtask(() => loadPending());
    return LeaveState(isLoading: true);
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

  Future<void> loadByEmployee(int employeeId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final history = await _repo.getByEmployee(employeeId);
      state = state.copyWith(history: history, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> create(LeaveRequest request) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.create(request);
      await loadPending();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> approve(int id, int approvedBy) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.approve(id, approvedBy);
      await loadPending();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> reject(int id, String reason) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.reject(id, reason);
      await loadPending();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }
}
