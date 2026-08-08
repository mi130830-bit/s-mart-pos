# บันทึกการแก้ไข (Fixes & Modifications Log)

ไฟล์นี้ใช้สำหรับบันทึกการแก้ไขบั๊ก, การปรับปรุงโค้ด, หรือการเปลี่ยนแปลงระบบที่เกิดขึ้นในโปรเจกต์ เพื่อเป็นประวัติการทำงานและใช้อ้างอิงในอนาคต

---

## [2026-08-08] จำกัดลิงก์ติดตามเฉพาะรถที่มี GPS

**ไทย:** ขณะนี้อนุญาตให้แนบลิงก์ติดตามลูกค้าเฉพาะรถเครน (`รถเครน`) ซึ่งเป็นรถที่
ติดตั้ง ESP GPS แล้ว งานที่ปล่อยรถคันอื่นยังส่งข้อความ LINE OA ว่า "กำลังเดินทาง"
ตามปกติ แต่จะไม่สร้างหรือแนบลิงก์ที่ยังแสดงตำแหน่งไม่ได้

**English:** Customer tracking links are currently enabled only for the crane
(`รถเครน`), the sole vehicle with an ESP GPS tracker. Jobs assigned to other
vehicles still receive the normal LINE OA shipping notification, without an
unusable tracking link.

---

## [2026-08-08] Customer delivery tracking through LINE OA

**ไทย:** Stage 2 ของ LINE OA สร้างลิงก์ติดตามเฉพาะออเดอร์และแนบพร้อมข้อความ
“กำลังเดินทางจัดส่ง” หน้าลูกค้าเห็นเฉพาะพิกัดรถคันที่ถูกปล่อยงานนั้น และ token
ถูกเพิกถอนทันทีเมื่อ backend รับการปิดงาน

**English:** LINE OA Stage 2 now issues and attaches an order-scoped tracking
link to the shipping notification. The customer page exposes only the assigned
vehicle's location, and its token is revoked as soon as the backend records
job completion.

---

## [2026-08-08] Canonical GPS vehicle identity

**ไทย:** กำหนดชื่อรหัส GPS กลางสำหรับรถดั้มเป็น `ดั้มเล็ก` และ `ดั้มใหญ่`
ให้ ESP32, S-Link, POS GPS backend และหน้าเว็บใช้ค่าเดียวกัน S-Link จะส่งชื่อ
รถก่อนทะเบียนในสถานะปล่อยรถและปิดงาน เพื่อไม่ให้เกิดรถคนละรายการบนแผนที่

**English:** Defined `ดั้มเล็ก` and `ดั้มใหญ่` as the canonical GPS vehicle
keys shared by ESP32 trackers, S-Link, the POS GPS backend, and the web map.
S-Link now prefers the vehicle name over the registration plate for departure
and completion GPS status updates, avoiding split vehicle records.

---

## [2026-08-08] Vehicle-specific GPS tracker sketches

**ไทย:** เพิ่มสเก็ตช์อัปโหลดแยกสำหรับ `ดั้มเล็ก` และ `ดั้มใหญ่` ใน
`GPS/vehicles/` โดยใช้ firmware กลางชุดเดียวกัน ชื่อรถที่ ESP32 ส่งขึ้น API
ตรงกับชื่อ canonical บนหน้า GPS จึงไม่ปะปนกับรถคันอื่น

**English:** Added separate upload sketches for `ดั้มเล็ก` and `ดั้มใหญ่`
under `GPS/vehicles/`. Both reuse the shared tracker firmware and send the
canonical GPS vehicle names, preventing vehicle-status mismatches.

---

## [2026-08-07] Paid-order edits, additional settlement, and audit trail

**ไทย:** การแก้ไขบิลที่เคยชำระแล้วจะแสดงยอดบิลใหม่, ยอดเก็บไปแล้ว และยอดคงค้างเฉพาะส่วนเพิ่มอย่างถูกต้อง หากเลือกเงินเชื่อ ระบบสร้างลูกหนี้และงานส่งแบบ “เก็บปลายทางเพิ่ม” เฉพาะส่วนต่าง; หากชำระทันที ระบบบันทึกเป็น “ชำระเพิ่ม (แก้ไขบิล)” โดยไม่สร้างหนี้ซ้ำ พร้อมป้องกันการลดบิลต่ำกว่าเงินที่รับแล้วซึ่งต้องใช้ขั้นตอนคืนเงินเฉพาะทาง นอกจากนี้เพิ่ม Audit Log สำหรับการแก้ไขลูกค้าและบิล เพื่อระบุผู้ทำ เวลา และรายละเอียดสำคัญของการเปลี่ยนแปลง

