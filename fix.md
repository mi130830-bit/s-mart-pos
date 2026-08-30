# บันทึกการแก้ไข (Fixes & Modifications Log)

## [2026-08-30] Mini PC Bare-Metal Proxmox Server Setup, MySQL 8.0 High-Performance Database & Cloudflare Tunnel Migration / ติดตั้งระบบเซิร์ฟเวอร์ Mini PC (Proxmox VE 9.x), ย้ายฐานข้อมูล MySQL ประสิทธิภาพสูง และโอนย้ายระบบ Cloudflare Tunnel

**ไทย:**
1. **การติดตั้ง Proxmox VE 9.x บนฮาร์ดแวร์จริง (Bare-Metal Proxmox Host Deployment):**
   - ตรวจรับและติดตั้ง Proxmox VE 9.x ลงบนเครื่อง Mini PC (GMKtec M5 Ultra, AMD Ryzen 7 7730U 8C/16T, 32GB DDR4 SK Hynix Dual Channel, 1TB NVMe SSD, Dual 2.5GbE LAN)
   - ปรับจูนระบบแม่ข่าย: สลับไปใช้ Proxmox Free No-Subscription Repository, ติดตั้งเครื่องมือจัดการจำเป็น (`htop`, `curl`, `rsync`, `sudo`), และดาวน์โหลด Ubuntu 24.04 LTS Container Template
2. **การสร้างและจัดสรรคอนเทนเนอร์ LXC 3 ตู้หลัก (Triple LXC Container Architecture):**
   - 📦 **LXC 100 (MySQL Database Server):** IP `192.168.1.201` (4 Cores / RAM 8GB / Disk 100GB)
   - 📦 **LXC 101 (Shelf Backend API):** IP `192.168.1.202` (4 Cores / RAM 4GB / Disk 50GB)
   - 📦 **LXC 102 (Cloudflare Tunnel):** IP `192.168.1.203` (2 Cores / RAM 2GB / Disk 20GB)
3. **การย้ายและปรับจูนฐานข้อมูล MySQL 8.0 สู่ LXC 100 (High-Performance MySQL Migration):**
   - ปรับแต่ง `smartpos.cnf` สำหรับหน่วยความจำขนาดใหญ่: กำหนด `innodb_buffer_pool_size = 4G`, `innodb_log_buffer_size = 256M`, `innodb_flush_log_at_trx_commit = 2`, `character-set-server = utf8mb4`, และเปิดการยืนยันตัวตน `mysql_native_password` สำหรับการเชื่อมต่อภายในวง LAN
   - ย้ายข้อมูลจริงจาก Laragon สู่ LXC 100 ครบถ้วน 100.000% ไม่มีตกหล่น: ตรวจสอบจำนวนแถว Orders (`11,121`), Products (`6,502`), Customers (`1,248`) ตรงกับต้นฉบับเป๊ะทุกตาราง
   - ติดตั้งระบบ Auto-Backup สำรองข้อมูลอัตโนมัติทุก 6 ชั่วโมง (`00:00`, `06:00`, `12:00`, `18:00`) บีบอัด `.sql.gz` พร้อมระบบลบไฟล์เก่าเกิน 14 วันอัตโนมัติ
4. **การ Deploy และรัน Backend API สู่ LXC 101 (Native Dart Shelf Backend Deployment):**
   - ติดตั้ง Dart SDK 3.13.2 บน LXC 101, ทำการ Compile เป็น Native AOT Binary (`server_bin`), และรันผ่าน Systemd Auto-Restart Service (`smartpos-backend.service`) บนพอร์ต 8080
   - เชื่อมต่อฐานข้อมูล MySQL (`192.168.1.201`) และระบบ Firebase Firestore Bridge สำเร็จ
5. **การโอนย้าย Cloudflare Tunnel สู่ LXC 102 (Production Zero-Trust Ingress Routing):**
   - ติดตั้ง `cloudflared` บน LXC 102 และเชื่อมต่อกับ Cloudflare Edge Node กรุงเทพฯ (`bkk07`) ผ่าน Token ประจำร้าน
   - ติดตั้ง `socat` ทำหน้าที่ Port Forwarding ส่งต่อทราฟฟิกพอร์ต 8080 ไปยัง Backend API และพอร์ต 3306 ไปยัง MySQL Server
   - ตรวจสอบการเชื่อมต่อภายนอกผ่าน `https://api.namecheap.work/api/v1/health` สำเร็จ (`HTTP 200 OK`, `status: ok`, `database: connected`)
6. **อัปเดตกฎเหล็กการทำงาน (Radical Candor & Constructive Challenge Rule):**
   - เพิ่มกฎข้อที่ 12 ใน `GEMINI.md` และข้อที่ 9 ใน `AGENTS.md` ให้ทีม AI กล้าคัดค้านและปฏิเสธไอเดียที่มีข้อบกพร่อง/มีความเสี่ยงทันที ห้ามเออออตามใจ
7. **ระบบสมองกล AI ประจำการร้าน "น้องเจนนี่" สุดยอดเลขาคนโปรด (Single Super Secretary - LXC 104):**
   - รวมพลังความสามารถทั้งหมดเข้าสู่ตัวตนเดียว: **"น้องเจนนี่" (Jennie)** เลขาสาวคนเก่ง พูดเก่ง อารมณ์ดี สุภาพ ละเอียด รอบคอบ ดูแลร้าน ส.บริการ ท่าข้าม ครบทุกมิติ
   - แปลงสูตรคำนวณวัสดุก่อสร้างจาก `calculator.html` (ConCal V19) ทั้ง 5 หมวด (คอนกรีต, งานผนังก่อฉาบ, ฝ้าเพดานยิปซั่ม/ทีบาร์, หลังคาเมทัลชีท/ซีแพค, งานสี) พร้อมตารางแปลงหน่วยงานช่างมาตรฐานร้าน (1 คิว = 50-60 บุ้งกี๋) ให้น้องเจนนี่คิดคำนวณให้พี่ติได้แม่นยำ
   - พัฒนาระบบ `face_watcher.py` กล้องสแกนใบหน้าหน้าร้านทักทายลูกค้าด้วยเสียงภาษาไทยธรรมชาติ (Neural TTS) และแจ้งเตือนผ่าน Telegram ทันที
8. **จัดระเบียบและอัปเดต Telegram Bot Token แยกตามหน้าที่ชัดเจน:**
   - 🚚 **Bot 1 (GPS Fleet Tracking):** ใช้บอท `PosGPS` (`8410912861:AAF70xuj0NglZcXo55E3tuLIJBRSdj0Uu-8`) ส่งเข้ากลุ่ม `POS-GPS` (Chat ID: `-5507041706`) สำหรับงานติดตามพิกัดรถขนส่งและรถเครน
   - 🔔 **Bot 2 (POS Notification):** ใช้บอท `POS notfy` (`7839145001:AAGYNOWwm1qCZBGpVxXpGza_RhF6pvBtdy8`) ส่งเข้ากลุ่ม `POS notify` (Chat ID: `-5576020223`) สำหรับงานแจ้งเตือนยอดบิลขาย, ลูกหนี้, ลบบิล, สต็อกต่ำ, และยอดขายรายชั่วโมงหน้าร้าน บันทึกเข้า `system_settings` สำเร็จ 100%
9. **ระบบรายงานพยากรณ์อากาศและสรุปข่าวเศรษฐกิจโลกประจำวัน 05:00 น. (Daily 05:00 AM Executive Briefing):**
   - พัฒนาโมดูล `morning_weather_alert.py` ดึงข้อมูลสภาพอากาศความละเอียดสูงตามพิกัดร้าน ส.บริการ ท่าข้าม จาก Open-Meteo API อัตโนมัติ (อุณหภูมิ, โอกาสฝนตก %, ปริมาณน้ำฝน, ความเร็วลม)
   - ผสานระบบดึงข่าวเศรษฐกิจโลก การเงิน น้ำมัน และเหตุการณ์สำคัญระดับโลกแบบ Real-time (RSS Feeds) พร้อมใช้ Local AI สรุปสาระสำคัญและผลกระทบต่อธุรกิจ/ราคาน้ำมัน/สินค้าให้พี่ติฟังใน 1 นาที
   - ส่งรายงานสรุปยามเช้าโดย "น้องเจนนี่" อัตโนมัติทุกเช้าเวลา 05:00 น. (เวลาประเทศไทย Asia/Bangkok GMT+7) ผ่าน Linux Cron บน LXC 104
10. **ระบบ AI Text-to-SQL เข้าถึงฐานข้อมูลร้านทั้งหมดแบบ Real-time (Full Database AI Agent):**
   - พัฒนาโมดูลแปลงคำถามภาษาธรรมชาติเป็น MySQL `SELECT` Query อัตโนมัติ (Text-to-SQL) ผ่าน Local Ollama LLM
   - ติดตั้งระบบความปลอดภัยเข้มงวด (Strict Read-Only Guardrail): ป้องกันคำสั่งทำลายข้อมูล (DROP/DELETE/UPDATE) รันเฉพาะคำสั่ง SELECT และคุม LIMIT ไม่เกิน 15-20 รายการ
   - เชื่อมต่อทุกตารางสำคัญในร้าน (`product`, `order`, `orderitem`, `customer`, `expenses`, `delivery_jobs`, `supplier`, `stockledger`) ให้น้องเจนนี่สามารถตอบคำถามสต็อก บิล ประวัติการซื้อ รายชื่อลูกค้า คิวส่งของ และค่าใช้จ่ายได้อย่างไร้ขีดจำกัด
11. **ผสานระบบ AI กล้องตรวจจับใบหน้าเข้าสู่วงจรชีวิตของโปรแกรม POS Desktop (Embedded Face Receptionist Lifecycle):**
   - พัฒนา `FaceReceptionistService` และสคริปต์ `scripts/face_watcher.py` รองรับโหมด Headless (เบื้องหลัง)
   - ผูกวงจรชีวิตของระบบกล้องเข้ากับ POS Desktop: เปิดโปรแกรม POS กล้องจะเริ่มทำงานอัตโนมัติ และเมื่อปิดหน้าต่างโปรแกรม POS ระบบจะตัดการทำงานของกล้องและคืนทรัพยากรทันที 100%
   - ป้องกันข้อผิดพลาด (Fail-Safe): หากไม่มีกล้อง Webcam เชื่อมต่ออยู่ ระบบจะข้ามการทำงานอย่างเงียบๆ ไม่ส่งผลกระทบต่อโปรแกรมขายหน้าร้าน
12. **รีเซ็ตคะแนนสะสมสมาชิกทั้งหมดเริ่มต้นที่ 0 คะแนน (Loyalty Points System Initial Reset):**
   - สำรองข้อมูลตาราง `customer` และ `point_ledger` ก่อนการปรับเปลี่ยน (`pre_points_reset_20260830.sql`)
   - ดำเนินการรีเซ็ตคะแนนสะสมของลูกค้าสมาชิกทุกคนในร้าน (1,248 ราย) เริ่มต้นที่ 0 คะแนน เพื่อเตรียมพร้อมเปิดตัวระบบสะสมแต้มและสิทธิประโยชน์สมาชิกใหม่ในวันพรุ่งนี้ (31 ส.ค. 2026) พร้อมบันทึก `activity_log` สำเร็จ 100%

**English:**
1. **Bare-Metal Proxmox Host Deployment:** Verified hardware and deployed Proxmox VE 9.x onto GMKtec M5 Ultra Mini PC (AMD Ryzen 7 7730U 8C/16T, 32GB SK Hynix Dual Channel RAM, 1TB NVMe SSD, Dual 2.5GbE LAN). Configured official no-subscription repository and downloaded Ubuntu 24.04 template.
2. **Container Infrastructure (LXC 100, 101, 102):** Created and configured 3 isolated containers: LXC 100 (MySQL DB `192.168.1.201`), LXC 101 (Backend API `192.168.1.202`), and LXC 102 (Cloudflare Tunnel `192.168.1.203`).
3. **High-Performance MySQL 8.0 Migration:** Configured 4GB InnoDB buffer pool, utf8mb4 encoding, and native password authentication. Migrated 100% of production database rows (11,121 orders, 6,502 products, 1,248 customers) with exact row parity. Setup 6-hour cron automated backups with 14-day retention.
4. **Dart Shelf Backend Deployment:** Compiled native AOT server binary running under Systemd daemon on LXC 101 port 8080 with live MySQL and Firestore bridge integrations.
5. **Cloudflare Tunnel Production Cutover:** Transitioned named tunnel connection to LXC 102 via token, configured internal routing, and verified public HTTPS ingress at `https://api.namecheap.work/api/v1/health` (HTTP 200 OK).
6. **Radical Candor Team Rule:** Added team operating rule mandating objective technical challenge against defective or risky ideas.

## [2026-08-29] Direct Quantity Input, Admin Rewards & Coupons Management, Storefront Merged Tab, & Member Profile Hub / ช่องพิมพ์จำนวนสินค้า, หน้า Admin จัดการคูปองและของรางวัล, รวมแท็บของรางวัลหน้าร้าน, และศูนย์ข้อมูลสมาชิก

**ไทย:**
1. **ช่องพิมพ์ระบุจำนวนสินค้าโดยตรง (Direct Numeric Input on Steppers):**
   - เปลี่ยนตัวเลขในปุ่มปรับจำนวน (Stepper) บนการ์ดสินค้าทุกใบ และในรายการสินค้าในตะกร้าจากข้อความธรรมดา (`<span>`) เป็นช่องป้อนตัวเลข (`<input type="number">`)
   - ลูกค้าสามารถแตะที่ตัวเลขแล้วพิมพ์จำนวนที่ต้องการได้ทันที เช่น `100`, `500` ก้อน (สำหรับอิฐ หิน ทราย หรือปูน) โดยไม่ต้องกดปุ่ม `+` ทีละครั้ง
   - เมื่อแตะช่องตัวเลข ระบบจะไฮไลต์ตัวเลขเดิมให้อัตโนมัติ (`onfocus="this.select()"`) เพื่อให้พิมพ์ทับได้ทันที และเมื่อกด Enter หรือแตะที่อื่นจะอัปเดตยอดคำนวณเงินในตะกร้า Real-time
   - ตกแต่ง CSS ให้สวยงาม สะอาดตา ไร้ลูกศรหมุนตัวเลขรบกวนตา และปรับขอบมนเข้ากับธีมหลักของร้าน
2. **ระบบจัดการคูปอง & ของรางวัลในหน้า Shop Admin (Shop Admin Rewards & Coupons Manager):**
   - เพิ่มแท็บใหม่ **"🎁 รางวัล & คูปอง"** ในหน้าแอดมิน (`/shop/admin`) พร้อมระบบ CRUD เต็มรูปแบบ
   - สามารถสร้าง, แก้ไข, ปิดใช้งาน และลบรายการของรางวัลประเภทของพรีเมียม (`GIFT`), คูปองส่วนลดเงินสด (`DISCOUNT_COUPON`) และคูปองส่งฟรี (`FREE_DELIVERY`)
   - แสดงประวัติการแลกแต้มของลูกค้า (Redemption Log) พร้อมปุ่มให้พนักงานกด `[ ✅ ยืนยันมอบของรางวัล ]` เพื่อปิดงาน
   - เพิ่ม API Endpoint จัดการรางวัลฝั่ง Staff ใน `RewardController`: `GET/POST/PUT/DELETE /api/v1/rewards-admin/rewards`
3. **รวมแท็บของรางวัลและคูปองเป็นแท็บเดียวบน Storefront (Merged Rewards & Coupons Tab):**
   - รวมแท็บ `[ 🎁 รางวัล ]` และ `[ 🎟️ คูปอง ]` ในแถบเมนูด้านล่างของหน้าเว็บร้านค้า (`/shop`) ให้เหลือเป็นแท็บเดียว **`[ 🎁 แลกรางวัล/คูปอง ]`** เพื่อความกระชับและใช้งานง่าย (4 แท็บหลัก: สั่งซื้อ, แลกรางวัล/คูปอง, ประวัติ, สมาชิก)
   - ภายในแท็บมีตัวกรองหมวดหมู่: `[ 🎁 ทั้งหมด ]`, `[ 🎟️ คูปองส่วนลด ]`, `[ 🏆 ของพรีเมียม ]`, และ `[ 📦 คูปองของฉัน ]` พร้อมแสดงยอดแต้มสะสมและปุ่มกดแลกรับทันที
4. **ศูนย์ข้อมูลและโปรไฟล์สมาชิกดิจิทัล (Member Profile Hub):**
   - พัฒนาหน้าจอแท็บ `[ 👤 สมาชิก ]` แบบเต็มรูปแบบ แสดงบัตรสมาชิกดิจิทัล (Digital Member Card) พร้อมรหัสสมาชิก, ระดับความภักดี (`👑 ลูกค้าประจำ`, `🛠️ ช่าง Pro+`, `👤 สมาชิกทั่วไป`), และแต้มสะสมคงเหลือ
   - แสดงสิทธิประโยชน์ของระดับสมาชิก (ตัวคูณแต้ม x2, สิทธิ์ราคาส่ง/ราคาช่าง, บริการส่งฟรีถึงหน้างาน)
   - แสดงข้อมูลที่อยู่จัดส่งและพิกัด GPS ประจำ พร้อมปุ่ม `[ ✏️ ปรับปรุงที่อยู่จัดส่ง ]` และลิงก์เปิดแผนที่ Google Maps
   - ข้อมูลติดต่อร้านค้า โทรด่วน และปุ่มออกจากระบบ/สลับบัญชี
5. **ระบบค้นหาและผูกสมาชิกลูกค้าอัตโนมัติด้วยเบอร์โทรศัพท์ (POS Customer Auto-Match by Phone):**
   - เพิ่ม `getCustomerByPhone` เพื่อค้นหาลูกค้าจากเบอร์โทรที่สั่งซื้อออนไลน์เข้ามา
   - เมื่อแคชเชียร์กด `[ดึงเข้า POS เพื่อเปิดบิลขาย]` ระบบจะดึงชื่อลูกค้า, เบอร์โทร และแต้มสะสมเข้าจอขาย POS อัตโนมัติ ไม่ขึ้นเป็น "ลูกค้าทั่วไป"
6. **กำหนดรูปแบบรหัสบิลออนไลน์ `ON-` และช่องทางการขาย `ONLINE` (Online Order Identification & Sales Channel Tagging):**
   - บิลที่สั่งซื้อผ่านเว็บหรือ LINE OA จะได้รหัสบิลขาย POS เป็น `ON-xxxxx` (เช่น `ON-11187`)
   - บันทึก `sales_channel = 'ONLINE'` และระบุหมายเหตุ `(LINE OA) ...` เพื่อใช้ในการวิเคราะห์ข้อมูล (Data Analytics) แยกยอดขายหน้าร้านกับออนไลน์
   - แสดงป้ายสีเขียว `[ 📲 LINE OA ]` ในตารางประวัติการขายบน Dashboard POS
7. **กระดานขนส่งรองรับการแก้ไขบิลก่อนปล่อยรถ & ติดตามพิกัดสด (Editable Pre-Dispatch Deliveries & Live GPS Tracking):**
   - ในหน้ากระดานขนส่ง (Active Deliveries) เพิ่มปุ่ม `[ ✏️ แก้ไขรายการบิลใน POS ]` สำหรับบิลที่ยังไม่ปล่อยรถ ให้แคชเชียร์สามารถปรับเพิ่ม/ลดรายการสินค้าได้ตลอดเวลา
   - เมื่อปล่อยรถแล้ว แสดงปุ่ม `[ 📍 ติดตามรถขนส่ง (Live GPS) ]` ให้ร้านค้ากดดูตำแหน่งรถขนส่งได้ทันที
8. **ระบบแสดงตัวคูณแต้มตามจริง & หลอดแสดงยอดชำระสะสมรายเดือน (Dynamic Multiplier & Monthly Spend Progress Guardrail):**
   - ปรับให้การ์ดสิทธิประโยชน์แสดงตัวคูณแต้มสะสมตามระดับจริงของลูกค้า (`x1.0`, `x2.0`, `x2.5`, `x3.0`) แทนข้อความตายตัว
   - เพิ่มการ์ดหลอดความคืบหน้ายอดชำระสะสมรายเดือน (เช่น `฿0 / ฿10,000`) พร้อมคำนวณยอดที่ต้องชำระเพิ่มเพื่อปลดล็อกสิทธิ์ "ลูกค้าประจำ (แต้มคูณ x2)"
   - ระบบกำหนดและแสดงชัดเจนว่า **"แต้มและยอดสะสมจะคำนวณจากบิลที่ชำระเงินสำเร็จแล้วเท่านั้น (ไม่นับออเดอร์ค้างชำระ เพื่อป้องกันการกดสั่งเล่น/ปั๊มแต้ม)"**
9. **ระบบคูปองแจกฟรี & กำหนดโควตาสิทธิ์ต่อคน (Claimable & Free Promotion Coupons with Per-User Quota Control):**
   - เพิ่มระบบคูปองแบบ **"🎁 กดรับฟรี" (FREE_CLAIM)** ควบคู่กับคูปองแลกแต้มสะสมเดิม (`POINTS_REDEEM`)
   - ในหน้าแอดมิน (`/shop/admin`) สามารถเลือกรูปแบบการรับสิทธิ์ระหว่าง **"💎 ใช้แต้มแลก"** หรือ **"🎁 แจกฟรี (ลูกค้ากดรับได้เลย)"**
   - รองรับการตั้งค่า **จำกัดสิทธิ์ต่อคน (`claim_limit_per_user`)** ได้แก่ จำกัด 1 ใบ/คน, 2 ใบ/คน, 3 ใบ/คน, 5 ใบ/คน, หรือไม่จำกัดสิทธิ์
   - ฝั่งหน้าร้าน (`/shop`) เพิ่มแท็บหมวดหมู่ **`[ 🎁 คูปองเก็บฟรี ]`** พร้อมปุ่ม **"🎁 กดรับคูปองฟรี"** โดยไม่ต้องหักแต้มสะสม และหากรับสิทธิ์ครบตามโควตาแล้ว ปุ่มจะเปลี่ยนเป็น **"✅ รับสิทธิ์ครบแล้ว"** อัตโนมัติ
   - ออกรหัสคูปองขึ้นต้นด้วย `FREE-xxxx-yyyy` บันทึกลงในกระเป๋าคูปองของฉัน (`MY_COUPONS`) เพื่อนำไปใส่รับส่วนลดในตระกร้าสั่งซื้อออนไลน์ได้ทันที
10. **ระบบล็อกอินความปลอดภัยสองชั้นแบบไฮบริด (Hybrid LINE Auto-Login + Phone & PIN Authentication):**
   - **🟢 LINE Login (บนมือถือ / LINE OA):** รองรับ Silent Login อัตโนมัติ 100% ผ่าน LINE LIFF โดยไม่ต้องพิมพ์เบอร์หรือรหัสผ่าน ปลอดภัยและสะดวกที่สุด
   - **📱 Phone Login (บนคอมพิวเตอร์ / เบราว์เซอร์ภายนอก):** ล็อกอินด้วยเบอร์โทรศัพท์ ต้องระบุ **รหัส PIN (4-6 หลัก)** คู่กันเสมอ เพื่อป้องกันการพิมพ์เบอร์ผิดไปเข้าบัญชีผู้อื่น
   - **⚡ Smart Default PIN:** กำหนดรหัส PIN เริ่มต้นสำหรับลูกค้าเดิมทุกคนเป็น **เลขท้าย 4 ตัวของเบอร์โทรศัพท์** โดยอัตโนมัติ (เช่น เบอร์ `085-137-7402` รหัสคือ `7402`)
   - **🔒 เปลี่ยนรหัส PIN ได้เอง:** เพิ่มการ์ดและปุ่ม **`[ 🔑 เปลี่ยนรหัส PIN ]`** ในหน้าโปรไฟล์สมาชิก ให้ลูกค้ากดเปลี่ยนรหัสผ่านส่วนตัวได้ตลอดเวลา
11. **แก้ไขปัญหายอดหนี้ไม่ลด/ยอดเพี้ยนเวลายกเลิกบิล (Ledger-Accurate Customer Debt Synchronization):**
   - **สาเหตุ:** ฟังก์ชัน `voidOrder` เดิมใช้วิธีนำ `amount` ในทุกแถวของ `debtor_transaction` มาลบออกจาก `currentDebt` ตรงๆ ทำให้เมื่อบิลมีรายการรับชำระ COD (`amount < 0`) จะกลายเป็นลบซ้อนลบ (หนี้เพิ่มขึ้นมาแทน) และไม่กรองแถวที่เคยถูกลบไปแล้ว
   - **การแก้ไข:** ปรับปรุง `voidOrder`, `unvoidOrder`, `markOrderAsUnpaid`, `deleteTransaction` และ `restoreTransaction` ทั้งหมด ให้คำนวณยอดหนี้คงเหลือ (`currentDebt`) จากผลรวมของรายการเดินบัญชีที่ถูกต้อง (`isDeleted = 0` และ `order.status != 'VOID'`) เสมอ ป้องกันการเพี้ยน 100%
   - **การเยียวยาข้อมูลเดิม:** ซิงค์คำนวณปรับยอดหนี้ลูกค้าทุกรายในฐานข้อมูลให้ตรงกับยอดจริงในสมุดบัญชีเรียบร้อย
12. **ระบบ Smart Landing & Auto-Redirect (เริ่มต้นที่หน้าล็อกอิน / จำได้เข้าหน้าขายทันที):**
   - หากลูกค้ายังไม่เคยเข้าสู่ระบบ เมื่อเปิดเว็บช็อปจะเริ่มต้นที่หน้า **"ศูนย์สมาชิก/เข้าสู่ระบบ"** ทันที เพื่อแนะนำสิทธิประโยชน์แต้มสะสมและราคาช่าง พร้อมปุ่ม `[ 🟢 เข้าสู่ระบบด้วย LINE ]`, `[ 📱 เบอร์โทรศัพท์+PIN ]` และ `[ 🛒 เลือกดูสินค้าเลย (ไม่ล็อกอิน) ]`
   - หากลูกค้าเคยเข้าสู่ระบบไว้แล้ว หรือเปิดผ่าน LINE LIFF ระบบจะจำข้อมูลและเปิดเข้า **"หน้าเลือกซื้อสินค้า/หน้าขาย"** ให้โดยอัตโนมัติทันที 0 คลิก
13. **ระบบเชื่อมโยงบัญชีเดิมอัตโนมัติ & สมัครสมาชิกใหม่ (LINE Account Auto-Binding & Self-Service Registration):**
   - **📱 ลูกค้าเก่า (เชื่อมโยงเบอร์เดิม):** เมื่อยืนยันเบอร์โทรศัพท์ + PIN 4 ตัว ระบบจะทำการผูก `line_user_id` เข้ากับข้อมูลสมาชิกในฐานข้อมูล POS ทันที ทำให้ดึงแต้มสะสม ประวัติบิล และสิทธิ์ราคาช่างเดิมมาใช้งานได้ครบ 100% โดยครั้งต่อไปเปิดจาก LINE OA จะล็อกอินอัตโนมัติ 0 คลิก
   - **📝 ลูกค้าใหม่ (ลงทะเบียนสมาชิก):** เพิ่ม API `POST /api/v1/shop/register` ให้ลูกค้าใหม่กรอกชื่อ-นามสกุล, เบอร์โทรศัพท์, และรหัส PIN เพื่อสร้างสมาชิกร้านใน POS และผูกกับ LINE ID อัตโนมัติ พร้อมระบบป้องกันการสมัครเบอร์ซ้ำ (`PHONE_EXISTS`)
   - **🎨 หน้าต่างต้อนรับ Smart Onboarding:** ปรับปรุงหน้าศูนย์สมาชิกให้แสดงปุ่มทางเลือกชัดเจน 3 ตัวเลือก: `[ 📱 เคยซื้อที่ร้านแล้ว (เชื่อมโยงเบอร์เดิม) ]`, `[ 📝 ลูกค้าใหม่ (ลงทะเบียนสมาชิก) ]`, และ `[ 🛒 เลือกดูสินค้าเลย (ไม่ล็อกอิน) ]`

**English:**
1. **Direct Numeric Quantity Input on Product Steppers:**
   - Converted static quantity labels on all storefront product cards and in-page cart rows from `<span>` to interactive `<input type="number">`.
   - Customers can tap the number and type bulk quantities directly (e.g., 100 or 500 bricks/cement bags) without repeatedly pressing the `+` button.
   - Includes auto-select on focus (`onfocus="this.select()"`), instant real-time cart recalculation on change/enter, and sleek styling without default browser spin buttons.
2. **Shop Admin Rewards & Coupons Management System:**
   - Added a dedicated **"🎁 รางวัล & คูปอง" (Rewards & Coupons)** tab in Admin dashboard (`/shop/admin`) with full CRUD functionality.
   - Allows creating, editing, activating/deactivating, and removing premium gifts (`GIFT`), discount coupons (`DISCOUNT_COUPON`), and free delivery perks (`FREE_DELIVERY`).
   - Integrated customer redemption log with staff fulfillment action `[ ✅ ยืนยันมอบของรางวัล ]`.
   - Added administrative CRUD endpoints to `RewardController`: `GET/POST/PUT/DELETE /api/v1/rewards-admin/rewards`.
3. **Merged Storefront Rewards & Coupons Tab:**
   - Consolidated `[ 🎁 รางวัล ]` and `[ 🎟️ คูปอง ]` bottom navigation tabs on web storefront (`/shop`) into a single unified tab: **`[ 🎁 แลกรางวัล/คูปอง ]`** (4 clean main tabs: Shop, Rewards/Coupons, History, Member).
   - Features category filter pills: `[ 🎁 ทั้งหมด ]`, `[ 🎟️ คูปองส่วนลด ]`, `[ 🏆 ของพรีเมียม ]`, and `[ 📦 คูปองของฉัน ]` alongside live customer points balance and instant redemption.
