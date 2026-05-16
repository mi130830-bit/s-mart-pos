import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../models/user.dart';

import '../services/firebase_service.dart';
import '../services/mysql_service.dart';
import '../services/api_service.dart';
import 'package:dbcrypt/dbcrypt.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  bool _isCheckingAuth = true; // ✅ เช็คสถานะเริ่มต้น (Splash Screen)
  bool _isSetupRequired = false; // ✅ ต้องตั้งค่าไหม

  final FirebaseService _firebaseService = FirebaseService();
  // final MySQLService _mySQLService = MySQLService(); // ❌ Removed as unused due to background loading

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  bool get isCheckingAuth => _isCheckingAuth; // ✅ Getter สำหรับ main.dart
  bool get isSetupRequired => _isSetupRequired; // ✅ Getter สำหรับ main.dart
  bool get canViewCost => isAdmin || (_currentUser?.canViewCostPrice ?? false);
  bool get canViewProfit => isAdmin || (_currentUser?.canViewProfit ?? false);
  bool get isAdmin => _currentUser?.role == 'ADMIN';

  // ✅ Permissions State
  Map<String, bool> _permissions = {};

  // ✅ ฟังก์ชันเช็คสถานะเมื่อเปิดแอป (เรียกจาก main.dart)
  Future<void> tryAutoLogin() async {
    debugPrint('🚀 [Auth] tryAutoLogin started...');
    _isCheckingAuth = true;
    notifyListeners();

    try {
      debugPrint('⏳ [Auth] Checking DB Config with 3s timeout...');
      // 1. Check if DB Config exists with Timeout
      // Protected against SecureStorage hangs (common on Windows)
      final hasConfig =
          await MySQLService().hasConfig().timeout(const Duration(seconds: 3));
      debugPrint('✅ [Auth] hasConfig result: $hasConfig');

      if (!hasConfig) {
        debugPrint(
            '⚠️ [Auth] No Database Config found. Redirecting to Setup...');
        _isSetupRequired = true;
      }
    } catch (e) {
      debugPrint('⚠️ [Auth] Error checking config: $e');
      // If error (e.g. timeout or secure storage fail), force setup?
      // Better allow retry or show setup.
      _isSetupRequired = true;
    } finally {
      debugPrint(
          '🏁 [Auth] tryAutoLogin FINISHED. Setting _isCheckingAuth = false');
      // ✅ Always ensure checking auth is set to false
      _isCheckingAuth = false;
      notifyListeners();
    }
  }

  // ✅ Load Saved Credentials for Login Screen
  Future<Map<String, String>> loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('saved_username') ?? '';
    final password = prefs.getString('saved_password') ??
        ''; // Note: Plain text as requested
    return {'username': username, 'password': password};
  }

  Future<bool> login(String username, String password,
      {bool rememberMe = false}) async {
    _isLoading = true;
    notifyListeners();
    debugPrint('🔄 AuthProvider: Starting login via API...');

    try {
      // 1. Call API
      final response = await ApiService().post('/auth/login', {
        'username': username.trim(),
        'password': password.trim(),
      });

      // 2. Parse Response
      final token = response['token'];
      final userData = response['user'];

      if (token != null && userData != null) {
        // Save Token
        await ApiService().setToken(token);

        // Parse User
        _currentUser = User.fromJson(userData);
        debugPrint('✅ Login Success (API): ${_currentUser!.username}');

        // Parse Permissions
        if (userData['permissions'] != null) {
          final Map<String, dynamic> permMap = userData['permissions'];
          _permissions =
              permMap.map((key, value) => MapEntry(key, value == true));
        } else {
          _permissions = {};
        }
        debugPrint('🔑 Loaded Permissions: $_permissions');

        // ✅ Handle Remember Me & Firebase ...
        await _handlePostLogin(username, password, rememberMe);
        return true;
      } else {
        throw Exception('Invalid response from API');
      }
    } catch (e) {
      debugPrint('🔥 Login API Error: $e');
      debugPrint('⚠️ attempting Local DB Login Fallback...');

      // Try Local Login
      final success = await _loginLocally(username, password);
      // If local login success, handle post login
      if (success) {
        await _handlePostLogin(username, password, rememberMe);
      }
      return success;
    } finally {
      _isLoading = false;
      notifyListeners();
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

    // Remove old 'last_username' if exists
    await prefs.remove('last_username');

    // ✅ Login to Firebase (Still using direct auth for now)
    await _loginToFirebase();
  }

  // ✅ Fallback: Login Directly with MySQL (Offline First Capability)
  Future<bool> _loginLocally(String username, String password) async {
    try {
      final db = MySQLService();
      // Query User
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
        // Legacy
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
          // Plain Text Legacy
          isMatch = (dbHash == password);
        }
      } catch (e) {
        debugPrint('⚠️ Local Login: Hash Verification Error: $e');
        // Fallback check
        isMatch = (dbHash == password);
      }

      if (isMatch) {
        debugPrint('✅ Local Login Success: $username');

        // Load Permissions
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
        _permissions = perms;

        // Construct User
        _currentUser = User.fromJson({
          'id': row['id'],
          'username': row['username'],
          'displayName':
              row['displayName'] ?? row['username'], // Fallback if missing
          'passwordHash': dbHash,
          'role': row['role'],
          'isActive': row['isActive'],
          'canViewCostPrice': row['canViewCostPrice'],
          'canViewProfit': row['canViewProfit'],
        });

        _isLoading = false;
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
    _currentUser = null;
    _permissions = {};
    _firebaseService.stopListener();

    // ✅ ลบข้อมูลออกจากเครื่องเมื่อ Logout
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_username');

    notifyListeners();
  }

  // ✅ New helper: Firebase Auth for Cloud Sync
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

  // ✅ Has Permission Check (Strict for Admin as well)
  bool hasPermission(String key) {
    if (_currentUser == null) return false;

    // Check if there is an explicit record in permissions map
    // (This allows Admin to be restricted if the toggle is OFF)
    if (_permissions.containsKey(key)) {
      return _permissions[key] ?? false;
    }

    // Default: Admin has all permissions if not explicitly restricted/allowed
    if (_currentUser!.role == 'ADMIN') return true;

    return false;
  }
}
