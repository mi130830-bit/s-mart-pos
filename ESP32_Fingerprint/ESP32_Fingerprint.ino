// ============================================================
// S.Mart POS - ESP32 Fingerprint Reader Firmware (WiFi Version)
// เวอร์ชัน 4.1 - อัปเดตฮาร์ดแวร์ล่าสุด
// ============================================================
// 📌 ดูแผนผังการต่อสายไฟ (Wiring Diagram) ได้ที่ไฟล์:
//    => HARDWARE.md
// ============================================================

#include <Adafruit_Fingerprint.h>
#include <Preferences.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <ESPmDNS.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// ---------------------------------------------------------------------------
// Network Config
// ---------------------------------------------------------------------------
const char* ssid     = "Kankanda_2.4G";
const char* password = "0318066064";

WiFiServer server(8080);
WiFiClient client;
WiFiUDP    udp;
unsigned long lastUdpBroadcast = 0;
unsigned long lastWifiCheck    = 0;

// ---------------------------------------------------------------------------
// Pin Definitions
// ---------------------------------------------------------------------------
#define BUZZER_PIN  18   // GPIO 18 (D18) - สลับตามการต่อสายจริงลงกล่อง

// ⚠️ ตั้งค่าตามประเภท Buzzer Module:
//   true  = Active HIGH  (ดังเมื่อ I/O = HIGH) — พบบ่อยที่สุด
//   false = Active LOW   (ดังเมื่อ I/O = LOW)  — บางรุ่นมีวงจร invert ในตัว
#define BUZZER_ACTIVE_HIGH false

// Macro ON/OFF ของ Buzzer
#define BUZZ_ON   (BUZZER_ACTIVE_HIGH ? HIGH : LOW)
#define BUZZ_OFF  (BUZZER_ACTIVE_HIGH ? LOW  : HIGH)
#define TOUCH_PIN    4  // GPIO 4  (D4)  - ย้ายตามบอร์ดจริง (Active Low)
#define BUTTON_PIN  33  // GPIO 33 (D33) - สลับตามการต่อสายจริงลงกล่อง
#define BUTTON_ACTIVE_HIGH true // เปลี่ยนเป็น true หากโมดูลปุ่มกดส่งไฟ HIGH ออกมาตอนกด

// ---------------------------------------------------------------------------
// Touch Debounce Config
// ---------------------------------------------------------------------------
#define TOUCH_DEBOUNCE_COUNT 3
#define TOUCH_DEBOUNCE_MS    5

// ---------------------------------------------------------------------------
// Button Double-Click Config
// ---------------------------------------------------------------------------
#define BTN_DEBOUNCE_MS     50   // กรอง noise ปุ่ม
#define BTN_DOUBLE_CLICK_MS 500  // ช่วงเวลาสูงสุดระหว่างการกด 2 ครั้งที่จะถือว่า Double Click

// ---------------------------------------------------------------------------
// LCD Config (20 ตัวอักษร × 4 บรรทัด)
// ---------------------------------------------------------------------------
#define LCD_ADDR  0x27  // I2C Address เริ่มต้น (ถ้าจอยังไม่ขึ้น ระบบจะลอง 0x3F อัตโนมัติ)
#define LCD_COLS  20
#define LCD_ROWS   4

// lcd จะถูก init ใน setup() หลัง auto-detect I2C address (0x27 หรือ 0x3F)
LiquidCrystal_I2C lcd(LCD_ADDR, LCD_COLS, LCD_ROWS);

// ---------------------------------------------------------------------------
// Serial / Fingerprint
// ---------------------------------------------------------------------------
HardwareSerial fingerSerial(2);  // UART2: RX=GPIO16, TX=GPIO17
Adafruit_Fingerprint finger = Adafruit_Fingerprint(&fingerSerial);
Preferences prefs;               // Flash สำหรับบันทึกชื่อพนักงาน

// ---------------------------------------------------------------------------
// State Machine
// ---------------------------------------------------------------------------
enum Mode { MODE_SCAN, MODE_ENROLL, MODE_BREAK_SCAN };

Mode currentMode  = MODE_SCAN;
int  enrollBase   = -1;
char enrollName[64] = "";

// สำหรับ Break mode: บันทึก ID ล่าสุดที่สแกนได้
int  lastScannedId = -1;
bool sensorReady   = false;  // ตรวจสอบว่าเชื่อมต่อเซนเซอร์ลายนิ้วมือสำเร็จหรือไม่

