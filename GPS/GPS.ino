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
#define USE_4G

// ------------------------------------------------------------------
// 📋 ตั้งค่าหลัก (แก้ได้ที่นี่จุดเดียว)
// ------------------------------------------------------------------
//
// ค่าลับ (Wi-Fi password / GPS device key) อยู่ใน
// gps_tracker_secrets.h ซึ่งเป็นไฟล์เฉพาะเครื่องและไม่ถูกเก็บใน Git.
// ถ้าย้ายไปเครื่องใหม่ ให้คัดลอก gps_tracker_secrets.h.example
// เป็น gps_tracker_secrets.h แล้วกรอกค่าของเครื่องนั้นก่อนอัปโหลด.
#include "gps_tracker_secrets.h"

// Vehicle-specific sketches can override this before including this firmware.
// Keep the identifier identical to the vehicle name used by the GPS web map.
#ifndef GPS_VEHICLE_NAME
#define GPS_VEHICLE_NAME "รถเครน"
#endif
const char* VEHICLE_NAME = GPS_VEHICLE_NAME;       // ชื่อรถ (แสดงบนแผนที่และ Telegram)
const char* SERVER_URL   = "https://api.namecheap.work/api/v1/gps";
const unsigned long SEND_INTERVAL_MS = 5000;       // ส่งพิกัดทุก 5 วินาที

// -- 4G SIM (AIS) --
const char* APN = GPS_APN;  // ค่า APN ของซิมที่ใช้งานจริง

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
// Power: supply VCC/GND directly from a regulated 5V source rated >= 2A peak.
// VDD is an output/rail to measure, not a 3.3V supply input. PWR_EN is left
// physically controlled until the replacement board's pinout is confirmed.

// ------------------------------------------------------------------
// 📦 Libraries
// ------------------------------------------------------------------
#include <TinyGPSPlus.h>
#include <ArduinoJson.h>

#ifdef USE_4G
  // โหมด 4G: ใช้ TinyGSM Library
  // TinyGSM ใช้ไดรเวอร์ชื่อ A7672X สำหรับโมเด็มตระกูล A7670/A7672
  #define TINY_GSM_MODEM_A7672X
  #define TINY_GSM_RX_BUFFER 1024
  #include <TinyGsmClient.h>
  TinyGsm        modem(Serial1);
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

#ifdef USE_4G
// A dead/unpowered modem cannot answer AT commands. Keep GPS processing alive
// and probe the modem at a measured interval instead of issuing network calls
// on every location update.
const unsigned long MODEM_RETRY_INTERVAL_MS = 30000;
unsigned long lastModemStartAttempt = 0;
bool modemIsResponsive = false;

// TinyGSM's A7672X localIP() parser can report 0.0.0.0 even though the
// modem's PDP context has an address. Read the documented PDP query directly.
String getDataIpFromModem() {
  while (Serial1.available() > 0) {
    Serial1.read();
  }
  Serial1.print("AT+CGPADDR=1\r\n");

  String response;
  const unsigned long startedAt = millis();
  unsigned long lastByteAt = startedAt;
  bool receivedAnyByte = false;
  while (millis() - startedAt < 1800L &&
         (!receivedAnyByte || millis() - lastByteAt < 250L)) {
    while (Serial1.available() > 0) {
      response += static_cast<char>(Serial1.read());
      receivedAnyByte = true;
      lastByteAt = millis();
    }
    while (Serial2.available() > 0) {
      gps.encode(Serial2.read());
    }
    delay(5);
  }

  const int labelAt = response.indexOf("+CGPADDR:");
  const int commaAt = response.indexOf(',', labelAt);
  if (labelAt < 0 || commaAt < 0) return "";

  int endAt = response.indexOf('\n', commaAt);
  if (endAt < 0) endAt = response.length();
  String ip = response.substring(commaAt + 1, endAt);
  ip.trim();
  ip.replace("\"", "");
  return ip;
}

bool hasUsableDataIp() {
  const String ip = getDataIpFromModem();
  return !ip.isEmpty() && ip != "0.0.0.0";
}

// Keep GPS serial data flowing while the cellular network assigns a PDP IP.
// A7670E can take several seconds after APN success before its IP is usable.
void serviceGpsWhileWaiting(unsigned long waitMs) {
  const unsigned long startedAt = millis();
  while (millis() - startedAt < waitMs) {
    while (Serial2.available() > 0) {
      gps.encode(Serial2.read());
    }
    delay(10);
  }
}

