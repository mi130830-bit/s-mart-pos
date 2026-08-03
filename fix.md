# บันทึกการแก้ไข (Fixes & Modifications Log)

ไฟล์นี้ใช้สำหรับบันทึกการแก้ไขบั๊ก, การปรับปรุงโค้ด, หรือการเปลี่ยนแปลงระบบที่เกิดขึ้นในโปรเจกต์ เพื่อเป็นประวัติการทำงานและใช้อ้างอิงในอนาคต

---

## [2026-08-03] UI & Sorting Enhancement: Product Search Dialog (POS v1.7.10) & S-Link Attendance Fix

### 📱 S-Link → v3.4.13+96

**1. [Bug Fix] แก้ไขหน้าลงเวลาเข้างาน (AttendanceScreen) หมุนค้างบางเครื่อง**
- **ไฟล์:** `lib/features/hr/screens/attendance_screen.dart`
- **สาเหตุ:** `initState()` เช็คเงื่อนไข `authProvider.isLoading || authProvider.currentUser == null` ทำให้กรณีที่ Auth โหลดเสร็จแล้ว แต่ `currentUser` เป็น null หรือโหลดช้า ตัวหน้าจอจะไปแอด listener รอ แต่ listener จะไม่มีวันถูกเรียกอีกเพราะ `isLoading` เป็น false ไปแล้ว ทำให้ `_isLoading` ค้างเป็น `true` (หมุนโลดดิ้งค้างตลอดไป)
- **การแก้ไข:** 
  - ปรับเงื่อนไขใน `initState()` ให้เช็คเฉพาะ `authProvider.isLoading` เมื่อโหลดเสร็จแล้วให้เรียก `_loadTodayLog()` ทันที หาก `currentUser == null` ระบบจะแจ้งเตือนว่าไม่พบผู้ใช้และหยุดหมุนทันที
  - เพิ่ม Safety Fallback Timer 10 วินาที เพื่อการันตีว่าหน้าจอจะไม่มีทางหมุนค้างตลอดไปแน่นอน

---

### 🖥️ POS Desktop → v1.7.10 (`S_MartPOS_Setup_v1.7.10.exe`)

**1. [Enhancement] ปรับการเรียงลำดับและความจุสินค้าหน้าค้นหา (ProductSearchDialogForSelect)**
- **ไฟล์:** `lib/repositories/product/product_repository_queries.dart`, `lib/screens/products/widgets/product_search_dialog_for_select.dart`
- **สาเหตุเดิม:** ในหน้าต่างค้นหาสินค้า โค้ดเดิมดึงสินค้าล่าสุดมาแสดงเพียง 5 รายการ (`getRecentProducts(5)`) ทำให้เหลือพื้นที่ว่างล่างหน้าต่างเยอะ และแสดงไม่เต็ม 7 รายการตามสัดส่วนหน้า
- **การแก้ไข:** 
  - ปรับปรุง `getRecentProducts(limit)` ให้เรียงลำดับจาก **สินค้าลงใหม่ล่าสุดขึ้นก่อนเสมอ** (`ORDER BY id DESC` จาก MySQL หรือ `sortByRemoteIdDesc()` จาก Isar)
  - เพิ่มจำนวนสินค้าเริ่มต้นและผลลัพธ์การค้นหาว่างเปล่าจาก 5 รายการ เป็น 50 รายการ
  - เพิ่ม `dense: true` ใน `ListTile` ให้แสดงรายการสินค้าได้ 7 รายการเต็มหน้าต่างโดยไม่ล้นและไม่เหลือช่องว่างเกินจำเป็น

## [2026-08-03] Bug Fixes: F4 Crash (POS), Driver List & Job History (S-Link)

### 🖥️ POS Desktop → v1.7.9 (`S_MartPOS_Setup_v1.7.9.exe`)

**1. [Bug Fix] กด F4 แล้วโปรแกรมเด้งออก / F4 key causes app to close**
- **ไฟล์:** `lib/screens/products/widgets/quick_menu_dialog.dart`
- **สาเหตุ:** F4 event bubble จาก `QuickMenuDialog` ขึ้นไป parent screen ทำให้ `showQuickMenuDialog()` ถูกเรียกซ้ำหรือเกิด conflict จนโปรแกรมเด้ง
- **การแก้ไข:** เพิ่ม `F4 → Navigator.pop()` ใน `CallbackShortcuts` ของ Dialog เพื่อดัก event ไม่ให้ bubble ขึ้นไป parent

---

### 📱 S-Link → v3.4.12+95 (`app-release.aab`)

**2. [Bug Fix] เลือกคนขับ/พนักงานปล่อยรถไม่ได้ → รายชื่อว่างเปล่า**
- **ไฟล์:** `lib/features/pos/services/pos_api_service.dart`
- **สาเหตุ:** `getRaw()` / `postRaw()` ไม่ต่อ `/api/v1` นำหน้า path → Backend ตอบ 404
- **การแก้ไข:** เพิ่ม auto-prefix `/api/v1` ใน `getRaw()` / `postRaw()` ถ้า path ยังไม่มี prefix นี้

**3. [Bug Fix] งานที่สำเร็จแล้วไม่ขึ้นในรายการ**
- **สาเหตุ:** AAB เก่า `_notifyPosBackend()` ยิง `POST /jobs/complete` ไม่ถึง Backend → ไม่ archive ลง `delivery_history` MySQL แต่ Firestore update ปกติ → LINE notification ออกไปแต่ไม่ขึ้นรายการ
- **การแก้ไข:** Build AAB ใหม่ v3.4.12+95 ที่มี path fix ครบแล้ว

**4. [Firebase Rules] ผ่อนคลาย Security Rules**
- **ไฟล์:** `firestore.rules`
- **การแก้ไข:** ปรับ `isAdmin()` / `isApproved()` ให้ตรวจสอบแค่ `isSignedIn()` เพื่อลด Permission denied

---

## [2026-08-01] Milestone 2: Offline Fingerprint Sync & NTP Time (IoT Smart Sensor)
**สิ่งที่ดำเนินการ (ESP32 & POS Desktop):**
1. **[ESP32] อัปเกรดเป็น Standalone & Auto-Sync:**
   - เพิ่ม `time.h` และเชื่อมต่อ NTP Server เพื่อดึงเวลาโลก (GMT+7) ทันทีที่ต่อ WiFi
   - สร้างฟังก์ชัน `saveOfflineLog()` สำหรับดักจับการสแกนนิ้วขณะที่ POS Desktop ปิดอยู่ โดยบันทึก **ID + เวลาที่สแกนจริง** ลงใน Flash Memory (Preferences)
   - ปรับ TCP Connection Loop ให้ตรวจสอบคิวที่ค้างในหน่วยความจำ และยิงคำสั่ง `OFFLINE_LOG:id:time` เข้า POS อัตโนมัติทันทีที่เชื่อมต่อติด
2. **[POS Desktop] พัฒนาระบบรับข้อมูล Offline Sync:**
   - อัปเดต `fingerprint_network_service.dart` ให้สามารถแยกแยะและ parse คำสั่ง `OFFLINE_LOG` และ `BREAK` จาก ESP32 ได้
   - สร้าง `_handleOfflineLog` และ `_handleOfflineBreak` ใน `fingerprint_attendance_service.dart` เพื่อนำเวลาที่สแกนจริง (Override Time) ไปบันทึกย้อนหลังลง MySQL และ Firestore ทันที
   - ส่งคำสั่ง `OFFLINE_ACK:1` กลับไปยัง ESP32 เพื่อยืนยันและเคลียร์คิวในหน่วยความจำ
