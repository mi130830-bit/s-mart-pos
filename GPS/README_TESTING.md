# GPS tracker staged test / การทดสอบ GPS Tracker แบบเป็นลำดับ

These sketches isolate each subsystem. Upload **only one sketch at a time**. Set the placeholder values locally before upload; never save a real Wi-Fi password or device key in Git.

สเก็ตช์เหล่านี้แยกทดสอบเป็นส่วน ๆ ให้เลือกอัปโหลด **ทีละไฟล์เท่านั้น** แก้ placeholder ในเครื่องก่อนอัปโหลด และห้ามบันทึกรหัส Wi-Fi หรือ device key จริงลง Git

## 1. ESP32 only / ESP32 อย่างเดียว

1. Disconnect the GPS and A7670E. Power the ESP32 from a known-good USB cable.
2. Upload a basic Blink sketch and open Serial Monitor at 115200 baud.
3. Confirm the board boots consistently before connecting any module.

1. ถอด GPS และ A7670E ออกทั้งหมด แล้วจ่ายไฟ ESP32 ด้วยสาย USB ที่แน่ใจว่าใช้งานได้
2. อัปโหลด Blink และเปิด Serial Monitor ที่ 115200 baud
3. ยืนยันว่าบอร์ดบูตได้สม่ำเสมอก่อนต่อโมดูลอื่น

## 2. GPS only / GPS อย่างเดียว

1. With ESP32 power off, connect GPS TX -> GPIO16, GPS RX -> GPIO17, VCC to the GPS module's rated supply, and GND -> ESP32 GND.
2. Keep the A7670E disconnected. Open and upload `GPS_WIFI_TEST/GPS_WIFI_TEST.ino`; it will report missing GPS serial data and wait for a fix.
3. Test outdoors with the antenna facing the sky. A valid latitude/longitude and satellite count confirm GPS operation.

1. ปิดไฟ ESP32 ก่อน แล้วต่อ GPS TX -> GPIO16, GPS RX -> GPIO17, VCC ตามแรงดันที่โมดูลรองรับ และ GND -> ESP32 GND
2. ยังไม่ต้องต่อ A7670E จากนั้นเปิดและอัปโหลด `GPS_WIFI_TEST/GPS_WIFI_TEST.ino`; โปรแกรมจะแจ้งหากไม่พบข้อมูลจาก GPS และรอพิกัด
3. ทดสอบกลางแจ้งโดยหงายเสารับฟ้า พิกัดและจำนวนดาวเทียมที่ถูกต้องยืนยันว่า GPS ทำงาน

## 3. GPS + Wi-Fi + API/map / GPS + Wi‑Fi + API/แผนที่

1. In `GPS_WIFI_TEST/GPS_WIFI_TEST.ino`, set `WIFI_SSID`, `WIFI_PASSWORD`, `SERVER_URL`, `GPS_DEVICE_KEY`, and `VEHICLE_NAME` locally. Do not commit them.
2. Keep A7670E completely disconnected. Upload the sketch.
3. Expect `[WiFi] Connected`, valid `[GPS]` coordinates, then `[WiFi] HTTP OK: 200` (or another 2xx response). Confirm the vehicle appears or moves on the map.
4. If Wi-Fi works but the API fails, check the URL/device key in the backend configuration; do not add secrets to source control.

1. แก้ `WIFI_SSID`, `WIFI_PASSWORD`, `SERVER_URL`, `GPS_DEVICE_KEY` และ `VEHICLE_NAME` ใน `GPS_WIFI_TEST/GPS_WIFI_TEST.ino` เฉพาะในเครื่อง ห้าม commit
2. ถอด A7670E ออกตลอดการทดสอบ แล้วอัปโหลดสเก็ตช์
3. ควรเห็น `[WiFi] Connected`, พิกัด `[GPS]` ที่ถูกต้อง และ `[WiFi] HTTP OK: 200` (หรือรหัส 2xx) จากนั้นตรวจรถบนแผนที่
4. ถ้า Wi‑Fi ผ่านแต่ API ไม่ผ่าน ให้ตรวจ URL/device key ในการตั้งค่า backend โดยห้ามใส่ความลับลง source control