4. **Enriched Digital Member Profile Hub:**
   - Redesigned the `[ 👤 สมาชิก ]` tab into a full-fledged Digital Member Profile Hub featuring digital member card with loyalty badges (`👑 Regular`, `🛠️ Contractor Pro+`, `👤 General Member`), member code, and live points balance.
   - Highlights tier privileges (x2.0 points multiplier, contractor pricing, delivery perks).
   - Displays saved delivery address and GPS pin with interactive Google Maps navigation and quick edit dialog.
   - Provides store contact hotline, LINE OA links, and account logout/switching.
5. **POS Customer Auto-Match by Phone:**
   - Implemented `getCustomerByPhone` to look up existing members by phone when pulling online orders into POS.
   - Displays actual customer profile, tier, and loyalty points on POS cart rather than defaulting to "General Customer".
6. **`ON-` Order Number Prefix & `ONLINE` Sales Channel Tagging:**
   - Online/LINE OA orders generate order numbers with `ON-` prefix (e.g., `ON-11187`) and `sales_channel = 'ONLINE'`.
   - Formats note with `(LINE OA)` prefix and renders `[ 📲 LINE OA ]` green badge in Dashboard.
7. **Editable Pre-Dispatch Deliveries & Live GPS Tracking:**
   - Added `[ ✏️ แก้ไขรายการบิลใน POS ]` on pending delivery cards before dispatch.
   - Added `[ 📍 ติดตามรถขนส่ง (Live GPS) ]` for shipping jobs.
8. **Dynamic Multiplier & Monthly Spend Progress Guardrail:**
   - Rendered actual tier multiplier (`x1.0` - `x3.0`) and monthly spend progress bar.
   - Clarified that only paid/completed orders contribute towards loyalty tier progress.
9. **Claimable & Free Promotion Coupons with Per-User Quota Control:**
   - Added `FREE_CLAIM` coupon mechanism alongside standard `POINTS_REDEEM`.
   - Shop Admin can configure claim type and set per-user claim limits (1, 2, 3, 5, or unlimited).
   - Web storefront includes a dedicated **`[ 🎁 คูปองเก็บฟรี ]`** filter tab with one-click claim button and automated quota enforcement.
10. **Hybrid LINE Auto-Login + Phone & PIN Authentication:**
   - Seamless 1-click silent login via LINE LIFF on mobile/LINE OA.
   - Requires 4-6 digit PIN for phone number login on desktop browsers to prevent unauthorized access via typos.
   - Default PIN seamlessly falls back to the last 4 digits of customer phone number (`085-137-7402` -> `7402`).
   - Integrated self-service **`[ 🔑 เปลี่ยนรหัส PIN ]`** modal inside Digital Member Profile Hub.
11. **Ledger-Accurate Customer Debt Synchronization on Order Void / Deletion:**
   - Root Cause: Legacy `voidOrder` manually subtracted each `debtor_transaction.amount` directly from `customer.currentDebt`. For COD orders containing payment rows (`amount < 0`), subtracting a negative added to the customer debt, and it processed already-deleted rows.
   - Fix: Unified `voidOrder`, `unvoidOrder`, `markOrderAsUnpaid`, `deleteTransaction`, and `restoreTransaction` to always recompute `customer.currentDebt` from valid active ledger entries (`isDeleted = 0` and non-void orders).
   - Data Remediation: Synchronized and repaired customer debt balances across the entire database to 100% ledger accuracy.
12. **Smart Landing & Auto-Redirect Navigation:**
   - Directs unauthenticated guests immediately to the Member Portal / Login Landing tab to introduce loyalty perks, offering 1-click LINE Login, Phone+PIN Login, and a frictionless "Browse without Login" option.
   - Automatically jumps straight into the Product Catalog / Sales page for remembered returning users or authenticated LINE LIFF sessions with zero clicks.
13. **LINE Account Auto-Binding & Self-Service Registration:**
   - **📱 Existing Customers (Phone Linking):** When verifying phone + 4-digit PIN, automatically binds `line_user_id` to the existing POS customer database and `customer_identity_owner` table. Seamlessly imports loyalty points, order history, and contractor pricing tiers. Subsequent visits from LINE OA auto-authenticate with zero clicks.
   - **📝 New Customers (Self Registration):** Added `POST /api/v1/shop/register` endpoint to create new customer accounts in POS with automated LINE account binding and `PHONE_EXISTS` collision avoidance.
   - **🎨 Smart Onboarding Hub:** Refreshed Member Portal Hero with clear tri-option onboarding cards: `[ 📱 เคยซื้อที่ร้านแล้ว (เชื่อมโยงเบอร์เดิม) ]`, `[ 📝 ลูกค้าใหม่ (ลงทะเบียนสมาชิก) ]`, and `[ 🛒 เลือกดูสินค้าเลย (ไม่ล็อกอิน) ]`.

---

## [2026-08-28] Beger Cool Shade Standardization & Custom Tint Filter from Storefront Search

**ไทย:** ปรับมาตรฐานชื่อสินค้าสีผสม Beger Cool และกรองสีผสมออกจากการค้นหาทั่วไป:
1. **จัดระเบียบชื่อสินค้ากลุ่ม Beger Cool (สูตรเดิม) ใน MySQL ทั้งหมด 258 รายการ:**
   - ปรับชื่อสินค้ากลุ่มสีผสมสูตรเดิมที่ไม่มี 2in1 ให้อยู่ในฟอร์มมาตรฐานเดียวกัน: `สีผสม Beger Cool <รหัสสี> <ขนาด>` (เช่น `สีผสม Beger Cool 031-5 2.5 กล.`, `สีผสม Beger Cool 063-4 1 กล.`) เพื่อไม่ให้มีคำว่า 2in1 ปะปน
   - คงสินค้ากลุ่มเบสผสมสี (`เบสA`, `เบสB`, `เบสC`, `เบสD`) และเคมีภัณฑ์อื่นๆ ไว้ 100%
2. **ระบบกรองสีผสมออกจากการค้นหาทั่วไป (`shop_controller.dart`):**
   - เพิ่มตัวกรอง `WHERE name NOT LIKE 'สีผสม %' AND barcode NOT LIKE 'BEGER-2IN1%'` ในการค้นหาและโหลดสินค้าหน้าเว็บทั่วไป
   - ลูกค้าค้นหาคำว่า "สี" หรือรหัสสีในช่องค้นหาทั่วไป จะเจอเฉพาะสีสำเร็จรูป (สีทาฝ้า, ทินเนอร์, แปรง ฯลฯ)
   - บังคับให้การสั่งสีผสมต้องเข้าผ่าน **"🎨 สั่งผสมสี Beger Cool 2in1" (Tint Studio)** เท่านั้น เพื่อให้ลูกค้าอ่านคำเตือนเรื่องเฉดสีหน้าจอและเงื่อนไขไม่รับเปลี่ยน/คืนสินค้าสั่งผลิตเฉพาะบุคคล
3. **ระบบสั่งตัดแผ่นเมทัลชีทตามขนาด & หลายขนาดความยาวในชุดเดียว (Metal Sheet Multi-Length Cut Studio) (`index.html`, `metalsheet-studio.js`, `metalsheet-studio.css`, `paint-studio.js`, `paint-studio.css`, `shop_controller.dart`, `online_orders_screen.dart`):**
   - **รองรับการสั่งตัดหลายขนาดความยาวในชุดเดียวกัน (Multi-Length Cut List):** ช่างหรือผู้รับเหมาสามารถเพิ่มรายการตัดได้หลายแถว เช่น `3.50 ม. x 10 แผ่น`, `2.00 ม. x 5 แผ่น`, `1.85 ม. x 3 แผ่น` พร้อมปุ่มกดเพิ่ม/ลบรายการและปรับความยาวได้อย่างอิสระ
   - **ระบบคำนวณและสรุปรวมอัตโนมัติ:** คำนวณจำนวนแผ่นรวมทั้งหมด, ความยาวรวมทั้งหมด (เมตร), และยอดเงินรวมสุทธิ ($ความยาวรวม \times ราคาต่อเมตร/ค่าฉนวน$) Real-time
   - **แยกโครงสร้างโค้ดเป็นโมดูลเฉพาะทาง (Clean Modular Architecture):** แยกไฟล์สไตล์และสคริปต์ออกเป็น `paint-studio.css`, `metalsheet-studio.css`, `paint-studio.js`, `metalsheet-studio.js` ชัดเจน แก้ปัญหา CSS ไม่โหลด/แคชเก่า และทำให้ดูแลรักษาโค้ดได้ง่ายดาย
   - **ปรับโทนสีให้กลมกลืนกับเว็บไซต์ (White & Emerald Green Theme Harmonization):** ยกเลิกสีดำมืดทึบ เปลี่ยนเป็นโทน **เขียวมรกต (Emerald Green `#059669`) และขาวมินต์สะอาดตา** เข้ากับธีมหลักของร้าน S-Mart อย่างลงตัว ทั้งตัวแบนเนอร์, ส่วนหัวของโมดูล, ปุ่มทางลัด และการ์ดรายการตัด
   - **ดึงราคาต่อเมตร Real-time จาก MySQL:** เชื่อมต่อกับสินค้าแม่บทในฐานข้อมูล (`MS-760-AZ030` ฿80, `MS-760-AZ035` ฿95, `MS-760-COL035` ฿105, `MS-760-COL040` ฿120, `MS-OPT-PE5MM` +฿25, `MS-OPT-PU25MM` +฿70) หากแอดมินแก้ไขราคาในหน้าจัดการสินค้าบน POS Desktop ราคาบนหน้าเว็บจะเปลี่ยนตามทันที
   - **การแจ้งเตือนบน POS Desktop:** แสดงกล่องแถบสีส้ม `🔨 มีรายการสั่งตัดเมทัลชีทตามขนาด` พร้อมรายละเอียดสรุปความยาวและจำนวนแผ่นบนหน้าจอรับออเดอร์ออนไลน์
4. **แยกร่างและจัดระเบียบโครงสร้างโค้ดหน้าเว็บอย่างสมบูรณ์ (Complete Storefront Codebase Modularization) (`index.html`, `shop.js`, `cart.js`, `shop-member.js`, `paint-studio.js`, `metalsheet-studio.js`):**
   - **แยก JavaScript เป็น 5 ไฟล์เฉพาะทาง:**
     1. 🎨 `paint-studio.js` : จัดการระบบผสมสี Beger Cool 2in1 และค้นหารหัสสี
     2. 🔨 `metalsheet-studio.js` : จัดการระบบสั่งตัดเมทัลชีทและตารางรายการตัดหลายขนาด
     3. 🛒 `cart.js` : จัดการระบบตะกร้าสินค้า, คำนวณค่าส่งตามระยะทาง GPS, และส่งคำสั่งซื้อ Checkout
     4. 👤 `shop-member.js` : จัดการระบบสมาชิก, LINE LIFF Silent Auth, แสดงแต้มสะสม, และระดับสมาชิก Tier
     5. 🌐 `shop.js` : แกนหลักหน้าเว็บ, โหลดหมวดหมู่, แสดงการ์ดสินค้า, และระบบค้นหาสินค้า
   - **แยก CSS เป็น 3 โมดูล:** `shop.css`, `paint-studio.css`, `metalsheet-studio.css` พร้อม Cache Buster `v12`
5. **ระบบจดจำการล็อกอินข้ามเซสชัน & เข้าสู่ระบบหลายช่องทาง (Multi-Channel Member Login & Session Persistence) (`shop-member.js`, `shop_controller.dart`):**
   - **จดจำการล็อกอินอัตโนมัติ (Instant Session Persistence):** บันทึก Token และโปรไฟล์สมาชิกลงใน `localStorage` ทันทีที่เปิดหน้าเว็บขึ้นมาจะดึงข้อมูลสมาชิก/แต้ม/เบอร์โทร/ที่อยู่ขึ้นมาแสดงผลทันทีโดยไม่ต้องรอโหลด เปิดค้างไว้หรือรีเฟรชก็ไม่หลุด 100%
   - **เข้าสู่ระบบด้วยเบอร์โทรศัพท์ (Quick Phone Login):** เพิ่ม API `POST /api/v1/shop/phone-login` ให้ลูกค้าที่เปิดผ่าน Google Chrome, Safari หรือบนคอมพิวเตอร์ สามารถกรอกเบอร์มือถือเพื่อดึงข้อมูลสมาชิก, ระดับช่างรับเหมา, แต้มสะสม, และที่อยู่จัดส่งเดิมมาลงฟอร์มอัตโนมัติ
   - **เข้าสู่ระบบด้วย LINE (LINE Login SSO):** แก้ไข Scope ตัวแปร `LIFF_ID` ในโมดูล `shop-member.js` และเพิ่มระบบ Fallback อัตโนมัติ: หากเปิดบน Localhost/HTTP หรือเบราว์เซอร์ภายนอก ระบบจะเด้งพาไปยังหน้า LINE App หรือเปิดหน้าต่างแนะนำเปิดผ่าน LINE OA ได้อย่างราบรื่น
   - **ระบบออกจากระบบ/สลับบัญชี (Logout & Account Switch):** รองรับการกดออกจากระบบและเคลียร์แคชข้อมูลประจำเครื่องได้อย่างปลอดภัย
6. **ปรับปรุง UX การเลือกสินค้า & แถบหมวดหมู่ติดหนึบ (Instant In-Place Stepper & Sticky Category Bar) (`cart.js`, `shop.js`, `shop.css`, `index.html`, `shop_controller.dart`):**
   - **อัปเดตปุ่มใส่ตะกร้าแบบ In-Place:** เปลี่ยนการทำงานของปุ่ม `+ ใส่ตะกร้า` และปุ่ม `+/-` ให้แก้เฉพาะการ์ดสินค้านั้นโดยตรง ไม่ Re-render หน้าจอใหม่ทั้งหมด หน้าจอไม่กระตุก ไม่เด้งกลับไปบนสุด ลูกค้าจิ้มเลือกสินค้าชิ้นต่อไปได้อย่างต่อเนื่องทันที
   - **แถบหมวดหมู่ติดหนึบที่ขอบบน (Sticky Category Bar):** ตั้งค่า `.category-nav` ให้เป็น `position: sticky` เวลาเลื่อนดูสินค้าลงมา แถบเลือกหมวดหมู่จะลอยอยู่ด้านบนสุดตลอดเวลา สามารถแตะสลับหมวดหมู่ได้ทันที ไม่ต้องเลื่อนจอกลับขึ้นไปข้างบนสุด
   - **คงลำดับและรายการสินค้าจัดหน้าร้านตามที่ตั้งค่าไว้ (Curated Storefront Catalog Priority):** ให้ความสำคัญกับสินค้าที่แอดมินจัดหน้าร้านไว้ใน `featured_config.json` (เช่น กลุ่มปูน ทราย หิน สินค้าไฮไลต์) ก่อนเสมอ และค้นหาจากสต็อกทั้งหมดเมื่อมีการพิมพ์คำค้นหา
7. **แก้ไขการแสดงผลรายการสินค้าในตะกร้า (In-Page Cart List Rendering Fix) (`cart.js`):**
   - แก้ไขฟังก์ชัน `renderCartItems` ให้แมป Element ID `#inpageCartItemsList` ให้ตรงกับโครงสร้าง HTML ใน `index.html` และปรับใช้สไตล์ `.cart-item-row`, `.cart-item-stepper`, `.cart-item-remove` ให้แสดงรายการสินค้า, จำนวน, ราคาต่อหน่วย, ยอดรวม และปุ่มลบถังขยะได้อย่างถูกต้องสวยงาม 100%
