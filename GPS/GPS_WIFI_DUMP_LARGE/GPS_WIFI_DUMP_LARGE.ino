// ============================================================
//  ร้านส.บริการ ท่าข้าม - GPS Tracker (Wi-Fi Edition)
//  Hardware : ESP32 + LM2596 Buck + NEO-M8N + Pocket Wi-Fi
//  Vehicle  : รถดั้มใหญ่ (ดั้มใหญ่)
//  Author   : Bob (Antigravity AI) - POS System
// ============================================================

#include <WiFi.h>
#include <esp_wifi.h>
#include <nvs_flash.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <TinyGPSPlus.h>
#include <ArduinoJson.h>

// ------------------------------------------------------------------
// 📋 ตั้งค่าหลัก (แก้ได้ที่นี่จุดเดียว)
// ------------------------------------------------------------------
// ค่าลับ (Wi-Fi password / GPS device key) อยู่ใน gps_wifi_test_secrets.h
// ถ้าย้ายไปเครื่องใหม่ ให้คัดลอก gps_wifi_test_secrets.h.example 
// แล้วกรอกค่าของเครื่องนั้นก่อนอัปโหลด
#include "gps_wifi_test_secrets.h"

const unsigned long SEND_INTERVAL_MS = 5000;       // ส่งพิกัดทุก 5 วินาที

// ------------------------------------------------------------------
// 📌 Pin Mapping (ตรวจสอบให้ตรงกับการต่อสายจริง)
// ------------------------------------------------------------------
// [GPS Module NEO-M8N] Serial2
#define GPS_RX_PIN  16   // ต่อสาย TX จาก GPS เข้า GPIO 16 (ESP32 RX2)
#define GPS_TX_PIN  17   // ต่อสาย RX จาก GPS เข้า GPIO 17 (ESP32 TX2)
#define GPS_BAUD    9600

// ------------------------------------------------------------------
// 🔧 Global Variables
// ------------------------------------------------------------------
TinyGPSPlus gps;
unsigned long lastSendTime     = 0;
unsigned long lastCheckGpsTime = 0;

// ------------------------------------------------------------------
// 📍 ฟังก์ชัน: ส่งพิกัดขึ้น Server
// ------------------------------------------------------------------
void sendGpsData(double lat, double lng, double speed) {
  // สร้าง JSON Payload
  StaticJsonDocument<200> doc;
  doc["lat"]     = lat;
  doc["lng"]     = lng;
  doc["speed"]   = speed;
  doc["vehicle"] = VEHICLE_NAME;

  String payload;
  serializeJson(doc, payload);

  Serial.println("[HTTP] Payload: " + payload);

  // เช็ค WiFi ก่อนส่ง
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WiFi] ⚠️ WiFi หลุด! กำลัง Reconnect...");
    WiFi.disconnect(true, true);
    delay(100);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    unsigned long t = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - t < 15000) {
      delay(10);
      while (Serial2.available() > 0) {
        gps.encode(Serial2.read());
      }
      if ((millis() - t) % 500 < 10) Serial.print(".");
    }
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("\n[WiFi] ❌ Reconnect ล้มเหลว (เช็ค Pocket Wi-Fi)");
      return;
    }
    Serial.println("\n[WiFi] ✅ Reconnect สำเร็จ!");
  }

  WiFiClientSecure client;
  client.setInsecure(); // ข้ามการเช็ก SSL Certificate สำหรับความง่าย (Cloudflare Tunnel)
  client.setTimeout(5);

  HTTPClient http;
  http.begin(client, SERVER_URL);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-GPS-Device-Key", GPS_DEVICE_KEY); // สำคัญมาก ไม่งั้นจะโดน 401 Unauthorized
  http.setTimeout(5000); // Timeout 5 วินาที

  int httpCode = http.POST(payload);
  if (httpCode > 0) {
    Serial.print("[WiFi] ✅ ส่งพิกัดสำเร็จ HTTP: ");
    Serial.println(httpCode);
    if (httpCode != 200 && httpCode != 204) {
      Serial.println("[HTTP] Response: " + http.getString());
    }
  } else {
    Serial.print("[WiFi] ❌ ส่งพิกัดผิดพลาด Error: ");
    Serial.println(httpCode);
    Serial.println("[HTTP] " + http.errorToString(httpCode));
  }
  http.end();
}