bool waitForUsableDataIp(unsigned long timeoutMs) {
  const unsigned long startedAt = millis();
  while (millis() - startedAt < timeoutMs) {
    if (hasUsableDataIp()) return true;
    serviceGpsWhileWaiting(1000);
    Serial.print('.');
  }
  Serial.println();
  return false;
}

void printAtResponse(const char* command, unsigned long timeoutMs = 1800L) {
  while (Serial1.available() > 0) {
    Serial1.read();
  }

  Serial.print("[AT] >> ");
  Serial.println(command);
  Serial1.print(command);
  Serial1.print("\r\n");

  const unsigned long startedAt = millis();
  unsigned long lastByteAt = startedAt;
  bool receivedAnyByte = false;
  while (millis() - startedAt < timeoutMs &&
         (!receivedAnyByte || millis() - lastByteAt < 300L)) {
    while (Serial1.available() > 0) {
      Serial.write(Serial1.read());
      receivedAnyByte = true;
      lastByteAt = millis();
    }
    while (Serial2.available() > 0) {
      gps.encode(Serial2.read());
    }
    delay(5);
  }
  if (!receivedAnyByte) Serial.print("(no response)");
  Serial.println();
}

void dumpDataSessionDiagnostics() {
  Serial.println("[4G] --- Raw data-session diagnostics ---");
  printAtResponse("AT+CPIN?");     // SIM ready / PIN state
  printAtResponse("AT+CGREG?");    // packet-service registration
  printAtResponse("AT+CEREG?");    // LTE EPS registration
  printAtResponse("AT+CGATT?");    // attached to packet service
  printAtResponse("AT+CGDCONT?");  // configured APN context
  printAtResponse("AT+CGACT?");    // PDP context activation
  printAtResponse("AT+CGPADDR=1"); // assigned PDP IP address
  Serial.println("[4G] --- End diagnostics ---");
}

bool openTcpSocket(const char* host, uint16_t port) {
  while (Serial1.available() > 0) {
    Serial1.read();
  }

  const String command = String("AT+CIPOPEN=0,\"TCP\",\"") + host +
                         "\"," + String(port);
  Serial.print("[AT] >> ");
  Serial.println(command);
  Serial1.print(command);
  Serial1.print("\r\n");

  String response;
  const unsigned long startedAt = millis();
  unsigned long lastByteAt = startedAt;
  bool receivedResult = false;
  while (millis() - startedAt < 20000L &&
         (!receivedResult || millis() - lastByteAt < 500L)) {
    while (Serial1.available() > 0) {
      const char c = static_cast<char>(Serial1.read());
      Serial.write(c);
      response += c;
      lastByteAt = millis();
      if (response.indexOf("+CIPOPEN:") >= 0) receivedResult = true;
    }
    while (Serial2.available() > 0) {
      gps.encode(Serial2.read());
    }
    delay(5);
  }
  if (!receivedResult) {
    Serial.println("[AT] TCP open timed out without +CIPOPEN result");
    return false;
  }
  return response.indexOf("+CIPOPEN: 0,0") >= 0;
}

bool ensureSocketServiceOpen() {
  while (Serial1.available() > 0) {
    Serial1.read();
  }
  Serial.println("[AT] >> AT+NETOPEN");
  Serial1.print("AT+NETOPEN\r\n");

  String response;
  const unsigned long startedAt = millis();
  while (millis() - startedAt < 20000L &&
         (response.indexOf("+NETOPEN:") < 0 &&
          response.indexOf("Network is already opened") < 0)) {
    while (Serial1.available() > 0) {
      const char c = static_cast<char>(Serial1.read());
      Serial.write(c);
      response += c;
    }
    while (Serial2.available() > 0) {
      gps.encode(Serial2.read());
    }
    delay(5);
  }

  const bool ready = response.indexOf("+NETOPEN: 0") >= 0 ||
                     response.indexOf("Network is already opened") >= 0;
  if (ready) {
    Serial.println("[4G] ✅ Socket service พร้อมใช้งาน");
  } else {
    Serial.println("[4G] ❌ เปิด Socket service ไม่สำเร็จ");
  }
  return ready;
}

