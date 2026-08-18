// GPS + Wi-Fi bench test only. No 4G/A7670E code is used here.
// Install: TinyGPSPlus, ArduinoJson. ESP32 board package is required.

#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <TinyGPSPlus.h>
#include <ArduinoJson.h>
#include "gps_wifi_test_secrets.h"

// Credentials and endpoint live only in the ignored local header above.
const unsigned long SEND_INTERVAL_MS = 5000;
const unsigned long MAX_GPS_FIX_AGE_MS = 5000;
const uint32_t MIN_GPS_SATELLITES = 4;
const double MAX_GPS_HDOP = 3.5;

// NEO-M8N UART2: GPS TX -> ESP32 GPIO16, GPS RX -> ESP32 GPIO17.
#define GPS_RX_PIN 16
#define GPS_TX_PIN 17
#define GPS_BAUD 9600

TinyGPSPlus gps;
unsigned long lastSendTime = 0;
unsigned long lastNoDataWarning = 0;

bool connectWifi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("[WiFi] Connecting");
  const unsigned long startedAt = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startedAt < 20000) {
    delay(500);
    Serial.print('.');
  }
  Serial.println();
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[ASSERT][WiFi] FAIL: check SSID, password, and 2.4 GHz signal");
    return false;
  }
  Serial.print("[ASSERT][WiFi] PASS: connected, IP=");
  Serial.println(WiFi.localIP());
  return true;
}

bool sendGpsData(double lat, double lng, double speed) {
  if (WiFi.status() != WL_CONNECTED && !connectWifi()) return false;

  StaticJsonDocument<200> document;
  document["lat"] = lat;
  document["lng"] = lng;
  document["speed"] = speed;
  document["vehicle"] = VEHICLE_NAME;
  String payload;
  serializeJson(document, payload);

  WiFiClientSecure client;
  // TEST ONLY: this bench sketch intentionally skips certificate validation.
  // Production firmware must use a pinned CA certificate instead.
  client.setInsecure();
  HTTPClient http;
  http.setTimeout(5000);
  if (!http.begin(client, SERVER_URL)) {
    Serial.println("[WiFi] FAILED: invalid SERVER_URL");
    return false;
  }
  http.addHeader("User-Agent", "Mozilla/5.0 (ESP32-GPS)");
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-GPS-Device-Key", GPS_DEVICE_KEY);
  const int httpCode = http.POST(payload);
  const bool success = httpCode >= 200 && httpCode < 300;
  Serial.print(success ? "[ASSERT][HTTP] PASS: " : "[ASSERT][HTTP] FAIL: ");
  Serial.println(httpCode);
  if (!success) {
    Serial.print("[WiFi] Server response: ");
    Serial.println(http.getString());
  }
  http.end();
  return success;
}

bool hasFreshGpsFix() {
  const uint32_t age = gps.location.age();
  const uint32_t satellites = gps.satellites.isValid() ? gps.satellites.value() : 0;
  const double hdop = gps.hdop.isValid() ? gps.hdop.hdop() : -1.0;
  const bool fresh = gps.location.isValid() && age != TinyGPSPlus::GPS_INVALID_AGE &&
      age <= MAX_GPS_FIX_AGE_MS;
  const bool enoughSatellites = satellites >= MIN_GPS_SATELLITES;
  const bool acceptableHdop = hdop < 0 || hdop <= MAX_GPS_HDOP;

  Serial.printf(
      "[GPS] age=%lums satellites=%lu hdop=%.2f\n",
      static_cast<unsigned long>(age), static_cast<unsigned long>(satellites), hdop);
  if (!fresh || !enoughSatellites || !acceptableHdop) {
    Serial.println("[ASSERT][GPS] FAIL: need a fresh fix, enough satellites, and acceptable HDOP");
    return false;
  }
  Serial.println("[ASSERT][GPS] PASS: fresh, usable location fix");
  return true;
}

void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println("\n=== GPS + Wi-Fi bench test (no 4G/A7670E) ===");
  Serial2.setRxBufferSize(1024);
  Serial2.begin(GPS_BAUD, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
  connectWifi();
  Serial.println("[GPS] Waiting for a satellite fix; test outdoors with antenna facing sky.");
}

void loop() {
  while (Serial2.available()) gps.encode(Serial2.read());

  if (millis() - lastSendTime >= SEND_INTERVAL_MS) {
    lastSendTime = millis();
    if (hasFreshGpsFix()) {
      const double speed = gps.speed.isValid() ? gps.speed.kmph() : 0.0;
      Serial.printf("[GPS] lat=%.6f lng=%.6f speed=%.1f km/h\n",
                    gps.location.lat(), gps.location.lng(), speed);
      sendGpsData(gps.location.lat(), gps.location.lng(), speed);
    } else {
      Serial.println("[GPS] Waiting for a fresh, usable location...");
    }
  }

  if (millis() > 20000 && gps.charsProcessed() < 10 && millis() - lastNoDataWarning > 8000) {
    lastNoDataWarning = millis();
    Serial.println("[GPS] No serial data: verify GPS TX -> GPIO16, shared GND, and GPS power.");
  }
}