// ---------------------------------------------------------------------------
// Button State
// ---------------------------------------------------------------------------
bool     btnLastState     = (BUTTON_ACTIVE_HIGH ? LOW : HIGH);
uint8_t  btnClickCount    = 0;
unsigned long btnFirstClickTime = 0;
unsigned long btnDebounceTime   = 0;

// ---------------------------------------------------------------------------
// Cooldown
// ---------------------------------------------------------------------------
unsigned long lastNoPosBeepTime = 0;

// ---------------------------------------------------------------------------
// Forward Declarations
// ---------------------------------------------------------------------------
void triggerBeep(int type);
bool isTouchDetected();
void connectWiFi();
void sendToPOS(String message);
void sendStep(int step, String message);
void resetToScan();
void sendEnrollFail();
void lcdClear();
void lcdPrint(uint8_t row, String text);
void lcdStatus(String line1, String line2 = "", String line3 = "", String line4 = "");
void handleButton();
void doBreakScanMode();

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);

  // Buzzer — ปิดให้แน่ใจตั้งแต่เริ่มต้น (รองรับทั้ง Active HIGH  // Buzzer Pin — Default OFF
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, BUZZ_OFF);
  Serial.println("[BUZZER] Setup: Forced OFF on boot."); 

  // Touch Pin — R307S ส่ง LOW เมื่อมีนิ้วแตะ, HIGH เมื่อไม่มีนิ้ว (Active Low)
  pinMode(TOUCH_PIN, INPUT_PULLUP);

  // Button Pin — โมดูลแบบ 3 ขา ถ้ารองรับ Active High ให้ใช้ PULLDOWN
  if (BUTTON_ACTIVE_HIGH) {
    pinMode(BUTTON_PIN, INPUT_PULLDOWN);
  } else {
    pinMode(BUTTON_PIN, INPUT_PULLUP);
  }

  Serial.println("\n\n--- S.Mart Fingerprint v4.1 (Pin 33 Test) ---");

  // LCD Init — เปิดการทำงานแล้ว
  Wire.begin(21, 22);  // SDA=GPIO21, SCL=GPIO22 (พอร์ตมาตรฐาน I2C ของ ESP32)
  delay(100);
  randomSeed(analogRead(34)); // ตั้งค่า seed สำหรับสุ่มคำกวนๆ

  // Auto-detect I2C address
  Wire.beginTransmission(0x27);
  uint8_t i2cErr = Wire.endTransmission();
  uint8_t lcdAddr = (i2cErr == 0) ? 0x27 : 0x3F;
  Serial.print("-> LCD I2C Address: 0x");
  Serial.println(lcdAddr, HEX);
  lcd = LiquidCrystal_I2C(lcdAddr, LCD_COLS, LCD_ROWS);

  lcd.init();
  lcd.backlight();
  lcdStatus("S.Mart POS v4.0", "System Starting...");
  
  Serial.println("-> LCD: Initialized.");

  // ---------------------------------------------------------------------------
  // Fingerprint Sensor — ตรวจหา Baud Rate อัตโนมัติ (Auto-Baud)
  // ---------------------------------------------------------------------------
  long bauds[] = {57600, 9600, 115200, 19200, 38400};
  bool sensorFound = false;

  Serial.println("-> กำลังค้นหาเซนเซอร์ลายนิ้วมือ...");
  lcdStatus("Finding Sensor...", "Please Wait...");

  for (int b = 0; b < 5; b++) {
    Serial.print("   ลองความเร็ว: ");
    Serial.print(bauds[b]);
    Serial.println(" bps");

    fingerSerial.begin(bauds[b], SERIAL_8N1, 16, 17);
    delay(300);


    if (finger.verifyPassword()) {
      Serial.print("-> พบเซนเซอร์ลายนิ้วมือที่ความเร็ว: ");
      Serial.print(bauds[b]);
      Serial.println(" bps! ✓");
      lcdStatus("S.Mart POS v4.0", "Sensor Ready");
      sensorFound = true;
      break;
    }
    
    // ปิด Serial ชั่วคราวก่อนลองความเร็วถัดไป
    fingerSerial.end();
    delay(200);
  }

  sensorReady = sensorFound;

  if (!sensorReady) {
    Serial.println("ALERT:ไม่พบเครื่องสแกนลายนิ้วมือ! ระบบจะเปิดทำงานในโหมดตรวจหาอัจฉริยะ (Hot-plug)...");
    Serial.println("📌 คำแนะนำแก้ไข: เช็คสาย VCC/GND, ไฟสีฟ้าที่บอร์ดสแกนนิ้ว และลองสลับสาย TX/RX (เหลือง/เขียว)");
    
    lcdStatus("!! NO SENSOR !!", "1. Check Power", "2. Swap TX/RX", "Retrying...");
    // ถอดเสียงเตือนตอนหาไม่เจอออก ปล่อยให้เงียบไปเลย
  }

  prefs.begin("fp_names", false);

  // WiFi
  connectWiFi();

  // mDNS
  if (MDNS.begin("fingerprint")) {
    MDNS.addService("fingerprint", "tcp", 8080);
    Serial.println("mDNS: fingerprint.local ready.");
  }

  server.begin();
  Serial.println("-> TCP Server started on port 8080");

  // แสดงหน้าหลัก
  lcdStatus("S.Mart POS Ready", "Place your finger",
            WiFi.status() == WL_CONNECTED ? "WiFi: " + WiFi.localIP().toString() : "WiFi: ออฟไลน์");
  Serial.println("-> System v4.0 ready.\n");
}