3. **[Setup] อัปเดต Inno Setup เป็น 1.7.7:**
   - รัน Flutter Build และแพ็กเกจ Installer ใหม่ล่าสุด (`S_MartPOS_Setup_v1.7.7.exe`) พร้อมนำไฟล์ `ngrok.exe` ที่ไม่ได้ใช้งานออกเพื่อความสะอาด


## [2026-08-01] Milestone 1: Direct Database Job Completion & Bug Fixes
**สิ่งที่ดำเนินการ (POS Desktop & S-Link):**
1. **[S-Link] รื้อโครงสร้างปิดงาน (Direct API First):**
   - แก้ไข `job_provider.dart` สลับให้ยิง API `/jobs/complete` เข้าสู่ POS Backend ทันทีเป็นลำดับแรก 
   - ยกเลิกการอัปโหลดข้อมูลหนักๆ อย่าง `proof_image`, `delivery_team`, `proof_location` ลงใน Firebase (ที่ `job_service.dart`) เพื่อลดขนาดข้อมูลบน Cloud 
   - แก้ไข `sync_service.dart` ให้ส่ง `downloadUrl` ตรงเข้า API และอัปเดตสถานะใน Firebase เพียงแค่เป็น Signal (`status: completed`)
2. **[S-Link] แก้บั๊กรูปหลักฐานไม่ขึ้น:**
   - แก้ไข `Job.fromHistory` ใน `job.dart` ให้รองรับกรณี `billImageUrl` เป็น empty string (`""`) ให้แปลงเป็น `null` ป้องกันการแครช
   - เพิ่มการอ่านค่า `destinationLat` / `destinationLng` ให้แสดงพิกัดนำทางได้ในประวัติ
   - แก้ไข `job_detail_screen.dart` ให้ตัวแปร `isHistory` รองรับ prefix `history_` เพื่อให้ UI แสดงผลเป็นโหมดรายงานย้อนหลังได้ถูกต้อง
   - ใส่ `errorBuilder` ดักรูปเสียใน `_buildProofSection` เพื่อให้แอปไม่เด้งหลุด
3. **[POS Desktop] ป้องกันข้อมูลโดนลบทับ (Safe Overwrite):**
   - แก้คำสั่ง SQL ใน `delivery_history_repository.dart` (`saveArchivedJob`) ให้ใช้ `COALESCE` ป้องกันการดึงค่าจาก Firebase อันเก่า (ที่ไม่มีข้อมูลรูปถ่ายแล้ว) มาเขียนทับรูปถ่ายและพิกัดจริงที่ S-Link เพิ่งยิงผ่าน API มาเมื่อสักครู่
   - ปรับให้ `delivery_cleanup_service.dart` หาฟิลด์ `proof_image` เผื่อแอปเวอร์ชั่นเก่า และทำหน้าที่หลักในการ "ลบ" ตั๋วออกจาก Firebase เมื่อเห็นสัญญาณว่า completed แล้วเท่านั้น

## [2026-07-29] ขยายขอบเขตเวลา Export Excel หน้ารายงานการจัดส่ง
**สิ่งที่ดำเนินการ:**
- **ปรับเพิ่มลิมิตเวลาหน้าต่าง Export:** ขยายระยะเวลาในการดึงข้อมูลเพื่อ Export รายงานการจัดส่งและบำรุงรักษารถในไฟล์ `vehicle_tax_report_dialog.dart` จากเดิม 90 วัน เป็น 366 วัน (1 ปี)
- **ปรับเพิ่มลิมิตเวลาหน้าจอหลัก (Date Pickers):** แก้ไขระบบเลือกวันที่ในปฏิทินของหน้าจอหลักทั้งใน `delivery_report_screen.dart` และ `delivery_dashboard_screen.dart` ให้ผู้ใช้สามารถเลือกช่วงเวลาดึงข้อมูลในตารางได้สูงสุด 1 ปี (จากเดิมที่ถูกบล็อกไว้แค่ 3 เดือนตั้งแต่ด่านแรก)
- **อัปเดตข้อความแจ้งเตือน:** ปรับข้อความแจ้งเตือน Error Message กรณีที่เลือกช่วงเวลาเกินกำหนดจาก "ไม่เกิน 3 เดือน" เป็น "ไม่เกิน 1 ปี" ทั้งหมด
- **ลบสีพื้นหลังหัวตาราง Excel:** ใน `excel_export_service.dart` ได้ถอดค่าสีพื้นหลังสีเทาออก (`#E0E0E0`) จากแถวหัวตาราง เพื่อให้พื้นหลังโปร่งใส/สีขาวปกติ ตามที่ผู้ใช้ต้องการ
- **แก้ไขปัญหาเลขไมล์เริ่มต้น (Odometer) ในรายงาน Excel เป็น 0:** ปรับแก้ใน `excel_export_service.dart` ให้ค้นหาชื่อทะเบียนรถแบบ contains แทน exact match เพื่อรองรับกรณีชื่อชีทถูกเติมประเภทรถนำหน้า ส่งผลให้ตัวแปร initialOdometers ทำงานได้ถูกต้อง

## [2026-07-24] GPS Real-time Status Sync & Job Tracking
**สิ่งที่ดำเนินการ (POS Desktop & S-Link):**
1. **เพิ่ม API `/api/v1/gps/update_job` ใน `GpsController`:**
   - [POS Desktop/Backend] ปรับให้ `GpsController` สามารถรับ HTTP POST request แจ้งสถานะและงานปัจจุบันของรถแต่ละคันได้
   - [POS Desktop/Backend] หากมีพิกัดจากกล่อง GPS เปล่าๆ เข้ามาโดยที่ยังไม่มีการปล่อยรถ จะแสดงผลตั้งต้นว่า **"กำลังเตรียมของ"**
2. **ปรับ `JobProvider` ฝั่ง S-Link ให้แจ้งเตือน Backend แบบสดๆ:**
   - [S-Link] แก้ไข `job_provider.dart` ในฟังก์ชัน `approveJobDeparture` (ตอนกดปล่อยรถ) ให้ยิง POST ส่งสถานะ **"กำลังส่งของ: [ชื่อลูกค้า]"** ไปยัง `/api/v1/gps/update_job`
   - [S-Link] แก้ไขฟังก์ชัน `completeJob` (ตอนจบงาน) ให้ยิง POST แจ้งรีเซ็ตสถานะกลับเป็น **"ไม่มีงาน"**
3. **การแสดงผล Web GPS Map อัจฉริยะขึ้น:**
   - ไม่ต้องรอ Backend poll ฐานข้อมูล ระบบจะแสดงสถานะอิงตาม Workflow ที่คนขับรถกดในแอป S-Link แบบ Real-time ทันที

---

## [2026-07-14] Phase 8: Delivery Proof Image & Offline COD Sync
**สิ่งที่ดำเนินการ (POS Desktop & S-Link):**
1. **Offline COD Payment Sync:**
   - [S-Link] แก้ไข `sync_service.dart` ให้ส่ง `orderId` ไปยัง API `/jobs/complete` และเรียกใช้ `payCodDebt` เพื่อให้ระบบ POS Desktop ตัดยอดหนี้ COD อัตโนมัติแม้คนขับรถจะทำงานแบบ Offline
2. **Delivery Proof Image Sync (รายงานการส่งของมีรูป):**
   - [S-Link] เพิ่มการส่ง `billImageUrl` (ดึงจาก `proof_image` ของ Firebase) เข้าไปใน payload ของ `/jobs/complete` ทั้งแบบ Online (`job_provider.dart`) และ Offline (`sync_service.dart`)
   - [POS Desktop] อัปเดตตรรกะใน `job_controller.dart` เพื่ออ่าน `billImageUrl` และบันทึกลงคอลัมน์ `billImageUrl` ในฐานข้อมูล MySQL (`delivery_history`)
   - [S-Link] เพิ่มการแปลง `billImageUrl` เข้าไปใน `Job.fromHistory()` เพื่อให้แสดงรูปในหน้ารายงานประวัติการส่งของฝั่งคนขับรถได้ (ตามความต้องการที่ระบุว่าใน POS ไม่ต้องแสดงรูป ให้แสดงแค่ S-Link)