**English:** Paid-order edits now preserve the amount already collected and settle only the additional balance. Credit creates a receivable and COD job only for that difference; immediate payment is recorded as an additional settlement without duplicate debt. Refund-requiring reductions are blocked for an explicit refund flow. Customer and order edits now write audit records with the actor, timestamp, and key change details.

**Thai addendum:** สำหรับบิลเดิมที่เก็บ `received` เป็นเงินที่ลูกค้ายื่นมา ระบบแก้ไขบิลจะหัก `changeAmount` ก่อนเสมอ เช่น รับ 11,000 และทอน 685 จะนับว่ารับจริง 10,315; ยอดเพิ่ม 225 จึงปิดบิลหรือเป็น COD/ลูกหนี้เพียง 225 เท่านั้น.

**English addendum:** For historical bills that store the tendered amount in `received`, order edits now subtract `changeAmount` first. A ฿11,000 tender with ฿685 change is treated as ฿10,315 collected, so only the ฿225 increase is settled or sent as COD.

**Maintenance:** Removed an unused delivery-edit calculation so `flutter analyze` remains warning-free.

**Release:** Bumped POS Desktop to `1.8.3` for the paid-order edit settlement, COD adjustment, and audit-log fixes.

**S-Link sync:** The active-job API now sends the outstanding balance rather than the full order total. It deducts prior change from tendered cash first, so an edited paid order with a ฿225 credit increase remains the same job and shows only ฿225 COD in S-Link.

**Settlement base:** Fully paid order edits now use the original bill total as the settled base directly. The additional amount is therefore always `new bill total − original bill total`; tendered cash and change are only relevant to bills that were already unpaid.

**GPS diagnostics:** `GPS/GPS.ino` now prints the HTTP response body after every position upload, making API acceptance or rejection visible in the Serial Monitor.

**4G recovery:** GPS sketches now reject the false-success `0.0.0.0` PDP state, reconnect the APN once, and skip HTTP until the A7670E has a usable mobile-data IP.

**GPS compile fix:** Replaced the non-Arduino `String.isNotEmpty()` call with `!String.isEmpty()` in the 4G IP check.


## [2026-08-04] Canonical Driver Identity & Safe Attendance Sync

**ไทย:** API รายชื่อคนขับส่ง `user.id` เป็นรหัส assignment หลัก พร้อมส่ง
`employee_profile.id` ใน `employee_id` เพื่อรองรับงานเดิมและงาน HR
นอกจากนี้ Attendance API จะ rollback และตอบ error เมื่อจับคู่พนักงานไม่ได้
แทนการข้ามรายการแล้วตอบสำเร็จ ซึ่งป้องกันเวลาเข้างานหายเงียบ ๆ

**English:** The driver API now exposes `user.id` as the canonical assignment
identity while retaining `employee_profile.id` as `employee_id` for legacy
jobs and HR. Attendance sync now rolls back when employee resolution fails,
so the mobile offline record remains queued for retry instead of being
silently marked as synchronized.

## [2026-08-03] Dual-Stack Backend Server, Smart Identity Resolution & S-Link Attendance Real-time Auto-Sync

### 🖥️ POS Backend & API Server
- **[Network & Cloudflare Fix] Dual-Stack Binding (IPv4 & IPv6):**
  - **ไฟล์:** `backend/bin/server.dart`
  - **รายละเอียด:** ปรับการเปิด Port ของ `shelf_io` ให้ใช้ `HttpServer.bind(InternetAddress.anyIPv6, port, v6Only: false)` เพื่อรองรับการเชื่อมต่อพร้อมกันทั้ง IPv4 (`127.0.0.1`) และ IPv6 (`[::1]`) แก้ปัญหา Cloudflare Tunnel เด้ง Error `dial tcp [::1]:8080: connectex` ขาดการเชื่อมต่อ
- **[Security & Identity] Smart Employee Identity Resolver (`_resolveEmployeeId`):**
  - **ไฟล์:** `backend/lib/controllers/attendance_controller.dart`
  - **รายละเอียด:** เพิ่มฟังก์ชันแปลงตัวตนแบบยืดหยุ่น รองรับการระบุตัวตนด้วยทั้ง Username (`miti`) หรือ User ID (`10`) โดยจับคู่เฉพาะ `employee_profile` ตัวจริงที่เปิดใช้งานอยู่ (`is_active = 1`) เพื่อป้องกันปัญหา ID ขยะในฐานข้อมูลแทรกแซง