// ---------------------------------------------------------------------------
// WiFi Connect (มี Timeout)
// ---------------------------------------------------------------------------
void connectWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);
  lcdStatus("Connecting WiFi...", String(ssid));
  WiFi.begin(ssid, password);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected! IP: " + WiFi.localIP().toString());
    lcdStatus("WiFi Connected!", WiFi.localIP().toString());
    delay(1500);
  } else {
    Serial.println("\n[WARN] WiFi failed. Running in offline mode.");
    lcdStatus("WiFi Failed", "Offline Mode");
    delay(1500);
  }
}

// ---------------------------------------------------------------------------
// Main Loop
// ---------------------------------------------------------------------------
void loop() {
  // ---- ระบบสแกนหาเซนเซอร์กรณีที่หลุดหรือยังไม่ได้ต่อ (Hot-plug) ----
  if (!sensorReady) {
    static unsigned long lastSensorCheck = 0;
    if (millis() - lastSensorCheck > 5000) {
      lastSensorCheck = millis();
      Serial.println("-> กำลังสแกนหาเซนเซอร์ลายนิ้วมือใหม่ (Hot-plug)...");
      
      long bauds[] = {57600, 9600, 115200, 19200, 38400};
      for (int b = 0; b < 5; b++) {
        fingerSerial.begin(bauds[b], SERIAL_8N1, 16, 17);
        delay(200);

        
        if (finger.verifyPassword()) {
          Serial.print("-> [HOT-PLUG] พบเซนเซอร์แล้วที่ความเร็ว: ");
          Serial.print(bauds[b]);
          Serial.println(" bps! ✓");
          lcdStatus("S.Mart POS Ready", "Place your finger",
                    WiFi.status() == WL_CONNECTED ? "WiFi: " + WiFi.localIP().toString() : "WiFi: ออฟไลน์");
          triggerBeep(1);
          sensorReady = true;
          break;
        }
        fingerSerial.end();
        delay(50);
      }
      
      if (!sensorReady) {
        Serial.println("-> [HOT-PLUG] ยังไม่พบเซนเซอร์ลายนิ้วมือ... กรุณาเช็คไฟเลี้ยงและลองสลับคู่สาย TX/RX");
      }
    }
    return; // ถ้ายังไม่มีเซนเซอร์ ให้กดข้าม loop หลักไปเลย ป้องกันความเสี่ยงบอร์ดค้าง/เสียงรบกวน
  }

  // ---- ตรวจสอบสถานะเซนเซอร์ระหว่างทำงาน (Heartbeat) ทุก 5 วินาที ----
  static unsigned long lastSensorPing = 0;
  if (millis() - lastSensorPing > 5000) {
    lastSensorPing = millis();
    // เช็คเฉพาะตอนว่างๆ (โหมด SCAN และไม่มีคนแตะนิ้วอยู่)
    if (currentMode == MODE_SCAN && !isTouchDetected()) {
      if (!finger.verifyPassword()) {
        Serial.println("-> [ERROR] ⚠️ เครื่องสแกนลายนิ้วมือขาดการเชื่อมต่อกะทันหัน! (สายหลุด / เครื่องดับ)");
        sensorReady = false;
        lcdStatus("!! SENSOR LOST !!", "Check Wiring!", "Reconnecting...");
        return; // ตัดกลับไปเข้าโหมด Hot-plug ด้านบนในรอบถัดไป
      }
    }
  }

  // ---- Auto-reconnect WiFi (ทุก 30 วินาที) ----
  if (millis() - lastWifiCheck > 30000) {
    lastWifiCheck = millis();
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("[WiFi] Disconnected. Reconnecting...");
      WiFi.reconnect();
      delay(3000);
      if (WiFi.status() == WL_CONNECTED) {
        Serial.println("[WiFi] Reconnected! IP: " + WiFi.localIP().toString());
      }
    }
  }

  // ---- UDP Broadcast ----
  if (WiFi.status() == WL_CONNECTED && millis() - lastUdpBroadcast > 3000) {
    lastUdpBroadcast = millis();
    String payload = "SMART_POS_FINGERPRINT_HERE:" + WiFi.localIP().toString();
    udp.beginPacket(IPAddress(255, 255, 255, 255), 8081);
    udp.print(payload);
    udp.endPacket();
  }

  // ---- รับ Client ใหม่ ----
  if (!client.connected()) {
    WiFiClient newClient = server.available();
    if (newClient) {
      client = newClient;
      Serial.println("-> POS Connected via WiFi!");
      if (currentMode == MODE_SCAN) {
        lcdStatus("S.Mart POS Ready", "Place your finger",
                  "POS: Connected");
      }
    }
  }

  // ---- Serial Monitor Commands ----
  if (Serial.available()) {
    String pccmd = Serial.readStringUntil('\n');
    pccmd.trim();
    if (pccmd.equalsIgnoreCase("delete")) {
      Serial.println("\n----------------------------------");
      Serial.println("⚠️ กำลังล้างฐานข้อมูลลายนิ้วมือทั้งหมด...");
      finger.emptyDatabase();
      prefs.clear();
      Serial.println("✅ สำเร็จ! ล้างฐานข้อมูลและรายชื่อเรียบร้อยแล้ว");
      Serial.println("----------------------------------\n");
      lcdStatus("DB Cleared OK", "Database Empty");
      triggerBeep(4);
    }
  }

  // ---- คำสั่งจาก POS ----
  checkNetworkCommand();

  // ---- ปุ่มกด ----
  handleButton(); // เปิดใช้งานปุ่มกดกลับมาแล้ว!

  // ---- State Machine ----
  if (currentMode == MODE_SCAN) {
    doScanMode();
  } else if (currentMode == MODE_ENROLL) {
    doEnrollMode();
  } else if (currentMode == MODE_BREAK_SCAN) {
    doBreakScanMode();
  }
}