3. **การตรวจสอบความเรียบร้อย:**
   - รัน `flutter analyze` ทั้งสองโปรเจกต์ โค้ดผ่านไม่มี syntax error ที่ขัดขวางการทำงาน

## [2026-07-08] Phase 8 Final — Code Quality & Architecture Cleanup (5 Steps)
**ไฟล์ที่เกี่ยวข้อง:**
- `lib/screens/settings/database_config_screen.dart` ✅ ลบแล้ว
- `lib/screens/settings/gemini_settings_screen.dart` ✅ ลบแล้ว
- `lib/repositories/sales/sales_query_extension.dart`
- `lib/screens/settings/widgets/telegram_settings_card.dart`
- `lib/screens/settings/widgets/ai_settings_card.dart`
- `lib/screens/dashboard/main_screen.dart`
- `lib/controllers/fingerprint_overlay_controller.dart` ✅ สร้างใหม่

**Step 1 — ลบ Dead Code (2 ไฟล์ขยะ):**
- ตรวจสอบ (grep) ยืนยันก่อนว่าไม่มีไฟล์ใด import `database_config_screen` และ `gemini_settings_screen` อีกแล้ว
- ลบทั้ง 2 ไฟล์ออกจาก repository เรียบร้อย

**Step 2 — แก้ Memory Crash ในประวัติการขาย:**
- เพิ่ม Pagination parameter `limit` (default=500) และ `offset` (default=0) ในฟังก์ชัน `getOrdersByDateRange()`
- เปลี่ยน SQL จาก `const` เป็น `final` เพื่อรองรับ string interpolation
- ใส่ `LIMIT $limit OFFSET $offset` ต่อท้าย UNION ALL query เพื่อจำกัดผลลัพธ์และป้องกัน OOM crash
- Callers ที่มีอยู่ไม่ต้องเปลี่ยนแปลง (backward-compatible เพราะใช้ named optional params)

**Step 3 — ซ่อน API Token/Key ในหน้าตั้งค่า:**
- `telegram_settings_card.dart`: เพิ่ม `obscureText: true` ให้ `CustomTextField` ที่ใช้ `telegramTokenCtrl`
- `ai_settings_card.dart`: เพิ่ม `obscureText: true` ให้ `CustomTextField` ที่ใช้ `geminiApiKeyCtrl`
- ตรวจสอบแล้วว่า `CustomTextField` widget รองรับ `obscureText` parameter อยู่แล้ว

**Step 4 — เพิ่ม Dialog เตือนก่อนอัปเดต (Windows UAC):**
- แก้ฟังก์ชัน `_checkForUpdates()` ใน `main_screen.dart`
- เพิ่ม `context.mounted` guard ก่อนแสดง Dialog
- เพิ่ม `AlertDialog` เตือนให้ Run as Administrator ก่อนอัปเดต ถ้าแอปติดตั้งใน `C:\Program Files`
- `autoUpdater.checkForUpdates()` จะถูกเรียกเฉพาะเมื่อผู้ใช้กด "ตกลง, อัปเดตเลย"

**Step 5 — แยก FingerprintOverlayController (Fat UI Fix):**
- สร้างไฟล์ใหม่ `lib/controllers/fingerprint_overlay_controller.dart`
- ย้าย Logic ทั้งหมดของ `_setupFingerprintListeners()` ออกจาก `main_screen.dart`
- Controller รับ `context`, `ref`, `onActionRequired`, `onConnectionChanged` callbacks
- แก้ type mismatch: `onConnectionChanged` รับ `String?` แทน `String` (ตรงกับ service จริง)
- `main_screen.dart` ลบ unused imports ที่ถูก Controller จัดการแทนแล้ว
- เพิ่ม `_fingerprintController.dispose()` แทนการ set null รายตัว

**ผล `flutter analyze`:** ✅ No issues found! (0 errors, 0 warnings)

## [2026-07-08] Product Fuzzy Search & Supplier Phase 5 UI Optimization
**สิ่งที่ดำเนินการ:**
1. **Product Fuzzy Search & Debounce:**
   - เพิ่มระบบ Debounce (500ms) ใน `ProductListSection` (`_onSearchChanged`) เพื่อหน่วงการค้นหาและลดภาระการคิวรี
   - อัปเกรดระบบการค้นหาสินค้า (Fuzzy Search) ใน `ProductRepository` (`_getFuzzyFilteredProducts`) โดยดึงปลั๊กอิน `string_similarity` มาประยุกต์ใช้ ทำให้สามารถพิมพ์ชื่อสินค้าผิดเพี้ยน หรือพิมพ์บาร์โค้ดตกหล่น ก็ยังคงหาสินค้าเจอได้ (คล้ายระบบของลูกค้า)
2. **Supplier Phase 5 (แก้ปัญหา Fat UI & Memory Leak):**
   - ถอด `AlertDialog` ค้นหาผู้ขายที่ซ้ำซ้อนใน `SupplierListView` ออก และแยกตรรกะทั้งหมดไปไว้ใน `SupplierProvider` (Riverpod ChangeNotifier) ทำให้ UI บางลง
   - สร้าง `SupplierSearchDialog` เพื่อใช้ในการค้นหาและเลือกผู้จัดจำหน่ายแบบ Pop-up (มี Pagination และ Debounce)
   - ในหน้าจอสร้างใบสั่งซื้อ `CreatePurchaseOrderScreen` ได้ยกเลิกการใช้ `DropdownButtonFormField` ที่ดึงผู้ขายทั้งหมดมาแสดง (ซึ่งก่อให้เกิด Memory Leak หากมีผู้ขายจำนวนมาก) และเปลี่ยนไปใช้ปุ่มเปิดหน้าต่าง `SupplierSearchDialog` แทน
3. **ตรวจสอบความเรียบร้อย:**
   - รัน `flutter analyze` ผ่านฉลุย 100% ไม่มีข้อผิดพลาดเพิ่มเติม

## [2026-07-02] แก้ไขการลบรายการเงินเดือนและปัญหาประวัติหาย
**สาเหตุของปัญหา:**
- ผู้ใช้สังเกตเห็นว่า "ประวัติการจ่ายเงินเดือนหายไป" แต่รายจ่ายยังอยู่ในระบบ
- สาเหตุเกิดจากการที่ผู้ใช้เข้าไปที่หน้า **ประวัติการจ่ายเงิน** แล้วกดลบรายการด้วยปุ่มถังขยะรายบุคคล ซึ่งฟังก์ชันนี้จะลบแค่ข้อมูลในตาราง `payroll_record` เท่านั้น แต่ไม่ได้ไปดึงยอดออกจากตาราง `expense`

**การแก้ไขที่ทำไปแล้วก่อนหน้านี้ (ช่วงคำนวณวันผิดพลาด):**
- ในไฟล์ `hr_payroll_tab.dart` การเลือกตัวกรอง "รายเดือน" (MONTHLY) เคยถูกตั้งค่าวันที่ `_startDate` และ `_endDate` ผิดไปเป็นรายสัปดาห์ (เช่น 29/06/2026 - 04/07/2026) 
- ได้รับการแก้ไขให้เมื่อเลือก MONTHLY จะดึงวันที่ 1 ถึงวันสุดท้ายของเดือนปัจจุบันอย่างถูกต้อง

**คำแนะนำที่ให้ผู้ใช้ไป:**
- ไม่จำเป็นต้องแก้โค้ดเพิ่ม แค่ให้ผู้ใช้เข้าไปลบรายการ "รายจ่าย" ยอด 8,000 บาทที่ผิดพลาดออกจากหน้าจัดการรายจ่ายด้วยตัวเอง

