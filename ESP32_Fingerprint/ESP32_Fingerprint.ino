// ============================================================
// S.Mart POS - ESP32 Fingerprint Reader Firmware (WiFi Version)
// เวอร์ชัน 3.1 - Full Enrollment + WiFi TCP Socket
// ============================================================
//
// 📌 การต่อสาย (ESP32 30-pin + R307S):
//   R307S VCC  →  ESP32 3.3V
//   R307S GND  →  ESP32 GND
//   R307S TX   →  ESP32 GPIO 16 (RX2)
//   R307S RX   →  ESP32 GPIO 17 (TX2)
//   Buzzer +   →  ESP32 GPIO 18
//   Buzzer -   →  ESP32 GND
//
// 📌 Protocol คุยกับ POS (ผ่าน WiFi TCP Port 8080):
//   POS  → ESP32:  ENROLL:<baseSlot>:<name>\n
//   POS  → ESP32:  ENROLL_CANCEL\n
//   ESP32 → POS:   MATCH_ID:<slotId>
//   ESP32 → POS:   ENROLL_STEP:<step(1-10)>:<message>
//   ESP32 → POS:   ENROLL_OK:<baseSlot>
//   ESP32 → POS:   ENROLL_FAIL:<baseSlot>
//   ESP32 → POS:   ALERT:<message>
// ============================================================

#include <Adafruit_Fingerprint.h>
#include <Preferences.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <ESPmDNS.h>

// ---------------------------------------------------------------------------
// Network Config
// ---------------------------------------------------------------------------
const char* ssid = "Kankanda_2.4G";
const char* password = "0318066064";

WiFiServer server(8080);
WiFiClient client;

#define BUZZER_PIN 18  // ขาสำหรับต่อ Buzzer
#define TOUCH_PIN  4   // สายสีน้ำเงิน (Touch/Wake) ต่อกับขา D4

// ---------------------------------------------------------------------------
// Serial Ports
// ---------------------------------------------------------------------------
HardwareSerial fingerSerial(2);  // UART2: RX=GPIO16, TX=GPIO17
Adafruit_Fingerprint finger = Adafruit_Fingerprint(&fingerSerial);
Preferences prefs;               // Flash สำหรับบันทึกชื่อพนักงาน

// ---------------------------------------------------------------------------
// State Machine
// ---------------------------------------------------------------------------
enum Mode { MODE_SCAN, MODE_ENROLL };

Mode currentMode  = MODE_SCAN;
int  enrollBase   = -1;    // baseSlot จาก POS
char enrollName[64] = "";  // ชื่อพนักงาน

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(TOUCH_PIN, INPUT_PULLUP); // ตั้งเป็น Input แบบ PULLUP สำหรับวงจร Active LOW

  // ลองพยายามเชื่อมต่อเซนเซอร์ลายนิ้วมือ
  fingerSerial.begin(57600, SERIAL_8N1, 16, 17);
  delay(200);

  // ตั้งค่าพิน Buzzer
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  Serial.println("\n\n--- Fingerprint System Initializing ---");

  finger.begin(57600);
  if (finger.verifyPassword()) {
    Serial.println("-> Fingerprint sensor ready.");
  } else {
    Serial.println("ALERT:ไม่พบเครื่องสแกนลายนิ้วมือ กรุณาตรวจสอบการต่อสาย");
    while (true) delay(1000);
  }

  prefs.begin("fp_names", false);
  
  // ------------------------------------------------
  // ตั้งค่า WiFi
  // ------------------------------------------------
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  // เริ่ม mDNS
  if (!MDNS.begin("fingerprint")) {
    Serial.println("Error setting up MDNS responder!");
  } else {
    Serial.println("mDNS responder started (fingerprint.local)");
    MDNS.addService("fingerprint", "tcp", 8080);
  }

  // เริ่มต้นเซิร์ฟเวอร์
  server.begin();
  Serial.println("-> TCP Server started on port 8080");
  Serial.println("-> System v3.1 (WiFi) ready.");
}

WiFiUDP udp;
unsigned long lastUdpBroadcast = 0;

