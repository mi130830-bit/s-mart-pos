# S-Link & POS Desktop: Routine Code Audit & Bug Hunt Checklist
(รอบการตรวจสอบทุกๆ 2-3 เดือน)

## 🎯 จุดประสงค์
เพื่อเป็น Checklist สำหรับ AI (บ๊อบ และทีม) และพี่ติ ในการตรวจสอบความสมบูรณ์ของระบบโดยไม่ต้องเสียเวลาวางแผนใหม่ สามารถไล่เช็คตามรายการนี้เพื่อหาบั๊กและ Refactor โค้ดให้ทำงานได้เสถียรขึ้นทันที

---

## 1. 🔍 ส่วนของ POS Desktop (Core System)
- **Database & Synchronization:**
  - ตรวจสอบ `MySqlService`, `IsarService`, `FirestoreRestService` ว่าการทำงานประสานกันอย่างถูกต้อง
  - ตรวจสอบ Fallback Logic: ถ้า MySQL ล่ม Isar ต้องทำงานแทนได้สแกนลื่นไหล, ถ้าเน็ตหลุด Firestore ต้องไม่ค้างและมี Retry Queue
- **State Management & UI:**
  - ตรวจสอบ State Controller (เช่น `PosStateNotifier`) ว่ามีการ Rebuild หน้าจอพร่ำเพรื่อหรือไม่
  - ย้ายการจัดการ Dialog/Alert ให้อยู่ในรูปแบบ Service/Controller (เช่น `QuickMenuService`) ให้หน้าจอเป็น `Pure UI Component`
- **Hardware & Peripherals:**
  - ตรวจสอบระบบ Print (PDF Document / ESC POS) ว่าทำงานรวดเร็ว
  - ตรวจสอบการเชื่อมต่ออุปกรณ์ Serial Port (เครื่องชั่งดิจิทัล, ตัวสแกนนิ้ว ESP32) ว่ามี Error Handling (Try-Catch) รองรับกรณีสายหลุดหรือ Port ชนกัน

---

## 2. 📱 ส่วนของ S-Link (Mobile Driver & Requester)
- **Role-Based Workflows:**
  - **Requester/Admin:** ตรวจสอบระบบตะกร้า (`cart_provider.dart`), การคำนวณเงิน
  - **Conflict Resolution (Stock):** การปรับปรุงสต็อกหน้าร้านต้องใช้ `Latest Timestamp Wins` เสมอ (ห้าม Overwrite ค่าสต็อกตรงๆ แต่ต้องส่งค่า Diff ให้ Backend คำนวณบวก/ลบ เพื่อป้องกันสต็อกเพี้ยนเวลาพนักงาน 2 คนทำงานพร้อมกัน)
- **Offline-First & Reliability:**
  - **SyncService:** ตรวจสอบการทำงานของ Queue เมื่อไม่มีเน็ต ระบบต้องนำข้อมูลไปพักใน `SharedPreferences` หรือ `SQLite/Isar` และทยอยอัปโหลดเมื่อเน็ตกลับมา
  - **Location Fallback:** ถ้าระบุพิกัด (`Geolocator`) ผ่านดาวเทียมไม่ได้ใน 10 วินาที ต้องยอมใช้พิกัดล่าสุด (`Last Known Position`) ทันทีเพื่อไม่ให้คนขับหงุดหงิด
  - **COD Graceful Failure:** การตัดหนี้ผ่าน API ถ้าเกิดเน็ตหลุดตรงนั้น **ห้าม Throw Exception จนปิดงานไม่ได้เด็ดขาด** ให้ยอมปิดงานผ่านไปก่อนแล้วจด Log ทิ้งไว้ให้ Admin ตามเก็บทีหลัง
- **Security & Network:**
  - **JWT Authorization:** ตรวจสอบ `AuthHttpClient` ว่ายังแนบ Firebase ID Token ไปกับทุก Request อัตโนมัติหรือไม่
  - **Connection Pooling:** `PosApiService` ต้องถูกเรียกใช้ผ่าน Singleton HttpClient เพื่อลดภาระแบตเตอรี่โทรศัพท์และลดอาการ Timeout

---

## 3. 🛠 แนวทางการอัพเดตและ Refactor ให้ดีกว่าเดิม (Best Practices)
1. **Lazy-Friendly Design (เพื่อคนขี้เกียจ):**
   - ทุกฟังก์ชันต้องถูกออกแบบมาให้ใช้จำนวนการ "กด (Click)" ให้น้อยที่สุด
   - วางค่า Defaults ล่วงหน้าให้เสมอ (เช่น ระบบจดจำรถล่าสุด หรือเครื่องปริ้นท์ล่าสุด)
   - เน้นระบบอัตโนมัติเป็นหลัก
2. **Graceful Degradation:**
   - ทุกฟีเจอร์ที่ต้องต่อเน็ต (Cloud/API) ต้องไม่ทำให้แอป Crash เมื่อออฟไลน์ ต้องเปลี่ยนสถานะเป็นโหมดรอ Sync เสมอ
3. **UI Decoupling:**
   - ไฟล์ UI แย่ๆ ที่ยาวเกิน 500-1,000 บรรทัด (เช่น `job_detail_screen.dart` ในอดีต) ควรถูกทยอยหั่นและแยกเป็น Widget ย่อย (Sub-components) ตามโฟลเดอร์ให้เป็นระเบียบ
4. **Clean Architecture:**
   - ดึง Logic คอนโทรลออกจาก UI (State แยกจาก Widget 100%)

---

## 4. 📝 ขั้นตอนการทำงานเมื่อบ๊อบเริ่มรอบ Audit ครั้งต่อไป (Next Cycle)
1. **ให้บ๊อบมาอ่านไฟล์นี้ (`AUDIT_CHECKLIST.md`) เป็นอันดับแรกสุด** เพื่อทบทวนเป้าหมาย
2. สั่งรันคำสั่ง `flutter analyze` ทั้งในโปรเจกต์ `pos_desktop` และ `s_link` เพื่อกวาดล้าง Syntax Error ขั้นต้น
3. ไล่โค้ดทีละหัวข้อตาม Checklist ด้านบน (บ๊อบจะไม่ต้องเสียเวลาวางแผนแบบละเอียดเหมือนครั้งแรก)
4. เมื่อพบบั๊กหรือจุดที่ควร Refactor ให้ลงมือแก้ไขทันที พร้อมบันทึกประวัติลง `fix.md`
5. จบงานด้วยการรัน `flutter analyze` ซ้ำอีกครั้ง และรอรับคำสั่ง Build จากพี่ติ!
