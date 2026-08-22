# GPS Tracker (Pocket Wi-Fi Edition)

This is the production firmware for vehicles using an ESP32 + NEO-M8N GPS + Pocket Wi-Fi connection.

นี่คือเฟิร์มแวร์สำหรับใช้งานจริงสำหรับรถที่ใช้ ESP32 + GPS NEO-M8N ร่วมกับ Pocket Wi-Fi
(ยกเลิกการเชื่อมต่อผ่านโมดูล A7670E แบบเดิม)

## Setup / การเตรียม

1. Copy `gps_wifi_test_secrets.h.example` to `gps_wifi_test_secrets.h` and enter
   local Wi-Fi, test endpoint and device key. The local file is ignored by Git.
2. Install the ESP32 board package plus `TinyGPSPlus` and `ArduinoJson`.
3. Upload `GPS_WIFI_TEST.ino`; use Serial Monitor at **115200 baud**.

| GPS NEO-M8N | ESP32 |
| --- | --- |
| TX | GPIO16 (RX2) |
| RX | GPIO17 (TX2, optional for this test) |
| GND | GND |
| VCC | module-rated supply (usually 3.3–5 V) |

Place the antenna outdoors with an open view of the sky. / วางเสาอากาศกลางแจ้ง
ให้เห็นท้องฟ้าโล่ง.

## Expected output / ผลที่ควรเห็น

```text
[ASSERT][WiFi] PASS: connected, IP=...
[GPS] age=...ms satellites=... hdop=...
[ASSERT][GPS] PASS: fresh, usable location fix
[ASSERT][HTTP] PASS: 200
```

The GPS assertion requires a fix no older than 5 seconds, at least 4 satellites,
and HDOP no worse than 3.5 when the module reports HDOP. / การทดสอบ GPS ต้องได้
พิกัดอายุไม่เกิน 5 วินาที ดาวอย่างน้อย 4 ดวง และ HDOP ไม่เกิน 3.5 หากมีค่า HDOP.

## Troubleshooting / แก้ปัญหา

- `WiFi FAIL`: confirm 2.4 GHz SSID/password, signal and ESP32 power.
- `GPS FAIL` or `No serial data`: confirm GPS TX → GPIO16, shared GND, power,
  antenna and outdoor sky view.
- HTTP `401`: device key is missing, wrong, or not authorized by the test API.
- HTTP `400`: inspect the printed response; normally the endpoint, JSON fields,
  or vehicle configuration is invalid.

`client.setInsecure()` is deliberately enabled only for this bench test. It
skips TLS certificate verification; production firmware must configure a CA.
