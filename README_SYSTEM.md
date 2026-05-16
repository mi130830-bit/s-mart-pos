# S_Mart Ecosystem Architecture & Documentation
*(เอกสารอธิบายโครงสร้างและระบบการทำงานของ S_MartPOS และแอปพลิเคชัน S-Link)*

---

## 1. ภาพรวมของระบบ (Ecosystem Overview)
ระบบ S_Mart ควบคุมการทำงานของร้านค้าผ่าน 2 แอปพลิเคชันหลักที่ทำงานสอดประสานกัน:
1. **S_MartPOS (Desktop App):** เป็นเครื่องคิดเงินหลัก (Main Server/POS) ประจำร้าน ตั้งอยู่กับที่ จัดการฐานข้อมูล MySQL และทำหน้าที่คอยอัปเดตข้อมูลขึ้นระบบคลาวด์ 
2. **S-Link (Mobile App):** เป็นแอปพลิเคชันพกพาสำหรับพนักงานและคนขับรถ เพื่อให้สามารถตีบิลหน้าร้าน, เช็คสต็อก, และวิ่งงานจัดส่งได้อิสระจากเครื่องหลัก (ผ่าน Cloudflare Tunnel API และ Firebase)

---

## 2. โครงสร้างและการทำงานของฮาร์ดแวร์หลัก (S_MartPOS - Desktop Application)

**Tech Stack:** `Flutter` ควบคุมการแสดงผลบน Windows, `Provider`, `mysql_client_plus` (Direct MySQL Connection)

### 2.1 โครงสร้างไฟล์หลัก (Directory Architecture)
ระบบเขียนให้แบ่งสัดส่วนด้วยสถาปัตยกรรมแบบ Feature & Layer-based:
- **`models/`**: โครงสร้าง Data Class ทั่วไป (Customer, Product, Order)
- **`repositories/`**: รวบรวมคำสั่ง SQL Database Queries (ไม่มีการใช้ ORM หนาๆ เพื่อลด Overhead)
- **`services/`**: ตรรกะของโปรแกรม เช่น `FirebaseService` สานต่อคลาวด์, `DatabaseInitializer` คอยดัดตารางอัตโนมัติ
- **`state/`**: Global Providers ดูแลสถานะพฤติกรรม เช่น `PosStateManager` จัดการบิลขาย
- **`screens/`**: UI ทั้งหมดออกแบบมาเพื่อ Landscape Screen เน้นการเลื่อนน้อยที่สุดและการเปิด Modal

### 2.2 กลไกลการเชื่อมต่อ Network (LAN & Dynamic IP) 🚀
ระบบ POS Desktop มีกลไกการเชื่อมต่อระหว่างเครื่องแม่ (Server) และเครื่องลูก (Client) ที่ชาญฉลาด:
- **DNS-Based Configuration:** เครื่องลูกสามารถบันทึก Config โดยใช้ **"ชื่อเครื่องแม่"** (เช่น `POS-MAIN`) แทนการใช้เลข IP ตายตัว เพื่อป้องกันปัญหาเชื่อมต่อไม่ได้เมื่อ Router จ่าย IP ใหม่ (DHCP)
- **Smart Runtime Resolution:** ในขณะที่แอปกำลังทำงาน ระบบจะทำการ Resolve ชื่อเครื่องเป็น IPv4 ให้อัตโนมัติ โดยกรองเฉพาะ IPv4 เพื่อข้ามปัญหา Timeout ของ IPv6 บน Windowsปรั
- **mDNS Support:** รองรับโปรโตคอล `.local` อัตโนมัติ ทำให้การค้นหาเครื่องแม่ในวงแลนทำได้รวดเร็วและแม่นยำสูง

### 2.3 กลไกสำคัญอื่นๆ บน Desktop
- **Single Instance Lock:** การป้องกันแอปเปิดซ้อนกัน (ผูก Port 59999 ไว้ตอนแอปทำงาน หากมีแอปอื่นพยายามเปิดจะเรียก PowerShell Popup เด้งเตือนและสั่งปิดโปรแกรมทันที ปกป้อง Database)
- **Customer Display (Multi-window):** แพ็กเกจ `desktop_multi_window` ปลีกตัวเป็นหน้าต่างที่สอง หันให้ลูกค้าดูราคาและแสกน QR PromptPay
- **Database Initializer:** ถ้าระบบเจอว่าคอลัมน์ขาดหายหรือมีการอัปเดต Schema ในโค้ด โค้ดจะจัดการยิงคำสั่ง `ALTER TABLE` สร้างคอลัมน์ชดเชยให้แบบอัตโนมัติทุกครั้งที่รัน
- **Auto-Retry Notifications:** แจ้งเตือน Line OA เมื่อสั่งซื้อสำเร็จ หากอินเทอร์เน็ตพังขณะยิง ระบบจะเก็บสถานะ `PENDING` ลงฐานและเปิด Background Loop พยายามยิงซ้ำจนกว่าจะส่งสำเร็จและมีหน้า Log สามารถจัดการสถานะได้ทีละรายการ

