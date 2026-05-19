# GEMINI.md: POS Desktop Context (Main Program)

## 🌟 AI & Tools Integration
- [x] **Star-Office-UI Integration**: ระบบ File Watcher (`antigravity_sync.py`) เพื่อซิงค์สถานะการทำงานของ Antigravity เข้ากับ UI ออฟฟิศพิกเซล (ใช้งานด้วยคำสั่ง `python antigravity_sync.py` ในโฟลเดอร์ `Star-Office-UI`)

## 🚀 Active Tasks & Delivery System Improvements

### 0. 🌐 Smart Networking & LAN Connectivity (New)
- [x] **DNS-Based Configuration**: เครื่องลูกบันทึก Config ด้วยชื่อเครื่องแม่ (Hostname) แทน IP เพื่อรองรับ Dynamic IP (DHCP)
- [x] **Smart IPv4 Resolution**: ระบบ Resolve Hostname เป็น IPv4 อัตโนมัติขณะ Runtime (กรอง IPv6 ทิ้งเพื่อแก้ปัญหา Timeout)
- [x] **mDNS / .local Support**: รองรับการระบุชื่อเครื่องแบบ `.local` ในวง LAN อัตโนมัติ
- [x] **API URL Auto-Sync**: ระบบหน้า Setup จะบันทึก API URL ตามชื่อ Host ที่ Resolve ได้จริง (เช่น `POS-SERVER.local`)
- [x] **Security Hardening (Self-Healing)**: ยกเลิกการ Fallback กลับไปหา `127.0.0.1` อัตโนมัติหากต่อเครื่องแม่ไม่ติด เพื่อป้องกันความสับสน

### 1. 📱 Line OA Notifications (Verification & Fix)
- [x] **Case 1-5 Validation**: ตรวจสอบการส่งข้อความ/รูปภาพในแต่ละกรณี (Cash, Delivery, Credit, Debt Payment) ให้ถูกต้อง 100%
- [x] **Stage 1 (Preparing)**: แก้ไขให้ระบบส่งข้อความ "กำลังเตรียมสินค้า" ทันทีที่สร้างงานใน Firestore (โดย `DeliveryIntegrationService`)
- [x] **Stage 2 (Shipping) & Stage 3 (Completed)**: ตรวจสอบการทำงานร่วมกับ Cloud Functions

### 2. 🚚 Delivery Workflow Optimization
- [x] **Firestore Auto-Cleanup**: ตั้งค่าให้ลบ Job ใน Firestore อัตโนมัติหลังจากงานเสร็จสิ้น (Stage 3) เพื่อประหยัดพื้นที่และค่าใช้จ่าย Cloud
- [x] **MySQL Archiving**: สร้างระบบบันทึกประวัติการส่งของลงในฐานข้อมูล MySQL ท้องถิ่น (`delivery_history`) ก่อนลบจาก Firestore
- [x] **Excel Export**: พัฒนาระบบดึงข้อมูลจาก MySQL History มาออกรายงาน Excel โดยแยก Sheet ตาม "รถ" และรวมรายชื่อคนขับในช่องเดียวกัน
- [x] **Retry Logic Fix**: ปรับปรุงหน้าประวัติการแจ้งเตือน (Notification Log) ให้รองรับการส่งใหม่ (Manual Retry) สำหรับรูปใบเสร็จโดยการดึงข้อมูลจาก Order จริงมาสร้างรูปใหม่
- [x] **Notification Log Clear**: เพิ่มปุ่มล้างประวัติการแจ้งเตือน (ลบทิ้งไปเฉพาะรายการที่สำเร็จหรือล้มเหลวแล้ว)

### 3. 🛡️ Security Hardening & Integration
- [ ] **API Authentication (JWT Token)**: ⏳ (Plan Drafted - รอทำช่วงเย็นหลังร้านปิด) ปกป้อง API (api.namecheap.work) โดยให้ Desktop ตรวจสอบ JWT จาก S-Link เพื่อขวางการยิงคำสั่งจากผู้ไม่ประสงค์ดี
- [ ] **Firestore Data Encryption**: มีการเข้ารหัสข้อมูลลูกค้า (เบอร์โทร/ชื่อ) ก่อนโยนไปแสดงผลในมือถือ (Firestore)
- [ ] **Conflict Resolution**: วางกระบวนการจัดการข้อมูลกรณีที่เกิดการ Sync สินค้าทับซ้อนกันระหว่าง 2 ระบบ (Desktop - S-Link)