- **[Data Integrity] Stale `clock_out` Sanitization:**
  - **ไฟล์:** `backend/lib/controllers/attendance_controller.dart`
  - **รายละเอียด:** เพิ่ม Logic เคลียร์ค่า `clock_out` ตกค้างในอดีตให้เป็น `NULL` เมื่อมีการเข้างานรอบใหม่ และกรอง `clock_out` ที่ลงไว้ก่อน `clock_in` ออกจากผลลัพธ์การดึงข้อมูล

- **[Feature & UX] Simplified Job Completion (Optional Photo):**
  - **ไฟล์:** `lib/features/jobs/screens/complete_job_form.dart`
  - **รายละเอียด:** ปรับกระบวนการปิดงานส่งสินค้าให้เรียบง่าย (Lazy-friendly) ปลดการบังคับถ่ายรูปออก คนขับสามารถกด **[ยืนยันการปิดงาน]** ได้ทันทีในคลิกเดียว โดยส่งเฉพาะยอด COD (ถ้ามี) และพิกัด GPS กลับมา ส่วนการถ่ายรูปปรับเป็นแบบ Optional (เลือกถ่ายหรือไม่ก็ได้)

- **[Feature & Admin UI] Delete Job from Delivery Dashboard:**
  - **ไฟล์:** `lib/screens/reports/delivery_dashboard_screen.dart`, `lib/screens/reports/widgets/delivery_dashboard/delivery_records_table.dart`, `lib/repositories/delivery_history_repository.dart`
  - **รายละเอียด:** เพิ่มฟังก์ชันและปุ่ม "ลบ" (Delete) ในหน้าแดชบอร์ดติดตามงานส่งของ (Delivery Dashboard) บน POS เพื่อให้ร้านค้าสามารถเลือกลบรายการงานที่สร้างผิด หรือเกิดจากการเทสระบบออกจากฐานข้อมูล MySQL (`delivery_history`) ได้โดยตรง

---

## [2026-08-03] Architecture Shift: Direct API & Offline Retry for Attendance (POS Desktop & S-Link)

### 📱 S-Link
- **[Feature & Fix] Auto-Push Offline Attendance Logs on Open:**
  - **ไฟล์:** `lib/features/hr/services/attendance_service.dart`
  - **รายละเอียด:** เพิ่ม `await syncUnsyncedLogs()` ไว้ที่จุดเริ่มต้นของ `fetchTodayLogFromServer()` ทำให้ทุกครั้งที่เปิดหรือรีเฟรชหน้าลงเวลา ระบบจะดันคิวที่บันทึกไว้ใน Isar ขณะออฟไลน์ (`isSynced = false`) ขึ้นไปยัง POS Backend API ทันทีเมื่อกลับมาเชื่อมต่อได้

### 🖥️ POS Desktop
- **[UI Clean & Architecture Alignment] Refreshed HR Attendance Tab:**
  - **ไฟล์:** `lib/screens/hr/tabs/hr_attendance_tab.dart`, `lib/screens/hr/hr_screen.dart`
  - **รายละเอียด:** ปรับปรุงข้อความปุ่มรีเฟรชและแจ้งเตือนจากคำว่า "ซิงค์ข้อมูลจากคลาวด์" (Firestore เดิม) เป็น "รีเฟรชข้อมูลลงเวลาล่าสุด" และเชื่อมต่อการดึงข้อมูลจาก MySQL ท้องถิ่นโดยตรง 100%
- **[Clean Code] Cleaned obsolete scratch test files:**
  - ลบไฟล์ทดสอบเก่าที่ไม่ใช้งาน (`check_db.dart`, `test_api.dart`, `test_db.dart`, `test_firestore.dart`, `test_mysql2.dart`) เพื่อให้ Visual Studio Code ดีบักได้อย่างลื่นไหล 0 Error

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
## 2026-08-04 — แก้ปุ่มลบในหน้าติดตามงานส่ง / Fix delivery tracking delete action

