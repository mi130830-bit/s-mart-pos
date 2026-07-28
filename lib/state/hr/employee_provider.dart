import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../models/hr/employee_profile.dart';
import '../../repositories/hr/employee_repository.dart';
import '../../services/firestore_rest_service.dart';
import '../../repositories/activity_repository.dart';
import '../auth_provider.dart';

class EmployeeState {
  final List<EmployeeProfile> allEmployees; // Unfiltered list
  final List<EmployeeProfile> employees; // Displayed (filtered) list
  final String searchQuery;
  final bool isLoading;
  final String? error;

  EmployeeState({
    this.allEmployees = const [],
    this.employees = const [],
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
  });

  EmployeeState copyWith({
    List<EmployeeProfile>? allEmployees,
    List<EmployeeProfile>? employees,
    String? searchQuery,
    bool? isLoading,
    String? error,
  }) {
    return EmployeeState(
      allEmployees: allEmployees ?? this.allEmployees,
      employees: employees ?? this.employees,
      searchQuery: searchQuery ?? this.searchQuery,
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
      state = state.copyWith(allEmployees: employees, isLoading: false);
      _applySearch();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query);
    _applySearch();
  }

  void _applySearch() {
    if (state.searchQuery.trim().isEmpty) {
      state = state.copyWith(employees: state.allEmployees);
      return;
    }
    final q = state.searchQuery.trim().toLowerCase();
    final filtered = state.allEmployees.where((emp) {
      return (emp.displayName?.toLowerCase().contains(q) ?? false) ||
             (emp.employeeCode?.toLowerCase().contains(q) ?? false) ||
             (emp.phone?.toLowerCase().contains(q) ?? false) ||
             (emp.roleType.toLowerCase().contains(q));
    }).toList();
    state = state.copyWith(employees: filtered);
  }

  Future<void> create(EmployeeProfile emp) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.create(emp);
      await _syncToFirestore(emp);
      
      ActivityRepository().log(
        userId: ref.read(authProvider).currentUser?.id,
        action: 'ADD_EMPLOYEE',
        details: 'Added employee: ${emp.displayName} (Code: ${emp.employeeCode})',
      );
      
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

      ActivityRepository().log(
        userId: ref.read(authProvider).currentUser?.id,
        action: 'UPDATE_EMPLOYEE',
        details: 'Updated employee: ${emp.displayName} (Code: ${emp.employeeCode})',
      );

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
        if (emp.firebaseUid != null && emp.firebaseUid!.isNotEmpty) {
          try {
            await FirestoreRestService.deleteDocument('users', emp.firebaseUid!);
          } catch (e) {
            debugPrint('Firestore Delete Error: $e');
          }
        }
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
    
    final items = List<EmployeeProfile>.from(state.allEmployees);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    // Optimistic UI update
    state = state.copyWith(allEmployees: items);
    _applySearch();

    try {
      final orderedIds = items.map((e) => e.id).toList();
      await _repo.updateSortOrder(orderedIds);
    } catch (e) {
      // Revert on error
      await loadAll();
    }
  }
}