String resolveHostIp(const char* host) {
  while (Serial1.available() > 0) {
    Serial1.read();
  }
  const String command = String("AT+CDNSGIP=\"") + host + "\"";
  Serial.print("[DNS] Resolving ");
  Serial.println(host);
  Serial1.print(command);
  Serial1.print("\r\n");

  String response;
  const unsigned long startedAt = millis();
  unsigned long lastByteAt = startedAt;
  bool receivedResult = false;
  while (millis() - startedAt < 10000L &&
         (!receivedResult || millis() - lastByteAt < 300L)) {
    while (Serial1.available() > 0) {
      const char c = static_cast<char>(Serial1.read());
      Serial.write(c);
      response += c;
      lastByteAt = millis();
      if (response.indexOf("+CDNSGIP:") >= 0) receivedResult = true;
    }
    while (Serial2.available() > 0) {
      gps.encode(Serial2.read());
    }
    delay(5);
  }

  const int resultAt = response.indexOf("+CDNSGIP:");
  const int firstQuote = response.indexOf('"', resultAt);
  const int secondQuote = response.indexOf('"', firstQuote + 1);
  const int thirdQuote = response.indexOf('"', secondQuote + 1);
  const int fourthQuote = response.indexOf('"', thirdQuote + 1);
  if (resultAt < 0 || thirdQuote < 0 || fourthQuote < 0) {
    Serial.println("[DNS] ❌ DNS lookup failed");
    return "";
  }

  const String ip = response.substring(thirdQuote + 1, fourthQuote);
  Serial.println("[DNS] ✅ " + ip);
  return ip;
}

bool connect4G(bool restartModem);

bool sendHttpPostViaA7670(const char* host, const char* path,
                           const String& payload) {
  if (!ensureSocketServiceOpen()) return false;
  String endpoint = resolveHostIp(host);
  if (endpoint.isEmpty()) return false;

  if (!openTcpSocket(endpoint.c_str(), 80)) {
    Serial.println("[HTTP] ⚠️ TCP socket ไม่พร้อม — รีเฟรช Data session แล้วลองอีกครั้ง...");
    modem.gprsDisconnect();
    serviceGpsWhileWaiting(1000);
    isConnected = connect4G(false);
    if (isConnected && !ensureSocketServiceOpen()) return false;
    endpoint = resolveHostIp(host);
    if (!isConnected || endpoint.isEmpty() || !openTcpSocket(endpoint.c_str(), 80)) {
      Serial.println("[HTTP] ❌ A7670E เปิด TCP socket ไม่สำเร็จหลัง retry");
      return false;
    }
  }

  const String request = String("POST ") + path + " HTTP/1.1\r\n" +
      "Host: " + host + "\r\n" +
      "User-Agent: ESP32-GPS\r\n" +
      "Content-Type: application/json\r\n" +
      "X-GPS-Device-Key: " + GPS_DEVICE_KEY + "\r\n" +
      "Content-Length: " + String(payload.length()) + "\r\n" +
      "Connection: close\r\n\r\n" + payload;

  while (Serial1.available() > 0) {
    Serial1.read();
  }
  Serial.print("[AT] >> AT+CIPSEND=0,");
  Serial.println(request.length());
  Serial1.print("AT+CIPSEND=0,");
  Serial1.print(request.length());
  Serial1.print("\r\n");

  String promptResponse;
  const unsigned long promptStartedAt = millis();
  while (millis() - promptStartedAt < 5000L && promptResponse.indexOf('>') < 0) {
    while (Serial1.available() > 0) {
      const char c = static_cast<char>(Serial1.read());
      Serial.write(c);
      promptResponse += c;
    }
    while (Serial2.available() > 0) {
      gps.encode(Serial2.read());
    }
    delay(5);
  }
  if (promptResponse.indexOf('>') < 0) {
    Serial.println("[HTTP] ❌ A7670E ไม่ส่ง prompt สำหรับข้อมูล HTTP");
    printAtResponse("AT+CIPCLOSE=0");
    return false;
  }

  Serial1.print(request);
  Serial1.flush();
  String sendResponse;
  const unsigned long sendStartedAt = millis();
  unsigned long lastByteAt = sendStartedAt;
  while (millis() - sendStartedAt < 15000L &&
         (sendResponse.indexOf("+CIPSEND:") < 0 || millis() - lastByteAt < 300L)) {
    while (Serial1.available() > 0) {
      const char c = static_cast<char>(Serial1.read());
      Serial.write(c);
      sendResponse += c;
      lastByteAt = millis();
    }
    while (Serial2.available() > 0) {
      gps.encode(Serial2.read());
    }
    delay(5);
  }

  // A7670E firmware reports +CIPSEND:<link>,<sent>,<requested>.
  // The send is successful when link 0 reports its byte counts.
  const bool sent = sendResponse.indexOf("+CIPSEND: 0,") >= 0;
  Serial.println(sent
    ? "[HTTP] ✅ ส่งพิกัดเข้า API สำเร็จ"
    : "[HTTP] ❌ A7670E ส่งข้อมูล TCP ไม่สำเร็จ");
  // API returns 204 and Connection: close; the modem reports +IPCLOSE itself.
  // Avoid CIPCLOSE after that server-initiated close, which only creates noise.
  if (!sent && sendResponse.indexOf("+IPCLOSE:") < 0) {
    printAtResponse("AT+CIPCLOSE=0");
  }
  Serial.println();
  return sent;
}