// ---------------------------------------------------------------------------
// ปุ่มกด — จัดการ Single Click และ Double Click
// ---------------------------------------------------------------------------
void handleButton() {
  bool btnCurrent = digitalRead(BUTTON_PIN);

  // --- Debounce: ต้องเปลี่ยนสถานะแล้วผ่าน debounce time ---
  if (btnCurrent == btnLastState) {
    btnDebounceTime = millis();
    btnLastState    = btnCurrent;
  }

  // ตรวจจับขอบ (กดปุ่ม) หลัง debounce
  static bool btnWasPressed = false;
  bool pressedState = BUTTON_ACTIVE_HIGH ? HIGH : LOW;
  bool releasedState = BUTTON_ACTIVE_HIGH ? LOW : HIGH;

  if (btnCurrent == pressedState && !btnWasPressed && (millis() - btnDebounceTime > BTN_DEBOUNCE_MS)) {
    btnWasPressed = true;
    Serial.println("[BTN] Pressed! -> CLOCK OUT REQUEST");
    onSingleClick(); // เรียกใช้ฟังก์ชันเลิกงานนอกเวลา
  }

  // ปล่อยปุ่ม
  if (btnCurrent == releasedState && btnWasPressed) {
    btnWasPressed = false;
    btnLastState  = releasedState;
  }
}

