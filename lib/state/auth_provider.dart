import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';

import '../services/firebase_service.dart';
import '../services/mysql_service.dart';
import '../services/api_service.dart';
import 'package:dbcrypt/dbcrypt.dart';

class AuthState {
  final User? currentUser;
  final bool isLoading;
  final bool isCheckingAuth;
  final bool isSetupRequired;
  final Map<String, bool> permissions;

  AuthState({
    this.currentUser,
    this.isLoading = false,
    this.isCheckingAuth = true,
    this.isSetupRequired = false,
    this.permissions = const {},
  });

  bool get isAuthenticated => currentUser != null;
  bool get canViewCost => isAdmin || (currentUser?.canViewCostPrice ?? false);
  bool get canViewProfit => isAdmin || (currentUser?.canViewProfit ?? false);
  bool get isAdmin => currentUser?.role == 'ADMIN';

  bool hasPermission(String key) {
    if (currentUser == null) return false;
    if (currentUser!.role == 'ADMIN') return true; // ✅ Admin overrides all permissions
    if (permissions.containsKey(key)) {
      return permissions[key] ?? false;
    }
    return false;
  }

  AuthState copyWith({
    User? currentUser,
    bool? isLoading,
    bool? isCheckingAuth,
    bool? isSetupRequired,
    Map<String, bool>? permissions,
    bool clearUser = false,
  }) {
    return AuthState(
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      isLoading: isLoading ?? this.isLoading,
      isCheckingAuth: isCheckingAuth ?? this.isCheckingAuth,
      isSetupRequired: isSetupRequired ?? this.isSetupRequired,
      permissions: permissions ?? this.permissions,
    );
  }
}

final authProvider = AutoDisposeNotifierProvider<AuthNotifier, AuthState>(
  () => AuthNotifier(),
);

class AuthNotifier extends AutoDisposeNotifier<AuthState> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  AuthState build() {
    ref.keepAlive();
    return AuthState();
  }

  Future<void> tryAutoLogin() async {
    debugPrint('🚀 [Auth] tryAutoLogin started...');
    state = state.copyWith(isCheckingAuth: true);

    try {
      debugPrint('⏳ [Auth] Checking DB Config with 3s timeout...');
      final hasConfig =
          await MySQLService().hasConfig().timeout(const Duration(seconds: 3));
      debugPrint('✅ [Auth] hasConfig result: $hasConfig');

      if (!hasConfig) {
        debugPrint(
            '⚠️ [Auth] No Database Config found. Redirecting to Setup...');
        state = state.copyWith(isSetupRequired: true);
      }
    } catch (e) {
      debugPrint('⚠️ [Auth] Error checking config: $e');
      state = state.copyWith(isSetupRequired: true);
    } finally {
      debugPrint(
          '🏁 [Auth] tryAutoLogin FINISHED. Setting isCheckingAuth = false');
      state = state.copyWith(isCheckingAuth: false);
    }
  }

  Future<Map<String, String>> loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('saved_username') ?? '';
    final password = prefs.getString('saved_password') ?? '';
    return {'username': username, 'password': password};
  }

  Future<bool> login(String username, String password,
      {bool rememberMe = false}) async {
    state = state.copyWith(isLoading: true);
    debugPrint('🔄 AuthNotifier: Starting login via API...');

    try {
      final response = await ApiService().post('/auth/login', {
        'username': username.trim(),
        'password': password.trim(),
      });

      final token = response['token'];
      final userData = response['user'];

      if (token != null && userData != null) {
        await ApiService().setToken(token);

        final currentUser = User.fromJson(userData);
        debugPrint('✅ Login Success (API): ${currentUser.username}');

        Map<String, bool> perms = {};
        if (userData['permissions'] != null) {
          final Map<String, dynamic> permMap = userData['permissions'];
          perms = permMap.map((key, value) => MapEntry(key, value == true));
        }
        debugPrint('🔑 Loaded Permissions: $perms');

        state = state.copyWith(currentUser: currentUser, permissions: perms);

        await _handlePostLogin(username, password, rememberMe);
        return true;
      } else {
        throw Exception('Invalid response from API');
      }
    } catch (e) {
      debugPrint('🔥 Login API Error: $e');
      debugPrint('⚠️ attempting Local DB Login Fallback...');

      final success = await _loginLocally(username, password);
      if (success) {
        await _handlePostLogin(username, password, rememberMe);
      }
      return success;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _handlePostLogin(
      String username, String password, bool rememberMe) async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setString('saved_username', username);
      await prefs.setString('saved_password', password);
    } else {
      await prefs.remove('saved_username');
      await prefs.remove('saved_password');
    }

    await prefs.remove('last_username');
    await _loginToFirebase();
  }

  Future<bool> _loginLocally(String username, String password) async {
    try {
      final db = MySQLService();
      final results = await db.query(
        'SELECT * FROM user WHERE username = :u',
        {'u': username},
      );

      if (results.isEmpty) {
        debugPrint('❌ Local Login: User not found in DB');
        return false;
      }

      final row = results.first;
      String? dbHash = row['passwordHash']?.toString();
      if (dbHash == null || dbHash.isEmpty) {
        dbHash = row['password_hash']?.toString();
      }
      if (dbHash == null || dbHash.isEmpty) {
        dbHash = row['password']?.toString();
      }

      if (dbHash == null) {
        debugPrint('❌ Local Login: No password found for user');
        return false;
      }

      bool isMatch = false;
      try {
        if (dbHash.startsWith('\$2')) {
          isMatch = DBCrypt().checkpw(password, dbHash);
        } else {
          isMatch = (dbHash == password);
        }
      } catch (e) {
        debugPrint('⚠️ Local Login: Hash Verification Error: $e');
        isMatch = (dbHash == password);
      }

      if (isMatch) {
        debugPrint('✅ Local Login Success: $username');

        final permResults = await db.query(
          'SELECT permissionKey, isAllowed FROM user_permission WHERE userId = :uid',
          {'uid': row['id']},
        );

        final Map<String, bool> perms = {};
        for (var p in permResults) {
          final key = p['permissionKey'].toString();
          final val = p['isAllowed'].toString();
          perms[key] = (val == '1' || val == 'true');
        }

        final currentUser = User.fromJson({
          'id': row['id'],
          'username': row['username'],
          'displayName': row['displayName'] ?? row['username'],
          'passwordHash': dbHash,
          'role': row['role'],
          'isActive': row['isActive'],
          'canViewCostPrice': row['canViewCostPrice'],
          'canViewProfit': row['canViewProfit'],
        });

        state = state.copyWith(
          currentUser: currentUser,
          permissions: perms,
          isLoading: false,
        );
        return true;
      } else {
        debugPrint('❌ Local Login: Password Mismatch');
      }
    } catch (e) {
      debugPrint('🔥 Local Login Critical Error: $e');
    }
    return false;
  }

  void logout() async {
    state = state.copyWith(clearUser: true, permissions: {});
    _firebaseService.stopListener();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_username');
  }

  Future<void> _loginToFirebase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('firebase_auth_email') ?? '';
      final password = prefs.getString('firebase_auth_password') ?? '';

      if (email.isNotEmpty && password.isNotEmpty) {
        debugPrint('☁️ Attempting Firebase Login: $email');
        await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        debugPrint('✅ Firebase Auth Success');
      } else {
        debugPrint('⚠️ Firebase Auth: No credentials configured in settings.');
      }
    } catch (e) {
      debugPrint('❌ Firebase Auth Error: $e');
    }
  }
}
