import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../models/hr/employee_profile.dart';
import '../../repositories/hr/employee_repository.dart';
import '../../services/firestore_rest_service.dart';

class EmployeeState {
  final List<EmployeeProfile> employees;
  final bool isLoading;
  final String? error;

  EmployeeState({
    this.employees = const [],
    this.isLoading = false,
    this.error,
  });

  EmployeeState copyWith({
    List<EmployeeProfile>? employees,
    bool? isLoading,
    String? error,
  }) {
    return EmployeeState(
      employees: employees ?? this.employees,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Can be null to clear
    );
  }
}

final employeeProvider = AutoDisposeNotifierProvider<EmployeeNotifier, EmployeeState>(
  () => EmployeeNotifier(),
);

class EmployeeNotifier extends AutoDisposeNotifier<EmployeeState> {
  final EmployeeRepository _repo = EmployeeRepository();

  @override
  EmployeeState build() {
    ref.keepAlive();
    Future.microtask(() => loadAll());
    return EmployeeState(isLoading: true);
  }

  Future<void> loadAll({bool activeOnly = true}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final employees = await _repo.getAll(activeOnly: activeOnly);
      state = state.copyWith(employees: employees, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> create(EmployeeProfile emp) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.create(emp);
      await _syncToFirestore(emp);
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> updateEmployee(EmployeeProfile emp) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.update(emp);
      await _syncToFirestore(emp);
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> _syncToFirestore(EmployeeProfile emp) async {
    if (emp.firebaseUid != null && emp.firebaseUid!.isNotEmpty) {
      try {
        await FirestoreRestService.updateDocument('users', emp.firebaseUid!, {
          'name': emp.displayName ?? '',
          'role': emp.roleType.toLowerCase(),
          'isActive': emp.isActive,
          'phone': emp.phone ?? '',
        });
      } catch (e) {
        // Log error but don't fail the whole transaction
        debugPrint('Firestore Sync Error: $e');
      }
    }
  }

  Future<void> deactivate(int id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final emp = await _repo.getById(id);
      await _repo.deactivate(id);
      if (emp != null) {
        await _syncToFirestore(EmployeeProfile(
          id: emp.id, 
          firebaseUid: emp.firebaseUid,
          roleType: emp.roleType,
          wageType: emp.wageType,
          isActive: false, 
          displayName: emp.displayName,
          phone: emp.phone,
        ));
      }
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> reorderEmployees(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final items = List<EmployeeProfile>.from(state.employees);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    // Optimistic UI update
    state = state.copyWith(employees: items);

    try {
      final orderedIds = items.map((e) => e.id).toList();
      await _repo.updateSortOrder(orderedIds);
    } catch (e) {
      // Revert on error
      await loadAll();
    }
  }
}