## 4. A7670E + 4G / A7670E + 4G

1. Power off ESP32. Connect **only** the A7670E UART: module TX -> GPIO26, module RX -> GPIO25, plus a shared GND. Leave GPS disconnected.
2. Power A7670E from its specified supply with at least 2A peak capacity. Never use the ESP32 3.3V pin. Verify the module board's PWRKEY/PWR_EN requirement from its own silkscreen/manual before testing.
3. In `GPS_4G_A7670E/GPS_4G_A7670E.ino`, set `APN`, `SERVER_HOST`, `GPS_DEVICE_KEY`, and `VEHICLE_NAME` locally. Upload and open Serial Monitor at 115200 baud.
4. First target: IMEI prints and network registration. Second target: IP address. The sketch defaults to network-only mode so it cannot create a false map location. Set `SEND_API_TEST=true` only when intentionally testing the API; it sends a deliberate `lat=0`, `lng=0` payload and expects a 2xx response. It does not test GPS.
5. Only after this passes, return to the Wi-Fi test for a real location, then integrate the known-good GPS and A7670E paths.

1. ปิดไฟ ESP32 ก่อน แล้วต่อ **เฉพาะ** UART ของ A7670E: TX โมดูล -> GPIO26, RX โมดูล -> GPIO25 และ GND ร่วมกัน ยังไม่ต้องต่อ GPS
2. จ่ายไฟ A7670E จากแหล่งจ่ายตามสเปกที่รับกระแสกระชากได้อย่างน้อย 2A ห้ามใช้ขา 3.3V ของ ESP32 และต้องตรวจ PWRKEY/PWR_EN ของบอร์ดรุ่นจริงจากสกรีน/คู่มือก่อน
3. แก้ `APN`, `SERVER_HOST`, `GPS_DEVICE_KEY` และ `VEHICLE_NAME` ใน `GPS_4G_A7670E/GPS_4G_A7670E.ino` เฉพาะในเครื่อง จากนั้นอัปโหลดและเปิด Serial Monitor ที่ 115200 baud
4. เป้าหมายแรกคือ IMEI และลงทะเบียนเครือข่ายได้ เป้าหมายสองคือได้ IP โดยค่าเริ่มต้นจะทดสอบเฉพาะเครือข่ายเพื่อไม่ให้เกิดพิกัดปลอมบนแผนที่ หากต้องการทดสอบ API โดยตั้งใจ ให้ตั้ง `SEND_API_TEST=true`; จะส่ง payload `lat=0`, `lng=0` และควรได้ HTTP 2xx ซึ่งยังไม่ได้ทดสอบ GPS
5. เมื่อผ่านแล้ว จึงกลับไปทดสอบตำแหน่งจริงผ่าน Wi‑Fi แล้วค่อยรวมเส้นทาง GPS และ A7670E ที่ผ่านการทดสอบแล้ว

## Stop conditions / จุดที่ต้องหยุดตรวจ

- No A7670E LEDs or no modem response: stop at power/PWRKEY/UART wiring; APN and application code cannot fix this.
- No GPS serial data: stop at GPS power and TX/RX wiring.
- No satellite fix indoors: move the antenna outdoors before changing code.

- A7670E ไม่มีไฟหรือโมเด็มไม่ตอบ: หยุดตรวจที่ไฟเลี้ยง/PWRKEY/UART ก่อน เพราะ APN และโค้ดแก้ไม่ได้
- GPS ไม่มีข้อมูล serial: หยุดตรวจที่ไฟเลี้ยง GPS และสาย TX/RX
- GPS จับดาวเทียมไม่ได้ในอาคาร: ย้ายเสาออกกลางแจ้งก่อนเปลี่ยนโค้ด
