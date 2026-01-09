import 'package:flutter/foundation.dart';
import 'mysql_service.dart';
import '../repositories/customer_repository.dart';
import '../repositories/product_component_repository.dart';
import '../repositories/expense_repository.dart';
import '../repositories/billing_repository.dart';
import '../repositories/promotion_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/sales_repository.dart';

class DatabaseInitializer {
  static final MySQLService _db = MySQLService();

  static Future<void> initialize() async {
    debugPrint('🚀 [DatabaseInitializer]: Starting initialization sequence...');

    try {
      // 1. Ensure Connection
      if (!_db.isConnected()) {
        await _db.connect();
      }

      if (!_db.isConnected()) {
        debugPrint(
            '❌ [DatabaseInitializer]: Failed to connect to database. Skipping table init.');
        return;
      }

      // 2. Core Tables (Internal MySQLService)
      debugPrint(
          '📦 [DatabaseInitializer]: Initializing core service tables...');
      await _db.initHeldBillsTable();
      await _db.initOrderPaymentTable();
      await _db.initProductBarcodeTable();
      await _db.initPurchaseOrderTables(); // ✅ PO
      await _db.initUserPermissionTable(); // ✅ Granular Permissions
      await _db
          .initActivityLogTable(); // ✅ Added: Fixes the crash when logging activity
      await _db.initSystemSettingsTable(); // ✅ Global Settings Sync

      // ------------------------------------------------------------------
      // ✅ [AUTO-FIX] ส่วนที่เพิ่ม: ตรวจสอบและเพิ่มคอลัมน์ที่ขาดในตาราง Order
      // ------------------------------------------------------------------
      debugPrint('🔧 [DatabaseInitializer]: Checking & Fixing Order Schema...');
      await _safeInit('Fix Order Columns', () async {
        // 1. เพิ่ม changeAmount (เงินทอน)
        try {
          // ใช้ `order` (มี Backtick) เพราะ order เป็นคำสงวน
          await _db.execute(
              "ALTER TABLE `order` ADD COLUMN changeAmount DECIMAL(15,2) DEFAULT 0.00");
          debugPrint("   ✅ Added column: changeAmount");
        } catch (e) {
          // ถ้ามีอยู่แล้วจะ Error ข้ามไป
        }

        // 2. เพิ่ม deliveryType (ประเภทจัดส่ง)
        try {
          await _db.execute(
              "ALTER TABLE `order` ADD COLUMN deliveryType VARCHAR(50) DEFAULT 'none'");
          debugPrint("   ✅ Added column: deliveryType");
        } catch (e) {
          // Already added
        }

        // 3. เพิ่ม userId (คนขาย)
        try {
          await _db.execute("ALTER TABLE `order` ADD COLUMN userId INT NULL");
          debugPrint("   ✅ Added column: userId");
        } catch (e) {
          // Already added
        }
        // 4. เพิ่ม conversionFactor ใน orderitem (สำหรับหน่วยนับ)
        try {
          await _db.execute(
              "ALTER TABLE orderitem ADD COLUMN conversionFactor DECIMAL(15,4) DEFAULT 1.000");
          debugPrint("   ✅ Added column: conversionFactor to orderitem");
        } catch (e) {
          // Already added
        }
      });

      // ✅ [AUTO-FIX] เพิ่มคอลัมน์ Sale ในตาราง Supplier
      await _safeInit('Fix Supplier Columns', () async {
        try {
          await _db.execute(
              "ALTER TABLE supplier ADD COLUMN saleName VARCHAR(200) NULL");
          debugPrint("   ✅ Added column: saleName");
        } catch (e) {
          // Already exists
        }
        try {
          await _db.execute(
              "ALTER TABLE supplier ADD COLUMN saleLineId VARCHAR(200) NULL");
          debugPrint("   ✅ Added column: saleLineId");
        } catch (e) {
          // Already exists
        }
      });
      // ------------------------------------------------------------------

      // 3. Repository Tables
      // We call them sequentially to avoid "Metadata Lock" issues if they touch same structures
      debugPrint('📦 [DatabaseInitializer]: Initializing repository tables...');

      // Schema Update
      await _safeInit('Branch Columns Update', () => _db.ensureBranchColumns());
      await _safeInit('PO Columns Update',
          () => _db.ensurePurchaseOrderColumns()); // ✅ Added

      // Customer & Tiers (Highest priority as many things depend on customers)
      await _safeInit('Customer Ledger & Tiers',
          () => CustomerRepository().initLedgerTable());

      // Products & Components
      await _safeInit('Products', () => ProductRepository().initTable());
      await _safeInit('Product Components',
          () => ProductComponentRepository().createTableIfNeeded());

      // Sales & Billing
      await _safeInit('Sales (Schema)', () => SalesRepository().initTable());
      await _safeInit('Billing Notes', () => BillingRepository().initTable());

      // Others
      await _safeInit('Expenses', () => ExpenseRepository().initTable());
      await _safeInit('Promotions', () => PromotionRepository().initTable());

      // 5. Performance Indices
      debugPrint('⚡ [DatabaseInitializer]: Optimizing indices...');
      await _safeInit('Product Indices', () async {
        await _ensureIndex('product', 'idx_product_barcode', 'barcode');
        await _ensureIndex('product', 'idx_product_name', 'name');
      });
      await _safeInit('Customer Indices', () async {
        await _ensureIndex('customer', 'idx_customer_phone', 'phone');
        await _ensureIndex('customer', 'idx_customer_name', 'firstName');
      });

      // 4. Data Seeding & Schema Checks
      debugPrint(
          '📦 [DatabaseInitializer]: Running data seeding and schema checks...');
      await _safeInit(
          'Default Admin', () => UserRepository().initializeDefaultAdmin());

      debugPrint('✅ [DatabaseInitializer]: Initialization complete.');
    } catch (e) {
      debugPrint(
          '❌ [DatabaseInitializer]: Fatal error during initialization: $e');
    }
  }

  static Future<void> _safeInit(
      String name, Future<void> Function() action) async {
    try {
      await action();
      debugPrint('   - $name: OK');
    } catch (e) {
      debugPrint('   - $name: FAILED ($e)');
    }
  }

  static Future<void> _ensureIndex(
      String table, String indexName, String column) async {
    try {
      final res = await _db
          .query("SHOW INDEX FROM $table WHERE Key_name = '$indexName'");
      if (res.isEmpty) {
        await _db.execute('CREATE INDEX $indexName ON $table ($column)');
        debugPrint('     + Created index: $indexName');
      }
    } catch (e) {
      // Ignored
    }
  }
}
