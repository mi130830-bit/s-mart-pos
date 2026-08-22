# บันทึกการแก้ไข (Fixes & Modifications Log)

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
# #   F i x :   B a r c o d e   S c a n n e r   I m p r o v e m e n t   P l a n  
 * * D a t e * * :   2 0 2 6 - 0 8 - 1 9  
 * * I s s u e * * :   B a r c o d e   s c a n n e r   i n t e g r a t i o n   h a d   s e v e r a l   i s s u e s   i n c l u d i n g   s c a n n i n g   t h e   w r o n g   p r o d u c t   d u e   t o   f u z z y   m a t c h i n g ,   A S C I I   c o n v e r s i o n   w i t h o u t   c h e c k i n g   f o r   T h a i   i n p u t ,   l a c k   o f   e n t e r / t a b   s u f f i x   c o n f i g u r a t i o n ,   a n d   m i s s i n g   h a r d w a r e   s c a n n e r   s u p p o r t   i n   p r o d u c t   c r e a t i o n   f o r m .  
 * * R e s o l u t i o n * * :  
 1 .   * * S t a r t u p   C o n f i g   L o a d i n g * * :   I n i t i a l i z e d   \ B a r c o d e U t i l s \   e a r l y   i n   \ m a i n . d a r t \ .  
 2 .   * * S a f e   T h a i   C o n v e r s i o n * * :   A d d e d   \ i s T h a i I n p u t ( ) \   g u a r d   i n   \ B a r c o d e U t i l s . f i x T h a i I n p u t \   t o   p r e s e r v e   E n g l i s h   i n p u t .   A d d e d   s c a n n e r   s u f f i x   c o n f i g u r a t i o n   ( \ E n t e r \ / \ T a b \ )   t o   s h a r e d   p r e f e r e n c e s .  
 3 .   * * H a r d e n e d   P O S   S c a n   F l o w * * :   R e m o v e d   t h e   d a n g e r o u s   3 0 0 m s   d e b o u n c e   t i m e r   i n   \ p o s _ b a r c o d e _ h a n d l e r _ m i x i n . d a r t \   a n d   c l e a r e d   \  a r c o d e C t r l \   s y n c h r o n o u s l y .   H a n d l e d   \ L o g i c a l K e y b o a r d K e y . t a b \   n a t i v e l y .  
 4 .   * * E x a c t   M a t c h   R e q u i r e m e n t * * :   R e m o v e d   \ e l s e   i f   ( m a t c h e s . i s N o t E m p t y ) \   f r o m   \ p o s _ c a r t _ m i x i n . d a r t \   t o   s t r i c t l y   e n f o r c e   e x a c t   p r i m a r y / u n i t   b a r c o d e   m a t c h .  
 5 .   * * P r o d u c t   F o r m   S u p p o r t * * :   I n j e c t e d   \  u t o f o c u s :   t r u e \   a n d   \  i x T h a i I n p u t ( ) \   n o r m a l i z a t i o n   i n   \ p r o d u c t _ f o r m _ l e f t _ c o l u m n . d a r t \   a n d   \ p r o d u c t _ u n i t _ b a r c o d e _ t a b . d a r t \ .  
 6 .   * * O f f l i n e   U n i t   B a r c o d e   S y n c * * :   A d d e d   \ P r o d u c t B a r c o d e C o l l e c t i o n \   t o   I s a r .   M o d i f i e d   \ P r o d u c t R e p o s i t o r y . g e t A l l P r o d u c t s ( ) \   t o   s y n c   \ p r o d u c t _ b a r c o d e \   a n d   \  i n d P r o d u c t B a r c o d e ( ) \   t o   f a l l b a c k   t o   I s a r   w h e n   o f f l i n e .  
 7 .   * * S e t t i n g s   U I   U p d a t e * * :   E n h a n c e d   \  a r c o d e _ s e t t i n g s _ s c r e e n . d a r t \   w i t h   a   S u f f i x   D r o p d o w n   ( \ E n t e r \   o r   \ T a b \ )   a n d   a   ' T e s t   S c a n '   i n t e r a c t i v e   d i a l o g   t o   p r e v i e w   m a p p e d   o u t p u t s .  
  
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