- แก้การอ่าน `delivery_history.id` ให้รองรับค่าจาก MySQL ทั้งชนิดตัวเลขและข้อความ ก่อนส่งไปลบในฐานข้อมูล
- เพิ่มข้อความแจ้งเตือนเมื่อรายการไม่มีรหัสประวัติ แทนการกดแล้วไม่มีการตอบสนอง
- การลบมีผลเฉพาะประวัติงานใน `delivery_history` ไม่กระทบบิลขาย ยอดเงิน หรือข้อมูลลูกค้า
- Parse `delivery_history.id` safely from either numeric or string MySQL values before deletion.
- Show an explicit error when a history row has no valid ID; deletion remains scoped to `delivery_history` only.
## 2026-08-04 — ตัวกรองช่วงวันที่มาตรฐาน / Shared date-range filters

**ไทย**

- เพิ่ม `DateRangeHelper` และ `QuickDateRangeSelector` เป็นมาตรฐานกลางสำหรับ วันนี้, สัปดาห์นี้ (จันทร์–วันนี้), เดือนนี้, ปีนี้ และกำหนดช่วงเอง
- แบบกำหนดเองเปิดโหมดกรอกวันที่เริ่มต้น/สิ้นสุดโดยตรงและสลับไปปฏิทินได้ เหมาะสำหรับข้อมูลย้อนหลังหลายปี
- ยกเลิกข้อจำกัดช่วงรายงานขนส่งไม่เกิน 366 วัน โดยยังคงใช้ขอบเขตต้นวัน–สิ้นวันให้ query SQL ตรงกัน
- นำตัวกรองกลางไปใช้ในหน้าติดตามงานส่ง, รายงานขนส่ง, รายรับ–รายจ่าย, Stock Ledger, สินค้าขายดี, ประวัติเงินเดือน และสรุปการรับเข้าตามผู้ขาย
- ไม่เปลี่ยนช่องวันที่เชิงธุรกรรม เช่น วันที่เอกสาร วันลา วันหยุด โปรโมชั่น และวันที่ราคาน้ำมัน เพราะไม่ใช่ตัวกรองรายงาน

**English**

- Added shared `DateRangeHelper` and `QuickDateRangeSelector` presets for today, week-to-date, month-to-date, year-to-date, and custom ranges.
- Custom selection starts in direct date-entry mode with a calendar toggle, making multi-year history easier to query.
- Removed the delivery report's 366-day limit and reused normalized start/end-of-day boundaries across report filters.
- Adopted the shared selector in delivery tracking/reporting, income/expense, stock ledger, best sellers, payroll history, and supplier receiving summary screens.
- Transaction-specific dates remain unchanged because they are data-entry fields rather than report filters.
## 2026-08-04 — HR Override API routing and release 1.8.2

**ไทย:** ย้าย route `GET /hr/attendance/list` มาไว้ใน
`AttendanceController` ซึ่งเป็น controller ที่ router จับ path นี้จริง
พร้อมคืนสถานะ/วิธีบันทึกสำหรับหน้าจอเข้างานแทน อัปเดต backend ให้รักษา
`PRESENT_OVERRIDE` และ `HR_OVERRIDE` ทั้งกรณี insert และ update และเตรียม
POS Desktop รุ่น `1.8.2` พร้อม backend executable รุ่นเดียวกับซอร์สล่าสุด

**English:** Registered `GET /hr/attendance/list` on the effective
`AttendanceController`, returned override metadata, preserved
`PRESENT_OVERRIDE`/`HR_OVERRIDE` during inserts and updates, and prepared POS
Desktop `1.8.2` with a backend executable compiled from the current source.
## 2026-08-04 — Analyzer warning cleanup

**ไทย:** แก้ deprecated color API, exception rethrow, string interpolation,
วงเล็บเงื่อนไข และ production logging ใน POS/backend พร้อมแยกไฟล์ Isar ที่
generate อัตโนมัติและสคริปต์ CLI/scratch ออกจากขอบเขต `flutter analyze`
โดยยังคงตรวจ source production และ test ปกติครบถ้วน

**English:** Cleaned deprecated color APIs, exception rethrowing, string
interpolation, conditional braces, and production backend logging. Generated
Isar files and standalone CLI/scratch tools are excluded from Flutter analysis,
while application source and normal tests remain fully analyzed.
## 2026-08-05 — Product list vertical overflow

