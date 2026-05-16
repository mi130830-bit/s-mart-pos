# S.Mart POS Desktop (Hybrid Logistics Edition)

ระบบจัดการหน้าร้าน (Point of Sale) และระบบบัญชาการโลจิสติกส์สำหรับ Windows Desktop ทำงานประสานงานกับ S-Link Mobile App

## 🚀 ฟีเจอร์หลัก (Key Features)

- **Real-time Delivery Sync**: เชื่อมต่อกับ Firebase Firestore เพื่อดึงสถานะงานส่งของจากคนขับ (Mobile) มาลงฐานข้อมูล Local (MySQL) อัตโนมัติ
- **Smart Archiving**: ระบบย้ายงานที่สำเร็จแล้วจาก Cloud มาเก็บไว้ในเครื่องตัวเอง เพื่อประหยัดพื้นที่ Firestore และเก็บประวัติได้ไม่จำกัด
- **Advanced Reporting**: 
    - ออกรายงาน Excel แยกตาม "รถ" อัตโนมัติ
    - รวมรายชื่อทีมงาน (คนขับ + เด็กติดรถ) ไว้ในช่องเดียวกัน
    - **Interactive GPS**: พิกัดส่งของคลิกเปิด Google Maps ได้ทันทีจากโปรแกรม และไฟล์ Excel มีการสไตล์ลิงก์ให้ชัดเจน
- **Data Reliability**: มีระบบ Force Token Refresh เพื่อแก้ปัญหา Session หมดอายุบน Windows ทำให้การ Sync ทำงานได้ 24 ชม.

## 🛠 Tech Stack

- **Frontend**: Flutter (Windows)
- **Database**: 
    - **MySQL (Local)**: สำหรับเก็บข้อมูลหลักและประวัติ
    - **Isar (Local NoSQL)**: สำหรับ Settings และ Cache
    - **Firestore (Cloud)**: สำหรับ Real-time Logistics
- **Security**: Role-based access via Firestore Rules (Admin, Driver, Requester)

## 📅 อัปเดตล่าสุด (April 9, 2026)

1.  **Fuel Cost Management System**:
    *   **Daily Pricing**: ระบบบันทึกราคาน้ำมันดีเซลรายวัน เพื่อใช้คำนวณต้นทุนย้อนหลังตามวันที่ส่งจริง
    *   **Vehicle Efficiency**: ตั้งค่าอัตราสิ้นเปลืองน้ำมัน (กม./ลิตร) แยกตามรายคัน (Default: 7.0 กม./ลิตร)
    *   **Monthly Report**: หน้าสรุปต้นทุนน้ำมันรายเดือน แยกตามรายรถและรายบริษัท
2.  **S-Link Requester Improvements**:
    *   **Driver Filter Confirmation**: ยืนยันระบบกรองเฉพาะพนักงานขับรถ (Driver Role) ตาม Business Logic ที่ถูกต้อง
    *   **UI Integration**: เพิ่มปุ่มเข้าถึง "จัดการน้ำมัน" ในหน้า Settings และ "สรุปน้ำมัน" ใน Dashboard ของ POS Desktop
3.  **Firebase Sync Reliability**: แก้ไขปัญหา [permission-denied] โดยการเพิ่มระบบบังคับ Refresh Token ก่อนเริ่ม Sync ทุกครั้ง
4.  **GPS Interactive Links**: 
    *   ในโปรแกรม: เพิ่มปุ่ม Map (เปิด Browser) และปุ่ม Copy (คัดลอกลง Clipboard)
    *   ใน Excel: ลิงก์จุดส่งของเปลี่ยนเป็นสีน้ำเงินและขีดเส้นใต้ เพื่อความสวยงามและใช้งานง่าย

---
*พัฒนาโดย Antigravity AI Code Assistant*
