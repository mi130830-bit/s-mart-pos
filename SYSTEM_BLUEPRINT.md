# SYSTEM_BLUEPRINT.md: พิมพ์เขียวระบบแม่บท (Master System Blueprint)
**ร้าน ส.บริการ ท่าข้าม (S.Borikarn Tha Kham) · Construction & Retail POS Logistics Platform**

> **เอกสารนี้รวบรวมแผนงาน แผนผังสถาปัตยกรรม และคู่มือการพัฒนาระบบทั้งหมดของร้าน**  
> *This document consolidates all system architecture blueprints, implementation plans, and development roadmaps.*  
> **หลักการออกแบบ (Core Philosophy):** เรียบง่าย มีประสิทธิภาพ ทำงานได้จริง และออกแบบสำหรับคนขี้เกียจ (Lazy-Friendly & High-Efficiency Design)

---

## 📑 สารบัญ (Table of Contents)
1. [ภาพรวมสถาปัตยกรรมระบบ (System Architecture Overview)](#1-ภาพรวมสถาปัตยกรรมระบบ-system-architecture-overview)
2. [โมดูล 1: แผนติดตั้งเซิร์ฟเวอร์ Beelink (Server Setup & Migration Blueprint)](#2-โมดูล-1-แผนติดตั้งเซิร์ฟเวอร์-beelink-server-setup--migration-blueprint)
3. [โมดูล 2: ระบบแต้มสะสมช่างและลูกค้า 2 ระดับ (Smart Loyalty Points Engine)](#3-โมดูล-2-ระบบแต้มสะสมช่างและลูกค้า-2-ระดับ-smart-loyalty-points-engine)
4. [โมดูล 3: ระบบสั่งของผ่าน LINE OA 24 ชม. (LINE OA 24hr E-Commerce Blueprint)](#4-โมดูล-3-ระบบสั่งของผ่าน-line-oa-24-ชม-line-oa-24hr-e-commerce-blueprint)
5. [โมดูล 4: ระบบสีผสมเครื่องเบเยอร์ (Beger Tinting Machine Catalog)](#5-โมดูล-4-ระบบสีผสมเครื่องเบเยอร์-beger-tinting-machine-catalog)
6. [โมดูล 5: ระบบฮาร์ดแวร์และ IoT ประจำร้าน (Hardware & IoT Peripherals)](#6-โมดูล-5-ระบบฮาร์ดแวร์และ-iot-ประจำร้าน-hardware--iot-peripherals)

---

## 1. ภาพรวมสถาปัตยกรรมระบบ (System Architecture Overview)

```
                       ┌──────────────────────────────────────────────┐
                       │           LINE OA & ลูกค้า (Customers)        │
                       │    - สั่งซื้อสินค้า 24 ชม. ผ่าน LIFF Web App  │
                       │    - รับใบเสร็จ / รูปส่งของ / ลิงก์ติดตาม GPS │
                       └──────────────────────┬───────────────────────┘
                                              │ HTTPS (api.namecheap.work)
                                              ▼
┌───────────────────────┐              ┌──────────────────────────────┐
│  คนขับรถ (S-Link App) │ ─── HTTPS ─► │   Cloudflare Single Tunnel   │
│  - เช็คงาน / นำทาง    │ (JWT Auth)   └──────────────┬───────────────┘
│  - ถ่ายรูปปิดงาน (POD)│                             │ Port 8080
│  - ทำงานออฟไลน์ได้    │                             ▼
└───────────────────────┘              ┌──────────────────────────────┐
                                       │   Beelink Mini S12 Pro Server│
┌───────────────────────┐              │   (Ubuntu Server 26.04 LTS)  │
│  POS Desktop (Windows)│ ── Local LAN ┼──────────────────────────────┤
│  - หน้าจอขายหน้าร้าน  │ (mDNS / HTTP)│   - Shelf Dart API Backend   │
│  - ยิงบิล / พิมพ์ใบเสร็จ│              │   - MySQL 8.0 Master DB      │
│  - จัดการสต็อก / HR   │              │   - Cockpit Web Admin        │
└───────────────────────┘              │   - Auto Backup & Audit Log  │
                                       └──────────────┬───────────────┘
┌───────────────────────┐                             │
│ อุปกรณ์ IoT & GPS     │ ── 4G / Wi-Fi Ping ─────────┘
│ - ESP32 GPS รถบรรทุก  │ (X-GPS-Device-Key)
│ - ESP32 สแกนนิ้วลงเวลา │
└───────────────────────┘
```

---

## 2. โมดูล 1: แผนติดตั้งเซิร์ฟเวอร์ Beelink (Server Setup & Migration Blueprint)

**อุปกรณ์ (Hardware):** Beelink Mini S12 Pro (Intel N100 / 32GB RAM / 500GB NVMe SSD)  
**ระบบปฏิบัติการ (OS):** Ubuntu Server 26.04 LTS (ISO ดาวน์โหลดแล้ว เบิร์น Flash Drive ด้วย Rufus 4.15 แล้ว)

### แผนงาน 4 ขั้นตอน (4-Phase Implementation):

#### Phase 1: การลง OS และเตรียมเครือข่าย (OS & Network Setup)
* [ ] บูตติดตั้ง Ubuntu Server 26.04 LTS จาก Flash Drive
* [ ] **สำคัญ:** ติ๊กเลือก `[X] Install OpenSSH server` เพื่อให้บ๊อบสามารถ Remote เข้าไปจัดการได้
* [ ] ตั้งชื่อ Hostname: `pos-server` และตั้ง Static IP ภายในวง LAN (เช่น `192.168.1.200`) หรือทำ DHCP Reservation ที่เร้าเตอร์
* [ ] ติดตั้งเครื่องมือบริหารจัดการเครื่องผ่านเบราว์เซอร์: Cockpit Web Console (`sudo apt install cockpit -y` พอร์ต `9090`)

#### Phase 2: ติดตั้งและปรับแต่งฐานข้อมูล (Database & Runtime Tuning)
* [ ] ติดตั้ง MySQL Server 8.0 ปรับแต่ง `my.cnf`:
  * `innodb_buffer_pool_size = 8G` (รองรับ RAM 32GB ได้อย่างเต็มประสิทธิภาพ)
  * `innodb_log_file_size = 1G`
  * `max_connections = 250`
  * `character-set-server = utf8mb4`
* [ ] ติดตั้ง Dart SDK Runtime และนำเข้า Backend Service (`c:\pos_desktop\backend`)
* [ ] ตั้งค่า Systemd Service ให้ Backend และ Cloudflare Tunnel รันอัตโนมัติเมื่อเปิดเครื่อง (`systemctl enable pos-backend cloudflared`)

#### Phase 3: การย้ายข้อมูลและตั้งค่า Single Tunnel (Data Migration & Tunnel)
* [ ] Export ข้อมูลจากเครื่อง POS แม่เดิม: `mysqldump --single-transaction --quick --routines --triggers pos_db > backup_master.sql`
* [ ] Import ข้อมูลเข้า Beelink Server ตรวจสอบ Checksum และจำนวนแถวทุกตาราง
* [ ] ย้าย Cloudflare Tunnel Connector มาผูกที่ Beelink ชี้โดเมน `https://api.namecheap.work` เข้า `localhost:8080`
* [ ] สลับเครื่อง POS หน้าร้านให้ชี้มาที่ IP ของ Beelink ผ่าน LAN (เร็วระดับเสี้ยววินาที)

#### Phase 4: ระบบสำรองข้อมูลอัตโนมัติ (Automated Guarded Backup)
* [ ] ตั้ง Cron Job สำรองข้อมูลทุกวันเวลา 23:00 น. (`0 23 * * *`)
* [ ] สร้างไฟล์สำรองพร้อม Manifest SHA-256 Checksum ตรวจสอบความสมบูรณ์
* [ ] ซิงค์ไฟล์สำรองขึ้น Cloud / สำรองลงไดรฟ์ภายนอกอัตโนมัติ

---

## 3. โมดูล 2: ระบบแต้มสะสมช่างและลูกค้า 2 ระดับ (Smart Loyalty Points Engine)

**เป้าหมาย (Goal):** ดึงดูดและล็อกลูกค้าช่าง/ผู้รับเหมาประจำ (Retention Lock-in) ด้วยแต้มสะสมที่เป็นธรรม

### กฎการคำนวณแต้ม (Point Calculation Rules):

| กลุ่มลูกค้า (Customer Tier) | อัตราแต้มสินค้าทั่วไป (General Items) | สินค้ากำไรบาง / ปูน / บล็อก (Fixed Qty Rule) |
| :--- | :---: | :--- |
| 🧑‍💼 **ลูกค้าทั่วไป (General Customer)** | **1%** ของยอดซื้อ | 20 ถุงปูน = 1 แต้ม / 200 ก้อนบล็อก = 1 แต้ม |
| 👷 **ช่าง / ผู้รับเหมา (Contractor)** | **2.5%** ของยอดซื้อ | **10 ถุงปูน = 1 แต้ม** / **100 ก้อนบล็อก = 1 แต้ม** |

*หมายเหตุ: 1 แต้มมีมูลค่าเท่ากับ 1 บาท ใช้เป็นส่วนลดเงินสดหรือแลกของรางวัลได้*

### การปรับปรุงฐานข้อมูล (Database Schema Extension):

```sql
-- 1. เพิ่มประเภทลูกค้าและยอดแต้มสะสมในตาราง customer
ALTER TABLE `customer` 
  ADD COLUMN `customer_type` ENUM('GENERAL', 'CONTRACTOR') DEFAULT 'GENERAL' AFTER `name`,
  ADD COLUMN `points_balance` INT DEFAULT 0 AFTER `customer_type`,
  ADD COLUMN `line_user_id` VARCHAR(100) NULL AFTER `points_balance`;

-- 2. เพิ่มรูปแบบการคิดแต้มในตาราง product
ALTER TABLE `product` 
  ADD COLUMN `point_calc_type` ENUM('PERCENT', 'FIXED_QTY', 'EXEMPT') DEFAULT 'PERCENT',
  ADD COLUMN `point_unit_qty` INT DEFAULT 0; -- เช่น ถ้าเป็น FIXED_QTY ค่านี้คือ 10 (10 ถุง = 1 แต้ม)

-- 3. ตารางประวัติการรับ-ใช้แต้ม (Point Ledger)
CREATE TABLE IF NOT EXISTS `point_ledger` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `customer_id` INT NOT NULL,
  `order_id` INT NULL,
  `points_earned` INT DEFAULT 0,
  `points_used` INT DEFAULT 0,
  `reason` VARCHAR(255) NOT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `expires_at` DATETIME NULL,
  FOREIGN KEY (`customer_id`) REFERENCES `customer`(`id`)
);
```

---

## 4. โมดูล 3: ระบบสั่งของผ่าน LINE OA 24 ชม. (LINE OA 24hr E-Commerce Blueprint)

**เป้าหมาย (Goal):** ให้ลูกค้าและช่างสั่งของได้ตลอด 24 ชั่วโมง โดยออกแบบสไตล์คนขี้เกียจ (3 คลิกจบ ไม่ต้องพิมพ์คุย)

### ขั้นตอนการสั่งซื้อ (3-Step Lazy Flow):
1. **คลิกที่ 1 (เลือกของ):** ลูกค้ากดปุ่ม "🛒 สั่งสินค้า" ใน Rich Menu -> หน้าเว็บแคตตาล็อก (LINE LIFF Web App) เด้งขึ้นมาใน LINE ทันที -> ค้นหา/จิ้มสินค้าใส่ตะกร้า `[ + ]` `[ - ]`
2. **คลิกที่ 2 (ปักหมุดส่งของ):** แตะปักหมุดพิกัดบนแผนที่ ระบบคำนวณระยะทางและค่าน้ำมันอัตโนมัติด้วย OSRM Engine
3. **คลิกที่ 3 (จ่ายเงิน):** ระบบเจน QR PromptPay ยอดสุทธิ -> ลูกค้าสแกนจ่าย -> ออเดอร์เด้งเข้า POS หน้าร้านและแอปคนขับ (S-Link) ทันที!

### กลยุทธ์การจัดการรูปภาพสินค้า (Smart Lean Catalog Strategy):
* 🚫 **ไม่จำเป็นต้องถ่ายรูปสินค้าทุกชิ้น (หลีกเลี่ยงงานถ่ายรูป 5,000 SKUs):**
  * ใช้ **ไอคอนหมวดหมู่มินิมอล (Category Badges)** สำหรับสินค้าเบ็ดเตล็ด (ข้องอ, ข้อต่อ, ตะปู, น็อต, สกรู)
  * ใส่ **รูปภาพจริงเฉพาะ Top 20 สินค้าขายดี** (ปูนช้าง, ปูนเสือ, อิฐบล็อก, แผ่นยิปซัม, สีทาบ้าน)
  * ใส่ **ลิงก์วิดีโอคลิปสาธิตการใช้งาน (YouTube / Supplier Media)** สำหรับเครื่องมือช่างและเคมีภัณฑ์ก่อสร้าง

---

## 5. โมดูล 4: ระบบสีผสมเครื่องเบเยอร์ (Beger Tinting Machine Catalog)

**เป้าหมาย (Goal):** รองรับการสั่งสีผสมเครื่องเบเยอร์หลายหมื่นเฉดสี โดยสต็อกไม่บวมและตัดปัญหาข้อพิพาทจอสีเพี้ยน

### แนวทางปฏิบัติ (Implementation Rules):
1. **ลงรายการในระบบเฉพาะรุ่นสีและขนาดถัง (Base Paint Only):**
   * เช่น *สีทาภายนอก BegerCool DiamondShield กึ่งเงา (เบส A) ขนาด 2.5 แกลลอน*
2. **ช่องระบุรหัสสีและลิงก์พัดสีออนไลน์ (Color Code Input & Fandeck Link):**
   * ให้ลูกค้าพิมพ์รหัสสีที่ต้องการในช่องหมายเหตุ (เช่น `052-3` หรือ `Ocean Blue`)
   * แปะปุ่มลิงก์ไปยัง **"แคตตาล็อกพัดสีออนไลน์ของบริษัทเบเยอร์"** ให้ลูกค้าเปิดเทียบเฉดสีได้เอง
3. **ข้อความเตือนและระบบยืนยัน (Disclaimer & Double Confirmation):**
   * แปะคำเตือน: *"⚠️ เฉดสีบนหน้าจอมือถืออาจแตกต่างจากสีจริงบนพื้นผิว 5-10% เนื่องจากค่าแสงและการแสดงผลของแต่ละหน้าจอ หากต้องการความแม่นยำ 100% สามารถเข้ามาดูพัดสีจริงที่หน้าร้านได้ครับ"*
   * มีข้อความยืนยันทาง LINE แจ้งเตือนว่า *"สีผสมเครื่องสั่งทำพิเศษ ไม่สามารถเปลี่ยนหรือคืนได้หลังเริ่มผสม"*

---

## 6. โมดูล 5: ระบบฮาร์ดแวร์และ IoT ประจำร้าน (Hardware & IoT Peripherals)

### 1. ระบบ GPS รถบรรทุก (ESP32 Vehicle Tracker)
* **รถ 6 ล้อ (ไฟ 24V):** ใช้ Fuse Tab บัดกรีสายไฟ + Fork Terminal (หางปลาแฉก) ขันยึดเข้ากล่องฟิวส์หลอดแก้ว 24V แน่นหนา ปลอดภัย
* **การส่งข้อมูล:** ยิงพิกัดผ่าน 4G Aircard / Wi-Fi เข้าสู่ `POST /api/v1/gps` ด้วย Header `X-GPS-Device-Key`
* **การแสดงผล:** หน้าร้านเห็นสถานะทั้งขาไปและขากลับบน `gps.html` พร้อม Geofence 200m รีเซ็ตสถานะเมื่อถึงร้านอัตโนมัติ

### 2. เครื่องสแกนลายนิ้วมือไร้สาย (ESP32 Fingerprint Attendance)
* **ฮาร์ดแวร์:** DOIT ESP32 DEVKIT V1 + Optical Fingerprint Sensor
* **ระบบ Offline Flash Memory Sync:** สแกนนิ้วได้แม้คอมพิวเตอร์หน้าร้านปิดอยู่ ข้อมูลจะเก็บลง Flash Memory พร้อมเวลา NTP และอัปโหลดเข้า POS อัตโนมัติเมื่อเปิดร้าน
* **เสียงตอบรับ (DFPlayer Mini MP3):** ต่อโมดูลเสียงพูดภาษาไทยแจ้งสถานะการบันทึกเวลาของพนักงาน

---

## 📝 ประวัติการปรับปรุงเอกสาร (Changelog)
- **2026-08-23:** จัดทำเอกสารพิมพ์เขียวระบบแม่บทฉบับสมบูรณ์ (Master System Blueprint v1.0) รวบรวมแผนงาน Beelink Server, Loyalty Points, LINE OA Commerce, และ Beger Tinting System