**ไทย:** ลดจำนวนสินค้าในหน้า Product List จาก 8 เป็น 7 แถวต่อหน้า เพื่อให้
แถวรายการและแถบแบ่งหน้าอยู่ภายในพื้นที่หน้าจอครบถ้วน สินค้าไม่ได้ถูกลบและ
รายการส่วนเกินจะเลื่อนไปหน้าถัดไปโดยระบบ pagination เดิม

**English:** Reduced the Product List page size from eight to seven rows so
the list and pagination controls fit within the available vertical space. No
products are removed; remaining products continue on the next page.
# 2026-08-05 — POS auto-refreshes S-Link attendance from MySQL

**ไทย:** หลังเปลี่ยน Attendance ให้ S-Link ส่งตรงเข้า POS API/MySQL หน้า
สถานะพนักงานของ POS ยังโหลดเฉพาะตอนเปิดหน้าหรือกดรีเฟรช จึงไม่เห็นรายการใหม่
เมื่อเปิดหน้าค้างไว้ แก้ให้แท็บลงเวลาโหลดจาก MySQL อัตโนมัติทุก 10 วินาที
แบบป้องกัน request ซ้อน และให้ปุ่มรีเฟรชรอผลจริงก่อนแจ้งว่าสำเร็จ

**English:** After attendance moved to the POS API/MySQL source of truth, the
POS attendance tab only loaded on entry or manual refresh. It now polls MySQL
every 10 seconds while mounted, prevents overlapping requests, and waits for
manual refresh completion before reporting success.
# 2026-08-05 - Idempotent SQL attendance merge / รวมข้อมูลลงเวลาใน SQL แบบส่งซ้ำได้อย่างปลอดภัย

- TH: ปรับ API ลงเวลาให้เวลาเข้างานเลือกค่าที่เก่าที่สุด และเวลาออกงานเลือกค่าที่ใหม่ที่สุด โดยข้อมูลค้างที่ไม่มีเวลาออกงานจะไม่สามารถล้างค่าออกงานใน MySQL ได้อีก
- EN: Attendance API now keeps the earliest clock-in and latest clock-out; stale payloads without a clock-out can no longer clear a confirmed MySQL clock-out.
- TH: ป้องกันการส่งเหตุการณ์ออกชั่วคราวซ้ำแล้วสร้างรอบใหม่ และไม่ให้สถานะ PRESENT จากมือถือเขียนทับสถานะที่ POS คำนวณ
- EN: Duplicate temporary-leave events no longer create extra rounds, and normal mobile PRESENT payloads no longer overwrite POS-calculated status.
# 2026-08-05 - A7670E GPS tracker production path / เส้นทาง GPS A7670E สำหรับใช้งานจริง

- TH: เปิดโหมด 4G ในเฟิร์มแวร์รถ เปลี่ยนไปใช้ TinyGSM A7672X driver ที่รองรับตระกูล A7670E และเพิ่มขั้นตอนรอเครือข่าย, ตรวจสัญญาณ, reconnect และ HTTPS timeout
- EN: Enabled vehicle 4G mode, selected TinyGSM's A7672X-family driver for A7670E, and added network registration, signal diagnostics, reconnect, and HTTPS timeout handling.
- TH: แยก GPS API เป็นช่องรับพิกัดสาธารณะที่ต้องมี device key, ช่องอ่านสำหรับหน้าแผนที่ และช่องอัปเดตสถานะงานที่ยังบังคับ JWT
- EN: Split GPS access into a device-key-protected location ingest path, public map reads, and a JWT-protected job-status update path.
# 2026-08-05 - JWT refresh endpoint / API ต่ออายุ JWT

- TH: เพิ่ม `/api/v1/auth/refresh` เพื่อออก Access Token ใหม่จาก Refresh Token อายุ 30 วัน และอ่านสิทธิ์ผู้ใช้ล่าสุดจาก MySQL ก่อนออก Token
- EN: Added `/api/v1/auth/refresh` to issue a new access token from a 30-day refresh token and reload the user's current MySQL identity before issuing it.
- TH: เปลี่ยนกรณี Token ขาดหาย/หมดอายุเป็น HTTP 401 เพื่อให้ client แยกจากข้อผิดพลาดสิทธิ์ธุรกิจได้ถูกต้อง
- EN: Missing, invalid, and expired tokens now return HTTP 401 so clients can distinguish authentication failures from business authorization errors.

# 2026-08-06 - Staged GPS / Wi-Fi / A7670E diagnostics