// ---------------------------------------------------------------------------
// Single Click: บันทึกออกงานชั่วคราว
// ---------------------------------------------------------------------------
void onSingleClick() {
  if (currentMode == MODE_ENROLL) return; // ไม่ทำในโหมด Enroll

  if (currentMode == MODE_BREAK_SCAN) {
    // กำลังรอสแกน Break อยู่แล้ว → ยกเลิก
    currentMode = MODE_SCAN;
    lastScannedId = -1;
    lcdStatus("S.Mart POS Ready", "Place your finger",
              client.connected() ? "POS: Connected" : "POS: Disconnected");
    triggerBeep(2);
    sendToPOS("BREAK_CANCEL");
    return;
  }

  // โหมดปกติ → เข้าโหมดเลิกงานนอกเวลา: ให้สแกนนิ้วยืนยัน
  currentMode   = MODE_BREAK_SCAN;
  lastScannedId = -1;
  lcdStatus("== EARLY CLOCKOUT ==", "Scan to Confirm",
            "Press to Cancel");
  Serial.println("[BTN] Entering EARLY_CLOCK_OUT mode...");
  triggerBeep(3);
}

// ---------------------------------------------------------------------------
// Double Click: ขอเข้าโหมดลงทะเบียน (ต้องรับ ENROLL:<slot>:<name> จาก POS)
// ---------------------------------------------------------------------------
void onDoubleClick() {
  if (currentMode == MODE_ENROLL) return;

  lcdStatus("== ENROLL MODE ==", "Waiting for POS...", "Select Employee");
  triggerBeep(3);
  sendToPOS("ENROLL_REQUEST");
  Serial.println("[BTN] Sent ENROLL_REQUEST to POS.");
}

// ---------------------------------------------------------------------------
// Touch Debounce
// ---------------------------------------------------------------------------
bool isTouchDetected() {
  // R307S Touch Pin: LOW = มีนิ้วแตะ, HIGH = ไม่มีนิ้ว (Active Low)
  // Debounce 3 ครั้ง เพื่อกันสัญญาณรบกวน
  for (int i = 0; i < TOUCH_DEBOUNCE_COUNT; i++) {
    if (digitalRead(TOUCH_PIN) == HIGH) return false;  // HIGH = ไม่มีนิ้ว → return false
    delay(TOUCH_DEBOUNCE_MS);
  }
  return true;  // อ่านได้ LOW ครบ 3 ครั้ง = มีนิ้วแตะจริง
}

// ---------------------------------------------------------------------------
// ส่งข้อมูลกลับ POS
// ---------------------------------------------------------------------------
void sendToPOS(String message) {
  Serial.println(message);
  if (client.connected()) {
    client.println(message);
  }
}

// ---------------------------------------------------------------------------
// รับคำสั่งจาก POS
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
    lcdStatus("S.Mart POS Ready", "Place your finger");
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
    enrollBase  = base;
    currentMode = MODE_ENROLL;

    Serial.print("-> Enroll starting: base=");
    Serial.print(enrollBase);
    Serial.print(" name=");
    Serial.println(enrollName);

    lcdStatus("== ENROLL MODE ==", String(enrollName), "Place Finger");
    return;
  }
}