// ---------------------------------------------------------------------------
// Main Loop
// ---------------------------------------------------------------------------
void loop() {
  if (WiFi.status() == WL_CONNECTED && millis() - lastUdpBroadcast > 3000) {
    lastUdpBroadcast = millis();
    udp.beginPacket(IPAddress(255, 255, 255, 255), 8081);
    udp.print("SMART_POS_FINGERPRINT_HERE");
    udp.endPacket();
  }

  // จัดการการเชื่อมต่อของ Client
  if (!client.connected()) {
    WiFiClient newClient = server.available();
    if (newClient) {
      client = newClient;
      Serial.println("-> POS Connected via WiFi!");
    }
  }

  // รับคำสั่งผ่าน Serial Monitor (พิมพ์ 'delete' เพื่อล้างข้อมูล)
  if (Serial.available()) {
    String pccmd = Serial.readStringUntil('\n');
    pccmd.trim();
    if (pccmd.equalsIgnoreCase("delete")) {
      Serial.println("\n----------------------------------");
      Serial.println("⚠️ กำลังล้างฐานข้อมูลลายนิ้วมือทั้งหมด...");
      finger.emptyDatabase();
      prefs.clear(); // ล้างชื่อพนักงานที่ผูกไว้ทั้งหมดด้วย
      Serial.println("✅ สำเร็จ! ล้างฐานข้อมูลและรายชื่อเรียบร้อยแล้ว");
      Serial.println("----------------------------------\n");
      triggerBeep(4); // เสียงปี๊บยาวแจ้งเตือนว่าสำเร็จ
    }
  }

  // รับคำสั่งผ่าน WiFi แทน USB Serial
  checkNetworkCommand();

  if (currentMode == MODE_SCAN) {
    doScanMode();
  } else if (currentMode == MODE_ENROLL) {
    doEnrollMode();
    // doEnrollMode() จะเรียก resetToScan() เองเมื่อเสร็จ
  }
}

// ---------------------------------------------------------------------------
// ส่งข้อมูลกลับ POS ผ่าน WiFi
// ---------------------------------------------------------------------------
void sendToPOS(String message) {
  // ส่งออก Serial Monitor เพื่อเช็คด้วย
  Serial.println(message);
  
  // ส่งเข้า POS ผ่าน Socket
  if (client.connected()) {
    client.println(message);
  }
}

// ---------------------------------------------------------------------------
// รับคำสั่งจาก POS (ผ่าน WiFi)
// ---------------------------------------------------------------------------
void checkNetworkCommand() {
  if (!client.connected() || !client.available()) return;

  String cmd = client.readStringUntil('\n');
  cmd.trim();
  if (cmd.isEmpty()) return;

  Serial.print("-> CMD: ");
  Serial.println(cmd);

  if (cmd == "ENROLL_CANCEL") {
    resetToScan();
    sendToPOS("-> Cancelled. Back to scan mode.");
    return;
  }

  if (cmd.startsWith("ENROLL:")) {
    String payload = cmd.substring(7);
    int colon = payload.indexOf(':');
    if (colon < 0) {
      sendToPOS("ALERT:Format ผิด ต้องการ ENROLL:baseSlot:name");
      return;
    }

    int base = payload.substring(0, colon).toInt();
    if (base < 1 || base > 124) {
      sendToPOS("ALERT:Base Slot ต้องอยู่ระหว่าง 1-124");
      return;
    }

    String name = payload.substring(colon + 1);
    name.trim();
    name.toCharArray(enrollName, sizeof(enrollName));
    enrollBase = base;
    currentMode = MODE_ENROLL;

    Serial.print("-> Enroll starting: base=");
    Serial.print(enrollBase);
    Serial.print(" name=");
    Serial.println(enrollName);
    return;
  }
}

