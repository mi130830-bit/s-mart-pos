
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repositories/user_repository.dart';
import '../../models/user.dart' as model;

class UserManagementState {
  final List<model.User> users;
  final bool isLoading;

  const UserManagementState({
    this.users = const [],
    this.isLoading = true,
  });

  UserManagementState copyWith({
    List<model.User>? users,
    bool? isLoading,
  }) {
    return UserManagementState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class UserManagementNotifier extends AutoDisposeNotifier<UserManagementState> {
  final UserRepository _userRepo = UserRepository();

  @override
  UserManagementState build() {
    loadUsers();
    return const UserManagementState();
  }

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true);
    final users = await _userRepo.getAllUsers();
    state = state.copyWith(users: users, isLoading: false);
  }

  Future<bool> deleteUser(int userId) async {
    final success = await _userRepo.deleteUser(userId);
    if (success) {
      await loadUsers();
    }
    return success;
  }

  Future<bool> changePassword(int userId, String newPassword) async {
    return await _userRepo.changePassword(userId, newPassword);
  }

  Future<Map<String, bool>> loadPermissions(int userId) async {
    return await _userRepo.getPermissions(userId);
  }

  Future<bool> saveUser({
    required bool isEditing,
    required model.User newUser,
    required Map<String, bool> permissions,
    required String rawPassword,
  }) async {
    bool success = false;
    
    if (isEditing) {
      success = await _userRepo.updateUser(newUser);
    } else {
      final trimmedUser = model.User(
        id: newUser.id,
        username: newUser.username,
        displayName: newUser.displayName,
        role: newUser.role,
        passwordHash: rawPassword.trim(),
        isActive: newUser.isActive,
        canViewCostPrice: newUser.canViewCostPrice,
        canViewProfit: newUser.canViewProfit,
      );
      success = await _userRepo.createUser(trimmedUser);
    }

    if (success) {
      int targetId = newUser.id;
      if (!isEditing) {
        final u = await _userRepo.getUserByUsername(newUser.username);
        if (u != null) targetId = u.id;
      }

      if (targetId > 0) {
        await _userRepo.setPermissions(targetId, permissions);
      }
      
      await loadUsers();
      return true;
    }
    return false;
  }
}

final userManagementProvider = NotifierProvider.autoDispose<UserManagementNotifier, UserManagementState>(
  UserManagementNotifier.new,
);
