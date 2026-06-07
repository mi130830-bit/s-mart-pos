# HR.md: Fingerprint Reader Integration (Arduino Nano)

เอกสารนี้ระบุรายละเอียดการออกแบบฮาร์ดแวร์ การเขียนโปรแกรมบนบอร์ด Arduino Nano ร่วมกับเซนเซอร์แสกนลายนิ้วมือ และการเชื่อมต่อเข้ากับระบบ POS Desktop ผ่าน Serial COM Port เพื่อใช้ในการบันทึกเวลาเข้างานของพนักงาน (Attendance Checking)

---

## 🛠️ Hardware Connection (การเชื่อมต่อฮาร์ดแวร์)

การต่อสายระหว่าง **Arduino Nano** และโมดูลแสกนลายนิ้วมือรุ่นมาตรฐาน (เช่น **AS608** หรือ **R503**):

| โมดูลแสกนลายนิ้วมือ (Fingerprint Module) | Arduino Nano Pin | หมายเหตุ |
| :--- | :--- | :--- |
| **VCC** (3.3V หรือ 5V ตามสเปคของโมดูล) | **3.3V** หรือ **5V** | แนะนำให้เช็คสเปคโมดูลก่อนต่อไฟ |
| **GND** | **GND** | กราวด์ร่วมกัน |
| **TX** | **D2** (RX ของ SoftwareSerial) | สายส่งข้อมูลจากเซนเซอร์เข้า Arduino |
| **RX** | **D3** (TX ของ SoftwareSerial) | สายรับข้อมูลจาก Arduino เข้าเซนเซอร์ |

> [!WARNING]
> เซนเซอร์ส่วนใหญ่ทำงานที่แรงดันระดับสัญญาณ Logic 3.3V หากต่อเข้า Arduino Nano (5V) ตรง ๆ อาจเกิดความร้อนสะสมในตัวรับสัญญาณได้ หากใช้เป็นระยะเวลานาน แนะนำให้ต่อตัวต้านทาน 10kΩ/20kΩ ทำ Voltage Divider ที่ขา RX ของเซนเซอร์ หรือใช้ Logic Level Shifter

---

## 🔌 1. Arduino Firmware Code (โค้ดฝั่ง Arduino)

โค้ดนี้ใช้ไลบรารีมาตรฐาน **`Adafruit Fingerprint Sensor Library`** เพื่อสั่งให้เซนเซอร์แสกนภาพลายนิ้วมือ แปลงเป็นรหัสคณิตศาสตร์ แล้วค้นหา ID ที่ตรงกัน จากนั้นส่งออกพอร์ต USB Serial ไปยังเครื่องคอมพิวเตอร์

```cpp
#include <Adafruit_Fingerprint.h>
#include <SoftwareSerial.h>

// กำหนดขาเชื่อมต่อแบบจำลองซีเรียลพอร์ต (D2 = RX, D3 = TX)
SoftwareSerial mySerial(2, 3);
Adafruit_Fingerprint finger = Adafruit_Fingerprint(&mySerial);

void setup() {
  Serial.begin(9600); // สำหรับส่งข้อมูลเข้าคอมพิวเตอร์ผ่าน USB
  while (!Serial);
  delay(100);
  
  Serial.println("\n\n--- Fingerprint System Initializing ---");

  // กำหนดอัตราบอดเรตเริ่มต้นของเซนเซอร์ส่วนใหญ่คือ 57600
  finger.begin(57600);
  delay(5);
  
  if (finger.verifyPassword()) {
    Serial.println("OK: Found fingerprint sensor!");
  } else {
    Serial.println("ERROR: Did not find fingerprint sensor :(");
    while (1) { delay(1); }
  }

  finger.getParameters();
  Serial.print("Sensor Template Capacity: "); 
  Serial.println(finger.templateCount);
}

void loop() {
  int result = getFingerprintID();
  delay(50); // ดีเลย์เพื่อป้องกันการแสกนซ้ำซ้อนอย่างรวดเร็ว
}

// ฟังก์ชันแสกนและค้นหาลายนิ้วมือในหน่วยความจำ
int getFingerprintID() {
  uint8_t p = finger.getImage();
  if (p != FINGERPRINT_OK) return -1; // ไม่มีนิ้วแตะ หรือตรวจจับไม่ได้

  p = finger.image2Tz();
  if (p != FINGERPRINT_OK) return -1; // แปลงภาพลายนิ้วมือไม่สำเร็จ

  p = finger.fingerSearch();
  if (p == FINGERPRINT_OK) {
    // พบลายนิ้วมือที่ตรงกันในหน่วยความจำของเซนเซอร์
    Serial.print("MATCH_ID:");
    Serial.println(finger.fingerID);
    
    // ส่งข้อมูลค่าความแม่นยำ (Confidence) ไปด้วยเพื่อวิเคราะห์
    Serial.print("CONFIDENCE:");
    Serial.println(finger.confidence);
    
    // บอร์ดส่งเสียงแจ้งเตือนสั้นๆ (ถ้ามี Buzzer ต่อพ่วง)
    // buzzerTrigger();
    
    delay(1000); // หน่วงเวลา 1 วินาทีเพื่อรอให้นำนิ้วออกจากเซนเซอร์
    return finger.fingerID;
  } else if (p == FINGERPRINT_NOTFOUND) {
    Serial.println("ALERT: Fingerprint Not Match!");
    delay(1000);
    return -2;
  } else {
    Serial.println("ERROR: Sensor Search Error!");
    return -3;
  }
}
```

---

## 💻 2. Flutter POS Integration Code (โค้ดฝั่ง POS)