### 4. 📊 Reporting, Analytics & Shift
- [x] **Financial Dashboard Consolidation**: รวมและย้ายหน้ารายงานสรุปบัญชีการเงินเข้ามาเป็นแท็บหลักในหน้า Dashboard พร้อมปรับปรุงสูตรกำไร (Sales - Cost) และแก้ไขทศนิยมยาวในกราฟ
- [x] **Fuel Cost Management (New)**: ระบบจัดการต้นทุนน้ำมันรายวันและรายคัน (กม./ลิตร) พร้อมรายงานสรุปรายเดือน
- [x] **Closing Shift (การปิดกะ)**: สร้างระบบพิมพ์สรุปยอดเงินสด (Drawer Reconciliation) เทียบยอดลิ้นชักกับในระบบ ก่อนดำเนินการปิดร้านสิ้นวัน
- [ ] **Peak Hours Analytics**: เพิ่มกราฟวิเคราะห์ช่วงเวลาที่ลูกค้าแน่นร้าน (Peak Hours) ลงใน Dashboard

### 4.1 🚀 Urgent: Delivery Report Enhancements (เร่งด่วน)
- [x] **Archive All Drivers**: แก้ไข `DeliveryIntegrationService` ให้จัดเก็บชื่อทีมงานทุกคน (คนขับ + เด็กติดรถ) ลงในฟิลด์ `driverName` โดยคั่นด้วยจุลภาค
- [x] **Manual/Auto Sync before Report**: เพิ่มปุ่ม Sync หรือระบบดึงข้อมูลจาก Cloud อัตโนมัติเมื่อเข้าหน้าพรีวิวรายงาน เพื่อให้ได้ข้อมูลล่าสุด (Real-time)
- [x] **Vehicle Plate Normalization**: ปรับระบบจัดกลุ่ม Excel ให้รองรับการตัดช่องว่างและตัวพิมพ์เล็ก/ใหญ่ (Trim & Uppercase) เพื่อไม่ให้ Sheet รถคันเดียวกันแยกจากกัน
- [x] **Interactive GPS Links**: เพิ่มระบบคลิกเปิด Google Maps และปุ่ม Copy Link ในหน้ารายงาน (April 4)
- [x] **Firebase Sync Reliability**: แก้ไขปัญหา [permission-denied] และ Stale Token บน Windows ด้วยระบบ Force Token Refresh (April 4)

### 5. 🔌 Hardware Peripherals
- [ ] **Serial Port Scale**: นำร่องรวบรวมข้อมูลและเชื่อมต่อเครื่องชั่งน้ำหนักดิจิทัลผ่าน Serial COM Port ให้ POS ดึงค่าน้ำหนักเข้าจอขายได้อัตโนมัติ
- [ ] **ESC/POS Native Kick**: ศึกษาและเพิ่มการเตะลิ้นชักใส่เงิน (Cash Drawer Kick) โดยตีผ่านโพรโตคอลคุม ESC/POS ตรง หากลูกค้าไม่ได้ใช้ Printer ผ่าน Driver Windows

### 6. 🌍 Advanced Sync & Offline Capabilities
- [ ] **Offline First for Mobile**: วางแผนทำ Local Cache (SQLite/Isar) ให้ S-Link ฝั่งคนขับ เพื่อให้กดยืนยันตอนไม่มีเน็ตได้ และมีคิว Local Queueing ทยอยเชื่อม
- [ ] **Conflict Detection Strategy**: ใช้ระบบ "Latest Timestamp Wins" คือสั่งบวก/ลบยอดสต็อกแทนเขียนทับ (Overwrite) กรณีขายพร้อมกับหน้าร้านผ่าน Offline
- [ ] **UUID Sync ID Mapping**: เปลี่ยนการใช้เลขที่บิลรันจากมือถือตอนเน็ตหลุดเป็นการ Random UUID เพื่อป้องกัน Primary Key บิลชนกัน (Collision)  
- [ ] **AuditInterceptor for Sync**: สร้างตัว Interceptor ดักทุก State ใน Repository ฝั่ง Mobile แล้วส่งยัดคิว Sync ทันทีหากอินเทอร์เน็ตกลับมาทำงาน