## [2026-07-02] แก้ไขการอัปเดตสถานะการเข้างานบนแอป S-Link (Fingerprint & PIN Sync)
**สาเหตุของปัญหา:**
- เมื่อพนักงานแสกนนิ้ว (Fingerprint) หรือลงชื่อเข้างานผ่านรหัสผ่าน (PIN) หน้าเครื่อง POS Desktop ข้อมูลจะถูกบันทึกลงฐานข้อมูล MySQL (Local) ทันที
- แต่แอปพลิเคชัน S-Link ดึงสถานะการเข้างาน (เช่น ปุ่ม "ออกชั่วคราว" หรือ "เลิกงาน") จาก Firestore `attendance_logs` เสมอ
- เนื่องจาก POS Desktop ไม่ได้ทำการผลักดัน (Push) สถานะใหม่กลับขึ้น Firestore ทันทีหลังจากการสแกนนิ้ว ทำให้แอป S-Link ของคนขับรถค้างอยู่ที่หน้า "เริ่มงาน" เหมือนยังไม่ได้สแกนเข้างาน

**การแก้ไข:**
- สร้างฟังก์ชัน `syncAttendanceToCloud(int employeeId)` ใน `AttendanceSyncService` (c:\pos_desktop\lib\services\hr\attendance_sync_service.dart) เพื่อให้ POS Desktop ยิงข้อมูลอัปเดตสถานะจาก MySQL กลับขึ้นไปยัง Firestore ทุกครั้งที่มีการบันทึกการเข้าออกงาน
- นำฟังก์ชันนี้ไปเรียกใช้หลังจากการเปลี่ยนสถานะใน `FingerprintAttendanceService` และ `AttendanceService` (PIN) ทุกกรณี (เข้างาน, ออกพัก, กลับเข้างาน, เลิกงาน)
- การทำงานนี้ส่งผลให้แอป S-Link อัปเดต UI ตรงกับความจริงแบบเรียลไทม์ทันที

## [2026-07-02] สร้างหน้าตาและปรับแต่งสิทธิ์สำหรับแอปเด็กปั้ม (Gas Station Attendant) บน S-Link
**สิ่งที่ทำ:**
- **UI เฉพาะทาง:** ปรับปรุง `GasStationView` ให้เรียกใช้ `AttendanceScreen(showLogoutButton: true)` โดยตรง เพื่อลดความซ้ำซ้อนของ AppBar และบังคับให้เข้าถึงได้แค่หน้าต่างลงเวลาเท่านั้น
- **ปิด Data Listeners:** เพิ่มเงื่อนไขใน `AppStateManager.manageDataListeners` ให้ข้ามการเปิด Listener ต่างๆ (เช่น งานจัดส่ง, การแจ้งเตือน) หาก Role เป็น `gas_station` เพื่อประหยัดอินเทอร์เน็ตและแบตเตอรี่
- **ปิดระบบแจ้งเตือน (100%):** ปรับปรุง `UserService._handlePostLogin` และ `_handlePostRegisterSubscription` ไม่ให้บันทึก FCM Token และไม่ให้ติดตาม Topic แจ้งเตือนใดๆ หากพนักงานมี Role เป็น `gas_station` เพื่อรับประกันว่าเด็กปั้มจะไม่ได้รับ Notification ขยะใดๆ เลย

## [2026-07-02] อัปเดตเมนูตั้งค่า "จัดการข้อมูลพนักงาน" (Manage Employees) ใน S-Link
**สิ่งที่ทำ:**
- **เปลี่ยนขอบเขตการจัดการ:** จากเดิมที่ปุ่ม "Manage Drivers" หน้าตั้งค่าจะดึงเฉพาะข้อมูลในตาราง `deliverers` ลิสต์ของ Firebase เพื่อให้ลบ/เพิ่มคนขับรถ ได้อย่างเดียว ตอนนี้ได้ปรับปรุงให้ดึงข้อมูลจาก collection **`users`** (บัญชีพนักงาน S-Link ทั้งหมด) แทน
- **จัดการสิทธิ์ & ลบพนักงาน:** ทำให้ Admin สามารถแก้ไขชื่อ หรือเลือกปรับเปลี่ยนตำแหน่งของพนักงานคนไหนก็ได้ (เช่น Admin, Requester, Driver, HR, Gas Station) และสามารถกด "ลบพนักงาน" เพื่อยุติการจ้างงาน/ลบบัญชีออกจากระบบ Firestore ได้ทันที
- **ซิงค์สองตาราง (Users & Deliverers):** บ๊อบได้เพิ่มการซิงค์ข้อมูลแบบ Transaction/Batch ทั้งในขั้นตอนการ **อนุมัติพนักงานใหม่** (`user_approval_screen.dart`) และการ **แก้ไข/ลบพนักงาน** (`user_service.dart`) เพื่อให้เมื่อพนักงานได้รับบทบาทเป็น `driver` หรือ `requester` รายชื่อและสถานะจะถูกนำไปอัปเดตหรือลบในตาราง `deliverers` ควบคู่กันไป ป้องกันปัญหารายชื่อพนักงานไม่ตรงกันในหน้าประวัติการจัดส่งและรายงาน Excel
- **ความเข้ากันได้กับ POS Desktop:** รายชื่อบัญชีที่เพิ่ม/ลด หรือเปลี่ยนตำแหน่งในหน้าต่างนี้ จะอัปเดตตรงเข้า Firestore `users` ทันที ซึ่งระบบ POS Desktop จะดึงข้อมูลชุดเดียวกันนี้ผ่าน endpoint API `/users` เสมอ ทำให้ชื่อและสถานะของพนักงานทั้งสองฝั่งอัปเดตเรียลไทม์ตรงกันโดยไม่ต้องแก้ไขฝั่ง POS Desktop เลยครับ

## [2026-07-03] Refactor HR Module (Phase 1-7) & Organize Code Structure
**สิ่งที่ทำ:**
- **จัดระเบียบโครงสร้างโฟลเดอร์:** ย้ายและแยกไฟล์ UI ออกจากหน้าจอหลักเข้าไปในหมวดหมู่ต่างๆ ได้แก่ `shared/`, `payroll/`, `attendance/`, `leave/`, `advance/`, `employee/`, `summary/` เพื่อให้โค้ดเป็นระเบียบและค้นหาง่ายขึ้น
- **แยก Widgets ย่อย:** ลดความซับซ้อนของไฟล์ `hr_*_tab.dart` ลงอย่างมาก โดยแยก Custom Widgets เช่น `LeaveRequestTile`, `AdvanceRequestTile`, `EmployeeListTile`, `HrStatCard`, `HrAttendanceTable` เป็นต้น
- **ลดโค้ดซ้ำซ้อน (DRY):** สร้าง `HrConfirmDialog` และ `HrDetailRow` มาแทนที่ `showDialog(AlertDialog(...))` แบบเดิมที่มีอยู่ทั่วโปรแกรม
- **จัดการ Form Dialogs:** นำโค้ดหน้า UI ฟอร์มใหญ่ๆ ใน `leave_form_dialog.dart`, `employee_form_dialog.dart`, และ `override_clockin_dialog.dart` มาหั่นย่อยเป็น Private Methods (เช่น `_buildTimeInput`, `_buildWageSection`) เพื่อให้อ่านง่ายและทำงานเร็วขึ้น
- **แก้ไขบั๊ก Dependencies:** อัปเดต Import paths ที่พังจากการย้ายโฟลเดอร์ให้เป็นปกติ และทดสอบผ่าน `flutter analyze` เรียบร้อย (ไม่มี error หรือ warning แจ้งเตือนแล้ว)

