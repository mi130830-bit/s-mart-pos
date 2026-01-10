import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../models/user.dart';
import '../repositories/user_repository.dart';
import '../services/firebase_service.dart';
// import '../services/mysql_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  bool _isCheckingAuth = true; // ✅ เช็คสถานะเริ่มต้น (Splash Screen)

  final UserRepository _userRepo = UserRepository();

  final FirebaseService _firebaseService = FirebaseService();
  // final MySQLService _mySQLService = MySQLService(); // ❌ Removed as unused due to background loading

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  bool get isCheckingAuth => _isCheckingAuth; // ✅ Getter สำหรับ main.dart
  bool get canViewCost => isAdmin || (_currentUser?.canViewCostPrice ?? false);
  bool get canViewProfit => isAdmin || (_currentUser?.canViewProfit ?? false);
  bool get isAdmin => _currentUser?.role == 'ADMIN';

  // ✅ Permissions State
  Map<String, bool> _permissions = {};

  // ✅ ฟังก์ชันเช็คสถานะเมื่อเปิดแอป (เรียกจาก main.dart)
  Future<void> tryAutoLogin() async {
    _isCheckingAuth = true;
    notifyListeners();

    // ❌ Disable Auto Login (Bypass) - Always show Login Screen
    // We only simulate a delay or check DB conection if needed
    await Future.delayed(const Duration(milliseconds: 500));

    _isCheckingAuth = false;
    notifyListeners();
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
    debugPrint('🔄 AuthProvider: Starting login...');

    try {
      await _userRepo.ensureAdminExists();
      final user = await _userRepo.login(username, password);

      if (user != null) {
        debugPrint('✅ Login Success: ${user.username}');
        _currentUser = user;
        // Load permissions
        _permissions = await _userRepo.getPermissions(user.id);
        debugPrint('🔑 Loaded Permissions: $_permissions');

        _isLoading = false;

        // ✅ Handle Remember Me
        final prefs = await SharedPreferences.getInstance();
        if (rememberMe) {
          await prefs.setString('saved_username', username);
          await prefs.setString('saved_password', password);
        } else {
          await prefs.remove('saved_username');
          await prefs.remove('saved_password');
        }

        // Remove old 'last_username' if exists to avoid confusion
        await prefs.remove('last_username');

        // ✅ Skip Firebase Listener for now as requested
        // _firebaseService.startJobStatusListener(_mySQLService);

        await _loginToFirebase(); // ✅ Login to Firebase

        notifyListeners();
        return true;
      } else {
        debugPrint('❌ Login Failed: User not found');
        _currentUser = null;
        _permissions = {};
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('🔥 Login Error: $e');
      _currentUser = null;
      _permissions = {};
      _isLoading = false;
      notifyListeners();
      return false;
    }
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

  // ✅ Has Permission Check
  bool hasPermission(String key) {
    if (_currentUser == null) return false;
    if (_currentUser!.role == 'ADMIN') return true; // Admin has all permissions
    return _permissions[key] ?? false;
  }
}