โค้ดฝั่งแอปพลิเคชันเดสก์ท็อปในหน้า POS จะใช้แพ็กเกจ `flutter_libserialport` ในการตรวจจับและคอยรับข้อมูลจากบอร์ด Arduino ผ่าน USB COM Port

### การเพิ่ม dependencies ใน `pubspec.yaml`
```yaml
dependencies:
  flutter_libserialport: ^0.4.0
```

### คลาสสำหรับจัดการพอร์ตเชื่อมต่อ (Serial Service Helper)
สร้างไฟล์แยกเช่น `lib/services/integration/fingerprint_serial_service.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

class FingerprintSerialService {
  SerialPort? _port;
  SerialPortReader? _reader;
  bool _isListening = false;
  
  // Callback ฟังก์ชันที่จะทำงานเมื่อมีข้อมูลลายนิ้วมือที่แมตช์ส่งมา
  final Function(int fingerId) onMatchDetected;
  final Function(String error) onErrorOccurred;

  FingerprintSerialService({
    required this.onMatchDetected,
    required this.onErrorOccurred,
  });

  // 1. ค้นหาพอร์ต COM ที่เชื่อมต่อกับบอร์ด Arduino อัตโนมัติ
  List<String> getAvailablePorts() {
    return SerialPort.availablePorts;
  }

  // 2. เริ่มต้นการเชื่อมต่อ
  bool connect(String portName) {
    try {
      disconnect();
      
      _port = SerialPort(portName);
      if (!_port!.openReadWrite()) {
        onErrorOccurred("ไม่สามารถเปิดพอร์ต $portName ได้");
        return false;
      }

      // ตั้งค่า baudRate ให้ตรงกับฝั่ง Arduino
      _port!.config.baudRate = 9600;
      _port!.config.bits = 8;
      _port!.config.stopBits = 1;
      _port!.config.parity = SerialPortParity.none;

      _reader = SerialPortReader(_port!);
      _isListening = true;
      
      StringBuffer buffer = StringBuffer();

      _reader!.stream.listen(
        (Uint8List data) {
          final incomingText = utf8.decode(data, allowMalformed: true);
          buffer.write(incomingText);

          // แปลงข้อมูลเป็นบรรทัดเมื่อเจอ \n (New line)
          while (buffer.toString().contains('\n')) {
            final content = buffer.toString();
            final nextLineIdx = content.indexOf('\n');
            final line = content.substring(0, nextLineIdx).trim();
            buffer.clear();
            buffer.write(content.substring(nextLineIdx + 1));

            _parseSerialLine(line);
          }
        },
        onError: (err) {
          onErrorOccurred("การเชื่อมต่อซีเรียลขัดข้อง: $err");
          disconnect();
        },
        onDone: () {
          disconnect();
        },
      );
      
      return true;
    } catch (e) {
      onErrorOccurred("เกิดข้อผิดพลาดในการเชื่อมต่อ: $e");
      return false;
    }
  }

  // 3. วิเคราะห์ข้อความที่ส่งมาจากบอร์ด
  void _parseSerialLine(String line) {
    debugPrint("Arduino Raw: $line");
    if (line.startsWith("MATCH_ID:")) {
      final idStr = line.split(":")[1];
      final matchedId = int.tryParse(idStr);
      if (matchedId != null) {
        onMatchDetected(matchedId);
      }
    } else if (line.startsWith("ALERT:")) {
      onErrorOccurred(line.substring(6));
    }
  }

  // 4. สั่งตัดการเชื่อมต่อเพื่อคืนทรัพยากรให้ระบบปฏิบัติการ
  void disconnect() {
    _isListening = false;
    _reader = null;
    if (_port != null && _port!.isOpen) {
      _port!.close();
      _port!.dispose();
    }
    _port = null;
  }

  bool get isConnected => _port != null && _port!.isOpen && _isListening;
}
```

---

## ⚙️ 3. การแมปข้อมูลลายนิ้วมือกับตารางพนักงาน (Database Mapping)

เนื่องจากลายนิ้วมือถูกเก็บบันทึกบน Flash Memory ของโมดูลแสกนลายนิ้วมือ เราจึงต้องมีตารางสำหรับจับคู่ระหว่าง `fingerprint_id` (ในโมดูล) เข้ากับ `employee_id` (ในแอป POS):

### ตารางเก็บข้อมูลลายนิ้วมือของพนักงาน (ตัวอย่าง SQL สำหรับ SQLite/MySQL)
```sql
CREATE TABLE IF NOT EXISTS employee_fingerprint (
  id INT PRIMARY KEY AUTO_INCREMENT,
  employee_id INT NOT NULL,
  fingerprint_slot_id INT NOT NULL UNIQUE, -- ค่า ID (1-127) ที่บันทึกไว้ในโมดูลแสกนลายนิ้วมือ
  finger_name VARCHAR(50) DEFAULT 'Right Index', -- ชื่อนิ้วที่บันทึก
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (employee_id) REFERENCES employee_profile(id) ON DELETE CASCADE
);
```

### ลอจิกฝั่ง POS เมื่อรับ ID ลายนิ้วมือมา
เมื่อคลาสบริการตรวจพบ `MATCH_ID: 5`:
1. ทำการค้นหาในฐานข้อมูล: `SELECT employee_id FROM employee_fingerprint WHERE fingerprint_slot_id = 5;`
2. หากเจอ `employee_id = 12`
3. สั่งบันทึกเวลาทำงานผ่าน API หรือคลาสบริการเช็คชื่อพนักงานได้ทันที:
   `await AttendanceRepository.logCheckIn(employeeId: 12, checkTime: DateTime.now());`