// ---------------------------------------------------------------------------
// โหมดสแกนปกติ
// ---------------------------------------------------------------------------
void doScanMode() {
  if (!isTouchDetected()) {
    delay(20);
    return;
  }

  Serial.println("[Scan] Touch detected! Capturing image...");
  lcdStatus("Scanning...", "Hold Finger");

  uint8_t p = finger.getImage();

  if (p == FINGERPRINT_NOFINGER) {
    lcdStatus("S.Mart POS Ready", "Place your finger",
              client.connected() ? "POS: Connected" : "POS: Disconnected");
    return;
  } else if (p != FINGERPRINT_OK) {
    Serial.print("[Scan] Image capture failed. Code: ");
    Serial.println(p);
    triggerBeep(2);
    lcdStatus("Image Unclear", "Try Again");
    liftFinger();
    lcdStatus("S.Mart POS Ready", "Place your finger");
    return;
  }

  // POS ไม่ได้ต่ออยู่
  if (!client.connected()) {
    unsigned long now = millis();
    if (now - lastNoPosBeepTime > 10000) {
      lastNoPosBeepTime = now;
      triggerBeep(2);
      lcdStatus("!! NO POS !!", "Check System");
    }
    Serial.println("[Scan] Image captured but POS not connected.");
    liftFinger();
    lcdStatus("S.Mart POS Ready", "Place your finger");
    return;
  }

  p = finger.image2Tz();
  if (p != FINGERPRINT_OK) {
    Serial.print("[Scan] Image conversion failed. Code: ");
    Serial.println(p);
    sendToPOS("ALERT:ภาพนิ้วไม่ชัด กรุณาวางนิ้วให้แน่นขึ้น");
    triggerBeep(2);
    lcdStatus("Image Unclear", "กรุณาวางนิ้วให้แน่น");
    liftFinger();
    lcdStatus("S.Mart POS Ready", "Place your finger");
    return;
  }

  p = finger.fingerSearch();
  if (p == FINGERPRINT_OK) {
    int matchedId = finger.fingerID;
    String key  = "s" + String(matchedId);
    String name = prefs.getString(key.c_str(), "");
    lastScannedId = matchedId;

    Serial.print("[Scan] Match Found! ID: ");
    Serial.print(matchedId);
    Serial.print(" Name: ");
    Serial.println(name);

    sendToPOS("MATCH_ID:" + String(matchedId));
    triggerBeep(1);

    // แสดงชื่อและสุ่มข้อความบน LCD (ภาษาอังกฤษล้วน)
    const char* inMsgs[] = {
      "Good morning!",
      "Let's work hard!",
      "Don't sleep! o_o",
      "Have a nice day!",
      "Keep fighting! ^_^"
    };
    int rIndex = random(5);
    String displayName = name.isEmpty() ? "ID:" + String(matchedId) : name;
    lcdStatus("Scan Success!", displayName, inMsgs[rIndex]);
    liftFinger();
    delay(500); // ลด delay จาก 1500 ให้เร็วขึ้น
    lcdStatus("S.Mart POS Ready", "Place your finger",
              client.connected() ? "POS: Connected" : "");
  } else {
    Serial.print("[Scan] Fingerprint not found or error. Code: ");
    Serial.println(p);
    sendToPOS("ALERT:ไม่พบลายนิ้วมือนี้ในระบบ");
    triggerBeep(2);
    lcdStatus("Not Found!", "Finger Mismatch", "Scan Again");
    liftFinger();
    delay(500); // ลด delay จาก 1500 ให้เร็วขึ้น
    lcdStatus("S.Mart POS Ready", "Place your finger");
  }
}

// ---------------------------------------------------------------------------
// โหมดออกพักชั่วคราว — รอสแกนนิ้วยืนยัน
// ---------------------------------------------------------------------------
void doBreakScanMode() {
  if (!isTouchDetected()) {
    delay(20);
    return;
  }

  Serial.println("[ClockOut] Touch detected! Scanning for early clock out...");

  uint8_t p = finger.getImage();
  if (p != FINGERPRINT_OK) {
    delay(100);
    return;
  }

  p = finger.image2Tz();
  if (p != FINGERPRINT_OK) {
    lcdStatus("Image Unclear", "Place Again");
    triggerBeep(2);
    liftFinger();
    lcdStatus("== EARLY CLOCKOUT ==", "Scan to Confirm");
    return;
  }

  p = finger.fingerSearch();
  if (p == FINGERPRINT_OK) {
    int matchedId = finger.fingerID;
    String key    = "s" + String(matchedId);
    String name   = prefs.getString(key.c_str(), "");

    // แสดงชื่อและสุ่มข้อความขากลับบน LCD (ภาษาอังกฤษล้วน)
    const char* outMsgs[] = {
      "Go home and rest!",
      "Good job today!",
      "Safe trip home! *_*",
      "See you tomorrow!",
      "Time to relax! <3"
    };
    int rIndex = random(5);
    String displayName = name.isEmpty() ? "ID:" + String(matchedId) : name;
    lcdStatus("Clock Out OK!", displayName, outMsgs[rIndex]);
    triggerBeep(1);

    sendToPOS("BREAK_START:" + String(matchedId));
    Serial.print("[ClockOut] BREAK_START (ClockOut) sent for ID: ");
    Serial.println(matchedId);

    liftFinger();
    delay(500);

    // กลับโหมดปกติ
    currentMode   = MODE_SCAN;
    lastScannedId = -1;
    lcdStatus("S.Mart POS Ready", "Place your finger",
              client.connected() ? "POS: Connected" : "POS: Disconnected");
  } else {
    lcdStatus("Not Found!", "Finger Mismatch");
    triggerBeep(2);
    liftFinger();
    delay(500);
    lcdStatus("== EARLY CLOCKOUT ==", "Scan to Confirm");
  }
}