// ---------------------------------------------------------------------------
// โหมดสแกนปกติ
// ---------------------------------------------------------------------------
void doScanMode() {
  // 💤 ตรวจสอบสาย Touch แบบกลับขั้ว (Active LOW: ตอนไม่แตะ=HIGH, ตอนแตะ=LOW)
  if (digitalRead(TOUCH_PIN) == HIGH) {
    return; // ไม่มีคนแตะ ให้ข้ามการสั่งงานไปเลย (เข้าโหมด Sleep)
  }

  uint8_t p = finger.getImage();
  if (p != FINGERPRINT_OK) return;

  // ⚠️ ป้องกันการสแกนทิ้งเปล่า: ถ้าพนักงานมาสแกนตอน POS ปิดอยู่ ให้ร้องเตือนว่า Error
  if (!client.connected()) {
    triggerBeep(2); // ร้อง 2 ปี๊บสั้น (Error)
    delay(2000); // รอให้เอานิ้วออก
    return;
  }

  p = finger.image2Tz();
  if (p != FINGERPRINT_OK) return;

  p = finger.fingerSearch();
  if (p == FINGERPRINT_OK) {
    int matchedId = finger.fingerID;

    // ดึงชื่อถ้ามี
    String key = "s" + String(matchedId);
    String name = prefs.getString(key.c_str(), "");

    // ส่งให้ POS ผ่าน WiFi
    sendToPOS("MATCH_ID:" + String(matchedId));

    if (name.length() > 0) {
      Serial.print("-> MATCH_NAME:");
      Serial.println(name);
    }

    triggerBeep(1); // สแกนผ่าน (1 ปี๊บสั้น)
    delay(2000); // ป้องกันสแกนซ้ำเร็วเกินไป

  } else if (p == FINGERPRINT_NOTFOUND) {
    sendToPOS("ALERT:ไม่พบลายนิ้วมือนี้ในระบบ");
    triggerBeep(2); // สแกนไม่ผ่าน (2 ปี๊บสั้น)
    delay(1000);
  }
}

// ---------------------------------------------------------------------------
// โหมดลงทะเบียน (2 นิ้ว × 3 รอบ = 2 Slots)
// ---------------------------------------------------------------------------
void doEnrollMode() {
  int base = enrollBase;

  sendStep(1, "วางนิ้วชี้มือขวา ครั้งที่ 1/3");
  if (!captureAndStore(1)) { return sendEnrollFail(); }
  liftFinger();

  sendStep(2, "วางนิ้วชี้มือขวา ครั้งที่ 2/3");
  if (!captureAndCreateModel(2, base + 0)) { return sendEnrollFail(); }
  liftFinger();

  sendStep(3, "วางนิ้วชี้มือขวา ครั้งที่ 3/3 (ยืนยัน)");
  if (!verifyFinger()) { return sendEnrollFail(); }
  liftFinger();

  Serial.println("-> นิ้วชี้มือขวา: บันทึกสำเร็จ ✅");
  delay(1500);

  sendStep(4, "เปลี่ยนมือ: วางนิ้วชี้มือซ้าย ครั้งที่ 1/3");
  if (!captureAndStore(1)) { return sendEnrollFail(); }
  liftFinger();

  sendStep(5, "วางนิ้วชี้มือซ้าย ครั้งที่ 2/3");
  if (!captureAndCreateModel(2, base + 1)) { return sendEnrollFail(); }
  liftFinger();

  sendStep(6, "วางนิ้วชี้มือซ้าย ครั้งที่ 3/3 (ยืนยัน)");
  if (!verifyFinger()) { return sendEnrollFail(); }
  liftFinger();

  // บันทึกชื่อลง Flash
  for (int i = 0; i < 2; i++) {
    String key = "s" + String(base + i);
    prefs.putString(key.c_str(), String(enrollName));
  }

  // แจ้ง POS ว่าสำเร็จ
  sendToPOS("ENROLL_OK:" + String(base));
  
  Serial.print("-> ✅ ลงทะเบียนสำเร็จ: ");
  Serial.print(enrollName);
  Serial.println(" (Slots " + String(base) + "–" + String(base + 1) + ")");

  triggerBeep(4); // ลงทะเบียนสำเร็จ (1 ปี๊บยาว)
  resetToScan();
}

// ---------------------------------------------------------------------------
// Helpers: Capture & Model
// ---------------------------------------------------------------------------

bool captureAndStore(uint8_t bufferSlot) {
  uint8_t p = waitForFinger();
  if (p != FINGERPRINT_OK) return false;

  p = finger.image2Tz(bufferSlot);
  if (p != FINGERPRINT_OK) {
    sendToPOS("ALERT:ภาพนิ้วไม่ชัด กรุณาวางนิ้วใหม่อีกครั้ง");
    triggerBeep(2);
    return false;
  }
  triggerBeep(3);
  return true;
}

