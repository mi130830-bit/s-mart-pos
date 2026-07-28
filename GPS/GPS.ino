// ============================================================
//  ร้านส.บริการ ท่าข้าม - GPS Tracker v2.0
//  Hardware : ESP32 + LM2596 Buck + SIMCOM A7670E + NEO-M8N
//  SIM      : Finn Mobile (DTAC Network)
//  Vehicle  : รถเครน
//  Author   : Bob (Antigravity AI) - POS System
// ============================================================

// ------------------------------------------------------------------
// ⚙️ โหมดการทำงาน: เลือกใช้อย่างใดอย่างหนึ่ง
//    - ปิด comment (#define USE_4G) ไว้ก่อน  = ทดสอบผ่าน WiFi
//    - เปิด comment (#define USE_4G)         = ใช้งานจริงผ่าน 4G SIM
// ------------------------------------------------------------------
// #define USE_4G

// ------------------------------------------------------------------
// 📋 ตั้งค่าหลัก (แก้ได้ที่นี่จุดเดียว)
// ------------------------------------------------------------------
const char* VEHICLE_NAME = "รถเครน";              // ชื่อรถ (แสดงบนแผนที่และ Telegram)
const char* SERVER_URL   = "https://api.namecheap.work/api/v1/gps";
const unsigned long SEND_INTERVAL_MS = 5000;       // ส่งพิกัดทุก 5 วินาที

// -- WiFi (โหมดทดสอบ) --
const char* WIFI_SSID     = "Ti";
const char* WIFI_PASSWORD = "12345678";

// -- 4G SIM (Finn Mobile ใช้เครือข่าย DTAC) --
const char* APN = "internet";  // APN ของ DTAC / Finn Mobile

// ------------------------------------------------------------------
// 📌 Pin Mapping (ตรวจสอบให้ตรงกับการต่อสายจริง)
// ------------------------------------------------------------------
// [GPS Module NEO-M8N] Serial2
#define GPS_RX_PIN  16   // ต่อสาย TX จาก GPS เข้า GPIO 16 (ESP32 RX2)
#define GPS_TX_PIN  17   // ต่อสาย RX จาก GPS เข้า GPIO 17 (ESP32 TX2)
#define GPS_BAUD    9600

// [A7670E 4G Module] Serial1
#define GSM_RX_PIN  26   // ต่อสาย TX จาก A7670E เข้า GPIO 26 (ESP32 RX1)
#define GSM_TX_PIN  25   // ต่อสาย RX จาก A7670E เข้า GPIO 25 (ESP32 TX1)
#define GSM_BAUD    115200

// ------------------------------------------------------------------
// 📦 Libraries
// ------------------------------------------------------------------
#include <TinyGPSPlus.h>
#include <ArduinoJson.h>

#ifdef USE_4G
  // โหมด 4G: ใช้ TinyGSM Library
  #define TINY_GSM_MODEM_A7670
  #define TINY_GSM_RX_BUFFER 1024
  #include <TinyGsmClient.h>
  #include <ArduinoHttpClient.h>
  TinyGsm        modem(Serial1);
  TinyGsmClientSecure gsmClient(modem);
#else
  // โหมด WiFi: ใช้ WiFi + HTTPClient
  #include <WiFi.h>
  #include <HTTPClient.h>
  #include <WiFiClientSecure.h>
#endif

// ------------------------------------------------------------------
// 🔧 Global Variables
// ------------------------------------------------------------------
TinyGPSPlus gps;
unsigned long lastSendTime     = 0;
unsigned long lastCheckGpsTime = 0;
bool          isConnected       = false;