// ---------------------------------------------------------------------------
// โหมดลงทะเบียน (3 มุม × 2 รอบ = 3 Slots)
// ---------------------------------------------------------------------------
void doEnrollMode() {
  int base = enrollBase;
  int step = 1;

  String angleNames[3] = {"มุมตรง", "เอียงซ้าย", "เอียงขวา"};

  for (int i = 0; i < 3; i++) {
    // แตะครั้งที่ 1
    while (true) {
      String msg = "วางนิ้ว" + angleNames[i] + " (1/2)";
      sendStep(step, msg);
      lcdStatus("Enroll: " + String(enrollName),
                angleNames[i],
                "วางนิ้ว ครั้งที่ 1/2");
      int res = captureAndStore(1);
      if (res ==  1) break;
      if (res == -1) { sendEnrollFail(); return; }
      liftFinger();
    }
    step++;
    liftFinger();

    // แตะครั้งที่ 2
    while (true) {
      String msg = "วางนิ้ว" + angleNames[i] + " (2/2)";
      sendStep(step, msg);
      lcdStatus("Enroll: " + String(enrollName),
                angleNames[i],
                "วางนิ้ว ครั้งที่ 2/2");
      int res = captureAndCreateModel(2, base + i);
      if (res ==  1) break;
      if (res == -1) { sendEnrollFail(); return; }
      liftFinger();
    }
    step++;
    liftFinger();
  }

  // บันทึกชื่อลง Flash
  for (int i = 0; i < 3; i++) {
    String key = "s" + String(base + i);
    prefs.putString(key.c_str(), String(enrollName));
  }

  sendToPOS("ENROLL_OK:" + String(base));
  Serial.print("-> ✅ ลงทะเบียนสำเร็จ: ");
  Serial.print(enrollName);
  Serial.println(" (Slots " + String(base) + "-" + String(base + 2) + ")");

  lcdStatus("Enroll Success!", String(enrollName), "Slots " + String(base) + "-" + String(base+2));
  triggerBeep(4);
  delay(2000);
  resetToScan();
  lcdStatus("S.Mart POS Ready", "Place your finger");
}

// ---------------------------------------------------------------------------
// Helpers: Fingerprint Capture
// ---------------------------------------------------------------------------
int captureAndStore(uint8_t bufferSlot) {
  uint8_t p = waitForFinger();
  if (p == FINGERPRINT_PACKETRECIEVEERR) return -1;
  if (p != FINGERPRINT_OK) return 0;

  p = finger.image2Tz(bufferSlot);
  if (p != FINGERPRINT_OK) {
    sendToPOS("ALERT:ภาพนิ้วไม่ชัด กรุณาวางนิ้วใหม่อีกครั้ง");
    lcdStatus("Image Unclear", "Try Again");
    triggerBeep(2);
    return 0;
  }
  triggerBeep(3);
  return 1;
}

int captureAndCreateModel(uint8_t bufferSlot, int targetSlot) {
  int cap = captureAndStore(bufferSlot);
  if (cap != 1) return cap;

  uint8_t p = finger.createModel();
  if (p == FINGERPRINT_OK) {
    p = finger.storeModel(targetSlot);
    if (p != FINGERPRINT_OK) {
      sendToPOS("ALERT:บันทึก Slot #" + String(targetSlot) + " ล้มเหลว");
      triggerBeep(2);
      return -1;
    }
    Serial.println("-> บันทึก Slot #" + String(targetSlot) + " สำเร็จ");
    triggerBeep(3);
    return 1;
  }

  sendToPOS("ALERT:ลายนิ้วมือขยับเยอะไป วางนิ้วเดิมแก้ตัวอีกครั้งครับ");
  lcdStatus("Finger Moved", "Place Same Finger");
  triggerBeep(2);
  return 0;
}

// ---------------------------------------------------------------------------
// Helpers: Timing & Flow
// ---------------------------------------------------------------------------
void sendStep(int step, String message) {
  sendToPOS("ENROLL_STEP:" + String(step) + ":" + message);
}

uint8_t waitForFinger() {
  while (true) {
    if (client.connected() && client.available()) {
      String cmd = client.readStringUntil('\n');
      cmd.trim();
      if (cmd == "ENROLL_CANCEL") {
        resetToScan();
        Serial.println("-> Cancelled by POS.");
        lcdStatus("S.Mart POS Ready", "Place your finger");
        return FINGERPRINT_PACKETRECIEVEERR;
      }
    }

    if (!isTouchDetected()) {
      delay(20);
      continue;
    }

    uint8_t p = finger.getImage();
    if (p == FINGERPRINT_OK) return FINGERPRINT_OK;
    delay(50);
  }
}