#endif

// ------------------------------------------------------------------
// 📡 ฟังก์ชัน: เชื่อมต่อ 4G (เรียกตอน setup และตอน reconnect)
// ------------------------------------------------------------------
#ifdef USE_4G
bool connect4G(bool restartModem) {
  if (restartModem) {
    lastModemStartAttempt = millis();
    Serial.println("[4G] กำลัง Restart โมดูล A7670E...");
    if (!modem.restart()) {
      modemIsResponsive = false;
      Serial.println("[4G] ❌ โมเด็มไม่ตอบสนอง");
      Serial.println("[4G]    หยุดลองต่อเครือข่ายชั่วคราว; ตรวจ VCC=5V, GND ร่วม, PWR_EN และ TX/RX");
      return false;
    }
    modemIsResponsive = true;
  }

  Serial.print("[4G] IMEI: ");
  Serial.println(modem.getIMEI());

  Serial.println("[4G] กำลังลงทะเบียนเครือข่าย...");
  if (!modem.waitForNetwork(60000L)) {
    Serial.println("[4G] ❌ ไม่พบเครือข่ายภายใน 60 วินาที");
    return false;
  }

  Serial.print("[4G] สัญญาณ: ");
  Serial.println(modem.getSignalQuality());
  Serial.print("[4G] กำลังเชื่อมต่อ APN: ");
  Serial.println(APN);

  if (!modem.gprsConnect(APN, "", "")) {
    Serial.println("[4G] ❌ เชื่อมต่อ GPRS ล้มเหลว!");
    return false;
  }

  // AIS may acknowledge APN before assigning a usable PDP IP. Wait first;
  // disconnecting immediately can make the session flap indefinitely.
  Serial.print("[4G] รอรับ Data IP สูงสุด 15 วินาที ");
  if (!waitForUsableDataIp(15000L)) {
    Serial.println("[4G] ⚠️ APN ต่อได้ แต่ยังไม่ได้ IP จริง — กำลังต่อใหม่...");
    modem.gprsDisconnect();
    serviceGpsWhileWaiting(2000);
    if (!modem.gprsConnect(APN, "", "")) {
      Serial.println("[4G] ❌ ต่อ APN ซ้ำไม่สำเร็จ");
      return false;
    }
    Serial.print("[4G] รอรับ Data IP รอบสุดท้าย ");
  }

  if (!hasUsableDataIp() && !waitForUsableDataIp(15000L)) {
    Serial.println("[4G] ❌ ยังไม่ได้ IP จากเครือข่าย (0.0.0.0)");
    dumpDataSessionDiagnostics();
    return false;
  }

  // Confirm that the PDP session remains alive before sending data.
  Serial.println("[4G] ได้ IP แล้ว — รอให้ Data session นิ่ง 2 วินาที...");
  serviceGpsWhileWaiting(2000);
  if (!hasUsableDataIp()) {
    Serial.println("[4G] ⚠️ IP หลุดระหว่างรอความนิ่ง");
    return false;
  }

  Serial.println("[4G] ✅ เชื่อมต่อ 4G สำเร็จ!");
  Serial.print("[4G] IP Address: ");
  Serial.println(getDataIpFromModem());
  return true;
}

bool ensure4GConnection() {
  if (!modemIsResponsive) {
    if (millis() - lastModemStartAttempt < MODEM_RETRY_INTERVAL_MS) {
      return false;
    }
    Serial.println("[4G] ลองปลุกโมเด็มใหม่หลังรอ 30 วินาที...");
    isConnected = connect4G(true);
    return isConnected;
  }

  if (!modem.isGprsConnected() || !hasUsableDataIp()) {
    Serial.println("[4G] ⚠️ GPRS หลุด! กำลัง Reconnect...");
    isConnected = connect4G(false);
  }
  return isConnected;
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
  if (!ensure4GConnection()) return;

  // Temporary compatibility path: A7670E cannot complete TLS negotiation
  // with this Cloudflare edge. The API still requires GPS_DEVICE_KEY.
  const char* host = "api.namecheap.work";
  const char* path = "/api/v1/gps";

  sendHttpPostViaA7670(host, path, payload);

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
    Serial.println("[HTTP] Response: " + http.getString());
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
  isConnected = connect4G(true);
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