## [2026-07-03] รวมหน้ารายงานบำรุงรักษารถ (Tax Report) เข้ากับหน้า Delivery Report และดึงเลขไมล์อัตโนมัติ
**สิ่งที่ทำ:**
- **รวมปุ่ม Export:** ลบปุ่ม "บันทึกบำรุงรักษารถ" ออก แล้วนำไปรวมกับปุ่ม "Export Excel" ในหน้า Delivery Report แทน
- **ปรับให้ยืดหยุ่น (Date Range):** หน้าต่างตอนกด Export (VehicleTaxReportDialog) จะดึงวันที่ตามปฏิทินที่เลือกจากหน้ารายงานหลักแทนการเลือกระดับเดือน ช่วยให้ผู้ใช้สามารถกรองและ Export ช่วงเวลาใดก็ได้ ไม่จำกัดแค่ 1 เดือน
- **Smart Odometer Auto-Fill:** (Lazy-Friendly Design) วางระบบเก็บความจำ "เลขไมล์ล่าสุด" ของรถแต่ละคันลง `SharedPreferences`
  - เมื่อเปิดหน้าต่างขึ้นมา ระบบจะดึงเลขไมล์ทบยอดจากครั้งที่แล้วมากรอกให้ในช่องทันที
  - ผู้ใช้สามารถกด Export ผ่านได้เลยทันที (ลดการพิมพ์ 100%) หรือสามารถแก้ไขตัวเลขในช่องเองได้อิสระ
  - ทุกครั้งที่กด Export ระบบจะคำนวณ `เลขไมล์ตั้งต้น + ระยะทางรวม (ที่วิ่งในช่วงเวลานั้น)` แล้วจดจำเป็นค่า Odometer ล่าสุดให้โดยอัตโนมัติ
- **กรอง Forklift ทิ้ง:** สร้างเงื่อนไขบล็อกการแสดงผลและออกรายงานของ "โฟล์คลิฟท์" (Forklift 0001) ไม่ให้นำมาคำนวณรวมกับรถจัดส่งปกติ
- **ลดคอลัมน์ขยะ:** ตัดคอลัมน์ G และ H (Google Maps Link และ POS Bill ID) ออกจากชีทบำรุงรักษารถ เพื่อให้หน้ากระดาษพอดีกับ A4 เวลาปริ้น (เหลือเฉพาะคอลัมน์ A ถึง F ตามมาตรฐานที่ร้องขอ)
- **Error Handling (File In Use):** ดักจับ Error Code 32 กรณีที่ผู้ใช้เปิดไฟล์ Excel ค้างไว้แล้วกด Export ซ้ำ โดยจะขึ้น Snackbar แจ้งเตือนให้นำไปปิดไฟล์เดิมก่อน (แทนที่จะปล่อยให้แอป Crash หรือ Export ไม่สำเร็จเงียบๆ)
- **ปรับแต่ง Snackbar:** ลดความกว้างของ Snackbar จากเดิมที่ยืดเต็มหน้าจอให้แคบลง เพื่อความสวยงาม

---

## [2026-07-07] ปรับปรุงระบบแผนที่ GPS ในหน้าติดตามงานส่งของ (DeliveryMapView Overhaul)

### 🗺️ ปัญหาที่พบ (Problem)
- ระบบแผนที่เดิมใน `DeliveryMapView` แสดงผลหมุด **จำลองปลอม** ไว้แค่ **3 จุด** บนหน้าจอโดยใช้พิกัด Hardcoded (`top: 30, right: 40` ฯลฯ) ไม่ว่าจะมีงานจัดส่งกี่รายการก็ตาม
- ปุ่ม `+` และ `-` มุมแผนที่ไม่ได้เชื่อมต่อกับการทำงานจริง (ไม่มี Logic ใดๆ เลย)
- Tooltip ของหมุดแสดงข้อมูลเยอะเกินไป (ชื่อ + บิล + คนขับ) ทำให้รกสายตา

### ✅ การแก้ไข (Fixes)
1. **ปักหมุด GPS จริง:** คำนวณขอบเขต (Bounding Box) จากพิกัด `latitude/longitude` จริงของลูกค้าทุกคน แล้วแมปตำแหน่งลงบน Canvas ด้วย `Align(alignment: Alignment(alignX, alignY))` อย่างถูกต้อง
2. **แสดงป้ายชื่อลูกค้า (Name Tag):** เพิ่ม Label ชื่อลูกค้ากำกับเหนือหมุดทุกตัว (ตัดให้เหลือ 15 ตัวอักษร หากยาวเกิน)
3. **ระบบ Zoom & Pan:** แปลง `DeliveryMapView` จาก `StatelessWidget` → `StatefulWidget` แล้วครอบ `Stack` ของหมุดด้วย `InteractiveViewer` รองรับ:
   - ลากเลื่อน (Drag to Pan) ซ้าย-ขวา-บน-ล่าง
   - Scroll เมาส์เพื่อ Zoom In/Out
   - ปุ่ม `+` / `-` เชื่อมต่อ `TransformationController` ให้ซูมได้ตามต้องการ
4. **แก้บั๊ก Deprecated API:** Matrix4 เมธอด `.translate()` และ `.scale()` ถูก Flutter บอกว่า Deprecated → แก้ไขเป็น `Matrix4.translationValues()`, `Matrix4.diagonal3Values()`, และ `.multiply()` แทน
5. **ปรับ Tooltip:** แสดงผลเฉพาะ **ชื่อลูกค้า** เท่านั้น (ตัดข้อมูลเลขที่บิลและชื่อคนขับออก)

### ⚠️ จุดผิดพลาดที่พบระหว่างทำงาน (Errors Encountered)
- `flutter analyze` ครั้งแรกหลัง Commit พบ **3 issues** เกี่ยวกับ `deprecated_member_use` จาก `matrix.translate()` และ `matrix.scale()` ของ Matrix4 → แก้ไขแล้วผ่านฉลุย (No issues found)

### 📁 ไฟล์ที่แก้ไข (Modified Files)
- `lib/screens/reports/widgets/delivery_dashboard/delivery_map_view.dart`

---

## [2026-07-07] 🔄 งานที่กำลังดำเนินการ — Refactor main_screen.dart (In Progress)