void liftFinger() {
  while (true) {
    if (client.connected() && client.available()) {
      String cmd = client.readStringUntil('\n');
      cmd.trim();
      if (cmd == "ENROLL_CANCEL") {
        resetToScan();
        Serial.println("-> Cancelled by POS (during liftFinger).");
        lcdStatus("S.Mart POS Ready", "Place your finger");
        return;
      }
    }
    // ใช้เซ็นเซอร์สัมผัสแทน getImage() เพื่อไม่ให้ไฟแฟลชกะพริบรัวๆ
    if (!isTouchDetected()) break;
    delay(50);
  }
}

void sendEnrollFail() {
  sendToPOS("ENROLL_FAIL:" + String(enrollBase));
  Serial.println("-> ❌ Enrollment failed. Back to scan mode.");
  lcdStatus("Enroll Failed", "Try Again");
  triggerBeep(5);
  delay(1500);
  resetToScan();
  lcdStatus("S.Mart POS Ready", "Place your finger");
}

void resetToScan() {
  currentMode = MODE_SCAN;
  enrollBase  = -1;
  memset(enrollName, 0, sizeof(enrollName));
}

// ---------------------------------------------------------------------------
// LCD Helpers
// ---------------------------------------------------------------------------

void lcdClear() {
  lcd.clear();
}

// ล้างจอและพิมพ์ข้อความ 1-4 บรรทัด
void lcdStatus(String line1, String line2, String line3, String line4) {
  lcdClear();
  if (line1.length() > 0) lcdPrint(0, line1);
  if (line2.length() > 0) lcdPrint(1, line2);
  if (line3.length() > 0) lcdPrint(2, line3);
  if (line4.length() > 0) lcdPrint(3, line4);
}

void lcdPrint(uint8_t row, String text) {
  lcd.setCursor(0, row);
  
  // ตัดข้อความถ้าเกินจอ (20 ตัวอักษร)
  if (text.length() > LCD_COLS) {
    text = text.substring(0, LCD_COLS);
  }
  
  // จัดกึ่งกลาง
  int padding = (LCD_COLS - text.length()) / 2;
  for (int i = 0; i < padding; i++) {
    lcd.print(" ");
  }
  lcd.print(text);
}

// ---------------------------------------------------------------------------
// Helpers: Active Buzzer (GPIO 32)
// ---------------------------------------------------------------------------
void triggerBeep(int type) {
  // ใช้ BUZZ_ON/BUZZ_OFF เพื่อรองรับทั้ง Active HIGH และ Active LOW module

  // type 1 = สแกนผ่าน (1 เสียงยาว 300ms)
  if (type == 1) {
    buzzSuccess();
  }
  // type 2 = ล้มเหลว/เตือน (2 เสียงสั้น)
  else if (type == 2 || type == 5) {
    buzzError();
  }
  // type 3 = รับภาพนิ้วสำเร็จ (1 เสียงสั้น)
  else if (type == 3) {
    buzzClick();
  }
  // type 4 = สำเร็จสมบูรณ์ (3 เสียงสั้น)
  else if (type == 4) {
    for (int i = 0; i < 3; i++) {
      buzzClick();
      delay(80);
    }
  }

  // ตรวจสอบให้แน่ใจว่า Buzzer ปิดสนิท
  digitalWrite(BUZZER_PIN, BUZZ_OFF);
}

void buzzSuccess() {
  Serial.println("[BUZZER] Triggered by: SUCCESS (สแกนผ่าน/ตอบรับ)");
  digitalWrite(BUZZER_PIN, BUZZ_ON);
  delay(100);
  digitalWrite(BUZZER_PIN, BUZZ_OFF);
  delay(100);
  digitalWrite(BUZZER_PIN, BUZZ_ON);
  delay(100);
  digitalWrite(BUZZER_PIN, BUZZ_OFF);
}

void buzzError() {
  Serial.println("[BUZZER] Triggered by: ERROR (สแกนไม่ผ่าน/ผิดพลาด)");
  for (int i = 0; i < 3; i++) {
    digitalWrite(BUZZER_PIN, BUZZ_ON);
    delay(150);
    digitalWrite(BUZZER_PIN, BUZZ_OFF);
    delay(150);
  }
}

void buzzClick() {
  Serial.println("[BUZZER] Triggered by: CLICK (กดปุ่ม)");
  digitalWrite(BUZZER_PIN, BUZZ_ON);
  delay(100);
  digitalWrite(BUZZER_PIN, BUZZ_OFF);
}