---

## 3. โครงสร้างและการทำงานของแอปฝั่งมือถือ (S-Link - Mobile Application)

**Tech Stack:** `Flutter`, `Provider`, เครือข่ายแบบ Single Tunnel API (`https://api.namecheap.work`), `Firebase Firestore` (ส่วนของการกระจายงานและ Sync ตะกร้า)

### 3.1 การเชื่อมต่อแบบ Single Tunnel (API Only)
แอปพลิเคชันเวอร์ชันใหม่ถูกรื้อระบบ **งดการให้ตัวมือถือยิงสดเข้าหา MySQL เครื่องหลักโดยตรง (No Direct DB Connection)** เพื่อแก้ปัญหาความปลอดภัย และการหลุดการเชื่อมต่อเมื่ออยู่นอกร้าน ระบบทำงานด้วยการยิงผ่าน API URL เพียงเส้นเดียว (`PosApiService`) เช่นการขายของ บันทึกประวัติ หรือรับของเข้า ให้ยิงผ่าน API ให้แบคเอนด์ทำงานแทนทั้งหมด 

### 3.2 ฟีเจอร์แกนหลักของฝั่ง Mobile
1. **Mobile POS (ขายหน้าร้าน/เดินขาย):**
   - พนักงานสแกนบาร์โค้ดจากกล้องมือถือ
   - คำนวณเงินสดและดึง QR PromptPay โทรศัพท์มือถือ
   - **Cloud Printing:** กรณีกดบันทึกบิล ตัวมือถือจะสาด Trigger ข้อมูลการสั่งขึ้น Firestore และเตะให้ S_MartPOS บนเดสก์ท็อปพิมพ์ใบเสร็จออกมาที่เครื่องปริ้นเตอร์หลัก
2. **Inventory Management (การจัดการส่วนคลังคลังสินค้า):**
   - นับสต็อกหน้าร้าน (Stock Check) และปรับยอดทันที 
   - รับของเข้า (Stock In) บันทึกลงสมุดบัญชี 
   - มีหน้าต่างแจ้งเตือนและร้องขอสินค้าเมื่อของใกล้หมด (Low Stock Alerts)
3. **Logistics & Stats (การจัดส่งเดลิเวอรี่):**
   - **Bidirectional Vehicle Matching:** ระบบสถิติอัจฉริยะที่สามารถรวบรวมยอดของ "ชื่อรถ" และ "ทะเบียน" ของคันเดียวกันเข้าด้วยกันได้ถูกต้องแม้ออกรายงาน Excel หรือดูผ่าน Driver Stats
   - มี Job Dashboard โชว์รายการกล่องสินค้าที่ต้องนำไปส่ง
   - กดปุ่มเพื่อนำทางผ่านแอป Google Maps 
   - กดยืนยันการชำระเงิน (รองรับ COD) ถ่ายรูปหน้างานและปิดระบบปิดจ็อบลง Firestore

---

## 4. กลไกทำงานร่วมกันระหว่าง Desktop และ Mobile (Cross-platform Synchronization)

ระบบเดสก์ท็อปและโมบายไม่ได้ทำงานแยกกัน แต่ประสานกันอย่างใกล้ชิดผ่านฐานข้อมูลเสมือนอย่าง **Firebase Firestore**

**วัฏจักรการขายและจัดส่ง:**
- **สร้างงานจากร้าน (Desktop):** เดสก์ท็อปทำการตีบิล หากเป็นการจัดส่ง (Delivery) ข้อมูลจะถูก Push ขึ้นไปยัง Collection `jobs` ของ Firestore 
- **ส่งแจ้งเตือนด่านแรก:** Desktop วิ่งชน API ส่งการแจ้งเตือนหา Line ลูกค้า แจ้งว่า *"ร้านได้รับคำสั่งซื้อแล้ว... กำลังเตรียมสินค้า"*
- **Mobile ตอบรับงาน (S-Link):** คนขับรถเปิดหน้า Job Dashboard ตัว Firestore ถีบข้อมูลงานใหม่หล่นลงมือถืออัตโนมัติ 
- **ยิงอัปเดตเป็นระยะ (Cloud Functions):** ตอนที่คนขับเปลี่ยนสถานะเป็น ดำเนินการจัดส่ง (Shipping) หรือ ส่งสำเร็จแล้ว (Completed) Cloud Functions จะคอยดักจับและเป็นตัวส่งแจ้งเตือนชิ้นต่อไปหาลูกค้า
- **Auto Cleanup & Archive (Desktop):** เมื่อรถส่งของเสร็จ Desktop ที่เปิดตั้งทิ้งไว้ในร้านจะดึงงานที่สำเร็จลงมาเก็บใน MySQL Local `delivery_history` เพื่อเตรียมให้แอดมินสามารถดึงยอดรายงานประวัติรอบการวิ่งรถเป็น Excel (Export จัดทรงไฟล์อัตโนมัติแยกตามป้ายทะเบียน) จากนั้นโค้ดจะเตะข้อมูลบน Cloud ทิ้งเพื่อประหยัดพื้นที่คลัง Firestore ทันที