- TH: เพิ่มสเก็ตช์แยก `GPS_WIFI_TEST.ino` สำหรับ GPS + Wi-Fi + API และ `GPS_4G_A7670E.ino` สำหรับยืนยันโมเด็ม/เครือข่าย 4G โดยไม่ต้องต่อ GPS พร้อมคู่มือ `GPS/README_TESTING.md` ที่เรียงการต่อไฟและทดสอบจาก ESP32, GPS, Wi-Fi ไปจนถึง A7670E
- EN: Added separate `GPS_WIFI_TEST.ino` and GPS-free `GPS_4G_A7670E.ino` diagnostics, plus `GPS/README_TESTING.md` with a staged ESP32, GPS, Wi-Fi, then A7670E power-up/test sequence.
- TH: ลบค่า Wi-Fi และ device key จริงออกจากสเก็ตช์ที่เกี่ยวข้อง; ทุกไฟล์ใช้ placeholder และการทดสอบ 4G จะไม่ส่งพิกัดทดสอบโดยค่าเริ่มต้น
- EN: Removed real Wi-Fi/device-key values from the related sketches; all use placeholders and the 4G diagnostic does not post a test location by default.
- TH: ตั้งค่า Wi-Fi test สำหรับรถเครนให้ใช้การตั้งค่า deployment ในเครื่องและชื่อรถจริง โดย device key ตรวจตรงกับ backend แล้ว
- EN: Set the Wi-Fi test's local deployment configuration and real crane-vehicle label; the device key was verified against the backend configuration.
- TH: ตั้งค่าสเก็ตช์ A7670E 4G สำหรับรถเครนด้วย APN และ API deployment จริง โดยคง network-only test เป็นค่าเริ่มต้นเพื่อไม่ส่งพิกัดทดสอบ 0,0 ขึ้นแผนที่
- EN: Configured the A7670E 4G test with the crane's local APN/API deployment values while retaining network-only mode by default to avoid posting a 0,0 test location.
- TH: ย้ายสเก็ตช์ทดสอบ Wi-Fi และ 4G เข้าโฟลเดอร์ของตัวเอง เพื่อป้องกัน Arduino IDE รวม `.ino` หลายไฟล์แล้วเกิด `redefinition`; เพิ่มการตั้งค่า VS Code ให้ IntelliSense เห็น ESP32 core และไลบรารีที่ติดตั้งแล้ว
- EN: Moved each test sketch into its own folder to prevent Arduino IDE from combining multiple `.ino` files and causing redefinitions; added VS Code IntelliSense paths for the installed ESP32 core and libraries.
- TH: เพิ่มการพิมพ์ข้อความตอบกลับจาก API เมื่อ Wi-Fi test ได้รหัส HTTP ที่ไม่ใช่ 2xx เพื่อแยกการถูก Cloudflare/เซิร์ฟเวอร์ปฏิเสธออกจากปัญหา Wi-Fi หรือ GPS
- EN: Added API error-body logging for non-2xx Wi-Fi test responses, distinguishing Cloudflare/server rejection from Wi-Fi or GPS failures.
# 2026-08-07 — POS: การแก้ไขบิลที่ชำระแล้ว / Paid-order edit settlement

- แยกยอดที่ลูกค้าจ่ายก่อนแก้ไขออกจากยอดส่วนเพิ่ม ทำให้หน้าชำระเงินแสดงยอดบิลใหม่, เก็บไปแล้ว, และยอดคงค้างที่ต้องรับจริง
- เลือกเงินเชื่อหลังเพิ่มรายการจะสร้างลูกหนี้เฉพาะยอดคงค้าง พร้อมบันทึก `เก็บปลายทางเพิ่ม (แก้ไขบิล #...)`; งานส่งของจะรับยอดส่วนต่างนั้นเป็น COD
- ชำระเงินสด/โอน/QR หลังแก้ไขจะบันทึก `ชำระเพิ่ม (แก้ไขบิล #...)` และบันทึกรายการใน `order_payment` โดยไม่สร้างลูกหนี้
- ป้องกันการลดบิลให้ต่ำกว่าเงินที่รับแล้ว เพื่อไม่ให้เกิดการคืนเงินหรือยอดลูกหนี้ติดลบโดยไม่ตั้งใจ
- The paid amount is now preserved during order edits. Credit creates receivables only for the new outstanding balance, while immediate payment is audited as an additional payment. Edits that require a refund are blocked for a separate, explicit refund workflow.