// ------------------------------------------------------------------
// 🚀 Setup
// ------------------------------------------------------------------
void setup() {
  // ล้างค่า Wi-Fi เก่าที่อาจค้างในหน่วยความจำ (แก้บั๊ก INIT loop)
  nvs_flash_erase();
  nvs_flash_init();

  Serial.begin(115200);
  Serial.println("\n================================================");
  Serial.println("  ร้านส.บริการ ท่าข้าม - GPS Tracker (Wi-Fi) เริ่มทำงาน");
  Serial.print  ("  ยานพาหนะ : ");
  Serial.println(VEHICLE_NAME);
  Serial.println("================================================\n");

  // เริ่ม GPS Serial
  Serial2.setRxBufferSize(1024);
  Serial2.begin(GPS_BAUD, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
  Serial.println("[GPS] เปิด Serial สำหรับ NEO-M8N แล้ว (GPIO 16, 17)");

  // สแกนหา Wi-Fi รอบตัวก่อนเชื่อมต่อ เพื่อดูว่า ESP32 มองเห็นไหม
  Serial.println("[WiFi] กำลังสแกนหาเครือข่ายรอบตัว...");
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(100);
  
  int n = WiFi.scanNetworks();
  if (n == 0) {
    Serial.println("[WiFi] ❌ ไม่พบเครือข่าย Wi-Fi ใดๆ เลย (เสาอากาศอาจหลุด หรือไฟไม่พอ)");
  } else {
    Serial.print("[WiFi] พบ ");
    Serial.print(n);
    Serial.println(" เครือข่าย:");
    for (int i = 0; i < n; ++i) {
      Serial.print("  ");
      Serial.print(i + 1);
      Serial.print(": ");
      Serial.print(WiFi.SSID(i));
      Serial.print(" (CH:");
      Serial.print(WiFi.channel(i));
      Serial.print(", RSSI:");
      Serial.print(WiFi.RSSI(i));
      Serial.println("dBm)");
      delay(10);
    }
  }
  Serial.println("----------------------------------------");

  // ตั้งชื่อ Hostname และบังคับโปรโตคอลให้รองรับเราเตอร์จีน
  WiFi.setHostname("ESP32-GPS");
  esp_wifi_set_protocol(WIFI_IF_STA, WIFI_PROTOCOL_11B | WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N);
  WiFi.setTxPower(WIFI_POWER_8_5dBm); // ลดความแรงคลื่นลง ป้องกันสัญญาณกวนกันเองเมื่ออยู่ใกล้เกินไป

  // เชื่อมต่อ WiFi (Pocket Wi-Fi)
  Serial.print("[WiFi] กำลังพยายามเชื่อมต่อ SSID: ");
  Serial.println(WIFI_SSID);
  
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD, 11); // ล็อกเป้า Channel 11 ตามที่สแกนเจอ
  
  unsigned long startAttemptTime = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startAttemptTime < 20000) {
    delay(10);
    while (Serial2.available() > 0) {
      gps.encode(Serial2.read());
    }
    if ((millis() - startAttemptTime) % 500 < 10) Serial.print(".");
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WiFi] ✅ เชื่อมต่อสำเร็จ! IP: " + WiFi.localIP().toString());
  } else {
    Serial.println("\n[WiFi] ❌ เชื่อมต่อไม่สำเร็จ โปรดเช็ก Pocket Wi-Fi!");
  }

  Serial.println("\n[GPS] กำลังรอสัญญาณดาวเทียม (อาจใช้เวลา 30-60 วินาที)...\n");
}

// ------------------------------------------------------------------
// 🔄 Loop
// ------------------------------------------------------------------
void loop() {
  // 1. อ่านข้อมูลจาก GPS ตลอดเวลา (ห้าม delay ในส่วนนี้)
  while (Serial2.available() > 0) {
    gps.encode(Serial2.read());
  }

  // 2. ส่งพิกัดตามช่วงเวลาที่กำหนด
  if (millis() - lastSendTime >= SEND_INTERVAL_MS) {
    lastSendTime = millis();

    // เช็กว่าพิกัดต้องอัปเดตใหม่ และสัญญาณดาวเทียมเพียงพอ
    if (gps.location.isValid() && gps.location.isUpdated()) {
      double lat   = gps.location.lat();
      double lng   = gps.location.lng();
      double speed = gps.speed.isValid() ? gps.speed.kmph() : 0.0;

      Serial.println("┌─── พิกัดล่าสุด ──────────────────────────");
      Serial.print  ("│ ยานพาหนะ : "); Serial.println(VEHICLE_NAME);
      Serial.print  ("│ ละติจูด  : "); Serial.println(lat, 6);
      Serial.print  ("│ ลองจิจูด : "); Serial.println(lng, 6);
      Serial.print  ("│ ความเร็ว : "); Serial.print(speed, 1); Serial.println(" km/h");
      Serial.print  ("│ ดาวเทียม : "); Serial.println(gps.satellites.value());
      Serial.println("└───────────────────────────────────────────");

      sendGpsData(lat, lng, speed);

    } else {
      Serial.print("[GPS] ⏳ รอสัญญาณดาวเทียม... ");
      if (gps.satellites.isValid()) {
        Serial.print("พบดาวเทียม ");
        Serial.print(gps.satellites.value());
        Serial.println(" ดวง (รอ Fix พิกัด)");
      } else {
        Serial.print("ยัง Lock ดาวเทียมไม่ได้ (รับข้อมูล NMEA: ");
        Serial.print(gps.charsProcessed());
        Serial.println(" bytes)");
      }
    }
  }

  // 3. แจ้งเตือนถ้า GPS ไม่มีข้อมูลเข้ามาเลย (อาจสายผิด)
  if (millis() > 20000 && gps.charsProcessed() < 10) {
    if (millis() - lastCheckGpsTime > 8000) {
      lastCheckGpsTime = millis();
      Serial.println("[GPS] ⚠️ ไม่พบข้อมูลจากโมดูล GPS!");
      Serial.println("      → เช็กสายไฟ: TX(GPS) -> GPIO 16, RX(GPS) -> GPIO 17, VCC=3.3V, GND=GND");
    }
  }
}