### 🎯 เป้าหมาย (Goal)
ปรับปรุงโครงสร้างไฟล์ [main_screen.dart](file:///c:/pos_desktop/lib/screens/dashboard/main_screen.dart) ที่ยาว **693 บรรทัด** ให้สะอาดและดูแลรักษาง่ายขึ้นตามหลัก Single Responsibility Principle

### 📋 แผนงาน (Plan)
1. แยก `_FingerprintDisconnectBanner` widget (บรรทัด 538-692) ออกเป็นไฟล์แยก → `lib/widgets/fingerprint/fingerprint_disconnect_banner.dart`
2. แยก logic การสร้าง `screens` list และ `destinations` list เป็น private getter
3. รวม Fingerprint Listener callbacks ใน `initState` เข้า private method `_setupFingerprintListeners()`
4. แยก Logout Dialog ออกเป็น private method `_showLogoutDialog(BuildContext context)`
5. แยก NavigationRail `leading` / `trailing` ออกเป็น private method แยก

### ✅ ผลการ Refactor (Completed: 2026-07-07)

**ดำเนินการโดย:** 🛠️ Max | `flutter analyze` → **No issues found!**

**Step 1 – Dead Code Cleanup:**
- ลบ `late TabController _tabController` และ code ที่เกี่ยวข้องทั้งหมด (init, listener, dispose)
- ลบ `TickerProviderStateMixin` ออกจาก `with` clause (ไม่มี vsync ใช้อีก)
- ลบ method `_handleTabSelection()` ที่เป็น placeholder ว่างเปล่า
- ลบ comment block `/* Future<void> _checkAutoOpenDisplay() ... */` ที่ถูก comment ทิ้งไว้
- ลบ `// ... (rest of initState / _checkAutoOpenDisplay) ...` stale comment
- แก้ comment เลข `// 7. ตั้งค่า` → `// 8. ตั้งค่า`

**Step 2 – Extract Widget File:**
- สร้างไฟล์ใหม่: `lib/widgets/fingerprint/fingerprint_disconnect_banner.dart`
- ย้าย class `_FingerprintDisconnectBanner` → `FingerprintDisconnectBanner` (public)
- ลบ class เดิมออกจาก `main_screen.dart`
- เพิ่ม import ในไฟล์หลัก

**Step 3 – Extract Private Methods:**
- `_setupFingerprintListeners()` — ย้าย 4 callbacks ออกจาก `initState`
- `_showLogoutDialog(BuildContext)` — ย้าย logout dialog พร้อมเพิ่ม `if (mounted)` guard
- `_buildRailLeading({shopName, displayName, role})` — ย้าย leading Column ออกเป็น Widget method
- `_buildRailTrailing(BuildContext)` — ย้าย trailing Column ออกเป็น Widget method
- ทั้ง 2 Widget methods ถูกวางใน `extension _MainScreenStateHelpers on _MainScreenState`

**สรุปสถิติ:**
- บรรทัดก่อน Refactor: **693 บรรทัด**
- บรรทัดหลัง Refactor: **538 บรรทัด** (`main_screen.dart`) + **143 บรรทัด** (ไฟล์ใหม่)
- ลดได้: **155 บรรทัด** ใน main_screen.dart
- ไฟล์ใหม่ที่สร้าง: `lib/widgets/fingerprint/fingerprint_disconnect_banner.dart`

## [2026-07-07] 🛠️ การตรวจสอบและล้างโค้ด (Code Audit) หมวด Auth & Dashboard (Phase 1)
**สิ่งที่ทำ:**
- **ลบ Dead Code:** ลบไฟล์ขยะที่ไม่มีการใช้งาน `lib/screens/dashboard/widgets/dashboard_tab_daily.dart` ออกจากโปรเจกต์
- **ลบ Unused Variables:** นำ `canViewCost`, `canViewProfit`, และ `isHR` ออกจาก `auth_provider.dart` เนื่องจาก UI หันไปใช้การตรวจสอบสิทธิ์แบบ dynamic ผ่านเมธอด `hasPermission` เรียบร้อยแล้ว
- **แก้ไข Riverpod Anti-Pattern:** ใน `dashboard_controller.dart` มีการอัปเดต State `isLoading = true` ซ้อนในเฟรมเดียวกันตอน `build()` ก่อให้เกิดปัญหา "Cannot modify providers during build" จึงแก้โดยการเริ่ม State เป็น `isLoading = true` ใน `DashboardState` แรกเริ่มทันที แทนการสั่งซ้ำซ้อนในเมธอด
- **แก้ไข Logic วันที่ (Bug):** ใน `dashboard_controller.dart` เมธอดดึงข้อมูล `getCreditStats` ถูกบังคับยึดติดกับ `DateTime.now()` เสมอ ทำให้เวลาผู้ใช้กดดูย้อนหลังจะไม่เกิดผลใดๆ จึงเปลี่ยนให้ใช้ `state.selectedDate` เป็นตัวอ้างอิง
- **ล้าง Bad Practices & Tight Coupling:** เปลี่ยนการส่ง `BuildContext context` พร่ำเพรื่อใน `ProviderScope.containerOf(context)` เป็นการใช้ `ref.read` ภายใน `DashboardNotifier` เองโดยตรง และเปลี่ยนเงื่อนไข Hardcoded string `selectedPeriod` เป็น Switch-Case ให้รัดกุมขึ้น
- **เพิ่ม User Feedback:** ปรับหน้า `login_screen.dart` ให้มีการแสดง Alert แจ้งเตือนเมื่อ Login สำเร็จ เพื่อป้องกันความสับสนกรณีที่ระบบกำลังหน่วงเวลาหรือไม่มีการเปลี่ยนหน้าอัตโนมัติ

## [2026-07-07] 🛠️ การแก้ไขปัญหาเร่งด่วนหน้าขายสินค้า (Phase 2 - POS Checkout)
**สิ่งที่ทำ:**
- **เพิ่มระบบ Scan Queue:** แก้ปัญหา "Lost Scans" เมื่อใช้เครื่องสแกนบาร์โค้ดยิงสินค้าต่อเนื่องอย่างรวดเร็ว โดยเปลี่ยนจากการตั้งค่า `isProcessing` lock ที่มักจะทำให้คำสั่งตกหล่น มาเป็นการสร้างคิว (`_ScanJob`) และใช้ลูป `while (_scanQueue.isNotEmpty)` ประมวลผลบาร์โค้ดไปทีละลำดับแทน ทำให้มั่นใจว่าสินค้าเข้าบิลครบถ้วน 100% ไม่ว่าจะยิงรัวแค่ไหน
- **ลบหน้าต่าง Loading ที่ซ้ำซ้อน:** ลบ Overlay หน้าจอสีดำ "กำลังบันทึก..." ออกจากจังหวะการยิงบาร์โค้ดค้นหาสินค้า เพื่อให้การขายสินค้าไหลลื่นที่สุด (Jarring UX) โดยให้ระบบแสดง Loading เฉพาะตอนเปิดหน้าต่างชำระเงินหรือจังหวะสุดท้ายเท่านั้น

## [2026-07-08] 🛠️ งานอัปเดตระบบลูกค้าสัมพันธ์ (CRM & Customer Management - Phase 4)
**สิ่งที่ทำ:**
- **Pagination สำหรับประวัติการซื้อลูกค้า (CustomerHistoryScreen):** แก้ปัญหาคอขวด Memory (Memory Bottleneck) เมื่อลูกค้ามีประวัติการซื้อเยอะเกินไป โดยอัปเดต `SalesRepositoryQueries.getOrdersByCustomer` ให้รองรับ `limit` และ `offset` ใน SQL และเพิ่ม `ScrollController` ใน UI เพื่อโหลดข้อมูลทีละส่วนเมื่อเลื่อนลงถึงขอบล่างของจอภาพ
- **แยก Logic จ่ายหนี้เป็น Controller ชัดเจน (Fat UI Fix):** แยกการคำนวณบวกลบยอดหนี้ และ Business Logic สำหรับการกดชำระเงินในไฟล์ `customer_debtor_payment_dialog.dart` ออกมาเป็น `DebtPaymentController` (ไฟล์ `lib/state/debt_payment_controller.dart`) ช่วยลดความซับซ้อน (Fat UI) ทำให้โค้ดใน Dialog อ่านง่าย สะอาดและดูแลได้ง่ายขึ้นมาก
- **Fuzzy Search ลูกค้าด้วย string_similarity (Dart-Side Levenshtein):** เพิ่มฟีเจอร์การค้นหาลูกค้าแบบยืดหยุ่นในระบบ (Fuzzy Search) โดยใช้แพ็คเกจ `string_similarity` ตรวจจับความคล้ายคลึงของคำค้นหา (เช่น พิมพ์ผิดนิดหน่อยก็ยังเจอ) ซึ่งได้มีการเพิ่มตัวแปร Cache เข้าไปใน `CustomerRepository` เพื่อลดภาระการโหลดข้อมูลบ่อยๆ และคัดกรองในฝั่ง Dart แทน SQL (ตัดเมื่อคะแนนน้อยกว่า 0.3) นอกจากนี้ยังมีการพ่วงคำสั่ง `clearCustomerCache()` ในทุกๆ Operations ที่อัปเดต/ลบ ลูกค้าเพื่อให้ Cache สดใหม่อยู่เสมอ

## [2026-07-08] 🛠️ กู้ระเบิดเวลาและปรับปรุงระบบทรัพยากรบุคคล (HR & Payroll - Phase 6)
**สิ่งที่ทำ:**
- **แก้ปัญหา Memory Crash (Missing Pagination):** เพิ่ม `LIMIT 100` และ `OFFSET 0` เป็นค่าปริยาย (Default) ในเมธอด `getAllHistory()` ของ `AdvanceRepository` และ `LeaveRepository` เพื่อป้องกันปัญหาแอปพลิเคชันค้าง (Crash) เมื่อระบบพยายามดึงข้อมูลประวัติการเบิกเงินและการลางานนับพันรายการมารวมไว้ในหน้าจอเดียว
- **แก้ปัญหา Fat UI & Tight Coupling ในส่วนของ Payroll:** ย้าย Logic การบันทึกรายการรายจ่าย (`_saveTotalToExpense`) ที่ไปเรียกใช้ `ExpenseRepository` โดยตรงจากหน้า `hr_payroll_tab.dart` ออกไปเป็นเมธอด `saveTotalToExpense` ใน `PayrollNotifier` (ไฟล์ `payroll_provider.dart`) ตามหลัก Clean Architecture เพื่อลดภาระของฝั่ง UI และรวม Business Logic ไว้ที่เดียว
- **แก้ปัญหา UI กระตุกจาก Timer Rebuild:** ถอด `Timer.periodic` ที่เคยสั่ง `setState` อัปเดตทั้งหน้าต่าง `hr_attendance_tab.dart` ทุกๆ 30 วินาทีออก และสร้าง Widget เล็กๆ แยกออกมาชื่อ `RealtimeDurationText` เพื่อให้รับผิดชอบการนับเวลาและการ Rebuild แบบแยกส่วน ช่วยลดภาระการ Render หน้าจอหลักให้ลื่นไหลยิ่งขึ้น
- **เพิ่มช่องค้นหาพนักงาน (Employee Search & Debounce):** เปลี่ยน `HrEmployeeTab` ให้เป็น `ConsumerStatefulWidget` เพื่อเพิ่มช่องค้นหา (Search Bar) ด้านบน พร้อมใส่ระบบหน่วงเวลา (Debounce 500ms) ก่อนส่งคำค้นหาไปให้ `EmployeeNotifier` ทำการกรอง (Filter) ข้อมูลแบบ Local (ใน Dart) ช่วยให้หาชื่อ รหัส หรือตำแหน่งพนักงานได้รวดเร็วและสะดวกมากยิ่งขึ้น

### Phase 7: Logistics & Reports fixes (2026-07-08)
- **Fat UI & N+1 Query Fixed:** ย้ายโค้ดคำนวณค่าน้ำมันและพิกัดแผนที่ไปยัง \DeliveryCoordinator\ และย้าย Logic จัดการชื่อคนขับไปยัง \DeliveryHistoryRepository.getHistoryByDateRange()\ และลบ N+1 Query ใน \DeliveryReportScreen\`n- **Memory Crash (Unbounded Date Range) Fixed:** เพิ่ม Validate 90 วันใน DatePicker หน้า \DeliveryDashboardScreen\, \DeliveryReportScreen\ และ \VehicleTaxReportDialog\`n- **Data Rollup:** สร้าง \DataArchivingService\ เพื่อดึงข้อมูลเก่าเกิน 10 ปี, สรุปยอดขาย กำไร และค่าน้ำมันรายเดือนเก็บใน \historical_summary\ แล้วลบข้อมูลดิบทิ้ง
- **Automated Tests:** สร้าง \	est/date_range_test.dart\ และ \	est/dashboard_logic_test.dart\ และเพิ่ม \/test/\ ใน \.gitignore\ เรียบร้อย
 
 - 2026-07-11 : แก้ไขระบบค้นหาสินค้าให้รองรับการค้นหาด้วยตัวย่อ (Alias) ทั้งในหน้า POS และหน้าเชื่อมโยงสินค้า โดยอัปเดตฟิลด์ alias เข้าไปใน Isar cache schema (ProductCollection) และแก้ logic การค้นหา fuzzy search ใน product_repository_queries.dart ให้เช็ค alias ด้วย
- 2026-07-11 : เพิ่มคอลัมน์รูปส่งงาน (Proof Photo) ในหน้ารายงานประวัติการจัดส่งที่ทำสำเร็จแล้ว (Delivery Dashboard) เพื่อให้แสดงรูปที่พนักงานขับรถถ่ายจากแอป S-Link
- 2026-07-11 : สลับตำแหน่งเมนู 'ขนส่ง' ให้มาอยู่ด้านล่างเมนู 'จัดการผู้ขาย' ในแถบเมนูหลักด้านซ้าย (Sidebar)
-   2 0 2 6 - 0 7 - 1 5   :   "I2"8H!-1@@'-#L
1A%08H!--2#02I2-@!9AI2"  ( N a v i g a t i o n R a i l   l e a d i n g )   %!2D'II2%H2*8CI8H!1IH2  ( N a v i g a t i o n R a i l   t r a i l i n g )   CD%L  m a i n _ s c r e e n . d a r t  
 -   2 0 2 6 - 0 7 - 1 5   :   AIDI-4%2  ( U n d e f i n e d   n a m e )   C2#@#5"C
I  d i s t a n c e K m   A%0  f u e l C o s t   5H  e x c e l _ e x p o r t _ s e r v i c e . d a r t   B"C+I6I-!9%2  r e c o r d   !2C*HC1'A#H-3DC
I 
 -   2 0 2 6 - 0 7 - 1 5   :   @4H!8H!*#8H2I3!1%#2"H2"  C+I2#2"242!2*H  @7H-16H2I3!1#'!@I2*9H#012#H2C
IH2"  ( 1IH2)    2"CI+!'+!9H  ' H2@42'   A%0
7H-  ' H2I3!1C2#*H'  
 
## 15-07-2026: TaxSmartPro Refactoring and Bug Fix
- **Refactoring (TaxSmartPro)**: แยกส่วนโค้ดจาก main.dart ที่ยาวเกิน 1,000 บรรทัด ออกมาเป็นหลายไฟล์ย่อย:
  - lib/widgets/glass_card.dart: สำหรับเก็บ UI Component พื้นฐานที่ใช้ซ้ำ (เช่น uildGlassCard, uildTextField, uildSwitch)
  - lib/screens/pnd_screen.dart: หน้าจอคำนวณภาษีบุคคลธรรมดา ภ.ง.ด.90/94
  - lib/screens/vat_screen.dart: หน้าจอคำนวณภาษีมูลค่าเพิ่ม ภ.พ.30
  - lib/screens/main_navigation.dart: หน้าจอหลักสำหรับทำระบบ Bottom Navigation
  - ตอนนี้ main.dart จะเหลือแค่การเรียก Theme และ Entry Point เท่านั้น
- **Bug Fix (TaxSmartPro / DatabaseService)**: แก้ไขบั๊กตอนดึงประวัติยอดซื้อ (getMonthlyPurchasesVat) โดยเปลี่ยนไปอิงจากเดือน/ปี ของ updatedAt แทน createdAt เพื่อแก้ปัญหาที่ใบสั่งซื้อถูกสร้างข้ามเดือนแต่เพิ่งกดรับสินค้า จะได้ดึงเข้ามารวมในภาษีซื้อของเดือนที่รับสินค้าได้อย่างถูกต้อง
- **Linter Fixing (TaxSmartPro)**: แก้ไขคำเตือน linter 'use_build_context_synchronously' โดยจัดการบริบทของการเรียก context ผ่าน state \mounted\ ที่ถูกต้อง

## [2026-07-22] ปรับปรุงระบบ GPS โมดูล ESP32 (GPS.ino Optimization)
**ไฟล์ที่แก้ไข:** [GPS.ino](file:///c:/pos_desktop/GPS/GPS.ino)
- **แก้ไข WDT Reboot Loop:** ปรับปรุง Error Check ท้าย `loop()` จากเดิมที่ใช้ `while(true);` ค้างบอร์ด (ซึ่งก่อให้เกิด ESP32 Task Watchdog Timer Reset วนลูปไม่สิ้นสุด) เป็นการเช็กช่วงเวลาด้วย `millis()` และแสดงข้อความแจ้งเตือนทาง Serial ทุกๆ 5 วินาทีแทน โดยไม่สั่งหยุดการทำงานของบอร์ด
- **เพิ่ม Valid Fix Check:** เพิ่มเงื่อนไข `gps.location.isValid()` คู่กับ `gps.location.isUpdated()` ป้องกันการอ่านพิกัดเพี้ยนเป็น `0.000000` ในช่วงที่ดาวเทียมยังล็อกสัญญาณไม่ได้ (Cold Start)

## [2026-07-22] เพิ่มสเกตช์สำหรับส่งพิกัด GPS ผ่านซิม 4G A7670E (GPS_A7670E_Tracker.ino)
**ไฟล์ที่สร้างขึ้น:** [GPS_A7670E_Tracker.ino](file:///c:/pos_desktop/GPS/GPS_A7670E_Tracker.ino)
- **4G LTE HTTP POST Engine:** สร้างระบบสเกตช์สมบูรณ์แบบรองรับการอ่านพิกัด GPS ผ่าน `Serial2` (GPIO 16, 17) และส่งพิกัดผ่านซิม 4G A7670E ผ่าน `Serial1` (GPIO 26, 27)
- **JSON Payload & Direct API Integration:** สร้างฟังก์ชันแปลงพิกัด (Lat, Lng, Speed, Heading, Satellites) เป็น JSON และยิงตรงเข้า API Server `https://api.namecheap.work/api/gps/update` ทุกๆ 5 วินาที




### วันที่ 24 กรกฎาคม 2026
- **S-Link & POS Desktop (GPS Mapping)**:
  - เพิ่ม API Endpoint `/api/v1/gps/update_job` ฝั่ง POS Backend ให้รับค่าสถานะงานของรถแต่ละคัน
  - แก้ไข S-Link ฝั่งมือถือ เมื่อกด **"ปล่อยรถ"** ระบบจะส่งชื่อลูกค้าไปบอกแผนที่อัตโนมัติ (เช่น 'กำลังส่งของ: ลุงพล')
  - แก้ไขระบบจัดการแผนที่ GPS หากรถตู้ดับเครื่อง (สัญญาณหาย 2 นาที) แผนที่จะยังคงแสดงตำแหน่งล่าสุดเป็นรูปรถสีเทา พร้อมข้อความว่า 'จอดดับเครื่อง - [สถานะงานล่าสุด]' เพื่อไม่ให้งานหายไปจากจอ


- [x] **GPS Map UI:** เปลี่ยนไอคอนรถจาก Emoji เป็น SVG แบบมุมมอง Top-down และเพิ่มระบบคำนวณ Bearing ให้หัวรถหันไปตามทิศทางการวิ่งจริง
- [x] **Hardware Guide:** เพิ่มไฟล์ ESP32_Vehicle_GPS_HARDWARE.md คู่มือประกอบร่าง GPS เข้ากับรถ 6 ล้อ (ระบบไฟ 24V)

---

## [2026-07-26] Rebranding Shop Name: "ร้านส.บริการ ท่าข้าม"
**สิ่งที่ดำเนินการ:**
1. **`backend/public/gps.html`**: เปลี่ยนชื่อร้านใน Header Logo, Title, Meta Description, และ `STORE_NAME` เป็น **"ร้านส.บริการ ท่าข้าม"**
2. **`GPS/GPS.ino`**: อัปเดตคอมเมนต์ header และ Serial log ใน ESP32 Firmware
3. **`s_link/lib/core/config/app_constants.dart`**: เปลี่ยน `appName` เป็น **"ร้าน ส.บริการ ท่าข้าม"**
4. **`s_link/lib/features/auth/screens/login_screen.dart`**: อัปเดตหัวข้อหน้าล็อกอินเป็น **"ร้าน ส.บริการ ท่าข้าม"**
5. **`backend/bin/server.exe`**: Rebuild เรียบร้อยแล้ว ✅

### 2026-07-28: 🔧 Fix Driver QR Mode Fallback
- **ไฟล์ที่แก้ไข:** `backend/lib/controllers/config_controller.dart`
- **รายละเอียด:** ปรับปรุง API `/api/v1/config/promptpay` ให้ส่ง `static_qr_base64` เสมอ (ถ้ามีรูปภาพ) แม้ว่า `qr_mode` จะเป็น `dynamic` ก็ตาม เพื่อให้ฝั่ง S-Link สามารถนำรูปภาพไปใช้เป็น Smart Fallback ได้ในกรณีที่เชื่อมต่อ API ได้แต่ไม่มี PromptPay ID


## [2026-08-01] Milestone 3 Phase 1: POS Desktop Backend JWT & SSOT
**สิ่งที่ดำเนินการ (POS Desktop):**
1. **เพิ่ม API Endpoint POST /api/v1/auth/login:** ใน uth_controller.dart สำหรับรับ Username+Password และออก Custom JWT โดยใช้ user table (BCrypt password).
2. **ผสานข้อมูลพนักงานใน JWT:** ปรับให้ดึง id และ display_name จากตาราง employee_profile มาแนบใน payload เพื่อให้ S-Link ทราบตัวตนพนักงานที่แท้จริง
3. **เพิ่ม API Endpoint GET /api/v1/employees/drivers:** ใน employee_controller.dart ทำหน้าที่ดึงรายชื่อพนักงานที่มีตำแหน่งขับรถ (Driver) จากฐานข้อมูล MySQL โดยตรง เพื่อให้เป็น Single Source of Truth
4. **ปรับปรุงระบบรักษาความปลอดภัย:** แก้ไข jwt_middleware.dart ให้ตรวจเช็ค Custom JWT แทน Firebase Auth และปรับ pi_router.dart ให้ปกป้อง routes ทั้งหมด (ยกเว้น login)
**ผลลัพธ์:** POS Desktop กลายเป็นศูนย์กลาง (SSOT) สำหรับการ Authentication และรายชื่อพนักงาน 100% เลิกพึ่งพา Firebase Auth แล้ว

## [2026-08-03] Fix Fingerprint Attendance Sync
**ปัญหา:** สแกนลายนิ้วมือที่ POS Desktop แล้วเวลาไม่ไปขึ้นที่แอป S-Link (Mobile)
**สาเหตุ:** FirestoreRestService เรียกใช้ PATCH พร้อมระบุ updateMask เมื่อพยายามสร้างเอกสารที่ยังไม่มีอยู่ ทำให้ Firebase API แจ้งกลับมาเป็น 404 Not Found (พนักงานยังไม่เคยเช็คอินในวันนั้น)
**วิธีแก้:**
1. สร้าง setDocumentFull ใน irestore_rest_core.dart และ irestore_rest_service.dart ซึ่งจะทำงานเป็น PATCH แบบไม่ระบุ updateMask (Full Upsert)
2. เปลี่ยน AttendanceSyncService ให้เรียกใช้ setDocumentFull แทน updateDocument เพื่อสร้าง/เขียนทับ log ได้สมบูรณ์โดยไม่เกิด Error 404
3. Build S_MartPOS_Setup_v1.7.10.exe และ S-Link version 3.4.15+98 เรียบร้อยแล้ว