bool captureAndCreateModel(uint8_t bufferSlot, int targetSlot) {
  int retryCount = 0;
  while (retryCount < 5) {
    if (!captureAndStore(bufferSlot)) return false;

    uint8_t p = finger.createModel();
    if (p == FINGERPRINT_OK) {
      p = finger.storeModel(targetSlot);
      if (p != FINGERPRINT_OK) {
        sendToPOS("ALERT:บันทึก Slot #" + String(targetSlot) + " ล้มเหลว");
        triggerBeep(2);
        return false;
      }
      Serial.println("-> บันทึก Slot #" + String(targetSlot) + " สำเร็จ");
      triggerBeep(3);
      return true;
    }

    // ลายนิ้วมือ 2 ครั้งไม่ตรงกัน ให้ลองใหม่โดยไม่ต้องเริ่มจาก 1 ใหม่
    sendToPOS("ALERT:ลายนิ้วมือขยับเยอะไป วางนิ้วเดิมแก้ตัวอีกครั้งครับ");
    triggerBeep(2);
    liftFinger(); // รอยกนิ้วก่อนสแกนแก้ตัว
    retryCount++;
  }
  
  sendToPOS("ALERT:ลายนิ้วมือไม่ตรงกันหลายครั้งเกินไป ยกเลิกการบันทึก");
  return false;
}

bool verifyFinger() {
  uint8_t p = waitForFinger();
  if (p != FINGERPRINT_OK) return false;
  Serial.println("-> ยืนยันคุณภาพสำเร็จ ✅");
  triggerBeep(3);
  return true;
}

// ---------------------------------------------------------------------------
// Helpers: Timing & Flow
// ---------------------------------------------------------------------------

void sendStep(int step, const char* message) {
  sendToPOS("ENROLL_STEP:" + String(step) + ":" + String(message));
}

uint8_t waitForFinger() {
  unsigned long start = millis();
  while (millis() - start < 15000) {
    // เช็ค CANCEL ผ่าน WiFi
    if (client.connected() && client.available()) {
      String cmd = client.readStringUntil('\n');
      cmd.trim();
      if (cmd == "ENROLL_CANCEL") {
        resetToScan();
        Serial.println("-> Cancelled by POS.");
        return FINGERPRINT_PACKETRECIEVEERR;
      }
    }

    uint8_t p = finger.getImage();
    if (p == FINGERPRINT_OK) return FINGERPRINT_OK;
    delay(50);
  }

  sendToPOS("ALERT:Timeout รอนานเกินไป ยกเลิกการลงทะเบียนอัตโนมัติ");
  return FINGERPRINT_TIMEOUT;
}

void liftFinger() {
  delay(500);
  while (finger.getImage() != FINGERPRINT_NOFINGER) {
    delay(100);
  }
  delay(300);
}

void sendEnrollFail() {
  sendToPOS("ENROLL_FAIL:" + String(enrollBase));
  Serial.println("-> ❌ Enrollment failed. Back to scan mode.");
  triggerBeep(5);
  resetToScan();
}

void resetToScan() {
  currentMode = MODE_SCAN;
  enrollBase  = -1;
  memset(enrollName, 0, sizeof(enrollName));
}

// ---------------------------------------------------------------------------
// Helpers: Buzzer
// ---------------------------------------------------------------------------
void triggerBeep(int type) {
  // type 1, 3, 4 = สำเร็จ (1 ปี๊บ ยาวและดังชัดเจน 300ms)
  if (type == 1 || type == 3 || type == 4) { 
    tone(BUZZER_PIN, 2500); // ความถี่ 2500Hz ปกติจะดังที่สุดสำหรับ Buzzer ตัวเล็ก
    delay(300);
    noTone(BUZZER_PIN);
  } 
  // type 2, 5 = ไม่สำเร็จ / แจ้งเตือน (2 ปี๊บสั้น)
  else if (type == 2 || type == 5) { 
    for (int i = 0; i < 2; i++) {
      tone(BUZZER_PIN, 2500);
      delay(150);
      noTone(BUZZER_PIN);
      delay(100);
    }
  }
}