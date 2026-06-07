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
import '../repositories/delivery_history_repository.dart';
import '../repositories/fuel_price_repository.dart';
import '../repositories/vehicle_settings_repository.dart';
import '../repositories/reward_repository.dart';

// HR Repositories
import '../repositories/hr/employee_repository.dart';
import '../repositories/hr/attendance_repository.dart';
import '../repositories/hr/leave_repository.dart';
import '../repositories/hr/advance_repository.dart';
import '../repositories/hr/payroll_repository.dart';

class DatabaseInitializer {
  static final MySQLService _db = MySQLService();

  static Future<void> initialize() async {
    debugPrint('🚀 [DatabaseInitializer]: Starting initialization sequence...');

    try {
      // 1. Ensure Connection
      // ✅ Check config first to avoid exception
      if (!await _db.hasConfig()) {
        debugPrint('⚠️ [DatabaseInitializer]: No config found. Skipping init.');
        return;
      }

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
      await _db.initPosCommandsTable(); // ✅ POS Commands (Local Polling)

      // ------------------------------------------------------------------
      // ✅ [AUTO-FIX] ตรวจสอบและเพิ่มคอลัมน์ที่ขาดในตาราง Order
      // ------------------------------------------------------------------
      debugPrint('🔧 [DatabaseInitializer]: Checking & Fixing Order Schema...');
      await _safeInit('Fix Order Columns', () async {
        await _ensureColumn(
            '`order`', 'changeAmount', 'DECIMAL(15,2) DEFAULT 0.00');
        await _ensureColumn(
            '`order`', 'deliveryType', "VARCHAR(50) DEFAULT 'none'");
        await _ensureColumn('`order`', 'userId', 'INT NULL');
        // เพิ่ม conversionFactor ใน orderitem (สำหรับหน่วยนับ)
        await _ensureColumn(
            'orderitem', 'conversionFactor', 'DECIMAL(15,4) DEFAULT 1.000');
      });

      // ✅ [AUTO-FIX] เพิ่มคอลัมน์ Sale ในตาราง Supplier
      await _safeInit('Fix Supplier Columns', () async {
        await _ensureColumn('supplier', 'saleName', 'VARCHAR(200) NULL');
        await _ensureColumn('supplier', 'saleLineId', 'VARCHAR(200) NULL');
      });

      // ✅ [AUTO-FIX] เพิ่มคอลัมน์ isActive ในตาราง Product
      await _safeInit('Fix Product Columns', () async {
        await _ensureColumn('product', 'isActive', 'TINYINT(1) DEFAULT 1');
        await _ensureColumn('product', 'deleteReason', 'TEXT NULL');
        await _ensureColumn('product', 'deletedAt', 'DATETIME NULL');
      });

      // ✅ [AUTO-FIX] เพิ่มคอลัมน์ Soft Delete และ Credit Limit ในตาราง Customer
      await _safeInit('Fix Customer Columns', () async {
        await _ensureColumn('customer', 'isDeleted', 'TINYINT(1) DEFAULT 0');
        await _ensureColumn('customer', 'deleteReason', 'TEXT NULL');
        await _ensureColumn('customer', 'deletedAt', 'DATETIME NULL');
        // ✅ เพิ่ม creditLimit (จำเป็นสำหรับจัดการวงเงินลูกหนี้)
        await _ensureColumn('customer', 'creditLimit', 'DOUBLE DEFAULT NULL');
      });

      // ✅ [AUTO-FIX] เพิ่มคอลัมน์ Void Status ในตาราง Order
      await _safeInit('Fix Order Columns Extra', () async {
        await _ensureColumn('`order`', 'voidReason', 'TEXT NULL');
      });

      // ✅ [AUTO-FIX] เพิ่มคอลัมน์ Soft Delete ในตาราง Debtor Transaction (Universal Soft Delete)
      await _safeInit('Fix Debtor Transaction Columns', () async {
        await _ensureColumn(
            'debtor_transaction', 'isDeleted', 'TINYINT(1) DEFAULT 0');
        await _ensureColumn('debtor_transaction', 'deleteReason', 'TEXT NULL');
        await _ensureColumn('debtor_transaction', 'deletedAt', 'DATETIME NULL');
      });

      // ------------------------------------------------------------------
      // 3. Repository Tables
      // We call them sequentially to avoid "Metadata Lock" issues if they touch same structures
      debugPrint('📦 [DatabaseInitializer]: Initializing repository tables...');

      // Schema Update
      await _safeInit('Branch Columns Update', () => _db.ensureBranchColumns());
      await _safeInit(
          'PO Columns Update', () => _db.ensurePurchaseOrderColumns());

      // ✅ [Partial Receive] Add receivedQuantity
      await _safeInit('PO Items Schema', () async {
        await _ensureColumn('purchase_order_item', 'receivedQuantity',
            'DECIMAL(15,2) DEFAULT 0.00');
      });

      // ✅ [Partial Receive] Update Status ENUM
      await _safeInit('PO Status ENUM Update', () async {
        await _db.execute(
            "ALTER TABLE purchase_order MODIFY COLUMN status ENUM('DRAFT', 'ORDERED', 'RECEIVED', 'CANCELLED', 'PARTIAL') DEFAULT 'DRAFT'");
      });

      // Customer & Tiers
      await _safeInit('Customer Ledger & Tiers',
          () => CustomerRepository().initLedgerTable());

      // Products & Components
      await _safeInit('Products', () => ProductRepository().initTable());
      await _safeInit('Product Components',
          () => ProductComponentRepository().createTableIfNeeded());

      // Sales & Billing
      await _safeInit('Sales (Schema)', () => SalesRepository().initTable());
      await _safeInit('Billing Notes', () => BillingRepository().initTable());
      await _safeInit('Delivery History', () => DeliveryHistoryRepository().initTable());
      await _safeInit('Delivery History Schema', () async {
        // Ensure new columns exist for existing installs
        await _ensureColumn('delivery_history', 'customerPhone', 'VARCHAR(50) NULL');
        await _ensureColumn('delivery_history', 'locationUrl', 'TEXT NULL');
        await _ensureColumn('delivery_history', 'receiptUrl', 'TEXT NULL');
        await _ensureIndex('delivery_history', 'idx_delivery_history_vehicle', 'vehiclePlate');
        await _ensureIndex('delivery_history', 'idx_delivery_history_firebase', 'firebaseJobId');
      });

      // ⛽ Fuel Management Tables
      await _safeInit('Fuel Prices', () => FuelPriceRepository().initTable());
      await _safeInit('Vehicle Settings', () => VehicleSettingsRepository().initTable());

      // Others
      await _safeInit('Expenses', () => ExpenseRepository().initTable());
      await _safeInit('Promotions', () => PromotionRepository().initTable());
      await _safeInit('Rewards', () => RewardRepository().initTable());
      
      // 🧑‍💼 HR & Payroll Tables
      await _safeInit('Employee Profiles', () => EmployeeRepository().initTable());
      await _safeInit('Attendance Logs', () => AttendanceRepository().initTable());
      await _safeInit('Leave Requests', () => LeaveRepository().initTable());
      await _safeInit('Advance Payments', () => AdvanceRepository().initTable());
      await _safeInit('Payroll Records', () => PayrollRepository().initTable());

      await _safeInit('Shift Summary', () async {
        await _db.execute('''
          CREATE TABLE IF NOT EXISTS shift_summary (
            id INT PRIMARY KEY AUTO_INCREMENT,
            openedAt DATETIME NOT NULL,
            closedAt DATETIME NOT NULL,
            closedBy VARCHAR(100) NULL,
            openingCash DECIMAL(15,2) DEFAULT 0.00,
            expectedCash DECIMAL(15,2) DEFAULT 0.00,
            actualCash DECIMAL(15,2) DEFAULT 0.00,
            difference DECIMAL(15,2) DEFAULT 0.00,
            totalSales DECIMAL(15,2) DEFAULT 0.00,
            totalCash DECIMAL(15,2) DEFAULT 0.00,
            totalTransfer DECIMAL(15,2) DEFAULT 0.00,
            totalCredit DECIMAL(15,2) DEFAULT 0.00,
            expenseAmount DECIMAL(15,2) DEFAULT 0.00,
            note TEXT NULL,
            createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      });

      // ✅ Upgrade shift_summary.closedBy from INT to VARCHAR(100) in case it was already created
      await _safeInit('Shift Summary (Schema Upgrade)', () async {
        try {
          await _db.execute('ALTER TABLE shift_summary MODIFY COLUMN closedBy VARCHAR(100) NULL');
        } catch (e) {
          debugPrint('Notice: shift_summary.closedBy modify skipped or not needed: \$e');
        }
      });

      await _safeInit('Promotions (Schema Upgrade)', () async {
        await _ensureColumn(
            'promotion', 'type', "VARCHAR(50) DEFAULT 'simple'");
        await _ensureColumn('promotion', 'start_time', 'VARCHAR(10) NULL');
        await _ensureColumn('promotion', 'end_time', 'VARCHAR(10) NULL');
        await _ensureColumn('promotion', 'days_of_week', 'VARCHAR(20) NULL');
        await _ensureColumn('promotion', 'member_only', 'TINYINT(1) DEFAULT 0');
        await _ensureColumn('promotion', 'priority', 'INT DEFAULT 0');
        await _ensureColumn('promotion', 'conditions', 'JSON NULL');
        await _ensureColumn('promotion', 'rewards', 'JSON NULL');
      });

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

      // ✅ [Line CRM] Add Line User ID Columns
      await _safeInit('Line CRM Columns', () async {
        await _ensureColumn('customer', 'line_user_id', 'VARCHAR(255) NULL');
        await _ensureIndex('customer', 'idx_customer_line_id', 'line_user_id');

        await _ensureColumn(
            'customer', 'line_display_name', 'VARCHAR(255) NULL');
        await _ensureColumn('customer', 'line_picture_url', 'TEXT NULL');
      });

      // 4. Data Seeding & Schema Checks
      debugPrint(
          '📦 [DatabaseInitializer]: Running data seeding and schema checks...');
      await _safeInit(
          'Default Admin', () => UserRepository().initializeDefaultAdmin());

      // 6. ✅ Quick Menu & Barcode Templates (Synced)
      debugPrint('📦 [DatabaseInitializer]: Initializing synced UI tables...');
      await _safeInit('Quick Menu Tables', () async {
        // Page Names
        await _db.execute('''
          CREATE TABLE IF NOT EXISTS quick_menu_page (
            id INT PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
          )
        ''');

        // Items
        await _db.execute('''
          CREATE TABLE IF NOT EXISTS quick_menu_item (
            page_id INT NOT NULL,
            slot_id INT NOT NULL,
            product_id INT NOT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (page_id, slot_id)
          )
        ''');
      });

      await _safeInit('Barcode Template Table', () async {
        await _db.execute('''
          CREATE TABLE IF NOT EXISTS barcode_template (
            id VARCHAR(50) PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            content_json JSON NOT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
          )
        ''');
      });
      debugPrint('🧹 [DatabaseInitializer]: Running auto-cleanup...');
      await _safeInit('Cleanup Recycle Bin', () async {
        await ProductRepository().cleanOldDeletedProducts();
        await CustomerRepository().cleanOldDeletedCustomers();
      });

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

  static Future<void> _ensureColumn(
      String table, String columnName, String columnType) async {
    try {
      // Remove backticks for checking column name in information_schema or SHOW COLUMNS
      // But table might have backticks.
      // Easiest is SHOW COLUMNS
      // 'SHOW COLUMNS FROM `order` LIKE 'changeAmount''
      final res =
          await _db.query("SHOW COLUMNS FROM $table LIKE '$columnName'");
      if (res.isEmpty) {
        await _db
            .execute('ALTER TABLE $table ADD COLUMN $columnName $columnType');
        debugPrint("   ✅ Added column: $columnName to $table");
      }
    } catch (e) {
      // If still fails, log but don't crash
      // debugPrint('   ⚠️ Failed to ensure column $columnName: $e');
    }
  }
}