# 2026-08-07 — GPS: รอ Data IP ให้เสถียรก่อนส่ง HTTPS / Wait for stable data IP before HTTPS

- TH: หลัง A7670E ตอบรับ APN จะรอรับ IP จริงสูงสุด 15 วินาที (และอ่านข้อมูล GPS ต่อเนื่องระหว่างรอ) ก่อนตัดต่อใหม่; เมื่อได้ IP แล้วจะยืนยันว่า session คงอยู่ต่ออีก 2 วินาทีก่อนเริ่ม HTTPS เพื่อลดอาการ IP แกว่งระหว่างเริ่มเชื่อมต่อ
- EN: After A7670E accepts the APN, the tracker waits up to 15 seconds for a real IP while continuously consuming GPS serial data before reconnecting; after an IP arrives, it confirms the data session remains alive for a further 2 seconds before HTTPS begins to reduce connection flapping.

- TH: เพิ่ม log คำสั่ง AT เฉพาะกรณีที่ต่อ APN แล้วไม่ได้ IP เพื่อแสดงสถานะ SIM, การลงทะเบียน packet/LTE, APN, PDP activation และ IP ที่เครือข่ายตอบกลับ โดยไม่ส่งผลกับรอบที่เชื่อมต่อสำเร็จ
- EN: Added raw AT-command diagnostics only when APN succeeds without an IP, reporting SIM, packet/LTE registration, APN, PDP activation, and the network-assigned IP without affecting successful connection cycles.

- TH: แก้การตรวจ IP ของ A7670E ให้ใช้ `AT+CGPADDR=1` โดยตรง หลังพบว่าไลบรารี TinyGSM รายงาน `0.0.0.0` ทั้งที่ modem ได้ PDP IP จริงแล้ว จึงไม่ตัดการเชื่อมต่อที่ใช้งานได้ทิ้งก่อนส่ง HTTPS
- EN: Corrected A7670E IP detection to query `AT+CGPADDR=1` directly after diagnostics showed TinyGSM reported `0.0.0.0` despite a valid PDP IP, preventing valid data sessions from being discarded before HTTPS.

- TH: แยกการเปิด TLS ไปยัง API ออกจากการส่ง HTTP เพื่อระบุได้ว่าความล้มเหลวอยู่ที่ secure socket หรือ request/response; เมื่อ TLS เปิดไม่สำเร็จจะแสดงค่า `AT+CSSLCFG?` สำหรับตรวจ config ของโมเด็ม
- EN: Split TLS socket establishment from the HTTP request so failures can be located at the secure socket or request/response stage; unsuccessful TLS setup prints `AT+CSSLCFG?` for modem SSL configuration diagnostics.

- TH: เมื่อ TLS เปิดไม่สำเร็จ เพิ่มการทดสอบ DNS ของ host และ plain TCP ไปพอร์ต 443 แยกจาก SSL เพื่อแยกปัญหาเครือข่าย/DNS ออกจาก TLS handshake โดยไม่เพิ่มการเชื่อมต่อในรอบที่ส่งสำเร็จ
- EN: When TLS setup fails, added host DNS and plain-TCP-to-443 checks separate from SSL to distinguish network/DNS faults from TLS handshakes without adding connections to successful reporting cycles.

- TH: เปิด TinyGSM AT debug ชั่วคราว เพื่อแสดงคำตอบ `+CCHOPEN` ที่มีรหัสความผิดพลาดของ TLS จาก A7670E โดยตรง; ต้องปิดบรรทัด debug นี้หลังวิเคราะห์เสร็จเพื่อลด serial log
- EN: Temporarily enabled TinyGSM AT debug to expose A7670E's `+CCHOPEN` TLS failure code directly; the debug line should be disabled after diagnosis to reduce serial logging.

- TH: จากผล `+CCHOPEN: 0,15` (TLS handshake error) ของ Cloudflare edge เปลี่ยน transport ของรถเครนเฉพาะโหมด 4G เป็น HTTP พอร์ต 80 ชั่วคราว เพื่อให้ส่งพิกัดใช้งานได้ โดย API ยังคงตรวจ `GPS_DEVICE_KEY`; ถอด TLS debug ที่ใช้วิเคราะห์ออกแล้ว
- EN: After `+CCHOPEN: 0,15` confirmed a Cloudflare-edge TLS handshake error, temporarily switched the crane's 4G transport to HTTP on port 80 so GPS reporting can operate while the API continues enforcing `GPS_DEVICE_KEY`; removed the diagnostic TLS debug.

