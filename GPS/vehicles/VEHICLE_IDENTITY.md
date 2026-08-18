# Canonical GPS vehicle identity / รหัสรถ GPS กลาง

The GPS tracker, S-Link departure/completion updates, POS GPS backend, and
the internal map must use the same stable vehicle key. A registration plate is
display information; it is not the GPS identity.

ESP tracker, การอัปเดตปล่อยรถ/ปิดงานจาก S-Link, backend GPS ของ POS และ
แผนที่ภายใน ต้องใช้ชื่อรหัสรถคงที่เดียวกัน ทะเบียนรถใช้สำหรับแสดงผลเท่านั้น
ห้ามใช้เป็นรหัส GPS

| Canonical GPS key / รหัสกลาง | Vehicle / รถ | ESP sketch / ไฟล์ ESP |
| --- | --- | --- |
| `ดั้มเล็ก` | รถดั้มเล็ก | `dump_small/dump_small.ino` |
| `ดั้มใหญ่` | รถดั้มใหญ่ | `dump_large/dump_large.ino` |
| `รถเครน` | รถเครน | `GPS.ino` (default) |

## Rules / กติกา

- Set the same key as the **vehicle name** in S-Link master data.
- Configure the same key in the ESP sketch through `GPS_VEHICLE_NAME`.
- Do not substitute the licence plate in GPS update payloads.
- If a vehicle is renamed for display, keep its canonical GPS key unchanged;
  create a dedicated mapping before changing deployed tracker firmware.

- ตั้งชื่อรถใน master data ของ S-Link ให้ตรงกับรหัสกลาง
- ตั้งค่า `GPS_VEHICLE_NAME` ใน ESP ให้ตรงกับรหัสกลาง
- ห้ามส่งทะเบียนรถแทนรหัสกลางใน GPS payload
- หากต้องการเปลี่ยนชื่อที่แสดง ให้คงรหัสกลางเดิมไว้ และทำ mapping ก่อนแก้
  firmware ที่ติดตั้งใช้งานอยู่