### 7. 🚌 Advanced Analytics & Reporting
- [x] **Consolidated Vehicle Reporting**: ระบบจับคู่รถและทะเบียนแบบ Bidirectional (ชื่อเล่นรถ + ทะเบียน) เพื่อรวมยอดสถิติให้ถูกต้อง (6 คันถ้วน)
- [x] **Excel Sheet Normalization**: หน้ารายงาน Excel รวมยอดสถิติรถแยกตาม Sheet ได้อย่างแม่นยำแม้ชื่อรถใน Job จะต่างกัน

### 8. 🛠️ Bug Fixes & Refinement
- [x] **COD Debt Clearance Verification**: ตรวจสอบและยืนยันการทำงานของระบบตัดชำระหนี้ปลายทาง (COD) จาก S-Link เข้าสู่ระบบ POS Desktop ว่าทำงานถูกต้องตามหลักบัญชี 100% (ลดหนี้, อัปเดตสถานะบิล, และแสดงผลในประวัติการขายโดยไม่เบิ้ลยอด)
- [x] **S-Link Driver Filter**: ยืนยันให้ดึงเฉพาะพนักงานที่มี Role เป็น 'driver' เท่านั้น (ถูกต้องตาม Business Logic แล้ว)
- [ ] **S-Link Requester Visibility**: ตรวจสอบว่าพนักงานถูกตั้ง Role เป็น 'driver' ครบถ้วนหรือไม่ หากรายชื่อว่างเปล่าเลือกรถไม่ได้
- [x] **Fuel Repository Fix**: แก้ไข Bug Named Parameters ใน MySQL Repository ของระบบน้ำมัน
- [x] **Fuel Summary Logic**: ปรับปรุงการคำนวณต้นทุนน้ำมันในรายงานสรุปให้ใช้ราคาน้ำมัน "ณ วันที่ส่ง" แทนราคาปัจจุบัน เพื่อความแม่นยำทางบัญชี 100%

### 🚀 Upcoming: UI Integration
- [ ] เพิ่มปุ่ม "สรุปน้ำมันรายเดือน" ในหน้า Dashboard/Reports ของ POS Desktop
- [ ] เพิ่มระบบ Sync อัตโนมัติสำหรับราคาน้ำมัน (Optional)

---

## 📦 Monolithic Codebase Decomposition Plan (500+ Lines)
แผนพัฒนาปรับปรุงโครงสร้างโค้ดสำหรับไฟล์ที่มีขนาดใหญ่เกิน 500 บรรทัด (ไม่รวมไฟล์ Generated `.g.dart`) เพื่อแยก Domain/UI Section และเพิ่มความง่ายในการรักษาความปลอดภัยและการทำงานในระยะยาว:

### 📂 1. Domain Repositories (Data & Logic Layers)
*   [x] `lib/repositories/stock_repository.dart` (~1,291 lines) - **เร่งด่วนที่สุด** (ควรแยกออกเป็น `StockReceiveRepository`, `StockHistoryRepository`, `StockAdjustmentRepository`)
*   [ ] `lib/repositories/sales_repository.dart` (~1,123 lines) - **เร่งด่วน** (ควรแยกส่วนพิมพ์บิล, สรุปยอดกะ, บันทึกการขาย หรือย้ายเข้า Services)
*   [ ] `lib/repositories/product_repository.dart` (~938 lines) - (ควรแยกการ Sync ข้อมูล, การจัดการคลัง, ข้อมูลสินค้าหลัก)
*   [ ] `lib/repositories/debtor_repository.dart` (~782 lines) - (ควรแยกการจัดการชำระหนี้, ประวัติ Ledger หนี้)
*   [ ] `lib/repositories/customer_repository.dart` (~720 lines) - (ควรแยกฟังก์ชันสมาชิก/แต้มสะสม ออกจากข้อมูลที่อยู่ลูกค้า)

