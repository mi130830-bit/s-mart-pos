# Vehicle GPS sketches / สเก็ตช์ GPS แยกรถ

Each vehicle sketch selects a stable vehicle identifier, then loads the shared
production firmware from `GPS/GPS.ino`. This prevents copied tracker code from
drifting between vehicles.

แต่ละสเก็ตช์กำหนดชื่อรถให้คงที่ แล้วเรียก firmware กลางจาก
`GPS/GPS.ino` จึงไม่ต้องคัดลอกโค้ด tracker ซ้ำ และแก้บั๊กครั้งเดียวได้ทุกคัน

| Vehicle / รถ | Sketch to upload / ไฟล์ที่อัปโหลด | GPS identifier / ชื่อบน GPS |
| --- | --- | --- |
| Small dump truck / รถดั้มเล็ก | `dump_small/dump_small.ino` | `ดั้มเล็ก` |
| Large dump truck / รถดั้มใหญ่ | `dump_large/dump_large.ino` | `ดั้มใหญ่` |

## Before upload / ก่อนอัปโหลด

1. Open only the intended vehicle sketch in Arduino IDE.
2. Confirm the shared configuration in `GPS/GPS.ino`: APN, device key, pin
   mapping, and whether the tracker should use 4G or Wi-Fi test mode.
3. Upload to one ESP32 only, then confirm the same vehicle name appears on the
   GPS map before programming the next tracker.

1. เปิดเฉพาะสเก็ตช์ของรถคันที่จะติดตั้งใน Arduino IDE
2. ตรวจการตั้งค่ากลางใน `GPS/GPS.ino`: APN, device key, การต่อขา และโหมด
   4G หรือ Wi-Fi สำหรับทดสอบ
3. อัปโหลดทีละ ESP32 และตรวจว่าหน้า GPS แสดงชื่อรถให้ตรงก่อนทำคันถัดไป

Do not place Wi-Fi passwords or replacement device keys in these per-vehicle
sketches. Configure credentials locally in the shared firmware or provision
them outside version control.

ห้ามใส่รหัส Wi-Fi หรือ device key ใหม่ลงในสเก็ตช์แยกรถ ให้ตั้งค่าข้อมูลลับ
เฉพาะเครื่องใน firmware กลาง หรือ provision นอกระบบ version control