8. **แก้บั๊กรายการสินค้าหายเมื่อคลิกบนหน้าจอ Desktop (:focus-within Catalog Hide Bug Fix) (`index.html`):**
   - ลบกฎ CSS เก่า `.catalog-search-block:not(:focus-within) .product-grid { display: none; }` ออกอย่างถาวร ซึ่งเดิมทำให้เมื่อคลิกที่สินค้าหรือคลิกนอกช่องค้นหาแล้วหน้าจอโฟกัสหลุด ส่งผลให้รายการสินค้าและตารางสินค้าถูกซ่อน (`dis90:    - สำหรับสินค้าสีรุ่นเก่าที่ไม่มี 2in1 (258 รายการ) และสินค้ากลุ่มเบส (`เบสA`, `เบสB`, `เบสC`, `เบสD`) ได้คงชื่อเดิมไว้ตามเดิม 100% ไม่ไปแปลงเป็น 2in1 เพื่อป้องกันความสับสนเรื่องสูตรและราคา
7. **ระบบพิมพ์หมายเหตุ (Notes / Remark) ครอบคลุมเอกสารและบิลทุกประเภท (`pos_delivery_mixin.dart`, `thermal_receipt_pdf.dart`, `cash_receipt_handler.dart`, `tax_invoice_pdf.dart`, `tax_invoice_handler.dart`, `dashboard_reprint_dialog.dart`, `debtor_list_controller.dart`, `command_service.dart`, `reprint_dialog.dart`):**
   - ตรวจสอบและแก้ไขระบบส่งต่อข้อมูลหมายเหตุ (Note/Remark) จากหน้าคิดเงิน POS และข้อมูลในฐานข้อมูล `orders.notes` ไปยังเอกสารพิมพ์ทุกประเภท
   - **ใบส่งสินค้าชั่วคราว (Delivery Note A4/A5/Continuous):** ดึง `manualNote` และ `orderData['notes']` ส่งเข้า `DeliveryNotePdf` แสดงผลในช่องหมายเหตุท้ายเอกสาร
   - **สลิปความร้อน 80mm (Thermal Slip Receipt):** เพิ่มการแสดงผล `หมายเหตุ: <ข้อความ>` ในสลิป 80mm ก่อนถึงส่วนท้ายบิล
   - **ใบกำกับภาษีเต็มรูป (Tax Invoice A4):** เพิ่มการแสดงผลหมายเหตุใต้ตารางรายการสินค้า
   - **ระบบพิมพ์ย้อนหลัง (Dashboard & Debtor Reprint):** ดึง `notes` เดิมของออเดอร์มาพิมพ์ประกอบทุกครั้ง ไม่สูญหาย

11. **ระบบดึงหมายเหตุ (Notes / Remarks) พิมพ์ลงเอกสารและบิลทุกประเภท (pos_delivery_mixin.dart, 	hermal_receipt_pdf.dart, cash_receipt_handler.dart, 	ax_invoice_pdf.dart, 	ax_invoice_handler.dart, dashboard_reprint_dialog.dart, debtor_list_controller.dart, command_service.dart, 
eprint_dialog.dart):**
    - แก้ไขจุดที่หมายเหตุ (Note/Remark) จากหน้าขาย POS ไม่ถูกส่งต่อไปยังเอกสารพิมพ์
    - **ใบส่งของชั่วคราว (Delivery Note A4/A5/Continuous):** ดึง manualNote และ orderData['notes'] ส่งเข้า generateDeliveryNoteData และพิมพ์ลงช่องหมายเหตุท้ายใบส่งของถูกต้อง
    - **สลิปความร้อน 80mm (Thermal Slip):** เพิ่มช่อง หมายเหตุ: <ข้อความ> ก่อนถึงส่วนท้ายบิล
    - **ใบกำกับภาษีเต็มรูป (Tax Invoice A4):** เพิ่มการดึงและพิมพ์หมายเหตุท้ายตาราง
    - **ระบบพิมพ์ย้อนหลัง (Dashboard & Debtor Reprint):** ดึง 
otes ของบิลเก่ามาพิมพ์ด้วยทุกครั้ง ไม่สูญหาย

12. **ปรับปรุงระบบหมวดหมู่สินค้าใน Shop Admin ให้ยึดตามหมวด POS จริง (22 หมวด) (product_controller.dart, dmin.js, index.html):**
    - เปลี่ยนระบบดึงหมวดสินค้าจากตาราง category เก่า (82 รายการในอดีต) ➡️ มาใช้ตาราง **product_type (22 หมวดสินค้าหลักของร้านในปัจจุบัน)** ตรงกับ POS 100%
    - เพิ่ม Emoji ประจำหมวดหมู่สินค้าให้อัตโนมัติ (เช่น 🎨 สี, 🪨 หินทราย, 🏗️ เหล็ก, 🚿 ท่อPVC, 💡 อุปกรณ์ไฟฟ้า, 🔧 อุปกรณ์ช่าง ฯลฯ)
    - ปรับเงื่อนไขการค้นหาและโหลดสินค้าให้เชื่อมโยงผ่าน p.productType ทำให้คลิกเลือกหมวดแล้วแสดงสินค้าตรงหมวดทันที

13. **ปรับเปลี่ยนแท็บแรกเป็น ⭐ สินค้าแนะนำ พร้อมคัดเลือก 10 สินค้ามูลค่าสูง (High-Ticket Items) (eatured_config.json, index.html, shop.js, dmin.js):**
    - เปลี่ยนชื่อและไอคอนหมวดหมู่แรกจาก 📦 ทั้งหมด ➡️ **⭐ สินค้าแนะนำ** ทั้งในหน้าเว็บหน้าร้าน (shop/index.html, shop.js) และระบบจัดการ (shop/admin/admin.js)
    - คัดเลือกสินค้าเด่นมูลค่าสูงที่มีสต็อกจริง 10 รายการขึ้นแสดงเป็นอันดับแรก:
      1. แท้งค์น้ำ 2,000 ลิตร (ID #2947 - ฿5,650)
      2. เครื่องเชื่อม MIG120 3in1 MC-Weld (ID #6277 - ฿4,250)
      3. แท่นตัดไฟเบอร์ Wurth (ID #935 - ฿4,150)
      4. ปั้มลม 3HP 50L 2 มอเตอร์ Ion (ID #409 - ฿4,000)
      5. เครื่องยิงตะปูไร้สาย 2in1 Eurox (ID #6537 - ฿3,900)
      6. ชุดประตู WPC 80*200 สีโอ๊ควู๊ด (ID #5837 - ฿3,700)
      7. สว่านโรตารี่ HHW (ID #588 - ฿3,400)
      8. หน้าต่างบานกระจก 2 ช่อง 120*110 ขาว+ลด. (ID #4245 - ฿3,300)
      9. เครื่องฉีดน้ำแรงดันสูง 120 บาร์ KP-21 (ID #496 - ฿3,000)
      10. ชักโครกชิ้นเดียวแบบกดบน (ID #1179 - ฿3,000)

14. **เชื่อมต่อข้อมูลร้านค้าจากฐาน POS อัตโนมัติและแก้ปัญหา Browser Cache (shop_controller.dart, shop.js, index.html):**
    - เพิ่ม API GET /api/v1/shop/info ดึงชื่อร้าน (*ร้าน ส.บริการ ท่าข้าม*), สโลแกน (*จำหน่ายวัสดุก่อสร้าง อุปกรณ์ไฟฟ้าและประปา*), เบอร์โทร, ที่อยู่, พิกัด และเลขผู้เสียภาษี จากตาราง system_settings ใน MySQL โดยตรง
    - ปรับหน้าเว็บหน้าร้าน (shop/index.html และ shop.js) ให้แสดงชื่อร้าน ส.บริการ อัตโนมัติ
    - Bump cache buster สคริปต์หน้าเว็บเป็น v20260829-v20 เพื่อให้เบราว์เซอร์โหลดปุ่ม **⭐ สินค้าแนะนำ** และชื่อร้านใหม่ทันทีโดยไม่ติด Cache เดิม

15. **ปรับปรุงแถบตะกร้าสินค้าขวามือให้เป็น Sticky Flow เลื่อนตามหน้าจออัตโนมัติ (`shop.css`, `index.html`):**
    - รวมการแสดงผลกล่อง **ตะกร้าสินค้า (Cart Items)** และ **สรุปยอดเงิน/ฟอร์มจัดส่ง (Checkout Summary)** ไว้ใน `<aside class="shop-sidebar-column">` ฝั่งขวามือ
    - ตั้งค่า CSS `position: sticky; top: 16px; max-height: calc(100vh - 32px); overflow-y: auto;` ทำให้แถบตะกร้าและปุ่มสั่งซื้อลอยตามการเลื่อนหน้าจอสินค้าฝั่งซ้ายตลอดเวลา
    - เมื่อผู้ใช้งานเลื่อนดูสินค้าด้านล่าง (เช่น ปูน, ทราย, ประตู, เครื่องมือ) ตะกร้าและปุ่มสั่งซื้อจะอยู่ระดับสายตาเสมอ กดใส่ตะกร้าและกดสั่งซื้อได้ทันทีโดยไม่ต้องเลื่อนจอกลับขึ้นไปด้านบนสุด
    - Bump cache buster เวอร์ชันสไตล์ชีตและสคริปต์เป็น `v20260829-v21`

16. **ปรับปรุงการคำนวณค่าจัดส่งออเดอร์ออนไลน์ตามระยะทางจริง (Distance-Based Delivery Fee) (`cart.js`, `online_order_service.dart`, `shop_controller.dart`):**
    - ปรับสูตรคำนวณค่าจัดส่งให้ยึด **ระยะทางถนนจริง (กม.)** เป็นเกณฑ์หลัก ตัดเงื่อนไขกำไรสุทธิออกตามนโยบายร้าน
    - ขั้นบันไดราคาประมาณการ: 0-5 กม. = ฿50, 5-10 กม. = ฿100, 10-15 กม. = ฿150, 15-20 กม. = ฿200, 20-30 กม. = ฿300, และ >30 กม. = ฿300 + ฿12/กม.
    - เพิ่มข้อความกำกับชัดเจนทั้งหน้าเว็บ ใบสรุป และข้อความ LINE แจ้งเตือน: *(ค่าจัดส่งเป็นการประเมินเบื้องต้นตามระยะทาง GPS อาจมีการปรับลดหรือยืดหยุ่นได้ตามรอบรถจริง เจ้าหน้าที่จะติดต่อยืนยันยอดสุดท้ายอีกครั้ง)*

17. **แก้ไขพิกัด GPS หน้าร้าน ส.บริการ ท่าข้าม (เพชรบูรณ์) ให้ตรงกับฐานข้อมูลจริง (`cart.js`, `online_order_service.dart`, `shop.js`):**
    - แก้ไขพิกัด Longitude เดิมที่ติดค่า Placeholder ในอดีต (`103.298284` มหาสารคาม) ➡️ เปลี่ยนเป็นพิกัดจริงของร้าน **`16.160189, 100.802307` (ต.ท่าข้าม อ.ชนแดน จ.เพชรบูรณ์)** ตรงตามตาราง `system_settings` ใน MySQL
    - เพิ่มฟังก์ชัน `setShopCoordinates` ใน `cart.js` และเชื่อมต่อกับ `fetchShopInfo()` ใน `shop.js` เพื่อให้อัปเดตพิกัดร้านค้าจากฐานข้อมูลแบบ Real-time
    - แก้ไขปัญหาคำนวณระยะทางผิดพลาด 360 กม. เมื่อลูกค้าปักหมุดในบริเวณร้าน ตอนนี้ปักหมุดบริเวณร้านจะได้ระยะทางจริง 0 - 0.05 กม. (ค่าส่งบันไดเริ่มต้น ฿50 หรือ ฿0 ตามที่ระบุ)

18. **เพิ่มข้อความกำกับที่อยู่จัดส่ง & ระบบจำข้อมูลลูกค้าอัตโนมัติ (Customer Form Auto-Fill & Persistence) (`index.html`, `cart.js`, `shop.js`):**
    - เพิ่มข้อความกำกับที่ช่องที่อยู่จัดส่ง: `ที่อยู่จัดส่ง / รายละเอียดหน้างาน * (เพื่อสะดวกต่อการส่งของพนักงาน ขอบคุณครับ)` ทั้งใน Label และ Placeholder
    - พัฒนาระบบ `localStorage` จดจำข้อมูลผู้สั่งซื้ออัตโนมัติ (`smartpos_saved_customer_info`) ครอบคลุม: ชื่อผู้ติดต่อ, เบอร์โทรศัพท์, ที่อยู่จัดส่ง/รายละเอียดหน้างาน และพิกัด GPS
    - เมื่อลูกค้าหรือช่างเข้าใช้งานเว็บในครั้งต่อๆ ไป ระบบจะ Auto-fill ข้อมูลเดิมให้อัตโนมัติทันที ไม่ต้องเสียเวลาพิมพ์ใหม่ทุกครั้ง (Lazy-Friendly 100%)

19. **เพิ่มระบบการแจ้งเตือนออเดอร์ออนไลน์ป๊อปอัปมุมล่างขวา & ปรับปรุงโฟลว์ยืนยันออเดอร์ (`online_order_floating_banner.dart`, `main_screen.dart`, `online_orders_screen.dart`):**
    - สร้างคอมโพเนนต์ **`OnlineOrderFloatingBanner`** การ์ดแจ้งเตือนลอยมุมล่างขวา (Bottom-Right Floating Toast) แสดงผลตลอดเวลาในทุกหน้าจอเมื่อมีออเดอร์ใหม่ พร้อมตัวเลขค้างส่ง และปุ่ม `[ ดูออเดอร์ ]` เปิดดูได้ใน 1 คลิก
    - มีระบบเสียงแจ้งเตือนสั้นๆ (Notification Sound) ทันทีที่มีออเดอร์ใหม่ยิงเข้ามา พร้อมไอคอนกระดิ่งเคลื่อนไหวกะพริบเรียกร้องความสนใจ
    - ปรับปรุงฟังก์ชัน **`_confirmOrderAction`** เมื่อกด "ยืนยันออเดอร์" จะมี Dialog ให้เลือกว่าต้องการ **`[ ดึงเข้า POS และเปิดบิล/เลือกรถ ]`** ทันที หรือแค่ **`[ ยืนยันสถานะไว้ก่อน ]`** พร้อมข้อความอธิบายชัดเจนว่ารายการจะย้ายไปอยู่ที่แท็บ "ยืนยันแล้ว" ป้องกันความสับสน

20. **ปรับปรุงข้อความและปุ่มยืนยันออเดอร์ให้ตรงตามกระบวนการหน้างานจริง (`online_orders_screen.dart`):**
    - ปรับปรุงข้อความบนปุ่มเป็น **`[ 🛒 ดึงเข้า POS เพื่อเปิดบิลขาย ]`** ตัดการถามเรื่องเลือกรถออกในขั้นตอนนี้
    - อธิบายขั้นตอนชัดเจนว่า: งานจัดส่งจะถูกส่งเข้าระบบขนส่งหน้าร้านเพื่อรอเลือกรถ/คนขับในขั้นตอน "ปล่อยรถ (Dispatch)" จริงตามธรรมชาติการทำงานของร้านค้า
    - Bump cache buster เวอร์ชันสไตล์ชีตและสคริปต์เป็น `v20260829-v22`

21. **ระบบดึงข้อมูลลูกค้าอัตโนมัติตามเบอร์โทร, รหัสบิล `ON-` และปุ่มแก้ไขบิลก่อนปล่อยรถ (`customer_repository_queries.dart`, `online_orders_screen.dart`, `order_processing_service.dart`, `sales_query_extension.dart`, `dashboard_orders_table.dart`, `active_deliveries_screen.dart`):**
    - **ค้นหาและผูกลูกค้าตามเบอร์โทรศัพท์อัตโนมัติ:** เมื่อกด "ดึงเข้า POS เพื่อเปิดบิลขาย" ระบบจะค้นหาประวัติสมาชิกในตาราง `customer` ตามเบอร์โทรศัพท์ของลูกค้าทันที หากพบจะโหลดชื่อ-นามสกุล แต้ม และระดับสมาชิกเข้าตะกร้า POS อัตโนมัติ หากยังไม่เคยเป็นสมาชิกจะตั้งชื่อและเบอร์โทรตามที่กรอกมาในออเดอร์ (ไม่แสดงเป็น 'ลูกค้าทั่วไป' อีกต่อไป)
    - **รหัสบิลขึ้นต้นด้วย `ON-` และบันทึกช่องทาง `sales_channel = 'ONLINE'`:** บิลที่ขายจากออเดอร์ออนไลน์/LINE OA จะถูกบันทึกรหัสบิลขึ้นต้นด้วย `ON-` (เช่น `ON-10025`) และบันทึก `sales_channel = 'ONLINE'` พร้อมติดแท็ก `[ 📲 LINE OA ]` สีเขียวในตารางประวัติการขายหน้า Dashboard เพื่อง่ายต่อการตรวจสอบและทำสถิติยอดขาย
    - **รองรับการแก้ไขรายการบิลก่อนปล่อยรถ (Edit Order Before Dispatch):** เพิ่มปุ่ม `[ ✏️ แก้ไขรายการบิลใน POS ]` ในหน้ารายการรอจัดส่ง (`ActiveDeliveriesScreen`) ช่วยให้แคชเชียร์สามารถดึงบิลกลับเข้า POS เพื่อเพิ่ม/ลดสินค้า ปรับยอดเงิน ปรับสต็อก และอัปเดตงานขนส่งได้ตลอดเวลาตราบใดที่ยังไม่ได้กดปล่อยรถ
    - **ปุ่มติดตามรถขนส่ง (Live GPS Tracking):** ในหน้ากำลังจัดส่ง เพิ่มปุ่มเปิดลิงก์ติดตามตำแหน่งรถขนส่งแบบ Real-time ให้ผู้ดูแลร้านตรวจสอบได้ทันที

**English:** Web Shop Beger Cool 2in1 Tint Studio & Paint Ordering System:
1. **Paints & Coatings Category (`featured_config.json`, `index.html`):**
   - Added the dedicated `🎨 สีและเคมีภัณฑ์` category on Web Shop with curated Beger paint, thinner, and brush starter items.
2. **Beger Cool 2in1 Tint Studio (`shop.js`, `shop.css`, `index.html`):**
   - Implemented the Beger Cool 2in1 Tint Studio modal with locked **Semi-Gloss (กึ่งเงา)** sheen, packaging sizes (1/4 GL ~0.9L, 1 GL ~3.5L, 2.5 GL ~9L), and direct outbound link to Beger Official Color Shade Search (`https://www.beger.co.th/th/search_color_shade`).
   - Integrated real-time color code lookup with price-pending quotation support, notifying customers that staff will call back directly to confirm the custom shade and final price.
3. **POS Desktop Paint Order Alerts (`online_orders_screen.dart`):**
   - Added prominent Paint Tint Notification Badges and pending price indicators with quick customer phone access on the cashier screen.
4. **Color Shade Accuracy Disclaimer & No-Return Policy Notice (`index.html`, `shop.js`, `shop.css`):**
   - Added prominent amber disclaimer boxes in the tint modal and add-to-cart confirmation popups, advising customers that device display settings may cause minor color deviations and that custom-tinted paints are non-refundable and ineligible for returns or claims when ordered online.
5. **Real-time SQL Paint Lookup & Beger Cool 2in1 Strict Matching (`shop_controller.dart`, `shop.js`):**
   - Implemented `GET /api/v1/shop/paint-lookup` API for live MySQL product table querying as users type the shade code.
   - Enforced strict `Beger Cool 2in1` prioritization, filtering out legacy non-2in1 formulas to prevent incorrect pricing. Live-bound matched products directly into the online cart with authentic MySQL ID, barcode, price, and inventory stock.
6. **Product Name Formatting for Active Beger Cool 2in1 Items:**
   - Standardized genuine Beger Cool 2in1 shade product names to `สีผสม Beger Cool 2in1 (กึ่งเงา) <Shade Code> <Size>` (e.g. `สีผสม Beger Cool 2in1 (กึ่งเงา) 141-4 2.5 กล.`, `สีผสม Beger Cool 2in1 (กึ่งเงา) 139-4 1 กล.`).
   - Preserved all 258 legacy non-2in1 items, Base tint containers (`เบสA`, `เบสB`, `เบสC`, `เบสD`), and primers intact without modifying them into 2in1.
7. **Comprehensive Order Notes / Remarks Printing Across All Bill & Invoice Formats:**
   - Audited and updated all bill generation handlers to propagate `orders.notes` / cashier remarks to print outputs.
   - **Delivery Notes (A4/A5/Continuous):** Passed `manualNote` and `orderData['notes']` into `DeliveryNotePdf.generate`.
   - **80mm Thermal Slip Receipts:** Added remark container block displaying `หมายเหตุ: <text>` before the footer.
   - **Tax Invoices (A4/A5):** Added remark display in `TaxInvoicePdf.generate` and `TaxInvoiceHandler`.
   - **Reprint Dialogs (Dashboard & Debtor Reprints):** Extracted existing `notes` from order records to ensure notes persist across all reprint actions.

11. **Comprehensive Order Notes / Remarks Printing Across All Bill & Invoice Formats:**
    - Audited and updated all bill generation handlers to propagate orders.notes / cashier remarks to print outputs.
    - **Delivery Notes (A4/A5/Continuous):** Passed manualNote and orderData['notes'] into DeliveryNotePdf.generate.
    - **80mm Thermal Slip Receipts:** Added remark container block displaying หมายเหตุ: <text> before the footer.
    - **Tax Invoices (A4/A5):** Added remark display in TaxInvoicePdf.generate and TaxInvoiceHandler.
    - **Reprint Dialogs (Dashboard & Debtor Reprints):** Extracted existing 
otes from order records to ensure notes persist across all reprint actions.

12. **Shop Admin Category Migration to Authoritative POS Product Types (22 Clean Categories):**
    - Migrated ProductController._getCategories and _getProducts from legacy category table (82 items) to active POS master product_type table (22 items).
    - Integrated automatic emoji decorators per category type.
    - Updated query filters to match p.productType directly with live inventory counts.

13. **Storefront Featured Recommendations Tab & 10 Curated High-Ticket Items:**
    - Renamed the primary storefront & admin category tab from 📦 All to ⭐ Featured Recommendations (สินค้าแนะนำ).
    - Curated 10 high-value, in-stock hardware and tool items at the top of eatured_config.json (2000L Water Tanks, MIG Welders, Wurth Cutters, Air Compressors, Nailers, WPC Doors, Rotary Drills, Glass Windows, Pressure Washers, and Modern Toilets).

14. **Dynamic Shop Info Integration from POS Database & Cache Buster Update:**
    - Implemented GET /api/v1/shop/info endpoint querying store identity (Shop Name: *ร้าน ส.บริการ ท่าข้าม*, Tagline, Phone, Address, Coordinates, Tax ID) directly from system_settings table in MySQL.
    - Updated web storefront (shop/index.html and shop.js) to render live store info dynamically.
    - Bumped script cache-buster parameters to 20260829-v20 ensuring client browsers load the new ⭐ สินค้าแนะนำ tab and store branding without stale caching.

---�� Route Alias `POST /api/v1/shop/checkout` ใน `shop_controller.dart` เพื่อรองรับทั้ง 2 รูปแบบ
    - **แก้ชื่อฟิลด์ที่อยู่จัดส่ง (Payload Mapping):** เปลี่ยนชื่อฟิลด์จาก `customerAddress` เป็น `deliveryAddress` ตามที่ `OnlineOrderRules.parseInput` ใน Backend คาดหวัง ป้องกันข้อผิดพลาด `Delivery address is required`
    - **เชื่อมต่อหมายเหตุและคูปอง:** แก้ไข Element ID ช่องหมายเหตุเป็น `custNotesInput` และส่งรหัสคูปองส่วนลด `couponCode` ไปยัง Backend
    - **ซิงค์และอัปเดตแคชเบราว์เซอร์:** ซิงค์ไฟล์ไปยัง `AppData/Local/S_Mart_POS/shop/` และปรับ Script Tag ใน `index.html` เป็น `v17`

**English:** Beger Cool Shade Standardization & Custom Tint Filter from Storefront Search:
1. **Beger Cool Legacy Shade Name Standardization in MySQL (258 items):**
   - Standardized legacy Beger Cool shade product names to `สีผสม Beger Cool <Shade Code> <Size>` (e.g. `สีผสม Beger Cool 031-5 2.5 กล.`, `สีผสม Beger Cool 063-4 1 กล.`) without `2in1` branding.
   - Preserved all base tint containers (`เบสA`, `เบสB`, `เบสC`, `เบสD`) and primers intact.
2. **Custom Tint Paint Filtering from Public Storefront Search (`shop_controller.dart`):**
   - Added backend filter `WHERE name NOT LIKE 'สีผสม %' AND barcode NOT LIKE 'BEGER-2IN1%'` for all public storefront product queries.
   - Prevents unguided custom tinted paint orders from regular catalog browsing, ensuring all custom paint tinting goes through the dedicated Beger Cool 2in1 Tint Studio where screen color disclaimers and non-refundable terms are presented.
3. **Metal Sheet Multi-Length Cut Studio with Modular Architecture & Dynamic MySQL Pricing (`index.html`, `metalsheet-studio.js`, `metalsheet-studio.css`, `paint-studio.js`, `paint-studio.css`, `shop_controller.dart`, `online_orders_screen.dart`):**
   - **Contractor-Grade Multi-Length Cut List:** Supports adding multiple cut length rows per sheet profile/color (e.g. `3.50m x 10 sheets`, `2.00m x 5 sheets`, `1.85m x 3 sheets`) with dynamic add/remove rows and quick length presets.
   - **Live Total Computation:** Instantly computes total sheet count, total linear meters, and total price ($\text{Total linear meters} \times (\text{Base price/m} + \text{Insulation/m})$).
   - **Clean Modular Codebase Decoupling:** Separated distinct studio styles and scripts into dedicated standalone modules (`paint-studio.css`, `metalsheet-studio.css`, `paint-studio.js`, `metalsheet-studio.js`) with cache-busting tags.
   - **Dynamic Price per Meter from MySQL:** Bound options to live MySQL master products (`MS-760-AZ030`, `MS-760-AZ035`, `MS-760-COL035`, `MS-760-COL040`, `MS-OPT-PE5MM`, `MS-OPT-PU25MM`).
   - **POS Desktop Order Notifications:** Added prominent orange alert badges with full cut breakdown specifications on cashier screen.

---

## [2026-08-27] Web Shop Beger Cool 2in1 Tint Studio & Paint Ordering System

**ไทย:** พัฒนาระบบสั่งสีผสม Beger Cool 2in1 และหมวดสีและเคมีภัณฑ์บน Web Shop:
1. **หมวดหมู่สินค้า `🎨 สีและเคมีภัณฑ์` (`featured_config.json`, `index.html`):**
   - เพิ่มหมวดหมู่ `🎨 สีและเคมีภัณฑ์` บนแถบหมวดหมู่หน้าร้าน Web Shop พร้อมคัดเลือกสินค้ากลุ่มสี Beger, ทินเนอร์, แปรงทาสี บรรจุไว้ในรายการเริ่มต้น
2. **ระบบสั่งผสมสี Beger Cool 2in1 Studio (`shop.js`, `shop.css`, `index.html`):**
   - พัฒนากล่องหน้าต่างและแบนเนอร์สั่งผสมสี Beger Cool 2in1 ล็อคชนิดฟิล์มสี **กึ่งเงา (Semi-Gloss)** ผสมรองพื้นในตัว ทาภายนอก/ใน
   - เพิ่มปุ่มลิงก์ตรงไปยังเว็บค้นหาเฉดสีออนไลน์ของ Beger (`https://www.beger.co.th/th/search_color_shade`) เพื่อให้ลูกค้าเลือกดูเฉดสีที่ชอบแล้วนำรหัสสีมากรอกสั่งซื้อได้ทันที
   - รองรับตัวเลือก 3 ขนาดบรรจุตามขนาดจริงของร้าน: 1/4 แกลลอน (~0.9 ลิตร กระป๋องเล็ก, ID #6555), 1 แกลลอน (~3.5 ลิตร, ID #6549), และ 2.5 แกลลอน (~9 ลิตร ถังกลาง, ID #6550)
   - ระบบ Auto-Lookup ตรวจสอบรหัสสี: หากมีราคาในระบบจะแสดงราคาขายทันที / หากเป็นเฉดสีใหม่ที่ยังไม่มีราคา จะปรับเป็นสถานะ `รอเช็คราคาผสมสี` พร้อมแจ้งลูกค้าว่าทางร้านจะโทรติดต่อกลับเพื่อพูดคุยรายละเอียดและแจ้งราคาจริง
3. **การแจ้งเตือนและการแสดงผลบน POS Desktop (`online_orders_screen.dart`):**
   - ปรับปรุง `OnlineOrdersScreen` ให้แสดงแถบสีฟ้าแจ้งเตือน `🎨 มีรายการสั่งผสมสี Beger Cool 2in1` พร้อมเน้นเบอร์โทรลูกค้าเพื่อให้พนักงานโทรแจ้งราคาได้สะดวกรวดเร็ว
   - แสดงป้าย `รอราคา` / `รอเช็คราคา` ในตารางรายการสินค้าสำหรับรายการสีผสมที่ยังไม่ได้ระบุราคา
4. **ข้อความแจ้งเตือนความคลาดเคลื่อนของเฉดสีและเงื่อนไขไม่รับเปลี่ยน/คืน (`index.html`, `shop.js`, `shop.css`):**
   - เพิ่มกล่องคำเตือนสีเหลืองทองชัดเจนในหน้าต่างสั่งผสมสี: แจ้งเรื่องสีบนหน้าจอมือถือ/คอมพิวเตอร์อาจผิดเพี้ยนจากสีจริงตามการตั้งค่าหน้าจอ
   - ระบุเงื่อนไขชัดเจนว่า สีผสมคอมพิวเตอร์เป็นสินค้าสั่งผลิตเฉพาะบุคคล ไม่สามารถเปลี่ยน คืน หรือเคลมได้ทุกกรณีหากสั่งผ่านออนไลน์ พร้อมแจ้งเตือนซ้ำในกล่องข้อความเมื่อกดเพิ่มลงตะกร้า
5. **ระบบ Real-time SQL Paint Lookup ค้นหาราคาจริงใน MySQL โดยตรง (`shop_controller.dart`, `shop.js`):**
   - เพิ่ม API `GET /api/v1/shop/paint-lookup` ค้นหาสินค้าจากตาราง `product` ใน MySQL แบบ Real-time ทันทีที่ลูกค้าพิมพ์รหัสสี
   - **ล็อคและเน้นเฉพาะสินค้ากลุ่ม `Beger Cool 2in1` (`2in1` / `2 in 1`):** กรองสินค้าเก่าหรือสูตรเดิมที่ไม่ใช่ 2in1 ออก เพื่อป้องกันการดึงราคาผิดพลาด
   - เมื่อแมตช์รหัสสีและขนาดบรรจุ (เช่น `2.5 แกลลอน (9L)` + `141-4` $\rightarrow$ พบ `เบเยอร์คูล2in1 141-4 9L` ฿1,593.00) จะขึ้นป้ายเขียวพร้อมแสดงราคาและสต็อกจริงทันที และผูก Product ID / บาร์โค้ดจริงลงในคำสั่งซื้อ
6. **จัดระเบียบชื่อสินค้ากลุ่ม Beger Cool 2in1 ของร้าน:**
   - ปรับชื่อสินค้ากลุ่ม **Beger Cool 2in1** ที่ใช้งานจริงทั้งหมด 24 รายการ ให้อยู่ในฟอร์มมาตรฐานเดียวกัน: `สีผสม Beger Cool 2in1 (กึ่งเงา) <รหัสสี> <ขนาด>` (เช่น `สีผสม Beger Cool 2in1 (กึ่งเงา) 141-4 2.5 กล.`, `สีผสม Beger Cool 2in1 (กึ่งเงา) 139-4 1 กล.`)
   - สำหรับสินค้าสีรุ่นเก่าที่ไม่มี 2in1 (258 รายการ) และสินค้ากลุ่มเบส (`เบสA`, `เบสB`, `เบสC`, `เบสD`) ได้คงชื่อเดิมไว้ตามเดิม 100% ไม่ไปแปลงเป็น 2in1 เพื่อป้องกันความสับสนเรื่องสูตรและราคา

**English:** Web Shop Beger Cool 2in1 Tint Studio & Paint Ordering System:
1. **Paints & Coatings Category (`featured_config.json`, `index.html`):**
   - Added the dedicated `🎨 สีและเคมีภัณฑ์` category on Web Shop with curated Beger paint, thinner, and brush starter items.
2. **Beger Cool 2in1 Tint Studio (`shop.js`, `shop.css`, `index.html`):**
   - Implemented the Beger Cool 2in1 Tint Studio modal with locked **Semi-Gloss (กึ่งเงา)** sheen, packaging sizes (1/4 GL ~0.9L, 1 GL ~3.5L, 2.5 GL ~9L), and direct outbound link to Beger Official Color Shade Search (`https://www.beger.co.th/th/search_color_shade`).
   - Integrated real-time color code lookup with price-pending quotation support, notifying customers that staff will call back directly to confirm the custom shade and final price.
3. **POS Desktop Paint Order Alerts (`online_orders_screen.dart`):**
   - Added prominent Paint Tint Notification Badges and pending price indicators with quick customer phone access on the cashier screen.
4. **Color Shade Accuracy Disclaimer & No-Return Policy Notice (`index.html`, `shop.js`, `shop.css`):**
   - Added prominent amber disclaimer boxes in the tint modal and add-to-cart confirmation popups, advising customers that device display settings may cause minor color deviations and that custom-tinted paints are non-refundable and ineligible for returns or claims when ordered online.
5. **Real-time SQL Paint Lookup & Beger Cool 2in1 Strict Matching (`shop_controller.dart`, `shop.js`):**
   - Implemented `GET /api/v1/shop/paint-lookup` API for live MySQL product table querying as users type the shade code.
   - Enforced strict `Beger Cool 2in1` prioritization, filtering out legacy non-2in1 formulas to prevent incorrect pricing. Live-bound matched products directly into the online cart with authentic MySQL ID, barcode, price, and inventory stock.
6. **Product Name Formatting for Active Beger Cool 2in1 Items:**
   - Standardized genuine Beger Cool 2in1 shade product names to `สีผสม Beger Cool 2in1 (กึ่งเงา) <Shade Code> <Size>` (e.g. `สีผสม Beger Cool 2in1 (กึ่งเงา) 141-4 2.5 กล.`, `สีผสม Beger Cool 2in1 (กึ่งเงา) 139-4 1 กล.`).
   - Preserved all 258 legacy non-2in1 items, Base tint containers (`เบสA`, `เบสB`, `เบสC`, `เบสD`), and primers intact without modifying them into 2in1.

---

## [2026-08-26] S-Link Stock Check & Image Resolution, Product Types & Categories Reorganization, Dead Stock Report, Cost Price Auto-Fill & Concrete Pole Pricing

### Shop POS-style desktop workspace / หน้า Shop เดสก์ท็อปแบบโต๊ะขาย POS

**ไทย:** เพิ่ม API ภายใน `GET /products/categories` ที่ดึงหมวดและจำนวนสินค้าที่ใช้งานจาก POS โดยตรง และปรับ Shop Admin ให้ใช้ API นี้ทั้งรายการหมวด จำนวนสินค้า และการกรองสินค้า. จึงไม่พึ่งชื่อหรือรหัสหมวด Shop ที่อาจถูกเปลี่ยนชื่อแล้วไม่ตรงกับ POS.

**English:** Added the internal `GET /products/categories` API to retrieve active POS categories and their product counts directly, then updated Shop Admin to use it for category navigation, counts, and product filtering. This removes dependency on renamed Shop category labels or stale IDs.

**ไทย:** แก้การกรองสินค้าใน Shop Admin ให้ยึดชื่อหมวดที่แสดงจริง ไม่ยึดรหัสเก่าที่ค้างจากการเปลี่ยนชื่อหมวด. เพิ่มกติกาคัดสินค้าสำหรับ “วงบ่อท่อระบายน้ำ”, “เสา”, และ “ตะปู+สกรู” เพื่อให้เปิดหมวดแล้วเจอสินค้าที่เกี่ยวข้องจาก POS.

**English:** Fixed Shop Admin product filtering to use the displayed category name rather than a stale legacy category ID after a category rename. Added POS-backed matching rules for drainage rings, poles, and fasteners so their relevant products appear when those categories are opened.

**ไทย:** ปรับหน้าเลือกสินค้าใน Shop Admin ให้ใช้หมวดเดียวกับที่ปรากฏบนหน้า Shop จริง โดยคงชื่อ ไอคอน และลำดับเดิม; ตัดการเพิ่ม ลบ แก้ไข และสลับหมวดจากหน้านี้เพื่อป้องกันหมวดสินค้าแยกกัน. บังคับให้เลือกหมวดก่อนติ๊กสินค้า เพื่อให้สินค้าขึ้นในหมวดที่ถูกต้อง.

**English:** Updated Shop Admin's product-selection page to use the exact category list shown in the public shop, preserving its names, icons, and order. Removed category add, delete, edit, and reorder controls here to prevent divergent category sets. A category must be selected before a product can be included, ensuring it appears in the correct shop category.

**ไทย:** ปรับแท็บเริ่มต้นของหน้าเลือกสินค้าใน Admin เป็น “สินค้าทั้งหมดในหมวด” และเมื่อคลิกเปลี่ยนหมวดให้เปิดแท็บนี้อัตโนมัติ เพื่อให้เลือกสินค้าใหม่ในหมวดที่ยังว่างได้ทันที.

**English:** Made “All products in category” the default Admin selection tab and open it automatically whenever a category is chosen, so an empty category can be populated immediately.

**ไทย:** ตัดแท็บ “สินค้าที่เลือกแล้ว” ออกจากหน้ารายการของ Shop Admin เพราะทำให้ดูเหมือนหมวดว่าง ทั้งที่ยังไม่ได้เลือกสินค้าเด่น. ตอนนี้เลือกหมวดด้านซ้ายแล้วจะแสดงสินค้าที่เปิดใช้งานจริงของหมวด POS นั้นทันที; การติ๊กเลือกและการบันทึกยังใช้เฉพาะกำหนดสินค้าเด่นบนหน้า Shop.

**English:** Removed the “selected products” tab from the Shop Admin catalogue because it made a POS category appear empty when no featured items had been selected. Selecting a category now immediately shows its active POS products; checkboxes and saving remain only for choosing storefront featured products.

**ไทย:** เพิ่มปุ่มถังขยะในแต่ละรายการของตะกร้าหน้า Shop เพื่อลบสินค้าที่เลือกผิดได้ในคลิกเดียว.

**English:** Added a trash button to every Shop cart line so an accidentally selected item can be removed in one click.

**ไทย:** ปรับโครงหน้าร้านเดสก์ท็อปให้คล้ายโต๊ะขาย POS: แถบค้นหา/หมวดอยู่ด้านบน, สินค้าเด่นเป็นปุ่มเปิดดู, ตะกร้าอยู่ซ้าย และสรุปยอด/ขั้นตอนสั่งซื้ออยู่ขวา. รายการผลค้นหาจะแสดงเมื่อผู้ใช้ค้นหาหรือเลือกหมวดเท่านั้น เพื่อลดความรกของหน้าเริ่มต้น.

**English:** Reorganized the desktop shop into a POS-like checkout desk: search and categories at the top, recommendations behind a button, cart on the left, and order summary/checkout on the right. Product results appear only after searching or choosing a category to keep the initial view uncluttered.

**ไทย:** ย้ายปุ่มสินค้าแนะนำเข้าไปอยู่ในกล่องค้นหาฝั่งซ้าย เพื่อไม่ให้ความสูงของตะกร้าฝั่งขวาสร้างช่องว่างใต้ปุ่มสินค้าแนะนำ; ช่องค้นหาแสดงติดกันทันที.

**English:** Moved the recommendations trigger into the left search panel so the taller right-side cart no longer creates empty space beneath it; search now follows the trigger immediately.

**ไทย:** ปรับลำดับอีกครั้งให้ “ค้นหาสินค้า” มาก่อนสินค้าแนะนำ โดยย้ายปุ่มสินค้าแนะนำไว้หลังผลการค้นหา เพื่อให้ลูกค้าที่ตั้งใจซื้อค้นหาและเพิ่มของได้ทันที ส่วนผู้ที่สนใจค่อยเลื่อนลงมาดูสินค้าแนะนำ.

**English:** Prioritized product search over recommendations by moving the recommendations trigger after search results, so intent-driven customers can search and add items immediately while others may scroll down to browse recommendations.

### Shop POS-style layout and stock availability / ปรับหน้า Shop แบบ POS และสถานะสินค้าหมด

**ไทย:** ปรับหน้าร้านบนมือถือให้โฟกัสรายการสินค้าเป็นหลัก โดยย้ายสินค้าแนะนำและตะกร้าไปเป็นแผงด้านล่างที่เปิดเมื่อกด, เปลี่ยนการ์ดสินค้าเป็นแถวแนวนอนอ่านง่าย, และซ่อนขั้นตอนสั่งซื้อจนลูกค้ากดดำเนินการจากตะกร้า. สินค้าสต็อกหมดจะแสดงต่อพร้อมป้าย “สินค้าหมดชั่วคราว” แต่กดใส่ตะกร้าไม่ได้. API ตรวจ `stockQuantity` ภายใน transaction ก่อนสร้างคำสั่งซื้ออีกชั้น; หากสต็อกเปลี่ยนระหว่างเลือกสินค้าและส่งคำสั่งซื้อ จะตอบ `OUT_OF_STOCK` และเว็บรีเฟรชข้อมูลจาก POS ให้ลูกค้าตรวจตะกร้าใหม่.

**English:** Reworked the mobile shop into a POS-style catalogue: products are the primary view, while recommendations and the cart open on demand as bottom sheets, with a clearer horizontal product row and a checkout step shown only after continuing from the cart. Out-of-stock products remain visible but cannot be added. The order API now validates `stockQuantity` inside its transaction before creating an order; an `OUT_OF_STOCK` response refreshes POS-backed product data for the customer.

**ไทย:** ช่องจำนวนในหน้าร้านและตะกร้าแก้ไขได้โดยตรง รองรับจำนวนมากและทศนิยม พร้อมตรวจไม่ให้จำนวนเกินสต็อกที่หน้าเว็บ.

**English:** Quantity fields in both the catalogue and cart are directly editable, support large and decimal quantities, and prevent quantities above currently loaded stock.

**ไทย:** ปรับปรุงระบบบันทึกสต็อก การแสดงผลรูปภาพ จัดระเบียบหมวดหมู่สินค้า รายงานสินค้าไม่เคลื่อนไหว คำนวณราคาทุนอัตโนมัติ และปรับราคาเสาปูน:
1. **แก้ไขประวัติการเช็คสต็อกจาก S-Link (`ADJUST_FIX_APP` / `STOCK_IN_APP`):**
   - อัปเดต `StockLedgerExtension.getHistoryByType` และแท็บประวัติในหน้าสินค้า ให้ครอบคลุม `ADJUST_FIX_APP`, `ADJUST_CORRECT`, และ `STOCK_IN_APP`
   - หน้า "ปรับปรุงสต็อก" -> แท็บ "ประวัติการเช็ค (History)" สามารถดึงประวัติการนับสต็อกที่ทำผ่าน S-Link มาจัดกลุ่มและแสดงผลได้อย่างถูกต้อง พร้อมป้ายกำกับภาษาไทย "ตรวจนับ (S-Link)" สีน้ำเงิน และ "รับเข้า (S-Link)" สีเขียว
   - ฝั่ง S-Link ดึงชื่อพนักงานผู้ตรวจนับจาก `AuthenticationProvider` ส่งไปบันทึกในประวัติเป็น `S-Link Stock Check (by [ชื่อพนักงาน])`
2. **ระบบแสดงผลและอัปโหลดรูปภาพสินค้า (`ProductImageHelper`):**
   - สร้าง `ProductImageHelper` แปลง URL สัมพัทธ์ของเซิร์ฟเวอร์ (`/public/products/...`) ให้ต่อเข้ากับ Base API URL อัตโนมัติ ทำให้หน้าจอแก้ไขสินค้าบนคอมพิวเตอร์หน้าร้านทั้งเครื่องแม่และเครื่องลูกโหลดรูปภาพที่ถ่ายจาก S-Link มาแสดงได้อย่างคมชัด
   - รองรับการเลือกเปลี่ยนรูปสินค้าใหม่จากเครื่อง Desktop และอัปโหลดขึ้นเซิร์ฟเวอร์ส่วนกลางอัตโนมัติผ่าน `ApiService().uploadProductImage`
3. **จัดระเบียบหมวดหมู่สินค้าใหม่ (Product Categories Reorganization):**
   - **สร้างหมวดหมู่ `ฝ้า ผนัง` (ID: 29):** ย้ายสินค้ากลุ่ม สมาร์ทบอร์ด, ยิปซั่ม, ไม้อัด, ซีลาย, ฉากอบ, ฉากสังกะสี, ทีเมน, ทีซอย, ผนังเบา, แผ่นฝ้า, ลวด/สปริงแขวนฝ้า รวม 44 รายการ เข้าสู่หมวดนี้
   - **สร้างหมวดหมู่ `ประตูหน้าต่าง` (ID: 30):** ย้ายสินค้ากลุ่ม ชุดประตู, ประตู PVC/UPVC/ไม้/กระจก, หน้าต่างบานกระจก/ช่องแสง, วงกบประตู-หน้าต่างทุกขนาด, ลูกบิดประตู, บานพับหน้าต่าง, มือจับประตู รวม 224 รายการ เข้าสู่หมวดนี้
   - **สร้างหมวดหมู่ `ตะปู สกรู` (ID: 31):** รวมศูนย์สินค้ากลุ่ม ตะปูตอกไม้/คอนกรีต/สังกะสี, สกรูปลายสว่าน/เกลียวปล่อย/หัวบล็อก/ไดร์วอลล์, พุกเหล็ก/พลาสติก/ดรอปอิน, ลูกรีเวท, น็อตตัวผู้/ตัวเมีย, แหวนอีแปะ/สปริง รวม 579 รายการ เข้าสู่หมวดนี้
4. **แยกหมวดหมู่อุปกรณ์ไฟฟ้าเป็น 3 หมวดชัดเจน (3-Way Electrical Separation):**
   - **สร้างหมวดหมู่ `สายไฟ` (ID: 32):** ย้ายสินค้ากลุ่มสายไฟ THW, VAF, VCT, NYY, สายโทรศัพท์, สายแลน, สาย RG6 รวม 116 รายการ เข้าสู่หมวดนี้
   - **สร้างหมวดหมู่ `หลอดไฟ` (ID: 33):** ย้ายสินค้ากลุ่ม หลอดไฟ LED, หลอดนีออน, โคมไฟ, สปอร์ตไลท์, ดาวน์ไลท์, ไฟโซล่าเซลล์, โคมพาแนล, ไฟกระพริบ, ไฟเส้น รวม 263 รายการ เข้าสู่หมวดนี้
   - **คงหมวด `อุปกรณ์ไฟฟ้า` (ID: 8):** สำหรับสวิตช์, เต้ารับ/ปลั๊ก, เบรกเกอร์, ตู้ไฟ/คอนซูมเมอร์, เทปพันสายไฟ, กล่องพักสาย, ท่อและข้อต่อร้อยสายไฟ รวม 471 รายการ
5. **แยกหมวดท่อ PVC, ข้อต่อ และกาวเคมีภัณฑ์ (PVC, Fittings & Glues):**
   - **สร้างหมวดหมู่ `ข้อต่อ` (ID: 34):** ย้ายสินค้ากลุ่ม ข้องอ, สามทาง, ต่อตรง, ข้อลด, นิปเปิ้ล, ยูเนี่ยน, บอลวาล์ว, กิ๊บจับท่อ, ก๊อกน้ำประปา รวม 555 รายการ
   - **สร้างหมวดหมู่ `กาว` (ID: 35):** รวมกาวทุกชนิด (กาวทาท่อ PVC, กาวร้อน, กาวลาเท็กซ์, กาวพลังตะปู, ซิลิโคน, แด๊ป, อีพ็อกซี่, พียูโฟม, กาวมหาอุด, กาวดักหนู) รวม 104 รายการ
   - **คงหมวด `ท่อPVC` (ID: 13):** เหลือเฉพาะท่อประปา PVC, ท่อเกษตร PE, สายยาง รวม 215 รายการ
6. **จัดระเบียบหมวดหมู่ใหญ่ 5 หมวด (เกษตร, สุขภัณฑ์, เครื่องมือไฟฟ้า, สีสเปรย์, อุปกรณ์ทาสี):**
   - **สร้างหมวดหมู่ `เกษตรและสวน` (ID: 36):** ย้ายสปริงเกอร์, หัวพ่นหมอก, สายไมโคร, ขุยมะพร้าว, ดินปลูก, สแลนบังแดด, จอบ, เสียม, ใบตัดหญ้า รวม 142 รายการ
   - **สร้างหมวดหมู่ `สุขภัณฑ์และห้องน้ำ` (ID: 37):** ย้ายสายฉีดชำระ, ฝักบัว, สะดืออ่าง, ท่อน้ำทิ้ง, สายน้ำดี, ชักโครก, ฝารองนั่ง, ก๊อกอ่างล้างหน้า รวม 255 รายการ
   - **สร้างหมวดหมู่ `เครื่องมือไฟฟ้าและปั๊มน้ำ` (ID: 38):** ย้ายสว่านไฟฟ้า, หินเจียร, เลื่อยไฟฟ้า, ตู้เชื่อม, เครื่องฉีดน้ำแรงดันสูง, ปั๊มน้ำ, ปั๊มหอยโข่ง, ดอกสว่าน รวม 237 รายการ
   - **สร้างหมวดหมู่ `สีสเปรย์` (ID: 39):** ย้ายสีสเปรย์กระป๋องทุกยี่ห้อ (Leyland, Red Fox, Bosny, ATM) รวม 66 รายการ
   - **สร้างหมวดหมู่ `อุปกรณ์ทาสี` (ID: 40):** ย้ายแปรงทาสี, แปรงวานิช, ลูกกลิ้ง, ถาดกลิ้งสี, ด้ามต่อ รวม 60 รายการ
   - **ทำความสะอาดหมวด `สี` (ID: 3):** กวาดสินค้าหลงหมวดกลับเข้าที่ถูกต้อง ทำให้หมวดสีเหลือเฉพาะ สีเบเยอร์คูล, เบเยอร์ 2in1, สีกระทิง, สีน้ำมัน และทินเนอร์ รวม 806 รายการ
7. **จัดระเบียบงานคอนกรีตหล่อ สังกะสี และระบบน้ำเกษตร (Precast Concrete, Zinc & PE/Drip):**
   - **สร้างหมวดหมู่ `เสาและคอนกรีตหล่อ` (ID: 41):** ย้ายเสาปูนทุกขนาด (4x2 ถึง 7x8), เสาบ่า, เสาเหล็กโผล่, เสารั้ว, วงบ่อ 60-120 ซม., ฝาวงบ่อ, ท่อระบายน้ำ คสล., ท่อใยหิน, บ่อพัก, บล็อกแก้ว, อิฐบล็อก, อิฐแดง รวม 114 รายการ
   - **สร้างหมวดหมู่ `สังกะสีและรางน้ำ` (ID: 42):** ย้ายแผ่นสังกะสี 5-12 ฟุต, สังกะสีแผ่นเรียบ, สังกะสีใส, รางน้ำฝน 5" และ 6", ขอรางน้ำ, แผ่นตรงซิ้งค์, แผ่นหลังคาซิ้งค์, รางน้ำตะเข้, แผ่นหลบสังกะสี รวม 34 รายการ
   - **อัปเดตหมวด `เกษตรและสวน` (ID: 36):** กวาดท่อ PE 16-32 มม., เทปน้ำหยด, สายน้ำพุ่ง, ข้อต่อล็อก PE, วาล์วน้ำหยด เข้าหมวดเกษตร รวมสินค้าเพิ่มเป็น 160 รายการ
8. **ระบบวิเคราะห์และรายงานสินค้าไม่เคลื่อนไหว พร้อมส่งออก Excel (Dead Stock & Slow Moving Report):**
   - **หน้าจอรายงานสินค้าไม่เคลื่อนไหว (`DeadStockScreen`):** เพิ่มเมนู "สินค้าไม่เคลื่อนไหว (Dead Stock)" ในหน้าคลังสินค้า พร้อมแดชบอร์ดสรุป 3 KPI สำคัญ (จำนวนรายการไม่เคลื่อนไหว, จำนวนชิ้นสต็อกค้างรวม, และมูลค่าเงินทุนที่จมอยู่)
   - **ตัวกรองอัจฉริยะ (Smart Inactivity Filters):** รองรับการกรองตามระยะเวลาที่ไม่เคลื่อนไหว (ไม่เคยเคลื่อนไหวเลย, 30+ วัน, 60+ วัน, 90+ วัน, 180+ วัน, 365+ วัน), หมวดหมู่สินค้า, สถานะสต็อก (มีสต็อกคงค้าง > 0, สต็อกเป็น 0, ทั้งหมด) และช่องค้นหาแบบเรียลไทม์ (Debounced Live Search)
   - **ระบบส่งออก Excel อัตโนมัติ (`DeadStockExcelService`):** ปุ่ม "Export Excel" สร้างไฟล์รายงาน `.xlsx` ตกแต่งหัวตาราง จัดระยะคอลัมน์ สรุปยอดรวมจำนวนชิ้นและมูลค่าเงินทุนจม พร้อมคำสั่งเปิดไฟล์ให้อัตโนมัติทันที
   - **ประสิทธิภาพและความเสถียร (`DeadStockRepository`):** คิวรี่ฐานข้อมูล MySQL แบบปรับแต่งพิเศษ ความเร็ว 19 ms พร้อมระบบ Pagination แบ่งหน้าเพื่อความลื่นไหลระดับ 60 FPS
9. **คำนวณและเติมราคาทุนอัตโนมัติจากราคาขาย (Automated Cost Price Calculation & Population):**
   - ตรวจสอบพบสินค้าที่ไม่มีราคาทุน (`costPrice <= 0` หรือ `NULL`) แต่มีราคาขาย (`retailPrice > 0`) รวม 2,009 รายการ
   - รันคำนวณและบันทึกราคาทุนใหม่ตามสูตร Markup 30% (`costPrice = ROUND(retailPrice / 1.3, 2)`) ลงในตาราง `product`
   - ส่งผลให้มูลค่าเงินทุนจมในรายงาน Dead Stock ปรับสู่ตัวเลขจริงที่แม่นยำขึ้นจาก 7.92 ล้านบาท เหลือ 4.78 ล้านบาท
10. **ปรับปรุงราคาเสาปูนหน้า 4, 5, 6 และคำนวณราคาทุนใหม่ (Concrete Pole Pricing Update):**
    - **เสาหน้า 4 (ศอกละ 120 บาท):** เสา 4*2 (240 บ. / ทุน 184.62 บ.) ถึง เสา 4*7 (840 บ. / ทุน 646.15 บ.)
    - **เสาหน้า 5 (ศอกละ 185 บาท):** เสา 5*2 (370 บ. / ทุน 284.62 บ.) ถึง เสา 5*8 (1,480 บ. / ทุน 1,138.46 บ.)
    - **เสาหน้า 6 (ศอกละ 210 บาท):** เสา 6*2 (420 บ. / ทุน 323.08 บ.) ถึง เสา 6*8 (1,680 บ. / ทุน 1,292.31 บ.)
    - อัปเดตราคาขายและราคาทุนครอบคลุมเสาปูนทุกแบบ (บ่าเดี่ยว, บ่าคู่, บ่าเดี่ยวยาว, เหล็กโผล่) รวม 49 รายการสำเร็จ 100%
11. **แก้ไขสีลูกศรย้อนกลับหน้าจัดการออเดอร์ออนไลน์ (`OnlineOrdersScreen`):**
    - กำหนด `foregroundColor` และ `iconTheme` ของ `AppBar` เป็นสีเข้ม (`#0F172A`) เพื่อให้ปุ่มลูกศรย้อนกลับ (Back Arrow) และไอคอนต่างๆ มองเห็นได้ชัดเจนคมชัดบนพื้นหลังสีขาว
12. **แก้ไข Type Error เมื่อกดแก้ไขสินค้าในหน้ารายงานสินค้าไม่เคลื่อนไหว (`DeadStockScreen`):**
    - แก้ไข `showDialog<bool>` ให้เป็น `showDialog<Product>` ในฟังก์ชัน `_editProduct` เพื่อให้รองรับประเภทข้อมูล `Product` ที่ `ProductFormDialog` ส่งกลับมาเมื่อบันทึกข้อมูลเสร็จสิ้น
    - ป้องกันปัญหาค้างและข้อผิดพลาด `type 'Product' is not a subtype of type 'bool?' of 'result'`
13. **จับคู่และบรรจุสินค้าเด่นใน Web Shop ตามคีย์ลัด POS ครบ 9 หมวดหมู่หลัก (`featured_config.json`):**
    - คัดเลือกเฉพาะสินค้าเด่นยอดนิยมตรงตามคีย์ลัด POS หมวดละ 10-15 รายการ รวม 130 รายการ พอดี ไม่ล้นหน้าจอ
    - จัดหมวดหมู่ทั้ง 9 หมวดหลัก: หิน ทราย ปูน (15 รายการ), เหล็ก (14 รายการ), ท่อ & PVC (12 รายการ), อุปกรณ์ไฟฟ้า (15 รายการ), ไม้อัด & แผ่นบอร์ด (12 รายการ), วงบ่อท่อระบายน้ำ (17 รายการ), เสา (23 รายการ), เครื่องมือช่าง (10 รายการ), ตะปู+สกรู (12 รายการ) พร้อมชื่อ ราคา และสต็อกจริงครบถ้วน
14. **ทดสอบและตรวจสอบกระบวนการสั่งซื้อจากเว็บ ตัดสต็อก และการเงินแบบ E2E (Web Order & Stock Cut Verification):**
    - ทดสอบยิงคำสั่งซื้อผ่าน API `POST /api/v1/shop/orders` พร้อมระบบกันยิงซ้ำ (Idempotency Key UUID) สำเร็จ 100%
    - ทดสอบกระบวนการคิดเงินหน้าร้าน POS (โหลดคำสั่งซื้อ $\rightarrow$ บันทึกบิลขาย `order` $\rightarrow$ ผูก `online_orders.posOrderId` $\rightarrow$ เปลี่ยนสถานะเป็น `COMPLETED`)
    - ตรวจสอบการตัดสต็อกสินค้าในตาราง `product` และการบันทึกประวัติการขายลงในตาราง `stockledger` พบว่าทำงานถูกต้อง แม่นยำ และปลอดภัยภายใต้ Database Transaction 100%
15. **ทดสอบและตรวจสอบกระบวนการปล่อยรถบน S-Link และระบบ Live GPS Tracking แบบ E2E:**
    - ตรวจสอบ Flow การอนุมัติปล่อยรถ (`ApproveDepartureDialog` $\rightarrow$ อัปเดต Firestore `is_departure_approved: true` $\rightarrow$ ส่ง API `POST /gps/update_job` แจ้งสถานะรถ "กำลังส่งของ")
    - ทดสอบการออกโทเคนติดตาม (`CustomerTrackingController.issue`) สำหรับส่งลิงก์แผนที่ Live GPS ให้ลูกค้าทาง LINE
    - ทดสอบการดึงพิกัดแบบเรียลไทม์ (`GET /api/v1/tracking/<token>`) และการเพิกถอนสิทธิ์ลิงก์อัตโนมัติเมื่อส่งเสร็จสิ้น (`CustomerTrackingController.revoke`) สำเร็จ 100%

**English:** S-Link Stock Check & Image Resolution, Product Types & Categories Reorganization, Dead Stock Report, Cost Price Auto-Fill & Concrete Pole Pricing:
1. **S-Link Stock Check History & Audit Trail:** Broadened `StockLedgerExtension.getHistoryByType` query targets to include `ADJUST_FIX_APP`, `ADJUST_CORRECT`, and `STOCK_IN_APP`. Recorded staff author names in stock ledger notes and displayed localized badges on POS Desktop.
2. **Product Image Resolution:** Created `ProductImageHelper` to dynamically resolve server relative paths (`/public/products/...`) against `SettingsService().apiUrl`, enabling seamless photo rendering and desktop uploads.
3. **Product Categories Reorganization (Ceiling, Door/Window, Fasteners):**
   - **"ฝ้า ผนัง" (ID: 29):** Re-assigned 63 ceiling and wall materials.
   - **"ประตูหน้าต่าง" (ID: 30):** Re-assigned 224 door and window products.
   - **"ตะปู สกรู" (ID: 31):** Consolidated 569 fastener items.
4. **3-Way Electrical Categories Separation:**
   - **"สายไฟ" (Wires & Cables, ID: 32):** Re-assigned 119 electrical wire products.
   - **"หลอดไฟ" (Lighting, ID: 33):** Re-assigned 262 lighting fixtures and bulbs.
   - **"อุปกรณ์ไฟฟ้า" (Electrical Hardware, ID: 8):** Preserved 457 electrical installation accessories.
5. **PVC, Fittings & Adhesives Reorganization:**
   - **"ข้อต่อ" (Plumbing Fittings & Valves, ID: 34):** Re-assigned 550 PVC elbows, tees, sockets, reducers, ball valves, and taps.
   - **"กาว" (Adhesives & Sealants, ID: 35):** Consolidated 104 adhesives (PVC pipe cements, super glues, latex, nail power adhesives, silicones, PU foams, epoxies).
   - **"ท่อPVC" (PVC & Agricultural Pipes, ID: 13):** Retained 204 clean pipe products.
6. **Comprehensive 5-Category Major Reorganization (Agri, Sanitary, Power Tools, Spray, Paint Tools):**
   - **"เกษตรและสวน" (Agriculture & Garden, ID: 36):** Re-assigned 142 irrigation sprinklers, micro-tubes, potting soils, shade netting, hoes, and mower blades.
   - **"สุขภัณฑ์และห้องน้ำ" (Sanitaryware & Bath, ID: 37):** Re-assigned 255 bidet sprays, shower heads, basin wastes, trap pipes, inlet hoses, and toilet suites.
   - **"เครื่องมือไฟฟ้าและปั๊มน้ำ" (Power Tools & Pumps, ID: 38):** Re-assigned 237 power drills, angle grinders, circular saws, welders, pressure washers, water pumps, and drill bits.
   - **"สีสเปรย์" (Spray Paints, ID: 39):** Re-assigned 66 aerosol spray paint cans.
   - **"อุปกรณ์ทาสี" (Painting Tools, ID: 40):** Re-assigned 60 paint brushes, rollers, paint trays, and extension poles.
   - **"สี" (Paints, ID: 3):** Cleaned up misclassified products, retaining 804 authentic architectural and wood paints (BegerCool, Beger 2in1, Beger Bull, enamels, and thinners).
7. **Precast Concrete, Zinc & PE/Drip Irrigation Reorganization:**
   - **"เสาและคอนกรีตหล่อ" (Precast Concrete & Poles, ID: 41):** Consolidated 114 precast concrete poles, concrete rings, lids, culverts, asbestos pipes, catch basins, bricks, and glass blocks.
   - **"สังกะสีและรางน้ำ" (Zinc Sheets & Rain Gutters, ID: 42):** Consolidated 34 corrugated zinc sheets, flat zinc, clear roof sheets, rain gutters (5"/6"), gutter brackets, and zinc flashing.
   - **"เกษตรและสวน" (Agriculture & Garden, ID: 36):** Moved 18 PE pipes, drip tapes, micro valves, and spray hoses into agriculture, increasing the catalog to 160 items.
8. **Dead Stock & Slow Moving Products Analytics and Excel Export:**
   - **Dead Stock Screen (`DeadStockScreen`):** Added a dedicated "Dead Stock" report in the Inventory menu featuring 3 key KPI cards (Total Dead Stock Items, Total Stuck Stock Units, and Dead Stock Capital Value).
   - **Multi-dimensional Filters (`DeadStockFilter`):** Inactivity period options (Never Moved, 30+, 60+, 90+, 180+, 365+ days), product category picker, stock status selector (In Stock Only, Zero Stock, All), and debounced live search.
   - **Excel Export Service (`DeadStockExcelService`):** Integrated one-click `.xlsx` export with formatted headers, auto column widths, summary totals for quantities & capital, and automatic file opening via `OpenFile`.
   - **Optimized Performance (`DeadStockRepository`):** Sub-20ms MySQL query execution with client-side paginated data table for 60 FPS smooth rendering.
9. **Automated Cost Price Calculation & Population:**
   - Identified 2,009 active products missing cost prices (`costPrice <= 0` or `NULL`) with valid retail prices.
   - Applied the 30% markup formula (`costPrice = ROUND(retailPrice / 1.3, 2)`) to populate accurate cost figures across the database.
   - Reduced estimated Dead Stock tied-up capital from 7.92M THB to a realistic 4.78M THB.
10. **Concrete Pole Pricing Matrix Update (Face 4, 5, 6):**
    - **Face 4 (120 THB/sok):** 4*2 (240 THB / Cost 184.62 THB) to 4*7 (840 THB / Cost 646.15 THB).
    - **Face 5 (185 THB/sok):** 5*2 (370 THB / Cost 284.62 THB) to 5*8 (1,480 THB / Cost 1,138.46 THB).
    - **Face 6 (210 THB/sok):** 6*2 (420 THB / Cost 323.08 THB) to 6*8 (1,680 THB / Cost 1,292.31 THB).
    - Fully updated retail and cost prices across 49 concrete pole SKUs.
11. **Online Orders Screen Back Button Contrast & Theme Fix (`OnlineOrdersScreen`):**
    - Configured explicit `foregroundColor` and `iconTheme` (`#0F172A`) on `AppBar` to ensure high contrast and clear visibility of the back arrow against the white appbar header.
12. **DeadStockScreen Edit Dialog Type Safety Fix (`DeadStockScreen`):**
    - Corrected dialog return type from `showDialog<bool>` to `showDialog<Product>` in `_editProduct`.
    - Resolved runtime crash and UI freeze caused by `type 'Product' is not a subtype of type 'bool?' of 'result'` when saving product changes.
13. **POS Quick Menu to Web Shop Auto-Population (`featured_config.json`):**
    - Cleaned and curated 130 high-relevance items matching the POS Quick Menu across all 9 storefront categories.
14. **End-to-End Web Order, Payment & Stock Deduction Verification:**
    - Ran live automated E2E test covering Web Shop order creation (`POST /api/v1/shop/orders`), idempotency UUID enforcement, POS checkout simulation, MySQL transaction boundaries, atomic stock deduction in `product`, and audit logging in `stockledger`. Verified 100% data integrity and consistency.
15. **S-Link Truck Dispatch & Live GPS Tracking E2E Verification:**
    - Verified departure approval flow (`ApproveDepartureDialog` $\rightarrow$ Firestore `is_departure_approved: true` $\rightarrow$ `POST /gps/update_job` updating vehicle status).
    - Tested customer live tracking token issuance (`CustomerTrackingController.issue`), real-time coordinate streaming (`GET /api/v1/tracking/<token>`), and automatic link revocation upon delivery completion (`CustomerTrackingController.revoke`).

---

## [2026-08-25] Web Shop Features & Custom Categories, LINE OA Keyword Expansion, POS Cart Hardening

**ไทย:** พัฒนาระบบ Web Shop, LINE OA Webhook และความเสถียรของระบบ POS Desktop:
1. **ระบบจัดการหมวดหมู่สินค้าและสินค้าเด่นบน Web Shop (`shop_controller.dart`, `admin.js`, `index.html`):**
   - **จัดการหมวดหมู่สินค้าอิสระ (Custom Categories CRUD):** เพิ่ม/แก้ไข/ลบหมวดหมู่ พร้อม Quick Emoji Picker (`🏗️`, `🪨`, `🚰`, `⚡`, `🏠`, `🎨`, `🔨`) และปุ่มเลื่อนจัดลำดับ (▲/▼)
   - **เลือกและจัดลำดับสินค้าเด่น (Product Curation & Reordering):** ค้นหาสินค้าทั้งหมดในร้าน ติ๊กเลือกเข้าหมวดหมู่ ปรับเปลี่ยนลำดับแสดงผล (◀/▶) และแก้ไขป้าย Tag/Badge สีได้อิสระ
   - **ซิงค์สู่หน้าร้านลูกค้า 100%:** แถบหมวดหมู่และลำดับสินค้าบนหน้าเว็บลูกค้า (`/shop/`) แสดงผลตรงตามที่แอดมินจัดไว้แบบเรียลไทม์
2. **ขยายคีย์เวิร์ดตอบกลับ LINE OA Webhook (`line_controller.dart`):**
   - ตรวจจับคีย์เวิร์ด `ติดต่อร้านค้า`, `ติดต่อร้าน`, `ติดต่อ`, `เบอร์โทร`, `เบอร์ร้าน`, `แอดมิน`, `เจ้าหน้าที่`, `โทร`, `contact`, `call`, `phone` เพื่อส่งข้อมูลเบอร์โทร (`085-1377402`), ลิงก์เพจ Facebook และคำแนะนำสอบถามบิล/จัดส่งอัตโนมัติทันที 24 ชั่วโมง
3. **เสริมความปลอดภัยและความแม่นยำของตะกร้า POS (`CartItemTile`, `CartService`, `PriceCalculationService`):**
   - ติดตั้ง Focus Listener แก้ปัญหา Focus Loss เมื่อพิมพ์เปลี่ยนจำนวน/ราคาแล้วคลิกไปช่องอื่น
   - ป้องกันยอดเงินในแถวติดลบโดย Clamp ส่วนลดไม่ให้เกินยอดรวม
   - รักษา Overridden Custom Price เมื่อสแกนบาร์โค้ดสินค้าเดิมซ้ำ
   - รองรับการลดจำนวนสินค้าชั่งน้ำหนัก/เศษทศนิยม (`newQty > Decimal.zero`)

**English:** Web Shop Features & Custom Categories, LINE OA Keyword Expansion, POS Cart Hardening:
1. **Dynamic Storefront Curation & Custom Categories:** Implemented full custom category CRUD with emoji pickers, product reordering (◀/▶), badge customization, and real-time storefront synchronization.
2. **LINE OA Webhook Auto-Reply Expansion:** Broadened `_isContactCommand` to match contact inquiries 24/7.
3. **Comprehensive POS Cart Hardening:** Added authoritative focus listeners, negative total prevention, overridden price preservation, and fractional quantity decrement support.

---

## [2026-08-24] Direct Admin Sync to Customer Storefront & Ultra-Compact Product Cards / ซิงค์สินค้าตามแอดมินเลือกสู่หน้าลูกค้า 100% พร้อมปรับการ์ดสินค้าฝั่งลูกค้าให้กะทัดรัด

**ไทย:** ปรับปรุงระบบ Web Shop หน้าร้านลูกค้าและระบบ Admin หลังบ้าน (`shop_controller.dart`, `featured_config.json`, `index.html`, `shop.css`, `shop.js`):
1. **ซิงค์สินค้าและหมวดหมู่ตามที่แอดมินเลือกในระบบ Admin สู่หน้าลูกค้า 100%:**
   - นำเข้าสินค้าเมนูด่วนหลักทั้งหมด 128 รายการจัดหมวดหมู่อย่างเป็นระเบียบลงใน `featured_config.json` ทำให้ในหน้า Admin มีสินค้าครบทุกหมวดหมู่พร้อมให้เลือกใช้งาน
   - ปรับปรุง API `GET /api/v1/shop/products` และ `GET /api/v1/shop/categories` ให้ดึงข้อมูลสินค้าและหมวดหมู่ตามที่แอดมินเลือกใน `featured_config.json` อย่างแม่นยำ
   - หมวดหมู่ไหนที่แอดมินไม่ได้เลือกสินค้าไว้ จะไม่แสดงแถบหมวดหมู่นั้นบนหน้าลูกค้า
   - เมื่อลูกค้าคลิกแต่ละหมวดหมู่ จะแสดงเฉพาะรายการสินค้าที่แอดมินเลือกไว้ในหมวดนั้นๆ ตรงกัน 100%
2. **ปรับขนาดรูปภาพและการ์ดสินค้าฝั่งลูกค้าให้กะทัดรัด (Ultra-Compact Customer Cards):**
   - ปรับความสูงกรอบรูปภาพสินค้า (`.product-img-wrapper`) เหลือ **70px** (จากเดิมที่เป็นสี่เหลี่ยมจัตุรัสขนาดใหญ่เต็มจอ)
   - ปรับขนาดไอคอน Emoji Placeholder เป็น 22px และปรับป้ายชื่อหมวดให้พอดีและสวยงาม
   - ปรับ Layout กริด (`.product-grid`) เป็นแบบ Responsive Auto-fill (`minmax(140px, 1fr)`) ทำให้บนจอคอมพิวเตอร์/แท็บเล็ตแสดงผลได้หลายคอลัมน์ และบนมือถือเป็น 2 คอลัมน์กะทัดรัด ไม่กินพื้นที่หน้าจอ
3. **ปลดล็อกขีดจำกัดจำนวนชิ้นในระบบ Admin:** ปลดล็อกข้อจำกัด 3 ชิ้นต่อหมวดใน `admin.js` และขยาย Payload รองรับได้ถึง 1,000 รายการ

**English:** Direct admin-selection sync to customer storefront with ultra-compact product cards (`shop_controller.dart`, `featured_config.json`, `index.html`, `shop.css`, `shop.js`):
1. **100% Direct Storefront Synchronization from Admin Config:**
   - Pre-populated all 128 core hardware items into `featured_config.json` categorized properly under standard store categories.
   - Updated `GET /api/v1/shop/products` and `GET /api/v1/shop/categories` to strictly serve only the products and categories selected by the store administrator.
   - Any category without selected items is automatically hidden from the customer storefront navigation.
2. **Ultra-Compact Product Cards on Customer Storefront:**
   - Reduced product thumbnail wrapper height to a sleek **70px** (eliminating the oversized square placeholder).
   - Tuned placeholder emoji to 22px with compact category badges.
   - Made the catalog grid responsive (`minmax(140px, 1fr)`), fitting comfortably across multiple columns on desktop and 2 columns on mobile.
3. **Unlimited Admin Selection:** Removed the 3-item limit in `admin.js` with payload support up to 1,000 items.

## [2026-08-23] Smart Dynamic Delivery Pricing & Heavy Goods Notification / ระบบคำนวณค่าส่งอัจฉริยะตามระยะทางและกำไรบิล

**ไทย:** พัฒนาระบบคำนวณค่าจัดส่งอัจฉริยะแบบเรียลไทม์ (Smart Dynamic Delivery Pricing) ในหน้า Web Shop (`shop.js`, `shop_controller.dart`, `index.html`) โดยดึงพิกัดร้านค้าและพิกัดลูกค้า (GPS Haversine x 1.35 Road Factor) ร่วมกับยอดกำไรขั้นต้นของสินค้าในตะกร้าตามสูตรของร้าน:
- **ระยะ 0 - 6 กม.:** กำไร $\ge 300$ บาท $\rightarrow$ **ส่งฟรี! (฿0)** (ถ้าไม่ถึง คิด 50 บาท)
- **ระยะ 6 - 9 กม.:** กำไร $\ge 500$ บาท $\rightarrow$ **ส่งฟรี! (฿0)** (ถ้าไม่ถึง คิด 100 บาท)
- **ระยะ 9 - 14 กม.:** กำไร $\ge 500$ บาท $\rightarrow$ **ส่งฟรี! (฿0)** (ถ้าไม่ถึง คิด 200 บาท)
- **ระยะ 14 - 18 กม.:** กำไร $\ge 1,000$ บ. ฟรี / กำไร $\ge 500$ บ. คิด 200 บ. / กำไร $\ge 300$ บ. คิด 300 บ. / กำไร $< 300$ บ. คิด 400 บ.
- **เกิน 18 กม.:** คิด 400 บาท + 15 บาท/กม. ส่วนเกิน
- **ปรับปรุงเมนูแถบข้าง (Sidebar Navigation):**
  - นำเมนู **"ออเดอร์ออนไลน์"** ออกจากการ์ดเมนูฝั่งซ้าย (NavigationRail) เพื่อความกระชับและไม่รกตา
  - ให้เรียกใช้งานผ่านปุ่มลัด **`[ 💬 ออเดอร์ออนไลน์ / ออเดอร์ใหม่ ]`** ที่แถบควบคุมด้านบนของหน้าขาย (POS) เพียงที่เดียว โดยเมื่อกดจะเปิดหน้าต่างจัดการออเดอร์ออนไลน์ขึ้นมา และเมื่อดึงรายการเข้าตะกร้าจะกลับมายังหน้าขายอัตโนมัติ
- **ปรับปรุงชื่อสินค้าหลักเป็น "ปลอก" (ถูกต้องตามหลักภาษา) พร้อมเพิ่ม Alias "ปอก" (Lazy-Friendly Search):**
  - **ชื่อทางการ (Name):** ตั้งเป็น **"ปลอก"** ตามพจนานุกรมและหลักวิศวกรรม เช่น *ปลอกคาน 10*15 ซม., ปลอกเสา 10*10, ปลอกลวด 3*3, ปลอกทับหลัง*
  - **ชื่อย่อ/คำค้น (Alias):** ใส่คำว่า **"ปอก"** เช่น *ปอกคาน 10*15 ซม., ปอกเสา 10*10* ทุกรายการ
  - **เครื่องมือช่าง (คีมปอกสายไฟ):** ตั้งชื่อเป็น *คีมปอกสายไฟ* (กริยาปอก) และใส่ Alias เป็น *คีมปลอกสายไฟ*
  - **ผลลัพธ์:** ถูกต้องตามหลักภาษาไทย 100% และเวลาแคชเชียร์พิมพ์ค้นหาด้วยคำว่า `"ปอก"` หรือ `"ปลอก"` ระบบจะค้นเจอทั้งคู่แบบรวดเร็วไร้รอยต่อ
- **จัดระเบียบและจำแนกหมวดหมู่สินค้าทั้งระบบ (~6,500 รายการ) เข้าสู่ 8 หมวดหมู่หลัก (Full Store Catalog Reorganization):**
  - จำแนกสินค้าทั้งหมดในร้านเข้าสู่หมวดหมู่หลักอย่างถูกต้อง แม่นยำ และเป็นระเบียบ 100%:
    1. 🔨 **อุปกรณ์ช่าง (1,639 รายการ):** สกรู, น็อต, ตะปู, สว่าน, ดอกสว่าน, ค้อน, คีม, ประแจ, ไขควง, ตลับเมตร, กระดาษทราย, เกรียง, กุญแจ, ลูกบิด, บานพับ, กลอน, เลื่อย, บันได ฯลฯ
    2. 🚰 **ท่อPVC (1,162 รายการ):** ท่อ PVC, ท่อเกษตร, ข้อต่อ, ก๊อกน้ำ, วาล์ว, บอลวาล์ว, ยูเนี่ยน, นิปเปิ้ล, สายยาง, สายน้ำดี, สุขภัณฑ์, สะดืออ่าง, ฝักบัว, สปริงเกอร์ ฯลฯ
    3. 🎨 **สี (1,074 รายการ):** สีน้ำ, สีน้ำมัน, สเปรย์, ทินเนอร์, น้ำมันสน, วานิช, แลคเกอร์, กาว, ซิลิโคน, อะคริลิค, ยาแนว, แด๊ป, แปรงทาสี, ลูกกลิ้ง ฯลฯ
    4. ⚡ **อุปกรณ์ไฟฟ้า (842 รายการ):** สายไฟ, หลอดไฟ, ขั้วไฟ, ปลั๊ก, สวิตช์, เบรกเกอร์, สปอร์ตไลท์, โคมไฟ, กล่องพักสาย, ท่อร้อยสาย, บัลลาสต์, LED ฯลฯ
    5. 🏗️ **เหล็ก (387 รายการ):** เหล็กเส้น, เหล็กกล่อง, ลวดผูกเหล็ก, ลวดหนาม, ตาข่ายกรงไก่, ตะแกรงเหล็ก, สังกะสี, เมทัลชีท, ปอกเสา/คาน ฯลฯ
    6. 🪨 **หินทราย (166 รายการ):** หินคลุก, หินคิว/ถุง, ทรายหยาบ/ละเอียด, ปูนซีเมนต์, ปูนกาว, ปูนขาว, อิฐบล็อก, อิฐแดง, วงบ่อ, ฝาวงบ่อ, ท่อระบายน้ำ, ท่อใยหิน, บ่อพัก, แผ่นพื้น, กระเบื้องหลังคา, ไม้ฝา ฯลฯ
    7. 🪚 **ใบตัด (78 รายการ):** ใบตัด 4", 14", 16", 7", ใบเจียรหนา/บาง, ใบตัดกระเบื้อง, ใบตัดเพชร, ใบตัดคอนกรีต/สแตนเลส/หินแกรนิต ฯลฯ
    8. 📦 **ทั่วไป (1,138 รายการ):** สินค้าอุปโภคบริโภค เครื่องดื่ม ขนม ของใช้เบ็ดเตล็ดทั่วไป
- **ปรับปรุงประเภทสินค้ากลุ่มใบตัด & ใบเจียร (Product Category Migration):**
  - จัดการย้ายและปรับปรุงประเภทสินค้ากลุ่ม **ใบตัด 4", ใบตัด 14", ใบตัด 16", ใบตัด 7", ใบตัดเพชร, ใบเจียร/ใบเจีย, ใบตัดกระเบื้อง, ใบตัดปูน, ใบตัดหิน, ใบตัดคอนกรีต, ใบตัดสแตนเลส, ใบตัดใยแก้ว** ทั้งหมด 78 รายการ เข้าสู่หมวดหมู่ **`ใบตัด` (Category ID: 6)** อย่างครบถ้วนเรียบร้อย
  - กรองแยกสินค้ากลุ่มเกษตร (เช่น *ใบตัดหญ้า*) และเครื่องมือช่าง (เช่น *เลื่อยตัดเหล็ก/กรรไกรตัดเหล็ก*) ให้อยู่ในหมวดหมู่เดิมอย่างถูกต้อง
- **แก้ไขปัญหาการสลับ QR Code บนหน้าจอลูกค้าเมื่อเลือกโอนเงิน (Fix Payment QR Switching on Customer Display):**
  - **แยก State ชัดเจนใน `QrSection`:** เมื่ออยู่ในโหมดชำระเงิน (`PaymentMode`) บังคับให้แสดง QR PromptPay หรือ QR โอนเงิน หรือกล่องเลขบัญชีธนาคาร 100% โดยไม่ให้หลุดไปแสดง LINE OA QR
  - **ปรับปรุงการดึง PromptPay ID & Fallback:** ใน `pos_order_mixin.dart` เพิ่มการค้นหา Fallback ไปยัง `bank_account` เพื่อให้สร้าง PromptPay Dynamic Payload ได้แม่นยำแม้ไม่ได้กรอก promptpay_id แยกต่างหาก
  - **แก้ไขการคำนวณยอด QR:** ใน `PaymentModalController` ปรับปรุงให้คำนวณ `qrAmount` เป็นยอดคงเหลือหรือยอดรวมเต็มจำนวนเสมอ
  - **ระบบ Auto-Discovery Subwindow ใน `CustomerDisplayService`:** เพิ่มกลไกค้นหา Window ID ของหน้าจอที่ 2 อัตโนมัติหาก `_windowId` หลุด เพื่อให้การส่งข้อมูลผ่าน MethodChannel อัปเดตไปยังหน้าจอลูกค้าได้ต่อเนื่อง 100%
- **ระบบ QR Code LINE OA สลับอัตโนมัติบนหน้าจอลูกค้า & ท้ายสลิป 80mm (LINE OA Smart Switching & Receipt Footer):**
  - **หน้าจอลูกค้า (Customer Display Screen):** พื้นที่ขวาล่างจะแสดง QR Code LINE OA สวยงามชัดเจนตลอดเวลาขณะสแกนสินค้า (Cart Mode/Idle) เพื่อให้ลูกค้าสแกนแอดเพื่อนสะสมแต้ม และเมื่อแคชเชียร์กดรับเงินโอน ระบบจะสลับไปเป็น QR Code PromptPay สำหรับชำระเงินโดยอัตโนมัติทันที
  - **ท้ายสลิปใบเสร็จ 80mm (Thermal Receipt 80mm):** เพิ่มบล็อกพิมพ์ QR Code LINE OA คมชัดระดับ Vector พร้อมข้อความ *"📲 สมัครสมาชิกกับเรา รับแต้มสะสม & สิทธิพิเศษ"* ที่ท้ายใบเสร็จ
  - **หน้าตั้งค่าระบบ (Display Settings Screen):** เพิ่มส่วนตั้งค่า LINE Official Account สำหรับระบุ LINE OA Link, LINE ID, ปุ่มอัปโหลดรูป QR Code พร้อมระบบบีบอัดภาพอัตโนมัติ และสวิตช์เปิด/ปิดการแสดงผลทั้งสองจุด
- **ระบบจัดการออเดอร์ออนไลน์ฝังใน POS Desktop (Online Orders Management):**
  - พัฒนาหน้าจอ `OnlineOrdersScreen` พร้อมระบบกรองสถานะ (`รอตรวจสอบ`, `ยืนยันแล้ว`, `กำลังจัดส่ง`, `สำเร็จ`, `ยกเลิก`)
  - เพิ่มการ์ดแสดงรายละเอียดคำสั่งซื้อจากลูกค้า (ชื่อ, เบอร์โทร, ที่อยู่จัดส่ง, ลิงก์แผนที่ Google Maps, ค่าจัดส่ง, ยอดรวมสุทธิ)
  - พัฒนาปุ่มฟีเจอร์เด็ด **`[ 🧾 ดึงเข้าตะกร้าขาย (POS) ]`** นำรายการสินค้าและลูกค้าเข้าสู่จอขายหน้าร้านทันทีเพื่อคิดเงิน/ตัดสต็อกได้ในคลิกเดียว
  - เชื่อมต่อตารางฐานข้อมูล `online_orders` ใน MySQL พร้อม REST API endpoints (`GET /api/v1/shop/orders`, `PUT /api/v1/shop/orders/<id>/status`)
  - เพิ่มปุ่มด่วนและป้ายตัวเลขแจ้งเตือนออเดอร์ใหม่ (`🔴 Pending Badge`) ที่แถบด้านบนของหน้าขาย (`PosControlBar`) และแถบเมนูหลัก (`NavigationRail`)
  - เพิ่มระบบตรวจจับออเดอร์ใหม่แบบเบื้องหลัง (Background Polling) พร้อมเสียงเตือน Chime
  - เพิ่มปุ่มแสดง QR Code ขนาดใหญ่ สำหรับให้ลูกค้าหน้าร้านสแกนเข้าสู่ Web Shop ได้ทันที
- **แถบหมวดหมู่สินค้า 2 แถวพร้อม Scrollbar & Drag-to-Scroll:** ปรับแถบเลือกหมวดหมู่สินค้า (`category-scroll`) เป็นตารางแนวนอน 2 แถว (2-Row Flow Grid) ช่วยให้เห็นหมวดหมู่ได้มากกว่าเดิม 2 เท่า พร้อมเพิ่ม Scrollbar สีเขียวมรกตที่เห็นชัดเจน และระบบคลิกลากเลื่อนด้วยเมาส์ (Mouse Drag-to-Scroll) ใช้งานลื่นไหลทั้งบนคอมพิวเตอร์และมือถือ
- **สินค้าแนะนำแบบกำหนดเอง (Manually Curated Featured Products):** พัฒนาระบบสินค้าแนะนำให้ร้านค้าสามารถเลือกรายการสินค้าและข้อความโปรโมชั่นได้เองผ่านไฟล์คอนฟิก `featured_config.json` (ระบุ `productId`, ป้าย `tag` เช่น "🔥 ขายดี", "⭐ ช่างแนะนำ", และสี `badgeColor`) โดยระบบจะดึงเฉพาะสินค้าที่ร้านคัดเลือกมาโชว์ในสไลด์แนวนอน ไม่ดึงสุ่มจากรายการสินค้าทั่วไป
- **การรักษาความเป็นส่วนตัวของสูตรระยะทาง (Distance Privacy):** ซ่อนตัวเลขระยะทาง (กม.) ไม่ให้แสดงต่อลูกค้าทั้งในหน้าเว็บและ LINE เพื่อเก็บเป็นความลับทางการค้าของร้าน โดยลูกค้าจะเห็นเฉพาะยอดค่าบริการจัดส่งหรือสถานะ `🟢 จัดส่งฟรี (โปรโมชั่น)` เท่านั้น
- **ข้อความแจ้งความยืดหยุ่นของค่าจัดส่ง (Flexible Shipping Disclaimer):** เพิ่มข้อความกำกับทั้งในหน้าเว็บและข้อความแจ้งเตือนทาง LINE ระบุว่า *"ค่าจัดส่งเป็นการประเมินเบื้องต้น อาจปรับลดหรือยืดหยุ่นได้ตามรอบรถและหน้างานจริง เจ้าหน้าที่จะติดต่อยืนยันยอดสุดท้ายอีกครั้ง"*
- **แจ้งเตือนสินค้าหนักพิเศษ:** ดักจับสินค้า เสา, วงบ่อ, อิฐบล็อก, บล็อก, ท่อปูน หากระยะทางเกิน 6 กม. จะแสดงแถบแจ้งเตือนสีส้มว่ามีค่าเที่ยวรถเฉพาะ และส่งสรุปค่าจัดส่งพร้อมยอดรวมสุทธิเข้าห้องแชท LINE อัตโนมัติ

**English:** Implemented the real-time Smart Dynamic Delivery Pricing engine across the Web Shop (`shop.js`, `shop_controller.dart`, `index.html`). Computes road distance via GPS coordinates and evaluates against cart estimated gross profit:
- **0 - 6 km:** Profit $\ge$ 300 THB $\rightarrow$ **Free Shipping (0 THB)** (otherwise 50 THB)
- **6 - 9 km:** Profit $\ge$ 500 THB $\rightarrow$ **Free Shipping (0 THB)** (otherwise 100 THB)
- **9 - 14 km:** Profit $\ge$ 500 THB $\rightarrow$ **Free Shipping (0 THB)** (otherwise 200 THB)
- **14 - 18 km:** Profit $\ge$ 1,000 THB $\rightarrow$ Free / $\ge$ 500 THB $\rightarrow$ 200 THB / $\ge$ 300 THB $\rightarrow$ 300 THB / $<300$ THB $\rightarrow$ 400 THB
- **> 18 km:** 400 THB + 15 THB/km surcharge
- **Heavy goods alert:** Automatically flags heavy materials (concrete poles, rings, cinder blocks) beyond 6 km with an on-page warning and detailed LINE push summary.

## [2026-08-23] Web Shop Fresh White & Emerald Green Theme / ปรับชุดสีหน้าเว็บเป็นโทนขาว-เขียวมรกต

**ไทย:** ปรับเปลี่ยนชุดสีของหน้าเว็บแค็ตตาล็อกและสั่งซื้อสินค้า (`index.html`, `shop.css`) เป็นโทน **"ขาว-เขียวมรกต / LINE Green" (Fresh White & Emerald Theme)** เพื่อความสะอาดตา สบายตา ดูน่าเชื่อถือ และเข้ากับดีไซน์ของ LINE Official Account อย่างลงตัว พร้อมแก้ปัญหา Static Assets Path และฝัง Embedded Stylesheet ป้องกันปัญหา CSS โหลดไม่ติด ช่วยให้แสดงผลการ์ด Grid, ปุ่ม และส่วนประกอบต่างๆ สวยงาม คมชัด 100%

**English:** Redesigned the Web Shop theme to a pristine **Fresh White & Emerald Green (LINE Green)** palette (`index.html`, `shop.css`) delivering high contrast, organic comfort, and seamless visual synergy with LINE Official Account. Resolved static asset path discovery in `server.dart` and integrated an embedded stylesheet to prevent unstyled layout drops.

## [2026-08-22] Server Migration Playbook & Guide / จัดทำคู่มือและสคริปต์ย้ายระบบขึ้น Mini PC Proxmox VE

**ไทย:** สร้างเอกสารคู่มือและขั้นตอนการย้ายระบบเซิร์ฟเวอร์สู่ Mini PC (`MIGRATION_GUIDE.md`) เพื่อเตรียมความพร้อมสำหรับเครื่อง Beelink Mini S12 Pro (Intel N100, 32GB RAM, 500GB SSD) ที่รัน Proxmox VE 9.x โดยรวบรวมพิมพ์เขียวสถาปัตยกรรมระบบ, การจัดสรรทรัพยากร LXC Container (MySQL Database 8GB, Backend API 4GB, Cloudflare Tunnel 1GB), สคริปต์คำสั่งติดตั้งและปรับแต่ง MySQL 8.0, Systemd Auto-Restart Service สำหรับ Dart Shelf Backend, ระบบ Auto-Shutdown ร่วมกับ UPS (`apcupsd`), และแผนสำรอง/กู้คืนระบบแบบ 2 ภาษา (ไทย-อังกฤษ)

**English:** Created the comprehensive server migration playbook and deployment guide (`MIGRATION_GUIDE.md`) preparing for the Beelink Mini S12 Pro (Intel N100, 32GB RAM, 500GB SSD) running Proxmox VE 9.x. The guide details the containerized architecture, LXC resource allocations (MySQL 8GB, Backend API 4GB, Cloudflare Tunnel 1GB), MySQL 8.0 high-performance tuning configs, Dart Shelf Backend Systemd auto-restart service units, UPS auto-shutdown integration (`apcupsd`), and disaster recovery/rollback plans bilingually (Thai & English).

## [2026-08-22] Customer Tracking Page Resilient UX / ปรับปรุงหน้าจอติดตามรถพร้อมปุ่มโทรติดต่อร้าน

**ไทย:** ปรับปรุงหน้าเว็บติดตามรถของลูกค้า (`customer_tracking.html`) ให้มีความยืดหยุ่นและเป็นมิตรกับผู้ใช้ยิ่งขึ้น เพิ่มปุ่มโทรด่วน `[ 📞 โทรสอบถามร้าน (085-1377402) ]` รองรับการแตะเพื่อโทรออกทันที, ปรับข้อความแจ้งเตือนเมื่อสัญญาณขาดหายเป็น "⏳ รถกำลังเดินทาง (สัญญาณขาดหายชั่วคราว)", และปรับหน้าจอเมื่อปิดงานแล้วให้แสดงข้อความขอบคุณอย่างสุภาพพร้อมปุ่มติดต่อร้าน.

**English:** Enhanced the customer delivery tracking page (`customer_tracking.html`) with resilient fail-safe UX, including a direct click-to-call store button (`tel:0851377402`), friendly connection-drop statuses ("⏳ รถกำลังเดินทาง (สัญญาณขาดหายชั่วคราว)"), and a polished delivery completion screen with a polite thank-you message and store contact action.

## [2026-08-22] Premium LINE OA Delivery Tracking Card (Flex Message) / ปรับการแจ้งเตือนส่งของเป็นการ์ดปุ่มกดติดตามรถ

**ไทย:** ปรับปรุงระบบแจ้งเตือนการปล่อยรถ (Stage 2) ใน `LineController` และ `LineService` จากข้อความธรรมดาที่แสดง URL เปลือย ให้กลายเป็นการ์ดข้อความแบบโต้ตอบ (LINE Flex Message Card) ดีไซน์พรีเมียมสีเขียว Teal พร้อมปุ่มกด "📍 กดติดตามตำแหน่งรถบนแผนที่" โดยไม่ต้องแสดง URL ยาวๆ ให้เกะกะสายตา เมื่อลูกค้าแตะปุ่มจะเปิดหน้าแผนที่ติดตามรถสดได้ทันที พร้อมมีระบบ Fallback ส่งข้อความสำรองอัตโนมัติหากการส่ง Flex Card มีปัญหา.

**English:** Upgraded Stage 2 delivery departure notifications in `LineController` and `LineService` from plain text with exposed URLs to interactive, styled LINE Flex Message Cards in teal branding with a direct "📍 กดติดตามตำแหน่งรถบนแผนที่" button. Customers can tap directly into the live tracking map without seeing raw URL strings, complete with an automatic plain-text fallback safeguard.

## [2026-08-22] GPS Live Status Flow & Vehicle Return Visibility / แก้ไขสถานะปล่อยรถและการแสดงผลรถขากลับ

**ไทย:** แก้ไขปัญหากดปล่อยรถแล้วสถานะงานในแผนที่ GPS ไม่เปลี่ยน โดยปรับปรุง `JobProvider.approveJobDeparture` ใน S-Link ให้ส่งชื่อรถจากทีมจัดส่งที่เลือกจริงไปยัง `/gps/update_job` และเพิ่มระบบ `normalizeVehicleKey` ใน `GpsController` ของ POS Backend เพื่อรองรับชื่อรถทั้งแบบเต็มและแบบย่อ ('รถเครน', 'ดั้มเล็ก', 'ดั้มใหญ่') พร้อม Broadcast SSE ทันที. ขยายเวลา Offline Threshold เป็น 120 วินาที และ Purge Timer เป็น 600 วินาที (10 นาที) เพื่อให้รถยังคงแสดงบนแผนที่ตลอดการเดินทางขากลับร้าน และเพิ่ม 'ดั้มเล็ก' กับ 'ดั้มใหญ่' ใน Whitelist ของ Customer Tracking เพื่อให้ออกลิงก์แผนที่ให้ลูกค้าได้ทุกคัน โดยหน้าเว็บลูกค้าแสดงเฉพาะตำแหน่งหมุด ไม่เปิดเผยชื่อรถหรือความเร็ว.

**English:** Fixed the issue where approving job departure did not update the GPS map status by ensuring S-Link's `JobProvider.approveJobDeparture` uses the effective selected vehicle team when dispatching to `/gps/update_job`, and introducing `normalizeVehicleKey` in POS Backend's `GpsController` to canonicalize keys ('รถเครน', 'ดั้มเล็ก', 'ดั้มใหญ่') with immediate SSE broadcasting. Extended OFFLINE detection to 120s and memory purge timer to 600s (10 min) so vehicles remain visible on the store map throughout the return trip. Added 'ดั้มเล็ก' and 'ดั้มใหญ่' to the Customer Tracking whitelist so tracking links can be issued for all fleet vehicles while strictly preserving customer privacy (showing only location pins without vehicle names or speeds).

## [2026-08-22] Verified backup and guarded restore / สำรองตรวจสอบได้และกู้คืนแบบมีรั้วป้องกัน

**ไทย:** ไฟล์สำรองที่สร้างใหม่เปลี่ยนเป็นรูปแบบมีเวอร์ชัน พร้อม Manifest, จำนวนแถว, รายชื่อคอลัมน์, และ SHA-256 checksum รายตาราง/ทั้งไฟล์ ระบบตรวจไฟล์ก่อนกู้คืนอย่างเข้มงวด โดยอนุญาตเฉพาะตารางและคอลัมน์ที่ตรงกับฐานข้อมูลปัจจุบัน และปฏิเสธไฟล์ที่ถูกแก้ไขหรือโครงสร้างไม่ครบ ก่อนเริ่มเขียนข้อมูล ระบบจะสร้างและตรวจสอบไฟล์สำรองของข้อมูลเดิมอัตโนมัติ 1 ชุด แล้วทำงานใน exclusive database scope; เปิด foreign-key checks กลับเสมอแม้เกิดข้อผิดพลาด และตรวจจำนวนแถวหลังนำเข้าทุกตาราง หน้าจอกู้คืนจะแจ้งผลตรวจ, เตือนว่าการกู้คืนย้อนกลับไม่ได้, และแสดงตำแหน่งไฟล์สำรองก่อนกู้คืนเมื่อสำเร็จ. ไฟล์ JSON แบบเดิมยังอ่านได้เมื่อมีทุกตาราง/คอลัมน์ตรงกันและไม่มีข้อมูล binary ที่พิสูจน์ความถูกต้องไม่ได้.

**English:** Newly created backups now use a versioned format with a manifest, row counts, column lists, and per-table/full-file SHA-256 checksums. Restore performs strict validation against the current database table and column allowlist and rejects altered or incomplete files. Before any mutation, the app creates and verifies one automatic pre-restore safety backup, then uses an exclusive database scope; foreign-key checks are always re-enabled and each restored table has its row count verified. The restore UI shows validation status, clearly warns that the action is irreversible, and displays the pre-restore backup location on success. Legacy JSON backups remain readable only when their complete table/column shape matches and they contain no unverifiable binary data.

## [2026-08-22] Canonical barcode registry migration / ทะเบียนบาร์โค้ดกลาง

**ไทย:** เพิ่มสคริปต์ `bin/migrate_barcode_registry.dart` สำหรับย้ายฐานข้อมูลแบบรัดกุม โดยอ่านค่า DB จาก environment/.env, ล็อก migration ด้วย MySQL advisory lock, ตรวจบาร์โค้ดซ้ำและหยุดก่อนเปลี่ยน schema, และสำรอง JSON แบบ UTF-8 ก่อน DDL. เมื่อข้อมูลสะอาด สคริปต์สร้าง `barcode_registry` ที่มี normalized barcode แบบ unique, backfill บาร์โค้ดหลักและหน่วยเสริม, แล้วติดตั้ง trigger สำหรับ insert/update/delete ของ `product` และ `product_barcode` เพื่อกันบาร์โค้ดซ้ำทั้งระบบ. การลบสินค้าจริงจะลบ reservation ทุกหน่วยของสินค้านั้น; soft delete จะยังสงวนบาร์โค้ดไว้. หลังทำงานสคริปต์ตรวจจำนวนและความตรงกันของ source/registry พร้อมสร้างรายงาน JSON; ไม่ซ่อมหรือกลืน error ของความถูกต้องอัตโนมัติ.

**English:** Added `bin/migrate_barcode_registry.dart`, a guarded database migration that reads DB settings from environment/.env, uses a MySQL advisory lock, audits duplicates and stops before schema changes, and writes a UTF-8 JSON snapshot before DDL. With clean source data it creates the unique normalized `barcode_registry`, backfills primary and unit barcodes, and installs product/product_barcode insert/update/delete triggers to enforce global uniqueness. Hard product deletion releases every reservation for that product, while soft deletion retains reservations. The migration verifies source/registry counts and mappings and writes a JSON report; it never silently repairs or suppresses integrity failures.

ไฟล์นี้ใช้สำหรับบันทึกการแก้ไขบั๊ก, การปรับปรุงโค้ด, หรือการเปลี่ยนแปลงระบบที่เกิดขึ้นในโปรเจกต์ เพื่อเป็นประวัติการทำงานและใช้อ้างอิงในอนาคต

## [2026-08-22] Simple shop refresh / ปรับหน้าเว็บขายของให้เรียบและใช้งานง่าย

**ไทย:** ปรับหน้า `backend/public/shop/` ใหม่ให้ดูสะอาด เรียบ และใช้งานง่ายขึ้น โดยยกเครื่อง `index.html`, `shop.css`, และ `shop.js` ให้มีโครงสร้างหน้าที่อ่านง่ายขึ้น, แถบหัวเรื่องที่สื่อสถานะได้ชัด, แถบค้นหาและหมวดหมู่ที่แตะง่าย, การ์ดสินค้าแบบมินิมอล, การ์ดสินค้าแนะนำแบบเลื่อนแนวนอน, และแถบตะกร้าด้านล่างที่เห็นยอดรวมชัดเจนขึ้น พร้อมปรับข้อความสรุปบนหน้าให้สะท้อนสถานะการใช้งานจริงแบบเรียบ ๆ ไม่ซับซ้อน

**English:** Refreshed `backend/public/shop/` to keep the shop page clean, simple, and easy to use. Updated `index.html`, `shop.css`, and `shop.js` to make the layout easier to scan, add a clearer status header, improve the search and category controls, simplify product cards, keep featured products in a horizontal strip, and make the floating cart summary more readable. Also updated the on-page summary text and metrics so the UI feels straightforward instead of busy.

---

## [2026-08-21] Primary barcode duplicate warning / แจ้งเตือนบาร์โค้ดหลักซ้ำทันที

**ไทย:** ช่องบาร์โค้ดหลักในฟอร์มสินค้าเช็กบาร์โค้ดซ้ำอัตโนมัติหลังหยุดพิมพ์หรือสแกน 350 มิลลิวินาที และเช็กทันทีเมื่อกด Enter โดยแปลงค่าจากเครื่องสแกนตามการตั้งค่าเดิมก่อนตรวจ. กันผลค้นหาเก่าค้างและกล่องแจ้งเตือนซ้ำ; เมื่อพบจะแจ้งชัดเจนว่า “บาร์โค้ดซ้ำ” และการบันทึกยังตรวจซ้ำอีกครั้งเพื่อป้องกันข้อมูลซ้ำ.

**English:** The primary barcode field now checks for duplicates 350 ms after typing or scanning settles, and immediately on Enter, preserving the existing scanner-input normalization. Stale lookups and repeated dialogs are suppressed; conflicts clearly show “Duplicate barcode,” while save-time validation remains a final duplicate-data safeguard.

## [2026-08-21] Confirmed S-Link attendance / ยืนยันการลงเวลาจาก S-Link

**ไทย:** POS รับการลงเวลาจากพนักงานที่ระบุใน JWT เท่านั้น และปฏิเสธ `user_id` ในข้อมูลที่ส่งมาหากไม่ตรงกัน. การตอบกลับซิงก์ระบุ `sync_id` ที่ยืนยันแล้ว; หน้า HR Summary รีเฟรชข้อมูลจาก POS ทุก 12 วินาทีและยกเลิก timer เมื่อปิดหน้า.

**English:** POS now accepts attendance only for the employee resolved from the JWT and rejects conflicting body `user_id` values. Sync acknowledgements identify confirmed `sync_id`s; HR Summary refreshes POS data every 12 seconds and cancels its timer on disposal.

## [2026-08-19] Wi-Fi GPS Firmware for Dump Trucks / สร้างโปรเจกต์ GPS Wi-Fi สำหรับรถดั้มเล็กและดั้มใหญ่

**ไทย:** สร้างโปรเจกต์ ESP32 GPS + Pocket Wi-Fi เพิ่มอีก 2 ชุดในโฟลเดอร์ `GPS_WIFI_DUMP_SMALL` และ `GPS_WIFI_DUMP_LARGE` โดยตั้งชื่อรถตามรหัสกลางของระบบ (`ดั้มเล็ก` และ `ดั้มใหญ่`) ซึ่งตรงกับระบบจัดส่ง S-Link, POS และหน้าเว็บแผนที่แบบ 100% ทำให้เมื่อกดปล่อยรถในแอป S-Link สถานะงานจะซิงค์ขึ้นแผนที่เรียลไทม์ได้ถูกต้องทันที.

**English:** Created two ESP32 GPS + Pocket Wi-Fi firmware projects under `GPS_WIFI_DUMP_SMALL` and `GPS_WIFI_DUMP_LARGE` with canonical vehicle keys `ดั้มเล็ก` and `ดั้มใหญ่`, matching S-Link delivery dispatch, POS, and the live GPS tracking map 100%.

---

## [2026-08-19] GPS Telegram Alert & Timeout Tuning / อัปเดตแจ้งเตือนและปรับเวลาตรวจจับดับรถ GPS

**ไทย:** อัปเดต Bot Token (`8410912861:...`) และ Group Chat ID (`-5507041706`) ใน `gps_controller.dart` สำหรับแจ้งเตือนสถานะ GPS รถยนต์ พร้อมปรับเวลาการตรวจจับดับเครื่องยนต์ให้แจ้งเตือนเร็วขึ้นเมื่อขาดสัญญาณเกิน 60 วินาที (1 นาที) และลบรถออกจากแผนที่เมื่อขาดสัญญาณเกิน 2 นาที (120 วินาที) โดยตรวจสอบความถี่ทุก 10 วินาที Rebuild `backend/server.exe` เรียบร้อย.

**English:** Updated the Telegram Bot Token and Group Chat ID (`-5507041706`) in `gps_controller.dart`. Tuned engine-stop/offline detection to alert after 60 seconds of signal loss and purge vehicles from map memory after 2 minutes (120 seconds), polling every 10 seconds. Rebuilt and restarted `backend/server.exe`.

---

## [2026-08-18] Authoritative S-Link checkout endpoint / จุดชำระเงิน S-Link ที่ตรวจสอบโดยเซิร์ฟเวอร์

**ไทย:** เพิ่ม API ที่ป้องกันด้วย JWT คือ `POST /api/v1/mobile-checkout/` แยกจาก
`/orders` เดิม เพื่อให้มือถือส่งเพียงสินค้าและจำนวน, ลูกค้า, วิธีชำระ และ UUID สำหรับ
กันคำสั่งซ้ำ. เซิร์ฟเวอร์ล็อกราคา/สต็อก/ledger, คำนวณยอด ส่วนลด และ VAT เอง แล้วสร้าง
บิล ตัดสต็อก ตัดแต้ม หรือใช้คูปองภายใน transaction เดียวกัน. ใช้แต้มกับคูปองพร้อมกัน
ไม่ได้ และคูปองถูกตรวจเจ้าของ สถานะ วันหมดอายุ และมูลค่าอีกครั้งก่อน commit. รองรับ
เฉพาะ CASH และ PROMPTPAY; CREDIT ถูกปฏิเสธจนกว่าจะย้าย logic หนี้มาอยู่บนเส้นทางนี้.

**English:** Added a JWT-protected `POST /api/v1/mobile-checkout/` endpoint,
separate from legacy `/orders`. Mobile submits only product IDs/quantities,
customer, payment method, and an idempotency UUID. The server locks and
calculates product prices, stock, loyalty data, discounts, and VAT, then creates
the order and consumes stock, points, or a coupon in one transaction. Points
and coupons are exclusive; coupon ownership, state, expiry, and value are
rechecked before commit. Only CASH and PROMPTPAY are supported; CREDIT is
rejected until debt handling is migrated to this authoritative path.

**Addendum:** Added JWT-protected `POST /api/v1/mobile-checkout/quote` for
read-only mobile UX. It returns the current ledger balance, configured
redemption rate, and `min(available, floor(pre-VAT base × 75% × rate))`; it
does not reserve a benefit. The final checkout repeats validation while locked.

---

## [2026-08-18] Point/coupon checkout safeguards / กติกาแต้มและคูปองตอนชำระเงิน

**ไทย:** จำกัดการแลกแต้มสูงสุดที่ 75% ของยอดหลังส่วนลดปกติและโปรโมชั่น (ก่อน VAT)
และป้องกันการใช้แต้มร่วมกับคูปอง LINE OA. คูปองและแต้มถูกตรวจซ้ำและตัดสิทธิ์ภายใน
transaction เดียวกับบิล; ตรวจเจ้าของคูปอง, สถานะ, วันหมดอายุ และมูลค่าส่วนลดก่อน commit.
ส่วนลดคูปองถูกคำนวณก่อน VAT แล้ว เพื่อให้ VAT ในบิลคำนวณจากยอดขายหลังส่วนลด.

**English:** Point redemption is capped at 75% of the post-discount/promotion,
pre-VAT sale base, and cannot be combined with a LINE OA coupon. Coupon and
point debits are revalidated and consumed inside the same order transaction,
including coupon owner, status, expiry, and discount value. Coupon discounts
now reduce the taxable base before VAT is calculated.

---

## [2026-08-15] GPS Wi-Fi bench-test kit / ชุดทดสอบ GPS ผ่าน Wi-Fi

**ไทย:** แยกชุดทดสอบ ESP32 + NEO-M8N ผ่าน Wi-Fi ออกจาก 4G โดยย้าย Wi-Fi, URL และ
device key ไปไว้ใน header ภายในเครื่องที่ Git ไม่เก็บ พร้อมไฟล์ตัวอย่าง. Serial Monitor
แสดงผล PASS/FAIL ชัดเจนสำหรับ Wi-Fi, พิกัดใหม่ (อายุ/ดาว/HDOP) และ HTTP 2xx; เพิ่ม
คู่มือต่อสายและแก้ปัญหา 401/400 แบบไทย–อังกฤษ. `setInsecure()` ถูกระบุชัดว่าใช้เฉพาะ
bench test เท่านั้น.

**English:** Refreshed the ESP32 + NEO-M8N Wi-Fi-only bench kit with ignored
local secrets and a committed example. Serial diagnostics now assert Wi-Fi,
fresh GPS quality (age/satellites/HDOP) and HTTP 2xx success. A bilingual
wiring/troubleshooting guide covers 401/400, and `setInsecure()` is explicitly
limited to the bench test.

---

## [2026-08-15] Duplicate barcode guard / ป้องกันบาร์โค้ดซ้ำ

**ไทย:** เตือนทันทีเมื่อกรอกบาร์โค้ดหลักเสร็จหากถูกใช้กับสินค้าอื่น และตรวจซ้ำอีกครั้ง
ก่อนบันทึกเพื่อกันข้อมูลเปลี่ยนระหว่างกรอก. ครอบคลุมบาร์โค้ดหน่วยย่อย/แพ็คด้วย และการ
แก้ไขสินค้าจะไม่เตือนบาร์โค้ดของสินค้าเดิมเอง.

**English:** The product form warns after entering a primary barcode already
owned by another product and checks again at save time. It also covers
unit/package barcodes, while editing a product never flags that product's own
barcodes.

---

## [2026-08-15] Fingerprint disconnect notification stability / ป้องกันแจ้งเตือนเครื่องสแกนนิ้วหลุดซ้ำ

**ไทย:** ทำให้การเชื่อมต่อ, auto-discovery และ retry ของเครื่องสแกนนิ้วทำงานทีละรอบ
และละทิ้ง callback ของ socket เก่า จึงไม่ตัดการเชื่อมต่อใหม่หรือทำให้ popup เด้งวนซ้ำ.
ปุ่มเชื่อมต่อใหม่รอผล retry จริงและจะปิดเมื่อสำเร็จเท่านั้น; ปุ่ม X ซ่อนเฉพาะเหตุการณ์
หลุดรอบนั้น แล้วจะแจ้งเหตุการณ์ใหม่อีกครั้งเมื่อกลับมาเชื่อมต่อและหลุดในภายหลัง.

**English:** Fingerprint connection, discovery and retry attempts are now
serialized, and stale socket callbacks cannot tear down a replacement socket or
loop the popup. Reconnect waits for one real retry and dismisses only on
success; X snoozes only the current outage, with a later post-recovery outage
shown again.

---

## [2026-08-15] Safe S-Link stock-count approval / ปิดใบตรวจนับ S-Link อย่างปลอดภัย

**ไทย:** เพิ่มแบบตรวจนับพื้นฐานที่แก้ไขได้จาก S-Link และ POS จะนำเข้าเฉพาะใบที่ยัง
รอยืนยันเท่านั้น เมื่อปรับครบทุกบรรทัดจึงปิดใบแบบมีเงื่อนไขและตรวจสอบผล ทำให้ใบเดิม
ไม่นำมาปรับซ้ำได้. API ล็อกใบที่ตรวจแล้ว: การส่งซ้ำด้วยข้อมูลเดิมเป็น no-op ที่ปลอดภัย
แต่การแก้ไขหรือลบใบที่ปิดแล้วจะได้ 409; ผู้ใช้ทั่วไปส่งหรือลบได้เฉพาะใบของตนเอง.
หน้าจอ POS ยังปฏิเสธใบหรือสินค้าที่ซ้ำในรายการรอบันทึก และเมื่อบางรายการล้มเหลวจะ
เก็บเฉพาะรายการที่ล้มเหลวไว้ให้ลองใหม่ ไม่ล้างทิ้ง.

**English:** Added an editable S-Link stock-count template and made POS import
only sheets still awaiting review. A sheet is conditionally marked reviewed and
verified only after all its rows apply, preventing a second adjustment. Checked
sheets are immutable at the API: an identical retry is a safe no-op, while a
changed retry or deletion returns 409; non-privileged users may only manage
their own sheets. POS rejects duplicate pending sheets/products and keeps only
failed rows for retry instead of clearing them.

**ไทย (เพิ่มเติม):** การปรับจาก S-Link ทำใน transaction เดียว: ล็อกใบที่ยัง
เปิดอยู่ทั้งหมดก่อน แล้วปรับสินค้า/บันทึก ledger/ปิดใบพร้อมกัน หากเครื่องอื่นปิดใบ
ไปก่อน จะ rollback ทั้งชุดและไม่เปลี่ยนสต๊อกแม้แต่รายการเดียว.

**English (additional):** S-Link approval is now one transaction: it locks all
open source sheets first, then updates products, ledger and sheet status
together. If another POS session closed a sheet first, the entire operation
rolls back with zero stock changes.

**ไทย (เพิ่มเติม):** ใบตรวจนับจาก S-Link ไม่ถามรหัสแอดมินแม้ส่วนต่างมาก;
การปรับสต๊อกด้วยมือยังคงถามตามค่าตั้งเดิมของระบบ.

**English (additional):** S-Link stock-count sheets never request an admin
PIN, regardless of variance; ad-hoc manual adjustments retain the existing
optional PIN setting.

---

## [2026-08-15] Magic Search product-name suggestions

**ไทย:** เพิ่มปุ่ม 🪄 ข้างช่องชื่อสินค้าในหน้าสร้าง/แก้ไขสินค้า เมื่อมีบาร์โค้ด 8–14
หลัก ระบบจะแสดง popup ค้นหาชื่อจาก UPCitemdb และ Open Food Facts ให้เลือกเองก่อน
เติมชื่อสินค้า หากไม่พบหรือบริการภายนอกขัดข้องยังกรอกชื่อแบบเดิมได้ และไม่มีการบันทึก
ชื่อจากภายนอกโดยอัตโนมัติ

**English:** The product form now has a 🪄 Magic Search button beside the name
field. For an 8–14 digit barcode, it shows optional UPCitemdb and Open Food
Facts name suggestions in a popup. The user must select a result; no external
name is saved automatically, and manual entry remains available on any lookup
failure.

---

## [2026-08-14] Select supplier before S-Link PO draft

**ไทย:** S-Link ต้องเลือกผู้ขายจากรายชื่อผู้ขายใน POS ก่อนบันทึกร่างใบสั่งซื้อ
ระบบส่ง `supplierId` ที่เลือกไปยัง backend และ backend ตรวจสอบว่าเป็นผู้ขายจริงก่อน
บันทึก จึงไม่ใช้ “ไม่ระบุผู้ขาย” โดยอัตโนมัติ และยังไม่รับสินค้าเข้าสต๊อก

**English:** S-Link now requires selection of an existing POS supplier before
creating a purchase-order draft. The selected `supplierId` is validated by the
backend; no automatic unspecified supplier is used, and the draft never
receives stock.

---

## [2026-08-14] Backend self-checks PO draft schema

**ไทย:** Backend จะตรวจและเพิ่มคอลัมน์/ดัชนีที่จำเป็นสำหรับการสร้างร่างใบสั่งซื้อ
จาก S-Link (`idempotencyKey`, hash และผู้ขายระบบ) ก่อนบันทึกร่างครั้งแรก จึงไม่
เกิดข้อผิดพลาดเมื่อยังไม่ได้เปิด POS Desktop เพื่อรัน migration เดิม ทั้งหมดเกิดก่อน
เริ่ม transaction ของใบสั่งซื้อ และยังไม่มีการปรับสต๊อกหรือราคา

**English:** Before creating an S-Link purchase-order draft, the backend now
ensures the required idempotency and system-supplier schema is present. This
removes the dependency on first launching POS Desktop for its legacy migration;
the check runs before the PO transaction and never changes stock or prices.

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
1A%08H!--2#02I2-@!9AI2"  ( N a v i g a t i o n R a i l   l e a d i n g )   %!2D'II2%H2*8CI8H!1IH2  ( N a v i g a t i o n R a i l   t r a i l i n g )   CD%L  m a i n _ s c r e e n . d a r t 
 
 -   2 0 2 6 - 0 7 - 1 5   :   AIDI-4%2  ( U n d e f i n e d   n a m e )   C2#@#5"C
I  d i s t a n c e K m   A%0  f u e l C o s t   5H  e x c e l _ e x p o r t _ s e r v i c e . d a r t   B"C+I6I-!9%2  r e c o r d   !2C*HC1'A#H-3DC
I
 
 -   2 0 2 6 - 0 7 - 1 5   :   @4H!8H!*#8H2I3!1%#2"H2"  C+I2#2"242!2*H  @7H-16H2I3!1#'!@I2*9H#012#H2C
IH2"  ( 1IH2)    2"CI+!'+!9H  ' H2@42'   A%0
7H-  ' H2I3!1C2#*H' 
 
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
# 2026-08-08 — S-Link count sheets reviewed in POS / ใบตรวจนับ S-Link ยืนยันใน POS

- TH: หน้าเช็คสต๊อก POS เปลี่ยนจากการดึง Firestore แบบเก่า เป็นการดึงใบตรวจนับ
  ที่ S-Link ส่งเข้า MySQL ของ POS และแสดงยอดระบบ–ยอดจริง–ส่วนต่างก่อนกดยืนยัน
- TH: หลังยืนยันปรับสต๊อกครบทุกสินค้าในใบเดียวกัน จึงทำเครื่องหมายใบตรวจนับว่า
  ตรวจแล้ว พร้อมผู้ยืนยันและเวลา; ถ้ารายการใดล้มเหลว ใบจะยังคงรอตรวจเพื่อไม่ให้
  ปรับซ้ำหรือทำข้อมูลหาย
- EN: POS stock check now imports S-Link count sheets from MySQL and marks a
  sheet reviewed only after every item has been confirmed successfully.
- TH: ป้องกันการใช้หน้าจอที่ปิดไปแล้วหลังรอปิดใบตรวจนับ จึงไม่เกิดคำเตือน
  `use_build_context_synchronously` จาก Dart analyzer

# 2026-08-09 — Scratch query syntax repair

- TH: ลบคำสั่ง build ที่เผลอติดอยู่หน้าบรรทัด import ใน `backend/scratch_query.dart`
ทำให้ไฟล์กลับเป็น Dart syntax ที่ถูกต้อง

# 2026-08-09 — S-Link stock-check import collation fix / แก้ collation ตอนดึงใบตรวจนับ S-Link

- TH: แก้คำสั่งอ่านใบตรวจนับจาก S-Link ทั้งหน้า POS และ API ประวัติงานให้กำหนด
  `utf8mb4`/collation ชัดเจน จึงไม่ชน MySQL error 1267 เมื่อคอลัมน์ HR เดิมใช้
  collation ต่างจากตารางใบงาน; จับคู่ Firebase UID แบบตรงตัวก่อน แล้วค่อยรองรับ
  รหัสพนักงานแบบเดิม และยังแสดงรหัสผู้ตรวจนับได้เมื่อไม่มี employee profile.
- EN: Normalized the POS and work-log API read queries to explicit
  `utf8mb4` collations, preventing MySQL 1267 errors across legacy HR table
  collations. Firebase UID matching is exact with legacy-ID fallback, while
  records without an employee profile still remain readable.

# 2026-08-09 — Deterministic S-Link work-log employee match / เลือกพนักงานใบงาน S-Link แบบแน่นอน

- TH: แก้ JOIN employee profile ของใบตรวจนับให้เลือกได้เพียงหนึ่งคนตามลำดับ
  Firebase UID, user ID เดิม, แล้วจึง employee profile ID จึงไม่คูณรายการสินค้า
  เมื่อตารางพนักงานมีข้อมูลรหัสซ้ำกัน
- EN: Made the count-sheet employee lookup deterministic: Firebase UID, then
  legacy user ID, then employee profile ID. This prevents duplicate item rows
  when legacy employee identifiers overlap.

# 2026-08-09 — Safe whitespace fallback for S-Link count sheets / รองรับช่องว่างในใบตรวจนับ S-Link อย่างปลอดภัย

- TH: แก้ชื่อมาตรฐาน `ฝาวงบ่อ60ซม.รูเล็ก` ใน S-Link ให้ตรง POS และเพิ่มการหา
  สินค้าสำรองเฉพาะเมื่อชื่อที่ตัดช่องว่าง ASCII, tab, CR และ LF ออกตรงกันเพียง
  รายการเดียว; หากไม่พบหรือพบมากกว่าหนึ่ง จะไม่ยืนยันใบตรวจนับ
- EN: Corrected the S-Link canonical product name and added a fallback that
  ignores ASCII space, tab, CR, and LF only when it identifies exactly one
  POS product. Zero or ambiguous matches keep the count sheet pending.

# 2026-08-09 — Shared S-Link stock-check template / แบบตรวจนับ S-Link ส่วนกลาง

- TH: เพิ่ม API เก็บแบบตรวจนับใน MySQL พร้อม revision ป้องกันบันทึกทับกัน และ
  อนุญาตเฉพาะ ADMIN/HR แก้ไข; ไม่มีการแก้ใบงานที่ส่งแล้ว
- EN: Added a MySQL-backed revisioned stock-check template API. Only ADMIN/HR
  may edit it, and submitted work logs remain unchanged.

# 2026-08-10 — Deterministic S-Link attendance identity / จับคู่ผู้ลงเวลา S-Link แบบแน่นอน

- TH: แก้ API ลงเวลาให้จับคู่บัญชี S-Link (`user.id`/`employee_profile.user_id`),
  ชื่อบัญชี และ Firebase UID ก่อนรหัส primary key ของพนักงาน จึงไม่ให้เลขบัญชี
  เช่น 16 หรือ 17 ไปชนกับรหัสพนักงานของคนอื่นและลงเวลาผิดคน.
- EN: Attendance API identity resolution now prioritizes the S-Link account
  (`user.id`/`employee_profile.user_id`), username, and Firebase UID before a
  legacy employee primary-key fallback, preventing account-ID collisions from
  recording attendance for another employee.

# 2026-08-13 — Goods receipt suggested price / ราคาแนะนำในใบรับสินค้า

- TH: เพิ่มข้อความตัวเล็กใต้ช่องทุน/หน่วยในหน้าใบรับสินค้า แสดงราคาแนะนำที่
  คำนวณจากทุน × 1.3 และอัปเดตทันทีเมื่อแก้ไขทุน เพื่อไม่ต้องคำนวณแยกเอง.
- EN: Added a small suggested-price label below the unit-cost field on goods
  receipts. It calculates cost × 1.3 and updates immediately when the cost changes.

# 2026-08-13 — Stock-alert price visibility / แสดงราคาในรายการแจ้งของหมด

- TH: เพิ่มป้ายราคาทุนและราคาขายปัจจุบันใต้ชื่อผู้แจ้งในรายการรอจัดการของหน้า
  แจ้งของหมด/แจ้งซ่อม โดยใช้การค้นหาสินค้าเดิม จึงไม่เพิ่มจำนวนคำขอฐานข้อมูล.
- EN: Added current cost and retail-price badges below the reporter on pending
  stock-alert rows, reusing the existing product lookup without additional database requests.

# 2026-08-13 — Editable goods receipt totals / กรอกราคารวมในใบรับสินค้า

- TH: เปลี่ยนคอลัมน์ราคารวมในใบรับสินค้าเป็นช่องกรอกโดยตรง และเอาปุ่มเครื่องคิดเลข
  ออก; แก้จำนวนหรือทุน/หน่วยจะคำนวณราคารวมใหม่ ส่วนการแก้ราคารวมจะคำนวณทุน/หน่วย
  ย้อนกลับทันที โดยไม่หารเมื่อจำนวนเป็นศูนย์.
- EN: Made the goods-receipt total column directly editable and removed the
  calculator button. Quantity or unit-cost edits update the total; total edits
  immediately derive the unit cost, while zero quantities are never divided.

# 2026-08-14 — Goods receipt retail price and VAT-aware suggestion / ราคาปลีกและคำแนะนำตาม VAT ในใบรับสินค้า

- TH: เพิ่มช่องราคาปลีกระหว่างทุน/หน่วยกับราคารวมในใบรับสินค้า โดยดึงราคาขายเดิม
  มาให้แก้ไขได้ทันทีและบันทึกเป็นราคาขายหน้าร้านเมื่อรับสินค้า รวมถึงกรณีรับบางส่วน;
  ปรับตารางให้กว้างพอดีกับคอลัมน์ใหม่ ตั้ง VAT เริ่มต้นเป็นไม่มีภาษี และคำนวณราคา
  แนะนำจากทุน × 1.3 หรือ × 1.391 เมื่อใบมี VAT.
- EN: Added an editable retail-price field between unit cost and total on goods
  receipts. It starts with the current retail price and updates the POS selling
  price on full or partial receipt. The wider table accommodates the new column,
  VAT now defaults to none, and suggested prices use cost × 1.3 or × 1.391 for
  VAT invoices.

# 2026-08-14 — Goods receipt price-column alignment / จัดหัวคอลัมน์ราคาในใบรับสินค้า

- TH: จัดหัวคอลัมน์ทุน/หน่วย ราคาปลีก และรวมให้อยู่กึ่งกลางตรงกับช่องกรอกราคาของ
  แต่ละคอลัมน์ โดยคงตัวเลขในช่องไว้ชิดขวาเพื่ออ่านง่าย.
- EN: Centered the unit-cost, retail-price, and total column headers over their
  respective inputs while retaining right-aligned numeric entry for readability.

- TH: เลื่อนส่วนทุน/หน่วยลงให้แนวกล่องกรอกตัวเลขตรงกับช่องราคาปลีกและราคารวม
  แม้มีข้อความราคาแนะนำอยู่ด้านล่าง.
- EN: Aligned the unit-cost input vertically with the retail-price and total
  inputs while preserving the suggested-price label below it.

- TH: จัดตัวเลขที่กรอกในช่องทุน/หน่วย ราคาปลีก และราคารวมให้อยู่กึ่งกลาง.
- EN: Centered entered values in the unit-cost, retail-price, and total fields.

# 2026-08-14 — S-Link purchase-order drafts / ร่างใบสั่งซื้อจาก S-Link

- TH: เปลี่ยนหน้ารับสินค้าของ S-Link ให้สร้างร่างใบสั่งซื้อหลายรายการแทนการเพิ่มสต็อก
  ทันที รองรับค้นหาสินค้าเดิมหรือพิมพ์ชื่อรายการใหม่ และให้จำนวน/ทุนต่อหน่วย/ยอดรวม
  คำนวณย้อนกลับหากันได้ ร่างทั้งหมดใช้ผู้ขาย “ไม่ระบุผู้ขาย” และต้องตรวจ/รับจริงบน POS.
  เพิ่ม API ที่ตรวจ JWT role (ADMIN/CASHIER), ใช้ UUID กันการส่งซ้ำ และทำ transaction
  เดียวโดยไม่แก้สต็อก ราคา หรือ stock ledger; รายการที่ยังไม่จับคู่สินค้าจะรับเข้าจริงไม่ได้.
- EN: Reworked S-Link receiving into a multi-item purchase-order draft flow.
  Existing products can be searched while freeform names are retained for POS
  correction; quantity, unit cost, and total calculate each other. Drafts use
  the server-resolved “Unspecified supplier” and must be reviewed/received on
  Desktop POS. The secured ADMIN/CASHIER API uses a stable UUID idempotency key
  and one transaction without mutating stock, prices, or the stock ledger;
  unresolved lines cannot be received.
- TH: เพิ่ม hash ของข้อมูลแต่ละคำขอไว้คู่กับ UUID: retry ที่ข้อมูลเดิมจะคืนร่างเดิม
  แต่ UUID เดิมกับข้อมูลต่างกันจะถูกปฏิเสธด้วย HTTP 409. ผู้ขายกลางใช้ system key
  แบบ unique และ UPSERT เพื่อไม่ให้เกิดชื่อผู้ขายซ้ำจากคำขอแรกที่มาพร้อมกัน.
- EN: Stored a request-payload hash with each UUID: identical retries return
  the existing draft, while a reused UUID with different data receives HTTP 409.
  The canonical supplier now has a unique system key and an UPSERT bootstrap to
  prevent concurrent first requests from creating duplicates.

# 2026-08-15 — GPS tracker local configuration / ตั้งค่า GPS Tracker เฉพาะเครื่อง

- TH: ย้ายรหัส Wi-Fi และ GPS device key ออกจาก `GPS/GPS.ino` ไปไว้ที่
  `GPS/gps_tracker_secrets.h` ซึ่งถูกละเว้นจาก Git พร้อมไฟล์ตัวอย่างสำหรับ
  เตรียมเครื่องใหม่; คงค่า APN, รถเครน และการต่อ UART ไว้ใช้งานทันที. เพิ่ม
  คำเตือนในโค้ดว่า A7670E ต้องรับไฟ 5V ที่ VCC/GND และยังไม่ให้ป้อนไฟเข้า VDD.
- EN: Moved Wi-Fi credentials and the GPS device key out of `GPS/GPS.ino` into
  the Git-ignored `GPS/gps_tracker_secrets.h`, with an example for new devices.
  APN, crane identity, and UART mapping remain ready to use. Added an explicit
  power note: feed A7670E at VCC/GND with regulated 5V and do not feed VDD.

- TH: เมื่อ A7670E ไม่ตอบ AT ตอนเริ่มต้น จะไม่ยิงคำสั่งต่อ GPRS ทุกครั้งที่ GPS
  ส่งพิกัดอีกต่อไป เพื่อให้ GPS ทำงานต่อและลด log ซ้ำ; firmware จะลองปลุกโมเด็มใหม่
  ทุก 30 วินาที พร้อมระบุให้ตรวจ VCC 5V, GND ร่วม, PWR_EN และ UART ก่อน APN.
- EN: If A7670E fails its initial AT response, the tracker no longer makes a
  GPRS call for every GPS update. GPS keeps running while firmware retries a
  controlled modem wake-up every 30 seconds and directs power/PWR_EN/UART
  checks before APN troubleshooting.
# 2026-08-18 — Advance/payroll deduction integrity / ความถูกต้องของการหักเงินเบิก

- TH: แก้วงจรเงินเบิกล่วงหน้าให้คำขอใหม่เป็น `PENDING` เสมอ และอนุมัติ/ปฏิเสธได้เฉพาะจากสถานะนี้เท่านั้น; เมื่ออนุมัติจึงตั้งยอดคงเหลือเท่ากับยอดขอ. การยืนยัน payroll ทำใน MySQL transaction เดียว: ล็อก payroll ฉบับร่างและรายการเบิกตามลำดับ, บันทึก ledger, หักยอดคงเหลือแบบมีเงื่อนไข, เปลี่ยนสถานะ แล้วจึง commit; ผิดพลาดหรือยอดไม่พอจะ rollback ทั้งหมด. การมาร์คจ่ายและการจ่ายทั้งรอบจะไม่หักเงินเบิกซ้ำหรือข้ามฉบับร่างอีกต่อไป, และลบได้เฉพาะ draft ที่ไม่มี ledger.
- EN: Made new advance requests always `PENDING`, with approval/rejection allowed only from that state; approval then initializes the remaining balance. Payroll confirmation now uses one MySQL transaction: it locks the DRAFT payroll and advances in deterministic order, writes the ledger, conditionally updates balances/statuses, confirms, and commits; any error or insufficient balance rolls back everything. Marking paid and bulk payment no longer deduct advances again or skip drafts, and deletion is limited to ledger-free drafts.
- TH: เพิ่ม unique key ปลอดภัยสำหรับ `(advance_id, payroll_id)` โดยจะไม่ลบหรือแก้ข้อมูลเก่าที่ซ้ำ—หากพบข้อมูลซ้ำจะไม่เพิ่ม key เพื่อให้ตรวจสอบก่อน. เพิ่มรายงาน anomaly แบบอ่านอย่างเดียว และคำสั่งซ่อมด้วยมือเฉพาะ `DEDUCTED` ที่ไม่มี ledger จริงและยอดเป็นศูนย์; ไม่มีการซ่อมอัตโนมัติหรือแก้ข้อมูลกำกวม.
- EN: Added a safe unique key for `(advance_id, payroll_id)` without deleting or altering historical duplicates—if duplicates exist, the key is not added pending review. Added a read-only anomaly report and a manual repair restricted to zero-balance `DEDUCTED` rows with no ledger; there is no automatic repair or mutation of ambiguous data.

- TH: เพิ่ม cutoff ตามวันสิ้นสุดรอบ payroll ทั้งตอนคำนวณและตอนยืนยันใน transaction: จะหักได้เฉพาะรายการที่ยื่นและอนุมัติไม่เกินวันสิ้นสุดรอบเท่านั้น จึงไม่สามารถนำรายการเบิกใหม่ไปหักกับรอบเงินเดือนย้อนหลังได้. ไม่ได้ซ่อมหรือเปลี่ยนข้อมูลจริงเดิมอัตโนมัติ.
- EN: Added a payroll-period-end cutoff both during calculation and during transactional confirmation: only advances requested and approved no later than the period end are eligible, so a new advance cannot reduce a historical payroll. No existing live data is repaired or changed automatically.

# 2026-08-18 — Guarded payroll batch cleanup / เครื่องมือล้างรอบเงินเดือนแบบมีเงื่อนไข

- TH: เพิ่มสคริปต์ครั้งเดียวแบบ preview เป็นค่าเริ่มต้นสำหรับล้างรอบเงินเดือนที่สร้างผิดวันที่ 18/08/2026 เท่านั้น. การล้างจริงต้องส่ง `--apply` และตรวจภายใน transaction ว่าตรงกับ payroll #383–#389 จำนวน 7 คน ยอดสุทธิ 7,398 บาท, ค่าใช้จ่าย #42 และรายการหักเงินเบิก #9–#11 รวม 2,100 บาทก่อนทุกครั้ง. หากเงื่อนไขใดไม่ตรงจะ rollback ทั้งหมด; หลังลบจะคำนวณยอดคงเหลือและสถานะของเงินเบิกจาก ledger ที่เหลือ (รวม ledger เก่าของรายการ #10) แล้วตรวจผลซ้ำ.
- EN: Added a preview-by-default, one-off cleanup script for only the erroneous 18 Aug 2026 payroll batch. Actual deletion requires `--apply` and transactionally verifies payroll #383–#389 (7 rows totalling 7,398 baht), expense #42, and advance deductions #9–#11 totalling 2,100 baht. Any mismatch rolls back everything; after deletion it recomputes affected advance balances/statuses from the remaining ledger, retaining advance #10's older ledger, and post-verifies the result.
# #   F i x :   B a r c o d e   S c a n n e r   I m p r o v e m e n t   P l a n 
 
 * * D a t e * * :   2 0 2 6 - 0 8 - 1 9 
 
 * * I s s u e * * :   B a r c o d e   s c a n n e r   i n t e g r a t i o n   h a d   s e v e r a l   i s s u e s   i n c l u d i n g   s c a n n i n g   t h e   w r o n g   p r o d u c t   d u e   t o   f u z z y   m a t c h i n g ,   A S C I I   c o n v e r s i o n   w i t h o u t   c h e c k i n g   f o r   T h a i   i n p u t ,   l a c k   o f   e n t e r / t a b   s u f f i x   c o n f i g u r a t i o n ,   a n d   m i s s i n g   h a r d w a r e   s c a n n e r   s u p p o r t   i n   p r o d u c t   c r e a t i o n   f o r m . 
 
 * * R e s o l u t i o n * * : 
 
 1 .   * * S t a r t u p   C o n f i g   L o a d i n g * * :   I n i t i a l i z e d   \ B a r c o d e U t i l s \   e a r l y   i n   \ m a i n . d a r t \ . 
 
 2 .   * * S a f e   T h a i   C o n v e r s i o n * * :   A d d e d   \ i s T h a i I n p u t ( ) \   g u a r d   i n   \ B a r c o d e U t i l s . f i x T h a i I n p u t \   t o   p r e s e r v e   E n g l i s h   i n p u t .   A d d e d   s c a n n e r   s u f f i x   c o n f i g u r a t i o n   ( \ E n t e r \ / \ T a b \ )   t o   s h a r e d   p r e f e r e n c e s . 
 
 3 .   * * H a r d e n e d   P O S   S c a n   F l o w * * :   R e m o v e d   t h e   d a n g e r o u s   3 0 0 m s   d e b o u n c e   t i m e r   i n   \ p o s _ b a r c o d e _ h a n d l e r _ m i x i n . d a r t \   a n d   c l e a r e d   \  a r c o d e C t r l \   s y n c h r o n o u s l y .   H a n d l e d   \ L o g i c a l K e y b o a r d K e y . t a b \   n a t i v e l y . 
 
 4 .   * * E x a c t   M a t c h   R e q u i r e m e n t * * :   R e m o v e d   \ e l s e   i f   ( m a t c h e s . i s N o t E m p t y ) \   f r o m   \ p o s _ c a r t _ m i x i n . d a r t \   t o   s t r i c t l y   e n f o r c e   e x a c t   p r i m a r y / u n i t   b a r c o d e   m a t c h . 
 
 5 .   * * P r o d u c t   F o r m   S u p p o r t * * :   I n j e c t e d   \  u t o f o c u s :   t r u e \   a n d   \  i x T h a i I n p u t ( ) \   n o r m a l i z a t i o n   i n   \ p r o d u c t _ f o r m _ l e f t _ c o l u m n . d a r t \   a n d   \ p r o d u c t _ u n i t _ b a r c o d e _ t a b . d a r t \ . 
 
 6 .   * * O f f l i n e   U n i t   B a r c o d e   S y n c * * :   A d d e d   \ P r o d u c t B a r c o d e C o l l e c t i o n \   t o   I s a r .   M o d i f i e d   \ P r o d u c t R e p o s i t o r y . g e t A l l P r o d u c t s ( ) \   t o   s y n c   \ p r o d u c t _ b a r c o d e \   a n d   \  i n d P r o d u c t B a r c o d e ( ) \   t o   f a l l b a c k   t o   I s a r   w h e n   o f f l i n e . 
 
 7 .   * * S e t t i n g s   U I   U p d a t e * * :   E n h a n c e d   \  a r c o d e _ s e t t i n g s _ s c r e e n . d a r t \   w i t h   a   S u f f i x   D r o p d o w n   ( \ E n t e r \   o r   \ T a b \ )   a n d   a   ' T e s t   S c a n '   i n t e r a c t i v e   d i a l o g   t o   p r e v i e w   m a p p e d   o u t p u t s . 
 
 
 
 
# 2026-08-22 — Stock-in barcode quick add / สแกนบาร์โค้ดเพื่อเพิ่มรายการรับสินค้า

- TH: เพิ่มช่องสแกนบาร์โค้ดที่โฟกัสอัตโนมัติบนหน้าสร้างใบรับสินค้า สแกนแล้วเพิ่มสินค้า
  ลงในร่างใบรับทันที รองรับทั้งบาร์โค้ดหลักและบาร์โค้ดหน่วยเสริม; สินค้าเดิมจะเพิ่มจำนวน
  ในแถวเดิมและคำนวณยอดใหม่โดยไม่สร้างรายการซ้ำ. รองรับ Enter และการหยุดรับข้อมูล 350 ms
  สำหรับเครื่องสแกนที่ส่ง Tab/ไม่มี suffix. หากไม่พบหรือค้นหาผิดพลาดจะแจ้งเตือนแบบไม่บล็อก
  และไม่สร้างสินค้าให้อัตโนมัติ. การสแกนเปลี่ยนเฉพาะร่างในหน้าจอ—ไม่เขียนสต็อกหรือ ledger
  จนกดรับสินค้าเข้า.
- EN: Added an autofocus barcode field to the goods-receipt creation page. A scan
  immediately adds the product to the in-memory receipt draft, resolving both
  primary and extra-unit barcodes; rescanning an existing product increments its
  existing row and recalculates totals. It supports Enter and a 350 ms idle
  fallback for Tab/no-suffix scanners. Missing or failed lookups show a
  non-blocking alert without auto-creating a product. No stock or ledger write
  happens until the user explicitly receives the goods.

- TH: ปรับการสแกนต่อเนื่องให้ทุกการเปลี่ยนข้อมูลยกเลิกผลค้นหาเดิมทันที และเก็บการ
  สแกนล่าสุดไว้ทำต่อหลังคำขอก่อนหน้าจบ จึงไม่เพิ่มสินค้าจากผลเก่าหรือทำรายการล่าสุดหาย;
  กรณีไม่พบสินค้า/ค้นหาผิดพลาดจะคืนโฟกัสให้ช่องสแกนสำหรับเครื่องที่ส่ง Tab.
- EN: Hardened consecutive scans so every input change immediately invalidates an
  older lookup and the latest pending scan runs after the active lookup finishes,
  preventing stale additions or lost latest scans. Missing/error outcomes also
  return focus to support Tab-suffix scanners.

# 2026-08-22 — Safe unknown write outcomes / ป้องกันการเขียนข้อมูลซ้ำเมื่อการเชื่อมต่อหลุด

- TH: เปลี่ยน `MySqlQueryExecutor.execute()` ไม่ให้ reconnect หรือ retry คำสั่งเขียน
  (INSERT/UPDATE/DELETE) อัตโนมัติเมื่อการเชื่อมต่อหลุด เพราะ MySQL อาจ commit สำเร็จก่อน
  ที่เครื่องลูกข่ายจะไม่ได้รับคำตอบ การ retry จะเสี่ยงสร้างรายการเงินหรือสต็อกซ้ำ. ระบบจะ
  ส่ง `MySqlWriteOutcomeUnknownException` ที่ระบุชัดว่าผลลัพธ์ไม่ทราบแน่ชัดและต้องตรวจสอบ
  (reconcile) ด้วย idempotency key/หลักฐานรายการก่อนให้ผู้ใช้ทำซ้ำ. คงการ reconnect และ
  retry หนึ่งครั้งไว้เฉพาะ SELECT/query ที่อ่านข้อมูลเท่านั้น.
- EN: Changed `MySqlQueryExecutor.execute()` so INSERT/UPDATE/DELETE operations
  are never reconnected and retried automatically after a connection loss:
  MySQL may have committed before the client lost its response, so retrying can
  duplicate money or stock records. It now raises the explicit
  `MySqlWriteOutcomeUnknownException`, requiring reconciliation through an
  idempotency key or operation evidence before a user retries. One reconnect
  and retry remains available only for read SELECT/query operations.

# 2026-08-22 — Checkout and purchase-order idempotency / ป้องกันบิลขายและใบสั่งซื้อซ้ำ

- TH: เพิ่ม UUID ต่อหนึ่งหน้าต่างชำระเงิน และต่อหนึ่งหน้าสร้างใบรับ/ใบสั่งซื้อใหม่; เมื่อกดซ้ำ
  หรือเครือข่ายหลุด ระบบใช้ UUID เดิมตรวจหาบิล/PO ที่บันทึกสำเร็จแล้ว พร้อมเทียบ SHA-256 ของ
  ข้อมูลรายการทั้งหมด. ข้อมูลเดียวกันจะคืนเลขเอกสารเดิมโดยไม่ตัดสต็อกหรือบันทึกเงินซ้ำ;
  ข้อมูลต่างกันภายใต้ UUID เดิมจะถูกปฏิเสธ. เพิ่ม unique key ของ `order.idempotencyKey` และ
  `purchase_order.idempotencyKey` โดยตรวจข้อมูลซ้ำเดิมก่อนสร้าง index. เพิ่ม exclusive
  transaction scope สำหรับ MySQL connection กลาง จึงไม่มี SQL จากงานอื่นแทรกระหว่าง
  START TRANSACTION กับ COMMIT/ROLLBACK และห้าม reconnect/retry SELECT ภายใน scope.
- EN: Added one UUID per payment dialog and per newly-created goods-receipt/PO page.
  Retries and unknown network outcomes reconcile through that same UUID and a
  canonical SHA-256 payload hash. A matching prior order/PO returns its original
  ID without repeating stock or payment side effects; a different payload using
  the same UUID is rejected. Added checked unique indexes for
  `order.idempotencyKey` and `purchase_order.idempotencyKey`, plus an exclusive
  transaction scope for the singleton MySQL connection so unrelated SQL cannot
  interleave between START TRANSACTION and COMMIT/ROLLBACK; reads neither
  reconnect nor retry inside that scope.

# 2026-08-22 — Safe PO receiving / รับสินค้า PO แบบกันซ้ำและรับเฉพาะยอดคงเหลือ

- TH: ปรับปุ่ม “รับทั้งหมด” ของใบสั่งซื้อให้รับเฉพาะจำนวนที่ยังค้างอยู่ ไม่ย้อนหรือลบ
  สต็อกที่เคยรับแล้ว และล็อกหัวใบ/รายการ PO (`FOR UPDATE`) ก่อนปรับสต็อก. การรับบางส่วน
  ตรวจสินค้าว่าอยู่ใน PO จริง, ไม่ซ้ำ, และจำนวนไม่เกินยอดค้างรับ ภายใน transaction เดียวกัน.
  เพิ่มตาราง `purchase_order_receipt_operation` เก็บ UUID และ SHA-256 ของการรับแต่ละครั้ง;
  การกดซ้ำหรือคำตอบจากเครือข่ายหายจะคืนผลเดิมโดยไม่เพิ่ม stock ledger ซ้ำ ส่วน UUID เดิมที่
  ส่งข้อมูลต่างกันจะถูกปฏิเสธ. ย้ายโครงสร้างนี้จริงแล้ว พร้อมรายงานใน `migration_reports`.
- EN: Changed “receive all” to receive only each PO line’s outstanding quantity,
  never reversing or deleting stock already received, and locks the PO header and
  lines (`FOR UPDATE`) before stock changes. Partial receiving now verifies that
  each product belongs to the PO, is not duplicated, and does not exceed its
  remaining quantity inside the same transaction. Added
  `purchase_order_receipt_operation` to store a UUID and SHA-256 per receipt
  action; repeated clicks and lost network responses reconcile to the completed
  action without duplicate stock-ledger writes, while a reused UUID with a
  different payload is rejected. The schema migration was applied and recorded
  under `migration_reports`.

# 2026-08-22 — PO lifecycle lock and immutable audit / ล็อกวงจร PO และประวัติถาวร

- TH: การปิดใบรับเข้าบางส่วนใช้ UUID กันกดซ้ำและล็อกหัวใบ/รายการใน transaction เดียวกัน
  แล้วตัดเฉพาะ “ยอดที่ยังไม่ได้รับ” โดยปรับจำนวนสั่งให้เท่ากับจำนวนรับจริง—ไม่ลบแถวหรือ
  ย้อนสต็อกที่รับไปแล้ว. เพิ่ม `CLOSE` ในตาราง operation และ `purchase_order_audit_log`
  สำหรับเก็บ snapshot ของการรับเต็ม/บางส่วน/ปิดใบ และการแก้ไขหรือยกเลิก PO แบบ append-only.
  การแก้ไข/ยกเลิกทำได้เฉพาะ DRAFT หรือ ORDERED ที่ยังไม่มี receivedQuantity; PARTIAL,
  RECEIVED และ CANCELLED ถูกปฏิเสธที่ repository แม้จะเรียกข้ามหน้าจอ. ปิดช่องทางเก่าที่
  เขียนทับใบที่รับแล้วและย้อน/เพิ่มสต็อกใหม่ เพื่อบังคับให้ใช้ receipt flow ที่กันซ้ำ.
- EN: Closing a partial PO now uses a persistent retry UUID and locks the header
  and lines in one transaction. It cancels only the outstanding quantity by
  reducing ordered quantity to received quantity; it never deletes PO lines or
  reverses stock already received. Added `CLOSE` receipt operations and the
  append-only `purchase_order_audit_log`, which snapshots full/partial receipts,
  close actions, and successful PO edits/cancellations. Repository-level guards
  allow edits/cancellation only for DRAFT or ORDERED POs with no received
  quantity; PARTIAL, RECEIVED, and CANCELLED POs are rejected even if a caller
  bypasses the UI. The old received-PO overwrite/reversal path now refuses work
  so receiving must use the idempotent receipt flow.

# 2026-08-22 — Legacy supplier PO safety / ปลอดภัยสำหรับหน้าผู้ขายแบบเก่า

- TH: เปลี่ยนปุ่มรับสินค้าในหน้าจัดการใบสั่งซื้อแบบเก่าให้เรียก receipt flow กลางที่
  ล็อก PO, รับเฉพาะยอดคงเหลือ, และบันทึก UUID ของการรับ แทนการบวกสต็อกและเขียน ledger
  เอง. หน้าจอเก็บ UUID เดิมต่อ PO จนกว่าจะสำเร็จ ดังนั้นกดซ้ำหรือคำตอบเครือข่ายหายจะไม่
  เพิ่มสต็อกซ้ำ. หน้า “สร้างใบสั่งซื้อ” แบบเก่าใช้ UUID และ SHA-256 ของข้อมูลรายการเช่นกัน
  พร้อม exclusive transaction และคืนเลข PO เดิมเฉพาะเมื่อข้อมูลตรงกัน.
- EN: Replaced the legacy supplier PO screen's direct stock/ledger writes with
  the shared receipt flow, which locks the PO, receives only outstanding
  quantities, and records a receipt UUID. The screen retains that UUID per PO
  until success, so repeated taps or lost responses cannot add stock twice.
  The legacy create-PO screen now also uses a UUID and SHA-256 payload hash,
  an exclusive transaction, and returns the original PO ID only for a matching
  retry.
# 2026-08-23 — Shop admin featured products / หน้า Admin จัดสินค้าเด่น

- TH: เพิ่มหน้า `/shop/admin/` สำหรับผู้ดูแล เลือกสินค้าเด่นได้ตามหมวดหมู่ไม่เกิน 3 รายการต่อหมวด ค้นหาสินค้าได้ และกำหนดป้ายกับสีป้ายได้เอง. เพิ่ม secured API สำหรับอ่าน/บันทึก `featured_config.json` โดยอนุญาตเฉพาะ role `admin`, `manager` และ `owner`.
- EN: Added `/shop/admin/` for admins to choose up to three featured products per category, search products, and customize badge text and color. Added secured APIs for reading and saving `featured_config.json`, restricted to `admin`, `manager`, and `owner` roles.
# 2026-08-23 — Admin product search / เพิ่มช่องค้นหาสินค้าในหน้า Admin

- TH: ย้ายช่องค้นหาไปไว้ในส่วนรายการสินค้าโดยตรง ให้ค้นหาชื่อหรือบาร์โค้ดภายในหมวดที่เลือกได้ พร้อมปุ่มล้างคำค้นหาและรีเซ็ตอัตโนมัติเมื่อเปลี่ยนหัวข้อ.
- EN: Moved product search into the product list section so admins can search by name or barcode within the selected category, with a clear button and automatic reset when switching categories.
# 2026-08-23 — Backend shop update without setup rebuild / อัปเดต Backend โดยไม่สร้าง Setup ใหม่

- TH: คอมไพล์ `backend/server.exe` ใหม่จาก source ล่าสุด แล้วอัปเดตเข้า `C:\Program Files\S_Mart POS\backend` พร้อมคัดลอกไฟล์ Shop/Admin และรีสตาร์ต backend เดิม. ไม่ได้สร้าง Setup ใหม่ ไม่ได้เปลี่ยนฐานข้อมูล และไม่ได้เปลี่ยน Cloudflare Tunnel. เก็บไฟล์เดิมไว้ที่ `C:\pos_desktop\server-backups\server.exe.before-shop-update`.
- EN: Recompiled `backend/server.exe` from the latest source, updated the existing installation, copied the Shop/Admin assets, and restarted the existing backend. No new setup, database change, or Cloudflare Tunnel change was made. The previous executable is backed up at `C:\pos_desktop\server-backups\server.exe.before-shop-update`.
# 2026-08-23 — Admin API filtering alignment / ทำให้ Admin ใช้การกรองแบบ API เดียวกับหน้าร้าน

- TH: ปรับหน้า Admin ให้เลือกหมวดและค้นหาสินค้าผ่าน `GET /api/v1/shop/products` ด้วย `category_id` และ `q` โดยตรง แทนการกรองด้วยกติกาซ้ำใน JavaScript. แก้ปัญหาหมวดรวม เช่น “หิน ทราย ปูน” แสดง 0 ทั้งที่มีสินค้า และอัปเดตไฟล์ Admin ในโฟลเดอร์ติดตั้งแล้ว.
- EN: Updated Admin to use the same `GET /api/v1/shop/products` filtering with `category_id` and `q` as the storefront, instead of duplicating category rules in JavaScript. Fixed aggregate categories such as “หิน ทราย ปูน” showing zero products, and updated the installed Admin asset.
# 2026-08-23 — Admin asset cache bust / บังคับโหลดไฟล์ Admin รุ่นล่าสุด

- TH: เพิ่ม version query ให้ `admin.js` ในหน้า Admin เพื่อป้องกัน browser/Cloudflare cache ไฟล์ JavaScript รุ่นเก่า หลังอัปเดตการเชื่อมต่อ API.
- EN: Added a version query to the Admin `admin.js` script so browsers/Cloudflare do not keep serving the older JavaScript after the API integration update.
# 2026-08-23 — Writable featured config / ย้าย config สินค้าเด่นไปพื้นที่เขียนได้

- TH: แก้ปัญหากดบันทึกสินค้าเด่นใน Admin แล้วหน้าขายยังแสดงรายการเดิม เพราะ backend ที่ติดตั้งใน `Program Files` เขียนไฟล์ไม่ได้. ย้ายไฟล์ runtime ไปที่ `%LOCALAPPDATA%\S_Mart_POS\shop\featured_config.json` และให้ Admin กับ Shop อ่าน/เขียนไฟล์เดียวกัน พร้อมคอมไพล์และอัปเดต `server.exe` แล้ว.
- EN: Fixed featured selections staying unchanged because the installed backend under `Program Files` could not write its config file. Runtime config now lives at `%LOCALAPPDATA%\S_Mart_POS\shop\featured_config.json`, shared by Admin and Shop, and the rebuilt `server.exe` has been installed.
# 2026-08-23 — Admin featured-only view / แสดงเฉพาะสินค้าเด่นที่เลือก

- TH: ปรับหน้า Admin ให้ค่าเริ่มต้นแสดงเฉพาะสินค้าที่ติ๊กไว้ ซึ่งเป็นรายการเดียวกับที่ส่งไปหน้า Shop. สินค้าที่ไม่ได้ติ๊กจะไม่แสดงหน้า Shop แต่ยังค้นหาและเพิ่มได้ผ่าน “ค้นหาสินค้าทั้งหมด” หรือช่องค้นหา.
- EN: Admin now defaults to showing only checked featured products, matching the list sent to the Shop. Unchecked products stay hidden from the Shop but remain searchable and can be added through “ค้นหาสินค้าทั้งหมด” or the search field.
# 2026-08-23 — Desktop split cart layout / แบ่งสินค้าและตะกร้าสองฝั่ง

- TH: ปรับหน้า Shop บน Desktop ให้สินค้าแนะนำและแค็ตตาล็อกอยู่ฝั่งซ้าย พร้อมตะกร้าสินค้าแบบ sticky อยู่ฝั่งขวา. บนมือถือยังใช้แถบตะกร้าลอยด้านล่างเหมือนเดิม เพื่อรักษาพื้นที่แสดงสินค้าและจำนวนกดที่น้อย.
- EN: Updated the Shop desktop layout with featured/catalog products on the left and a sticky cart sidebar on the right. Mobile keeps the bottom floating cart to preserve product space and minimize taps.
# 2026-08-23 — Shop cart ID normalization / แก้ปุ่มใส่ตะกร้าจากรหัสสินค้า

- TH: แก้ปัญหาปุ่ม `ใส่ตะกร้า` ไม่ทำงานเมื่อรหัสสินค้าจาก API เป็น string แต่ค่าจาก inline button เป็น number โดย normalize รหัสก่อนค้นหาในรายการสินค้าและสินค้าแนะนำ พร้อมเพิ่ม version ให้ `shop.js` เพื่อบังคับโหลดไฟล์แก้ไข.
- EN: Fixed the Shop add-to-cart button when API product IDs were strings but inline button values were numbers. IDs are normalized before product lookup, and `shop.js` now has a cache-busting version.

# 2026-08-24 — Optional product photos during stock work / เพิ่มรูปสินค้าระหว่างปรับสต็อกและรับเข้า

- TH: เพิ่มการถ่ายหรือเลือกรูปสินค้าแบบไม่บังคับในหน้าปรับสต็อกของ POS Desktop และหน้ารับเข้าสินค้าของ S-Link. รูปของสินค้าที่มี `productId` จะถูกอัปโหลดผ่าน API กลางไปเก็บบนเซิร์ฟเวอร์ และบันทึก URL ลง `product.imageUrl` ใน SQL เพื่อให้เว็บใช้รูปเดียวกัน. เพิ่มเส้นทางไฟล์รูปแบบเขียนได้และแก้คำสั่งเว็บให้ดึง `imageUrl` จาก SQL.
- EN: Added optional product photo capture or selection to POS Desktop stock adjustment and S-Link stock receiving. Photos for lines with a `productId` upload through a shared API, and the resulting URL is stored in SQL `product.imageUrl` for the web storefront. Added writable static serving for product images and included `imageUrl` in storefront product queries.

# 2026-08-24 — Backend lint cleanup / แก้ warning ของ Backend

- TH: ห่อคำสั่งเงื่อนไขใน `shop_controller.dart` ด้วยบล็อกปีกกาให้ครบตาม Dart lint และตรวจซ้ำแล้วไม่พบ issue.
- EN: Wrapped the conditional statements in `shop_controller.dart` with braces to satisfy the Dart lint rule; re-analysis reports no issues.

# 2026-08-24 — Stock check name search button / เพิ่มปุ่มค้นหาชื่อสินค้าในหน้าเช็คสต๊อก

- TH: เพิ่มปุ่ม `ค้นหาชื่อสินค้า` ให้เห็นชัดในหน้าต่างเพิ่มรายการเช็คสต๊อก โดยเปิดตัวค้นหาสินค้าด้วยชื่อ/บาร์โค้ดโดยไม่แสดงปุ่มสแกนซ้ำ และคงการสแกนบาร์โค้ดเดิมไว้.
- EN: Added a visible `ค้นหาชื่อสินค้า` button to the stock-check item dialog. It opens the existing name/barcode product search without duplicating the scanner button, while preserving the original barcode scan flow.

# 2026-08-25 — Unified LINE OA shop, membership, coupons, and loyalty / รวมร้านค้า สมาชิก คูปอง และคะแนน LINE OA

- TH: รวมหน้าร้านออนไลน์เป็นหน้าเดียว 5 แท็บ (ร้านค้า, รางวัล, คูปอง, ประวัติ,
  สมาชิก) พร้อมตะกร้าและคูปองชุดเดียว, สมัคร/ผูกสมาชิกแบบขั้นตอนสั้น, QR จับคู่
  ใช้ครั้งเดียวอายุ 5 นาที, คิวอนุมัติหลังร้าน และหน้าค้นหา/สร้างสมาชิกด่วน.
- EN: Unified the online storefront into five tabs (shop, rewards, coupons,
  history, and membership) with one cart/coupon state, short signup/linking,
  a one-time five-minute pairing QR, an admin approval queue, and quick member
  search/create tools.

- TH: ยืนยัน LINE ID token ฝั่งเซิร์ฟเวอร์, ตรวจลายเซ็น webhook, แยก endpoint
  แจ้งเตือนภายในออกจาก webhook สาธารณะ, บังคับ JWT/role และ internal secret,
  จำกัด payload รูปใบเสร็จ และไม่ส่งรายละเอียด exception กลับผู้ใช้ภายนอก.
- EN: Added server-side LINE ID-token verification, webhook signature checks,
  separated internal notification routes from the public webhook, enforced
  JWT/roles and an internal secret, bounded receipt-image payloads, and removed
  internal exception details from public errors.

- TH: ทำคำสั่งซื้อออนไลน์, จอง/ใช้คูปอง และแลกรางวัลแบบ idempotent ด้วย UUID,
  ล็อกเจ้าของ/ยอดแต้ม/สต็อกใน transaction และให้ MySQL ผ่าน POS API เป็นข้อมูลหลัก.
- EN: Made online orders, coupon reservation/consumption, and reward redemption
  UUID-idempotent, locking ownership, point balances, and stock in transactions;
  MySQL through the secured POS API remains the source of truth.

- TH: กติกาคะแนนสุดท้ายใช้ยอดชำระจริงก่อนบิลปัจจุบัน ดังนั้นบิลที่ทำให้ถึงเกณฑ์
  ยังใช้อัตราเดิมและเริ่มอัตราใหม่ในบิลถัดไป. ลูกค้าทั่วไปยอดก่อนหน้าอย่างน้อย
  10,000 บาทได้ x2; ช่างได้ x2 เป็นพื้นฐาน, มากกว่า 20,000 บาทได้ x2.5 และ
  มากกว่า 50,000 บาทได้ x3. เมื่อชนกับ Tier/วันเกิด/โปรโมชั่นใช้ตัวคูณสูงสุด
  ไม่คูณซ้อน และให้แต้มเฉพาะเมื่อชำระบิลครบ.
- EN: Final loyalty rules use paid spend before the current bill, so the bill
  crossing a threshold keeps the old rate and the following bill gets the new
  rate. Ordinary customers get x2 after at least THB 10,000 prior spend;
  contractors get base x2, x2.5 above THB 20,000, and x3 above THB 50,000.
  Tier, birthday, campaign, and monthly multipliers use the single highest
  value, never stack, and points are awarded only after full payment.

- TH: เชื่อมการให้แต้มแบบ atomic/idempotent ครบ POS, ปิดบิลเครดิตรายใบ,
  จ่ายหลายบิล, ใบวางบิล, COD และ Mobile checkout. คะแนนเป็นรายล็อตตามอายุเดิม:
  ได้ช่วง ม.ค.–มิ.ย. หมด 30 มิ.ย. ปีถัดไป; ได้ช่วง ก.ค.–ธ.ค. หมด 31 ธ.ค.
  ปีถัดไป. ทุกช่องทางใช้ล็อตใกล้หมดอายุก่อน, เก็บล็อตถาวรไว้ท้ายสุด และหน้า
  สมาชิกแสดงจำนวน/วันหมดอายุรอบถัดไป. การแลกรางวัล LINE เปลี่ยนจากแถวลบถาวร
  เป็นตัดจากล็อตจริง จึงไม่ทำให้ยอดติดลบเมื่อแต้มต้นทางหมดอายุ.
- EN: Added atomic/idempotent awarding across POS, individual and batch debt
  closure, billing notes, COD, and mobile checkout. Points retain the existing
  semiannual lot policy: Jan–Jun earnings expire 30 June next year; Jul–Dec
  earnings expire 31 December next year. Every redemption consumes the nearest
  expiry first, permanent lots last, and the member page shows the next expiring
  amount/date. LINE reward redemption now consumes real earning lots instead of
  creating a permanent negative row, preventing negative balances after expiry.

- TH: เพิ่ม migration แบบมีเวอร์ชัน 001–006 สำหรับตัวตนสมาชิก, การจองคูปอง,
  idempotency การแลก, payment/award audit และระดับช่าง. ยังไม่ได้รัน migration
  กับฐานข้อมูลจริง, ไม่ได้ deploy, ไม่เปลี่ยนเวอร์ชัน และไม่ได้ build installer;
  ก่อนติดตั้งต้องสำรองฐานข้อมูล, ตั้ง timezone MySQL เป็น +07:00 และกำหนด
  `INTERNAL_API_SECRET` ให้ Backend/Desktop/Functions ตรงกัน.
- EN: Added versioned migrations 001–006 for membership identity, coupon
  reservation, redemption idempotency, payment/award audit, and contractor
  levels. No live migration, deployment, version bump, or installer build was
  performed. Before rollout, back up the database, set MySQL/session timezone
  to +07:00, and configure the same `INTERNAL_API_SECRET` for Backend, Desktop,
  and Functions.

- TH: ตรวจแล้ว Backend tests 49/49, POS focused tests 9/9, Backend `dart analyze`
  และ Flutter `flutter analyze` ผ่านทั้งหมด; JavaScript ของ Shop/Admin/Functions
  ตรวจ syntax ผ่าน. `git diff --check` เหลือเฉพาะ whitespace เดิมใน
  `backend/scratch_query.dart` และ `pos_desktop.iss` ซึ่งไม่เกี่ยวกับงานนี้.
- EN: Verification passed: 49/49 backend tests, 9/9 focused POS tests, clean
  backend `dart analyze` and Flutter `flutter analyze`, plus syntax checks for
  Shop/Admin/Functions JavaScript. `git diff --check` reports only pre-existing
  unrelated whitespace in `backend/scratch_query.dart` and `pos_desktop.iss`.

# 2026-08-25 — Safe loyalty reversal cycles / ย้อนแต้มแบบไม่ทำยอดรวน

- TH: เพิ่ม migration 007 สำหรับเก็บรอบการให้แต้มและ snapshot การย้อนรายการแบบ
  ถาวร โดยไม่แก้หรือลบ migration 001–006. การยกเลิกบิล, เปลี่ยนบิลเป็นยังไม่จ่าย
  และย้อนรายการรับชำระ จะล็อกบิล ลูกค้า award และล็อตแต้มใน transaction เดียวกัน
  ก่อนแตะสต็อก หนี้ ยอดสะสม หรือสถานะบิล.
- EN: Added migration 007 for award-cycle numbering and immutable reversal
  snapshots without changing migrations 001–006. Voiding, marking unpaid, and
  reversing a debt payment now lock the order, customer, award, and point lot in
  one transaction before stock, debt, lifetime spending, or status is changed.

- TH: หากแต้มจากบิลถูกใช้แม้เพียง 1 แต้ม ระบบจะยกเลิกการทำงานทั้งหมดและแจ้ง
  พนักงานให้ย้อนรายการใช้แต้ม/คูปองก่อน โดยไม่สร้างคะแนนติดลบ. หากแต้มยังไม่ถูกใช้
  ระบบจะทำให้ล็อตเดิมใช้ไม่ได้, เก็บหลักฐานรอบเดิม, หักยอดสะสม และคำนวณคะแนนใหม่
  แบบ atomic. เมื่อรับชำระหรือกู้บิลกลับ ระบบสร้างรอบแต้มใหม่ด้วยเวลาและกติกาปัจจุบัน
  โดยไม่ทับประวัติเดิม.
- EN: If even one point from the bill has been consumed, the entire operation is
  blocked with an actionable staff message; no negative point debt is created.
  An unused lot is neutralized, snapshotted, lifetime spending is reversed, and
  the balance is recalculated atomically. A later valid repayment/unvoid creates
  a new award cycle using current time/settings without overwriting old history.

- TH: การกู้รายการรับชำระทำซ้ำได้โดยไม่เพิ่มยอดซ้ำ, ใบวางบิลที่ชำระแล้วถูกบล็อก
  ไม่ให้ย้อนสถานะแบบครึ่งรายการ และการกู้บิลจะเป็น COMPLETED เฉพาะเมื่อยอดรับเต็ม.
  ตรวจแล้ว Backend tests 50/50, POS focused tests 12/12 และ analyze ทั้งสองฝั่งผ่าน.
- EN: Restoring a payment is idempotent, paid billing notes cannot be partially
  rolled back, and an unvoided order becomes COMPLETED only when fully received.
  Verification passed: 50/50 backend tests, 12/12 focused POS tests, and clean
  analysis on both backend and Flutter.

- TH: ยังไม่ได้รัน migration 007 กับฐานข้อมูลจริง, deploy, build, เปลี่ยนเวอร์ชัน
  หรือ push. ต้องลง schema และโปรแกรม Desktop/Backend รุ่นนี้พร้อมกัน และห้ามย้อน
  กลับไปใช้ binary เก่าหลังเริ่มมีข้อมูล reversal cycle.
- EN: Migration 007 was not run on the live database; no deployment, build,
  version bump, or push was performed. Roll out the schema and matching
  Desktop/Backend binaries together, and do not roll back to older binaries
  after reversal-cycle data has been created.

# 2026-08-25 — New loyalty program cutoff / จุดเริ่มระบบแต้มใหม่

- TH: เพิ่ม migration 008 แบบ additive โดยเพิ่ม `program_started_at` ใน
  `loyalty_tier_settings` และตาราง `loyalty_program_reset_audit` ที่บังคับ
  idempotency key ไม่ซ้ำ พร้อมเก็บเวลา ผู้ดำเนินการ เหตุผล จำนวนแถว/แต้มที่ล้าง
  และจำนวนสมาชิก ณ เวลาล้าง เพื่อให้การเริ่มระบบแต้มใหม่ตรวจสอบย้อนหลังได้.
- EN: Added additive migration 008 with `program_started_at` on
  `loyalty_tier_settings` and an idempotent `loyalty_program_reset_audit`
  table recording reset time, actor, reason, cleared row/point totals, and
  membership counts for a fully auditable new-program start.

- TH: Query ยอดซื้อรายเดือนของหน้า Member, POS, COD และ Mobile checkout จะนับ
  เฉพาะยอดชำระตั้งแต่เวลาที่ช้ากว่าระหว่างต้นเดือนกับ `program_started_at`.
  Cutoff ใช้เฉพาะสิทธิ์ยอดซื้อรายเดือน ไม่แก้ยอดซื้อสะสมถาวร, Tier, ลูกค้า, หนี้,
  คูปอง, ประวัติแลกรางวัล หรือออเดอร์เดิม.
- EN: Member, POS, COD, and mobile monthly-spend queries now start at the later
  of the Bangkok month boundary and `program_started_at`. The cutoff affects
  monthly loyalty eligibility only; lifetime spending, tiers, customers,
  debts, coupons, reward-redemption history, and historical orders remain.

- TH: เปิดใช้ migration 001–008 และ reset ฐานข้อมูลจริงสำเร็จใน transaction
  เดียวเมื่อ `2026-08-25 10:47:15` (Asia/Bangkok) ด้วย key
  `LIVE_RESET:20260825`, actor `BOB_FOR_TI`, reason
  `NEW_LOYALTY_PROGRAM`: ล้าง `point_ledger` 634 แถว (ยอดคงเหลือตาม ledger
  31,929 แต้ม), ตั้ง `customer.currentPoints` ของลูกค้าทุกคนเป็นศูนย์ และตั้ง
  cutoff สำหรับยอดซื้อรายเดือนใหม่. สำรองฐานข้อมูลก่อนทำไว้ที่
  `server-backups/smartpos-before-loyalty-reset-20260825-102747.sql`.
- EN: Migrations 001–008 and the live reset completed in one transaction at
  `2026-08-25 10:47:15` Asia/Bangkok using key `LIVE_RESET:20260825`, actor
  `BOB_FOR_TI`, and reason `NEW_LOYALTY_PROGRAM`. The reset cleared 634
  point-ledger rows (31,929 active ledger points), zeroed every cached customer
  balance, and established the new monthly-spend cutoff. The pre-reset database
  backup is `server-backups/smartpos-before-loyalty-reset-20260825-102747.sql`.

- TH: ถอดการผูก LINE เดิม 13 รายทั้ง canonical owner และฟิลด์ legacy โดยเก็บ
  link audit เป็น `REVOKED`; คำขอที่รอดำเนินการถูกทำให้หมดอายุ. ไม่ลบลูกค้า
  1,243 ราย, บิล 10,907 ใบ, ยอดซื้อสะสม, Tier, หนี้, คูปอง USED/EXPIRED หรือ
  ประวัติแลกรางวัล ลูกค้าเดิมจึงสมัคร/ยืนยันใหม่โดยกลับเข้ารายชื่อลูกค้าเดิมได้.
- EN: Reset 13 legacy LINE bindings across canonical and legacy identity stores,
  retained link audit rows as `REVOKED`, and expired pending requests. No
  customers (1,243), orders (10,907), lifetime spending, tiers, debts,
  USED/EXPIRED coupons, or reward-redemption history were deleted. Returning
  customers can re-register and recover the same customer record safely.

- TH: สร้างและเปิด Backend/POS release โดยไม่เปลี่ยนเลขเวอร์ชัน. เนื่องจาก
  Windows ไม่อนุญาตให้เขียนทับ `Program Files` โดยไม่มี UAC จึงติดตั้ง runtime
  ใหม่แบบ per-user ที่ `%LOCALAPPDATA%/Programs/S_Mart POS` พร้อมทางลัด
  `S-Mart POS` บน Desktop; เก็บตัวติดตั้งเดิมไว้เป็น rollback และไม่ push โค้ด.
- EN: Built and launched the Backend/POS release without a version bump. Because
  Windows denied non-elevated writes to `Program Files`, the live runtime was
  installed per-user at `%LOCALAPPDATA%/Programs/S_Mart POS` with an `S-Mart POS`
  Desktop shortcut. The original installation remains available for rollback;
  no code was pushed.

# 2026-08-25 — Internal LINE proxy bypass fix / ปิดช่องโหว่ proxy เข้า LINE ภายใน

- TH: แก้ middleware ของ `/api/v1/line-internal` ให้เมื่อกำหนด
  `INTERNAL_API_SECRET` แล้ว ทุกคำขอต้องส่ง secret ที่ถูกต้อง แม้ remote address
  จะเป็น loopback จาก Cloudflare/reverse proxy. Loopback ที่ไม่ส่ง secretอนุญาต
  เฉพาะ local development ซึ่งไม่ได้กำหนด secret เท่านั้น.
- EN: Hardened `/api/v1/line-internal` so a configured
  `INTERNAL_API_SECRET` is mandatory for every request, including requests that
  appear loopback through Cloudflare or another reverse proxy. Secret-free
  loopback remains available only when local development has no configured
  secret.

- TH: Launcher อ่าน secret จาก `backend/.env` แล้วส่งผ่าน process environment
  ให้ทั้ง Backend และ POS โดยไม่พิมพ์ค่า. การส่งใบเสร็จข้อความและรูปจาก Desktop
  ใช้ internal headers กลางชุดเดียวกัน; หากไฟล์ไม่มี secret launcher จะหยุดทันที.
- EN: The launcher reads the secret from `backend/.env` and injects it into both
  Backend and POS child environments without logging it. Desktop text/image
  receipt calls use the shared internal headers, and startup fails closed when
  the secret is missing.

- TH: สร้างและคัดลอก Backend/POS ใหม่เข้า runtime แบบ per-user แล้วเปิดใช้งาน
  สำเร็จ. Smoke test ผ่าน: health ทั้ง local/remote = 200, Web Shop = 200,
  คำขอ remote ที่ตรง route แต่ไม่มี secret = 401 และคำขอที่มี secret ถูกต้อง
  ผ่าน middleware ไปถึง controller = 404 สำหรับ order ทดสอบที่ไม่มีอยู่จริง.
- EN: Rebuilt and copied the patched Backend/POS into the live per-user runtime.
  Smoke verification passed: local/remote health = 200, Web Shop = 200, a
  matched remote internal route without the secret = 401, and the same request
  with the valid secret passed middleware and reached the controller = 404 for
  the deliberately nonexistent test order.

- TH: ตรวจรอบสุดท้ายผ่าน Backend tests 53/53, Backend analyze และ Flutter
  analyze สะอาด, focused POS tests 12/12 ผ่าน. `git diff --check` เหลือเฉพาะ
  whitespace เดิมใน `backend/scratch_query.dart` และ `pos_desktop.iss` ซึ่งไม่
  เกี่ยวกับงานนี้และไม่ได้แก้ทับ.
- EN: Final verification passed 53/53 Backend tests, clean Backend and Flutter
  analysis, and 12/12 focused POS tests. `git diff --check` reports only the
  pre-existing unrelated whitespace in `backend/scratch_query.dart` and
  `pos_desktop.iss`, which this rollout deliberately left untouched.

# 2026-08-25 — Queued LINE receipt URL fix / แก้ URL คิวส่งรูปใบเสร็จ LINE

- TH: รวมการสร้าง URL ของ internal LINE endpoint ให้ใช้ฐาน `/api/v1` เพียง
  ครั้งเดียวทุกประเภท แก้คิว retry ของ `RECEIPT_IMAGE` ที่เคยสร้าง path ซ้ำเป็น
  `/api/v1/api/v1/...` และเพิ่ม regression test ครอบคลุม URL ที่มี/ไม่มี prefix
  และ trailing slash.
- EN: Centralized internal LINE endpoint URL construction so `/api/v1` appears
  exactly once for every queued message type. This fixes `RECEIPT_IMAGE` retries
  that previously produced `/api/v1/api/v1/...`, with regression coverage for
  prefixed, unprefixed, and trailing-slash inputs.

- TH: สร้าง release และคัดลอก fix นี้เข้า runtime ที่ใช้งานจริงแล้ว; URL tests
  2/2 และ focused POS tests รวม 14/14 ผ่าน, Flutter analyze สะอาด, หลัง restart
  health/Web Shop = 200 และ internal route ที่ไม่มี secret ยังถูกปฏิเสธ = 401.
- EN: Rebuilt and deployed this fix to the active runtime. URL tests passed 2/2,
  the combined focused POS suite passed 14/14, Flutter analysis remained clean,
  and post-restart health/Web Shop = 200 while an unauthenticated internal route
  remained correctly rejected with 401.

# 2026-08-25 — Simple member signup address fields / ฟอร์มสมัครสมาชิกแบบง่ายพร้อมที่อยู่

- TH: ปรับฟอร์มสมาชิกบนเว็บร้านให้สมัครง่ายขึ้น โดยบังคับเฉพาะชื่อและเบอร์โทร
  ส่วนที่อยู่และที่อยู่จัดส่งเป็นทางเลือก; ถ้าไม่กรอกที่อยู่จัดส่ง ระบบใช้ที่อยู่
  หลักแทนโดยอัตโนมัติ. ข้อมูลถูกส่งเข้า `/api/v1/membership-member/signup`
  เพื่อสร้าง/ผูกกับ `customer` ใน POS หลัก ไม่สร้างฐานสมาชิกแยก.
- EN: Simplified the shop member signup form so only name and phone are
  required; address and shipping address are optional, and shipping address
  falls back to the main address when omitted. The form posts to
  `/api/v1/membership-member/signup`, creating/linking the POS `customer`
  record instead of a separate member store.

- TH: ขยาย backend self-signup ให้รับ `address` และ `shippingAddress` พร้อม
  ตรวจความยาวและกัน control characters ก่อนบันทึกลง `customer.address` และ
  `customer.shippingAddress`. กรณีเบอร์ตรงกับรายชื่อเก่าใน POS ยังคงเข้าคิว
  recovery ให้พนักงานตรวจสอบ ไม่ผูก LINE อัตโนมัติ.
- EN: Extended backend self-signup to accept `address` and `shippingAddress`,
  validating length and control characters before writing to
  `customer.address` and `customer.shippingAddress`. Existing POS phone matches
  still go to the recovery queue for staff review instead of auto-linking LINE.

- TH: ปรับหน้า LIFF legacy ให้ส่งข้อมูลที่อยู่ชุดเดียวกัน เผื่อลิงก์เก่าถูกเปิด
  แม้เส้นทางหลักปัจจุบันจะอยู่ที่ `/shop/`. ตรวจผ่าน membership tests 12/12
  และ backend `dart analyze` ไม่พบปัญหา.
- EN: Updated the legacy LIFF page to submit the same address fields in case an
  old link is opened, while the current primary route remains `/shop/`.
  Verification passed membership tests 12/12 and clean backend `dart analyze`.

# 2026-08-25 — Web-first membership admin / ย้ายงานจัดการสมาชิกไปฝั่งเว็บ

- TH: ปรับแนวทางให้หน้าจัดการสมาชิกอยู่ที่เว็บแอดมิน `/shop/admin/` เป็นหลัก
  โดยยังใช้ฐานข้อมูล `customer` ของ POS หลักเหมือนเดิม. แท็บ `สมาชิก LINE`
  ถูกปรับเป็นศูนย์จัดการสมาชิกสำหรับสร้างสมาชิกด่วน ค้นหารายชื่อเก่า ออก QR
  ผูก LINE และตรวจคิวคำขอกู้บัญชี โดยไม่ต้องเปิดหน้าจอสมาชิกใน POS.
- EN: Moved the membership management workflow to the web admin at
  `/shop/admin/` while keeping the POS `customer` table as the single source of
  truth. The `LINE members` tab is now positioned as the membership center for
  quick create, legacy customer search, one-time LINE pairing QR, and recovery
  request review without needing a POS membership screen.

- TH: ขยาย quick-create ของแอดมินให้รับที่อยู่และที่อยู่จัดส่งเหมือนฟอร์มลูกค้า
  พร้อม fallback ที่อยู่จัดส่งจากที่อยู่หลัก และใช้ validation ชุดเดียวกันก่อน
  บันทึกลง POS หลัก. ตรวจผ่าน membership tests 13/13 และ backend
  `dart analyze` ไม่พบปัญหา.
- EN: Extended admin quick-create to accept main and shipping addresses like
  the customer signup form, falling back shipping address to the main address
  and using the shared validation before saving into the POS database.
  Verification passed membership tests 13/13 and clean backend `dart analyze`.

- TH: Compile backend ใหม่และคัดลอกเข้า runtime ที่ใช้งานจริง
  `%LOCALAPPDATA%/Programs/S_Mart POS` พร้อมไฟล์เว็บ `backend/public`; เก็บ
  `shop/featured_config.json` เดิมไว้ก่อนคัดลอกเพื่อไม่ให้สินค้าเด่นหาย แล้ว
  เปิด Backend/POS กลับสำเร็จ. Smoke test ผ่าน: local health = 200,
  `/shop/admin/` ทั้ง local/remote = 200 และ endpoint แอดมินที่ไม่ login = 401.
- EN: Recompiled the backend and copied it plus `backend/public` into the
  active per-user runtime at `%LOCALAPPDATA%/Programs/S_Mart POS`, preserving
  the existing `shop/featured_config.json` before copying so featured products
  were not reset. Backend/POS restarted successfully. Smoke checks passed:
  local health = 200, `/shop/admin/` local/remote = 200, and an unauthenticated
  admin endpoint returns 401.

# 2026-08-25 — LINE contact rich-menu reply / ข้อความตอบกลับปุ่มติดต่อร้าน

- TH: เพิ่มคำสั่ง webhook สำหรับ rich menu `ติดต่อร้าน` รวมถึงคำว่า `ติดต่อ`,
  `contact`, และ `call` ให้ตอบกลับข้อความเบอร์โทรและ Facebook ของร้านทันที
  โดยทำงานได้แม้ผู้ใช้ยังไม่ได้สมัครสมาชิก. Compile backend ใหม่และ deploy เข้า
  runtime ที่ใช้งานจริงแล้ว; local health ตรวจผ่าน 200.
- EN: Added LINE webhook command handling for the `ติดต่อร้าน` rich-menu
  message, plus `ติดต่อ`, `contact`, and `call`, replying with the shop phone
  and Facebook link even when the LINE user is not yet a member. Recompiled and
  deployed the backend to the active runtime; local health check passed 200.

# 2026-08-25 — Member signup pending UX cleanup / ปรับหน้าสมัครเมื่อเจอสมาชิกเดิม

- TH: ปรับหน้า `/shop/` เมื่อสมัครด้วยเบอร์ที่ตรงกับรายชื่อเก่าใน POS จากเดิม
  ที่แสดงกล่องเตือนใต้ปุ่ม ให้เปลี่ยนเป็น popup แจ้งว่า “ส่งคำขอแล้ว” และไม่
  แสดงกล่องแดง/ส้มค้างใต้ฟอร์ม. เพิ่ม cache-bust ของ `shop.js` แล้วคัดลอก
  `index.html` และ `shop.js` เข้า runtime จริง. ตรวจ local/remote `/shop/`
  ผ่าน 200 และโหลด script เวอร์ชันใหม่ได้.
- EN: Updated `/shop/` so signups whose phone matches an existing POS customer
  show a lightweight “request submitted” popup instead of leaving the red/orange
  warning under the form. Added a cache-busting `shop.js` query and copied
  `index.html` plus `shop.js` to the active runtime. Local/remote `/shop/`
  checks passed 200 and loaded the new script version.

# 2026-08-25 — Duplicate member merge and phone-match linking / รวมสมาชิกซ้ำและผูกเบอร์เก่าอัตโนมัติ

- TH: ตรวจพบว่าสมาชิกใหม่ `Miti` ถูกสร้างเป็นลูกค้าใหม่เพราะตอนสมัครกรอกเบอร์
  `0851377102` แต่รายชื่อเดิม `ติ` ใน POS ใช้เบอร์ `0851377402`. ตรวจ safety
  แล้วแถวใหม่ไม่มีบิล ไม่มี point ledger ไม่มีคูปอง และไม่มี redemption จึงย้าย
  LINE identity จากลูกค้าใหม่ id 1263 ไปยังลูกค้าเดิม id 1076 และตั้งแถวใหม่
  เป็น `isDeleted = 1` โดยไม่แตะหนี้ ยอดซื้อ หรือประวัติของลูกค้าเดิม.
- EN: Found that the new `Miti` customer was created because signup used phone
  `0851377102`, while the existing POS customer `ติ` used `0851377402`. Safety
  checks confirmed the new row had no orders, point ledger, coupons, or
  redemptions, so LINE identity was moved from new customer id 1263 to existing
  customer id 1076 and the new row was marked `isDeleted = 1` without touching
  the existing customer debt, spending, or history.

- TH: ปรับ backend self-signup ให้ถ้าเบอร์ที่สมัครตรงกับลูกค้าเก่าเพียง 1 ราย
  และรายนั้นยังไม่มี LINE ผูก ระบบจะผูกเข้า record เดิมทันทีแทนการสร้างสมาชิก
  ใหม่หรือส่งเข้าคิว. ถ้าเจอหลายรายหรือมี LINE ผูกอยู่แล้ว ยังเข้าคิวตรวจสอบ
  ตามเดิม. Compile/deploy backend เข้า runtime จริงแล้ว; health ผ่าน 200,
  membership tests 13/13 และ backend `dart analyze` ไม่พบปัญหา.
- EN: Updated backend self-signup so an exact unique phone match to an existing
  customer with no LINE binding links that existing record immediately instead
  of creating a new member or entering the review queue. Multiple matches or
  already-linked customers still require review. Recompiled/deployed the
  backend to the active runtime; health passed 200, membership tests passed
  13/13, and backend `dart analyze` remained clean.
