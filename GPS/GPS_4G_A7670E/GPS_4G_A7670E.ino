// A7670E / 4G network test. GPS hardware is deliberately not used here.
// Install: TinyGSM, ArduinoHttpClient, ArduinoJson.

#define TINY_GSM_MODEM_A7672X
#define TINY_GSM_RX_BUFFER 1024
#include <TinyGsmClient.h>
#include <ArduinoHttpClient.h>
#include <ArduinoJson.h>

// Local deployment configuration. Do not commit credentials to a shared repo.
const char* APN = "internet";
const char* SERVER_HOST = "api.namecheap.work";
const char* SERVER_PATH = "/api/v1/gps";
const char* GPS_DEVICE_KEY = "s-mart-gps-a7670e-2026";
const char* VEHICLE_NAME = "รถเครน";
// Keep false while checking only modem/network. True posts a test point (0,0).
const bool SEND_API_TEST = false;

// A7670E TX -> ESP32 GPIO26, A7670E RX -> ESP32 GPIO25; common GND required.
#define GSM_RX_PIN 26
#define GSM_TX_PIN 25
#define GSM_BAUD 115200

TinyGsm modem(Serial1);
TinyGsmClientSecure gsmClient(modem);

bool hasUsableDataIp() {
  const String ip = modem.localIP().toString();
  return !ip.isEmpty() && ip != "0.0.0.0";
}

bool connect4G(bool restartModem) {
  if (restartModem) {
    Serial.println("[4G] Restarting A7670E...");
    if (!modem.restart()) {
      Serial.println("[4G] MODEM NO RESPONSE: check module power, PWRKEY/PWR_EN, UART TX/RX, and common GND.");
      return false;
    }
  }
  Serial.print("[4G] IMEI: "); Serial.println(modem.getIMEI());
  Serial.println("[4G] Registering on network...");
  if (!modem.waitForNetwork(60000L)) {
    Serial.println("[4G] NETWORK NOT FOUND within 60 seconds.");
    return false;
  }
  Serial.print("[4G] Signal quality: "); Serial.println(modem.getSignalQuality());
  if (!modem.gprsConnect(APN, "", "")) {
    Serial.println("[4G] PDP/APN connection failed.");
    return false;
  }
  delay(1000);
  if (!hasUsableDataIp()) {
    Serial.println("[4G] APN connected but IP is 0.0.0.0; reconnecting PDP...");
    modem.gprsDisconnect();
    delay(500);
    if (!modem.gprsConnect(APN, "", "")) return false;
    delay(1000);
  }
  if (!hasUsableDataIp()) {
    Serial.println("[4G] NO USABLE DATA IP after reconnect.");
    return false;
  }
  Serial.print("[4G] Connected. IP: "); Serial.println(modem.localIP());
  return true;
}

void postNetworkTest() {
  if ((!modem.isGprsConnected() || !hasUsableDataIp()) &&
      !connect4G(false)) return;
  StaticJsonDocument<200> document;
  document["lat"] = 0.0; // Deliberate test payload; no GPS required.
  document["lng"] = 0.0;
  document["speed"] = 0.0;
  document["vehicle"] = VEHICLE_NAME;
  document["test"] = true;
  String payload;
  serializeJson(document, payload);

  HttpClient http(gsmClient, SERVER_HOST, 443);
  http.setHttpResponseTimeout(10000);
  http.beginRequest();
  const int err = http.post(SERVER_PATH);
  http.sendHeader("User-Agent", "Mozilla/5.0 (ESP32-GPS)");
  http.sendHeader("Content-Type", "application/json");
  http.sendHeader("X-GPS-Device-Key", GPS_DEVICE_KEY);
  http.sendHeader("Content-Length", payload.length());
  http.beginBody(); http.print(payload); http.endRequest();
  if (err == 0) {
    const int status = http.responseStatusCode();
    Serial.print(status >= 200 && status < 300 ? "[4G] HTTP OK: " : "[4G] HTTP FAILED: ");
    Serial.println(status);
    http.responseBody();
  } else {
    Serial.print("[4G] HTTP transport error: "); Serial.println(err);
  }
  http.stop();
}

void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println("\n=== A7670E + 4G test (GPS disconnected) ===");
  Serial1.begin(GSM_BAUD, SERIAL_8N1, GSM_RX_PIN, GSM_TX_PIN);
  delay(1000);
  
  bool isConnected = connect4G(true);
  if (isConnected) {
    Serial.println("[4G] SUCCESS: Modem is ALIVE and connected to the Internet!");
    if (SEND_API_TEST) {
      postNetworkTest();
    }
  } else {
    Serial.println("[4G] ERROR: Modem test failed.");
  }
  
  Serial.println("\n--- ENTERING RAW AT COMMAND MODE ---");
  Serial.println("Type 'AT' in the Serial Monitor (with Both NL & CR) and press Enter.");
  Serial.println("If the modem is alive, it will reply with 'OK'.");
}

void loop() {
  // Pass-through mode: route anything typed in Serial Monitor directly to the 4G module
  if (Serial.available()) {
    Serial1.write(Serial.read());
  }
  // Route any response from the 4G module directly to the Serial Monitor
  if (Serial1.available()) {
    Serial.write(Serial1.read());
  }
}