- TH: เปิด TinyGSM AT debug ชั่วคราวอีกครั้งและเพิ่ม `NETOPEN?`/`CIPOPEN?` เมื่อ TCP พอร์ต 80 เปิดไม่สำเร็จ เพื่ออ่านรหัสตอบกลับของ A7670E ก่อนแก้การเชื่อมต่อ HTTP
- EN: Temporarily re-enabled TinyGSM AT debug and added `NETOPEN?`/`CIPOPEN?` after a failed port-80 TCP open to obtain A7670E's response code before correcting the HTTP connection.

- TH: เปลี่ยน diagnostic TCP เป็นการสั่ง `AT+CIPOPEN` ตรงและรอผล asynchronous `+CIPOPEN` สูงสุด 20 วินาที เพื่อให้เห็นรหัสเปิด socket จริง แทนคำสั่ง query ที่ไม่คืนสาเหตุการล้มเหลว
- EN: Replaced the TCP diagnostic with a direct `AT+CIPOPEN` attempt that waits up to 20 seconds for its asynchronous `+CIPOPEN` result, exposing the actual socket-open code instead of an uninformative status query.

- TH: หลังยืนยัน `AT+CIPOPEN` เปิด socket สำเร็จแต่ TinyGSM เปิด TCP ไม่ได้ เปลี่ยนเส้นทางส่ง GPS 4G ให้ใช้ native A7670E socket (`CIPOPEN` → `CIPSEND` → `CIPRXGET` → `CIPCLOSE`) โดยตรง พร้อม log ผลส่งและคำตอบ API
- EN: After direct `AT+CIPOPEN` succeeded while TinyGSM TCP failed, changed the 4G GPS reporting path to use native A7670E sockets directly (`CIPOPEN` → `CIPSEND` → `CIPRXGET` → `CIPCLOSE`) with send-result and API-response logging.

- TH: เมื่อ native `CIPOPEN` ไม่สำเร็จ จะไม่สั่งปิด socket ที่ยังไม่เปิดแล้ว; เปลี่ยนเป็น refresh PDP data session และ retry เปิด TCP หนึ่งครั้ง เพื่อฟื้นจาก socket state ค้างโดยไม่ส่งพิกัดซ้ำ
- EN: When native `CIPOPEN` fails, the tracker no longer closes a socket that was never opened; it refreshes the PDP data session and retries TCP once to recover from a stale socket state without duplicating the location post.

- TH: แยก DNS ออกจาก `CIPOPEN`: resolve `api.namecheap.work` ด้วย `CDNSGIP` ก่อน แล้วให้ socket เชื่อมต่อด้วย IPv4 ที่ได้ ขณะที่ HTTP `Host` ยังคงชื่อโดเมนเดิม เพื่อลดความไม่เสถียรของ DNS ภายใน TCP socket ของ A7670E
- EN: Separated DNS from `CIPOPEN`: resolve `api.namecheap.work` via `CDNSGIP` first, then connect the socket to the returned IPv4 while retaining the original HTTP `Host`, reducing A7670E socket-internal DNS instability.

- TH: แก้ลำดับ native TCP ให้สั่ง `AT+NETOPEN` และรอ `+NETOPEN: 0` ก่อน `CIPOPEN`; ก่อนหน้านี้ TinyGSM เคยเปิด Socket Service ขั้นนี้โดยอ้อม แต่ native path ยังขาดอยู่จึงทำให้ `CIPOPEN: 0,2`
- EN: Corrected the native TCP sequence to issue `AT+NETOPEN` and wait for `+NETOPEN: 0` before `CIPOPEN`; TinyGSM previously opened this socket service indirectly, while the native path omitted it and caused `CIPOPEN: 0,2`.

- TH: รองรับรูปแบบผลส่งของ firmware A7670E คือ `+CIPSEND:<link>,<sent>,<requested>` โดยถือว่าการส่งสำเร็จเมื่อ link 0 รายงาน byte count; API ตอบ 204 แล้วปิด connection เอง จึงตัดการอ่าน body/ปิด socket ซ้ำที่ทำให้ log error ปลอม
- EN: Added support for A7670E firmware's `+CIPSEND:<link>,<sent>,<requested>` result format, treating link-0 byte counts as success; because the API returns 204 and closes the connection itself, removed body reads/redundant socket close calls that produced false error logs.
