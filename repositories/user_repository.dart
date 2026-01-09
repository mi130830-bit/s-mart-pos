import '../services/mysql_service.dart';
import '../models/user.dart';
import 'package:flutter/foundation.dart';
// ✅ Import Firebase Admin SDK หรือ Service ที่สร้าง Token (Mock ในที่นี้)
//import '../services/firebase_service.dart';
// import '../state/auth_provider.dart'; // ❌ ลบออก (Unused Import)

class UserRepository {
  final MySQLService _dbService = MySQLService();
  // final FirebaseService _firebaseService = FirebaseService(); // ❌ ลบออก (Unused Field)

  // ตรวจสอบและสร้าง Admin คนแรกถ้ายังไม่มี
  Future<void> initializeDefaultAdmin() async {
    if (!_dbService.isConnected()) await _dbService.connect();

    // ตรวจสอบว่ามี user อยู่บ้างไหม
    final result = await _dbService.query('SELECT COUNT(*) as count FROM user');
    if (result.isEmpty) return;

    final count = int.tryParse(result.first['count'].toString()) ?? 0;

    if (count == 0) {
      // สร้าง Admin คนแรก: admin / 1234
      await createUser(
        User(
          id: 0,
          username: 'admin',
          displayName: 'ผู้ดูแลระบบสูงสุด',
          role: 'ADMIN',
          passwordHash: '1234', // ในงานจริงควร Hash
          isActive: true,
          canViewCostPrice: true,
          canViewProfit: true,
          // colorValue: 0xFF3F51B5, // ตัดออกตามที่ตกลง
        ),
      );
      await setPermissions(1, {
        'sale': true,
        'void_item': true,
        'void_bill': true,
        'view_cost': true,
        'view_profit': true,
        'manage_product': true,
        'manage_stock': true,
        'manage_user': true,
        'manage_settings': true,
        'pos_discount': true,
        'open_drawer': true,
        'create_po': true,
        'receive_stock': true,
        'audit_log': true,
        'customer_debt': true,
        // Grandular Settings
        'settings_shop_info': true,
        'settings_payment': true,
        'settings_printer': true,
        'settings_general': true,
        'settings_display': true,
        'settings_system': true,
        'settings_scanner': true,
        'settings_expenses': true,
        'settings_ai': true,
      });
      debugPrint('✅ Default Admin Created & Permissions Seeded');
    }
  }

  // Compatibility alias used by callers expecting ensureAdminExists
  Future<void> ensureAdminExists() async {
    await initializeDefaultAdmin();
  }

  // --- 1. LOGIN: ตรวจสอบและสร้าง/อัปเดต Firebase Token ---
  Future<User?> login(String username, String password) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    try {
      final sql =
          'SELECT * FROM user WHERE username = :user AND passwordHash = :pass AND isActive = 1;';
      final results = await _dbService.query(sql, {
        'user': username,
        'pass': password, // ⚠️ WARNING: ในงานจริงต้องใช้ Hash/Verify
      });

      if (results.isNotEmpty) {
        final localUser = User.fromJson(results.first);
        return localUser;
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

    // ⚠️ Warning: passwordHash is assumed to be plain text for this demo
    // In production, always hash the password before inserting.
    final sql = '''
      INSERT INTO user (username, displayName, passwordHash, role, isActive, canViewCostPrice, canViewProfit)
      VALUES (:username, :displayName, :password, :role, :isActive, :canViewCost, :canViewProfit)
    ''';

    await _dbService.execute(sql, {
      'username': user.username,
      'displayName': user.displayName,
      'role': user.role,
      'password': user.passwordHash,
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
    // ⚠️ WARNING: In production, hash newPassword first!
    try {
      final sql = 'UPDATE user SET passwordHash = :pass WHERE id = :id';
      await _dbService.execute(sql, {
        'pass': newPassword,
        'id': userId,
      });
      // Even if affectedRows is 0 (same password), we consider it a success if no error was thrown.
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