---

## 5. ระบบโครงสร้างพื้นฐานที่มีอยู่แล้ว (Existing Infrastructure)
1. **ระบบ Auto-Backup:** โค้ดมี `BackupScheduler` ทำงานคู่กับ `GoogleDriveService` คอยตั้งเวลา Export ก้อนข้อมูล (`.sql`) ขึ้น Google Drive ป้องกันฮาร์ดแวร์หน้าร้านพัง
2. **User Role & Permissions:** มีระบบบัญชีผู้ใช้ผ่าน `UserRepository` บน Desktop ชัดเจนที่ไปควบคุมสิทธิ์การเข้าถึงเมนูสำคัญ (ผูกผสานกับ `AuthProvider` ตอนเกิด UI) 
3. **Advanced Reporting Dashboard:** แอปมีหน้าจอ `DashboardScreen` ที่ผูกคณิตศาสตร์ดึงยอดตัวชี้วัดสำคัญ ๆ (Metrics) ครบถ้วน ไม่ว่าจะเป็น สินค้าขายดี (Top Sellers) หรือกำไรขั้นต้น (Gross Profit) 
4. **Hardware (Printer Agnostic):** สถาปัตยกรรมไม่ได้ถูกผูกติดกับภาษา Native ESC/POS อย่างเดียว แอปพึ่งพาตารางวาด `pdf` และรันผ่าน `printing` แพ็กเกจ
5. **Database Indexing:** การโหลดบิลเป็นแสนใบไม่ใช่ปัญหา เพราะระบบ `DatabaseInitializer` ฝังคำสั่ง `_ensureIndex` ดัด Index ที่คอลัมน์ชื่อ, เบอร์ลูกค้า, และบาร์โค้ดมาตั้งแต่ต้นทาง
6. **UI/UX & Update Path:** ระบบ UI ถูกเชื่อมกับ `ThemeProvider` เรียบร้อย รองรับการเปลี่ยน ธีมมืด/สว่าง (Dark Mode)
7. **Firestore Quota Management (Data Purging):** มีกลไก `Auto-Cleanup` คอยลบงานเดลิเวอรีที่สำเร็จแล้วทิ้งจาก Firestore อัตโนมัติ
8. **Handheld Hardware Support:** รองรับเครื่องสแกนบาร์โค้ด Bluetooth (โหมดพอร์ตชิป HID)
9. **Audit Logs (ระบบตรวจสอบย้อนหลัง):** ฐานข้อมูล MySQL มีตาราง `activity_logs` บันทึกประวัติการแก้ไขข้อมูลสำคัญ

---

## 6. ข้อควรระวังและการตั้งค่าเครือข่าย (Network Setup & Developer Notes) 🛠️

### 6.1 หัวใจสำคัญของการเชื่อมต่อในร้าน (LAN Setup)
เพื่อให้เครื่องลูกหาเครื่องแม่เจอผ่านชื่อเครื่อง (Hostname) จะต้องตรวจสอบดังนี้:
1. **Network Profile:** ทั้งเครื่องแม่และเครื่องลูกต้องตั้งค่า WiFi/LAN เป็น **"Private"** (หากเป็น Public ตัว Windows จะสั่งบล็อกการเชื่อมต่อ)
2. **Windows Firewall:** ต้องอนุญาต (Allow Inbound Rules) สำหรับ Port **3306** (MySQL) และ **8080** (API)
3. **MySQL User:** ยูสเซอร์ต้องถูกตั้งสิทธิ์ให้เข้าถึงได้จาก Host `%` (Any Host)
4. **Network Discovery:** เปิด Network Discovery ใน Windows Settings เพื่อให้ mDNS/NetBIOS ทำงานได้สมบูรณ์

### 6.2 Developer Notes
1. **โค้ดดิ้งร่วมกับ S-Link:** งดการใช้ `mysql_client` บนมือถือ ให้วิ่งผ่าน API เท่านั้น
2. **แจ้งเตือนหลุด:** หากเพิ่มฟีเจอร์ใหม่ที่ต้องการยิงไลน์ ให้ยิงผ่าน `NotificationRepository` เพื่อให้ระบบ Retry ทำงาน
3. **Firestore Quota:** ระวังการเรียก snapshot query เยอะๆ ให้เน้นการใช้ `where` filter ที่แม่นยำเพื่อลดการอ่าน Data Transfer
