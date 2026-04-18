import '../services/mysql_service.dart';
import 'package:dbcrypt/dbcrypt.dart';
import '../models/user.dart';
import 'package:flutter/foundation.dart';
// ✅ Import Firebase Admin SDK หรือ Service ที่สร้าง Token (Mock ในที่นี้)
//import '../services/firebase_service.dart';
// import '../state/auth_provider.dart'; // ❌ ลบออก (Unused Import)

class UserRepository {
  final MySQLService _dbService = MySQLService();
  // final FirebaseService _firebaseService = FirebaseService(); // ❌ ลบออก (Unused Field)

  // Deprecated: Admin creation is now handled in InitialSetupScreen.
  Future<void> initializeDefaultAdmin() async {
    // No-op to prevent hardcoding.
    // Logic moved to InitialSetupScreen.
  }

  Future<void> ensureAdminExists() async {
    await initializeDefaultAdmin();
  }

  // --- 1. LOGIN: ตรวจสอบและสร้าง/อัปเดต Firebase Token ---
  Future<User?> login(String username, String password) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    try {
      // 1. Find user by username first
      final sql = 'SELECT * FROM user WHERE username = :user AND isActive = 1;';
      final results = await _dbService.query(sql, {'user': username});

      if (results.isNotEmpty) {
        final userData = results.first;
        final dbHash = userData['passwordHash'].toString();

        // 2. Verify Password
        // Handle legacy plain text (migration support) OR new BCrypt
        bool isValid = false;
        try {
          isValid = DBCrypt().checkpw(password, dbHash);
        } catch (e) {
          // If error (e.g. invalid salt), it might be old plain text?
          // Strict mode: Fail.
          // Legacy fallback for transition:
          isValid = (password == dbHash);
        }

        if (isValid) {
          return User.fromJson(userData);
        }
      }
    } catch (e) {
      debugPrint('Error during login check: $e');
    }
    return null;
  }

  // ✅ เพิ่มฟังก์ชันนี้สำหรับ Auto Login (ดึง User ด้วย username อย่างเดียว)
  Future<User?> getUserByUsername(String username) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    try {
      // Query หา User จาก username โดยไม่ต้องเช็ค password และต้อง Active อยู่
      final sql = 'SELECT * FROM user WHERE username = :user AND isActive = 1;';
      final results = await _dbService.query(sql, {
        'user': username,
      });

      if (results.isNotEmpty) {
        return User.fromJson(results.first);
      }
    } catch (e) {
      debugPrint('Error getting user by username: $e');
    }
    return null;
  }

  Future<List<User>> getAllUsers() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      const sql = 'SELECT * FROM user ORDER BY role, displayName;';
      final rows = await _dbService.query(sql);
      return rows.map((r) => User.fromJson(r)).toList();
    } catch (e) {
      debugPrint('Error fetching users: $e');
      return [];
    }
  }

  Future<bool> createUser(User user) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    // ✅ Secure: Hash password with BCrypt before saving
    final salt = DBCrypt().gensalt();
    final hashedPassword = DBCrypt().hashpw(user.passwordHash, salt);

    final sql = '''
      INSERT INTO user (username, displayName, passwordHash, role, isActive, canViewCostPrice, canViewProfit)
      VALUES (:username, :displayName, :password, :role, :isActive, :canViewCost, :canViewProfit)
    ''';

    await _dbService.execute(sql, {
      'username': user.username,
      'displayName': user.displayName,
      'role': user.role,
      'password': hashedPassword, // Store Hash
      'isActive': user.isActive ? 1 : 0,
      'canViewCost': user.canViewCostPrice ? 1 : 0,
      'canViewProfit': user.canViewProfit ? 1 : 0,
    });
    return true;
  }

  Future<bool> updateUser(User user) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    final sql = '''
      UPDATE user 
      SET displayName = :name, role = :role, isActive = :active, 
          canViewCostPrice = :viewCost, canViewProfit = :viewProfit
      WHERE id = :id
    ''';

    await _dbService.execute(sql, {
      'name': user.displayName,
      'role': user.role,
      'active': user.isActive ? 1 : 0,
      'viewCost': user.canViewCostPrice ? 1 : 0,
      'viewProfit': user.canViewProfit ? 1 : 0,
      'id': user.id,
    });
    return true;
  }

  Future<bool> changePassword(int userId, String newPassword) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    // ✅ Secure: Hash new password
    final salt = DBCrypt().gensalt();
    final hashedNewPassword = DBCrypt().hashpw(newPassword, salt);

    try {
      final sql = 'UPDATE user SET passwordHash = :pass WHERE id = :id';
      await _dbService.execute(sql, {
        'pass': hashedNewPassword,
        'id': userId,
      });
      return true;
    } catch (e) {
      debugPrint('Error changing password: $e');
      return false;
    }
  }

  Future<bool> deleteUser(int id) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      const sql = 'DELETE FROM user WHERE id = :id';
      final res = await _dbService.execute(sql, {'id': id});
      return res.affectedRows.toInt() > 0;
    } catch (e) {
      debugPrint('Error deleting user: $e');
      return false;
    }
  }

  // --- 4. Permissions ---
  Future<Map<String, bool>> getPermissions(int userId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final sql =
          'SELECT permissionKey, isAllowed FROM user_permission WHERE userId = :uid';
      final results = await _dbService.query(sql, {'uid': userId});
      final Map<String, bool> permissions = {};
      for (var row in results) {
        permissions[row['permissionKey'].toString()] =
            (int.tryParse(row['isAllowed'].toString()) ?? 0) == 1;
      }
      return permissions;
    } catch (e) {
      debugPrint('Error getting user permissions: $e');
      return {};
    }
  }

  Future<void> setPermissions(int userId, Map<String, bool> permissions) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      await _dbService.execute('START TRANSACTION;');
      for (var entry in permissions.entries) {
        final sql = '''
          INSERT INTO user_permission (userId, permissionKey, isAllowed)
          VALUES (:uid, :key, :allowed)
          ON DUPLICATE KEY UPDATE isAllowed = :allowed
        ''';
        await _dbService.execute(sql, {
          'uid': userId,
          'key': entry.key,
          'allowed': entry.value ? 1 : 0,
        });
      }
      await _dbService.execute('COMMIT;');
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error setting user permissions: $e');
    }
  }
}