### 🖥️ 2. Large UI Screens & Dialogs (Presentation Layer)
*   [ ] `lib/screens/products/stock_in/pages/stock_in_create_page.dart` (~1,132 lines) - **เร่งด่วน** (ควรดึง Widget ตารางและฟอร์มสร้างใบสั่งซื้อไปเป็น Sub-widgets)
*   [ ] `lib/screens/customers/debtor_list_screen.dart` (~964 lines) - (ควรแยก Tab ชำระหนี้ และ Tab แสดงรายการลูกหนี้)
*   [ ] `lib/screens/reports/delivery_dashboard_screen.dart` (~940 lines) - (แยก Widget แผนที่ Google Maps, สรุปคนขับ และกราฟรายงาน)
*   [ ] `lib/screens/products/widgets/quick_menu_dialog.dart` (~848 lines) - (แยกเมนูทางลัดปุ่มลัดออกเป็น Module)
*   [ ] `lib/screens/products/stock_ledger_views.dart` (~813 lines) - (แยกส่วนตารางประวัติสินค้า และตัวกรอง Filter)
*   [ ] `lib/screens/reports/delivery_report_screen.dart` (~806 lines)
*   [ ] `lib/screens/settings/backup_settings_screen.dart` (~763 lines)
*   [ ] `lib/screens/users/user_management_screen.dart` (~745 lines)
*   [ ] `lib/screens/settings/connection_settings_screen.dart` (~714 lines)
*   [ ] `lib/screens/promotions/reward_management_screen.dart` (~709 lines)
*   [ ] `lib/screens/products/stock_return_section.dart` (~697 lines)
*   [ ] `lib/screens/products/barcode_printing_screen.dart` (~695 lines)
*   [ ] `lib/screens/settings/fuel_management_screen.dart` (~670 lines)
*   [ ] `lib/screens/promotions/promotion_list_screen.dart` (~649 lines)
*   [ ] `lib/screens/pos/pos_payment_panel.dart` (~639 lines)
*   [ ] `lib/screens/products/stock_adjustment_section.dart` (~631 lines)
*   [ ] `lib/screens/products/dialogs/product_form/layouts/product_form_left_column.dart` (~615 lines)
*   [ ] `lib/screens/products/product_import_screen.dart` (~604 lines)
*   [ ] `lib/screens/settings/barcode_designer_screen.dart` (~601 lines)
*   [ ] `lib/screens/pos/payment_modal/controllers/payment_modal_controller.dart` (~590 lines)
*   [ ] `lib/screens/products/master_data_management_screen.dart` (~590 lines)
*   [ ] `lib/screens/settings/barcode_print_setup_screen.dart` (~586 lines)
*   [ ] `lib/screens/dashboard/dashboard_screen.dart` (~576 lines)
*   [ ] `lib/screens/pos/pos_checkout_screen.dart` (~575 lines)
*   [ ] `lib/screens/customers/customer_form_dialog.dart` (~567 lines)
*   [ ] `lib/screens/customers/create_billing_screen.dart` (~564 lines)
*   [ ] `lib/screens/products/stock_in/tabs/purchase_order_history_tab.dart` (~560 lines)
*   [ ] `lib/screens/customer_display/customer_display_screen.dart` (~527 lines)
*   [ ] `lib/screens/pos/pos_cart_list.dart` (~527 lines)
*   [ ] `lib/screens/settings/initial_setup_screen.dart` (~502 lines)

### ⚙️ 3. Core Services & Integrations
*   [ ] `lib/services/firebase_service.dart` (~1,022 lines) - **เร่งด่วน** (แยก Logic การเชื่อมต่อ Realtime Firestore และฟังก์ชันอัปเดต Token)
*   [ ] `lib/services/mysql_service.dart` (~845 lines) - (ควรแยก SQL Queries และ Connection pooling ออกจากกัน)
*   [ ] `lib/services/integration/delivery_integration_service.dart` (~657 lines) - (ควรแยกส่วน Cloud Functions และ Firestore sync)
*   [ ] `lib/services/firestore_rest_service.dart` (~623 lines)