// ------------------------------------------------------------------
// 📡 ฟังก์ชัน: เชื่อมต่อ 4G (เรียกตอน setup และตอน reconnect)
// ------------------------------------------------------------------
#ifdef USE_4G
bool connect4G() {
  Serial.println("[4G] กำลัง Restart โมดูล A7670E...");
  modem.restart();
  delay(3000);

  Serial.print("[4G] IMEI: ");
  Serial.println(modem.getIMEI());

  Serial.print("[4G] กำลังเชื่อมต่อ APN: ");
  Serial.println(APN);

  if (!modem.gprsConnect(APN, "", "")) {
    Serial.println("[4G] ❌ เชื่อมต่อ GPRS ล้มเหลว!");
    return false;
  }

  Serial.println("[4G] ✅ เชื่อมต่อ 4G สำเร็จ!");
  Serial.print("[4G] IP Address: ");
  Serial.println(modem.localIP());
  return true;
}
#endif

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

#ifdef USE_4G
  // --- โหมด 4G ---
  if (!modem.isGprsConnected()) {
    Serial.println("[4G] ⚠️ GPRS หลุด! กำลัง Reconnect...");
    isConnected = connect4G();
    if (!isConnected) return;
  }

  // แยก Host และ Path จาก URL
  const char* host = "api.namecheap.work";
  const char* path = "/api/v1/gps";

  HttpClient httpClient(gsmClient, host, 443);
  httpClient.connectionKeepAlive();

  int err = httpClient.post(path, "application/json", payload);
  if (err == 0) {
    int statusCode = httpClient.responseStatusCode();
    Serial.print("[4G] ✅ ส่งพิกัดสำเร็จ HTTP: ");
    Serial.println(statusCode);
    httpClient.skipResponseHeaders();
  } else {
    Serial.print("[4G] ❌ HTTP POST Error: ");
    Serial.println(err);
  }
  httpClient.stop();

#else
  // --- โหมด WiFi ---
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WiFi] ⚠️ WiFi หลุด! กำลัง Reconnect...");
    WiFi.reconnect();
    unsigned long t = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - t < 10000) {
      delay(500);
      Serial.print(".");
    }
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("\n[WiFi] ❌ Reconnect ล้มเหลว");
      return;
    }
    Serial.println("\n[WiFi] ✅ Reconnect สำเร็จ!");
  }

  WiFiClientSecure client;
  client.setInsecure(); // ข้ามการเช็ก SSL Certificate (Cloudflare Tunnel)
  client.setTimeout(5);

  HTTPClient http;
  http.begin(client, SERVER_URL);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(5000); // Timeout 5 วินาที (ตาม Shadow แนะนำ)

  int httpCode = http.POST(payload);
  if (httpCode > 0) {
    Serial.print("[WiFi] ✅ ส่งพิกัดสำเร็จ HTTP: ");
    Serial.println(httpCode);
  } else {
    Serial.print("[WiFi] ❌ ส่งพิกัดผิดพลาด Error: ");
    Serial.println(httpCode);
  }
  http.end();
#endif
}

// ------------------------------------------------------------------
// 🚀 Setup
// ------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  Serial.println("\n================================================");
  Serial.println("  ร้านส.บริการ ท่าข้าม - GPS Tracker v2.0 เริ่มทำงาน");
  Serial.print  ("  ยานพาหนะ : ");
  Serial.println(VEHICLE_NAME);
  Serial.println("================================================\n");

  // เริ่ม GPS Serial
  Serial2.setRxBufferSize(1024);
  Serial2.begin(GPS_BAUD, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
  Serial.println("[GPS] เปิด Serial สำหรับ NEO-M8N แล้ว");

#ifdef USE_4G
  // เริ่ม A7670E Serial
  Serial1.begin(GSM_BAUD, SERIAL_8N1, GSM_RX_PIN, GSM_TX_PIN);
  Serial.println("[4G] กำลังเริ่มต้นโมดูล A7670E...");
  delay(1000);
  isConnected = connect4G();
#else
  // เชื่อมต่อ WiFi
  Serial.print("[WiFi] กำลังเชื่อมต่อ SSID: ");
  Serial.print(WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n[WiFi] ✅ เชื่อมต่อสำเร็จ! IP: " + WiFi.localIP().toString());
  isConnected = true;
#endif

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
      Serial.println("[GPS] ⏳ รอสัญญาณดาวเทียม...");
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