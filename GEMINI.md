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