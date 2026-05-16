# Troubleshooting & Known Issues (บันทึกข้อผิดพลาดและการแก้ไข)

เอกสารนี้รวบรวมปัญหาที่พบบ่อยและวิธีการแก้ไขเบื้องต้น สำหรับนักพัฒนาและผู้ดูแลระบบ

## 1. ปัญหาฐานข้อมูลและการบันทึกข้อมูล (Database & Saving Issues)

### Error: `type 'String' is not a subtype of type 'int' in type cast` (ขณะบันทึกสินค้า)
**อาการ (Symptom):**  
แอปเด้งออก (Crash) หรือแสดงหน้าต่างแจ้งเตือนข้อผิดพลาด "type 'String' is not a subtype of type 'int' in type cast" เมื่อกดบันทึกสินค้า

**สาเหตุ (Cause):**  
Driver `mysql1` หรือการตั้งค่า Database บางครั้งจะส่งค่าตัวเลข (เช่น `id`) กลับมาเป็น `String` แทนที่จะเป็น `int` โดยเฉพาะเมื่อใช้คำสั่ง `count(*)` หรือในบางเวอร์ชันของ MySQL

**วิธีแก้ไข (Solution):**  
ต้องแปลงค่า ID อย่างปลอดภัยเสมอ โดยใช้ `int.tryParse()` แทนการ Cast ตรงๆ ด้วย `as int`
```dart
// แบบที่ผิด (ทำให้เกิด Error)
final id = row['id'] as int;

// แบบที่ถูกต้อง (Safe Parsing)
final val = row['id'];
final id = (val is int) ? val : int.tryParse(val.toString()) ?? 0;
```
**ตำแหน่งไฟล์ที่แก้:** `lib/repositories/product_repository.dart` (เมธอด saveProduct)

---

## 2. ปัญหาหน้าจอและการแสดงผล (UI & Form Issues)

### Issue: หน้าแก้ไขสินค้าไม่แสดงหน่วยนับที่บันทึกไว้
**อาการ (Symptom):**  
เมื่อเปิดหน้า "แก้ไขสินค้า" ช่อง "หน่วยสินค้า" จะว่างเปล่า ทั้งๆ ที่สินค้านั้นมีหน่วยนับบันทึกอยู่ในฐานข้อมูลแล้ว

**สาเหตุ (Cause):**  
ตัวแปร `_selectedUnitId` ในไฟล์ `ProductFormDialog` ไม่ได้ถูกกำหนดค่าเริ่มต้นจาก `widget.product.unitId` ในฟังก์ชัน `_loadInitialData` (ในโค้ดเดิมทำแค่ Supplier ID)

**วิธีแก้ไข (Solution):**  
เพิ่มโค้ดเพื่อตรวจสอบและดึงค่า `widget.product?.unitId` มาใส่ใน `_selectedUnitId` หากค่านั้นมีอยู่ในลิสต์ของหน่วยนับ
**ตำแหน่งไฟล์ที่แก้:** `lib/screens/products/product_list_view.dart` (เมธอด _loadInitialData)

---

## 3. ปัญหาการพิมพ์และ PDF (PDF & Check Printing)

### Error: `Unable to download ... fonts` ระหว่างรัน `flutter test`
**อาการ (Symptom):**  
เมื่อรันคำสั่ง `flutter test` จะเกิด Error เกี่ยวกับการดาวน์โหลดฟอนต์ (เช่น Sarabun) หรือแจ้งว่าไม่มี Unicode support

**สาเหตุ (Cause):**  
สภาพแวดล้อมที่ใช้ทดสอบ (Test Environment) มักจะไม่มีการเชื่อมต่ออินเทอร์เน็ต ทำให้โหลดฟอนต์ Google Fonts ไม่ได้ หรือไฟล์ `AssetManifest.json` อาจหายไปหากไม่ได้ Initialize อย่างถูกต้อง

**วิธีแก้ไข (Solution):**  
- **สำหรับ Testing:** ใช้ไฟล์ฟอนต์จำลองในเครื่อง (Mock/Stub) หรือตรวจสอบให้แน่ใจว่าเรียก `TestWidgetsFlutterBinding.ensureInitialized()`
- **สำหรับ Production:** ตรวจสอบว่าแอปมีอินเทอร์เน็ตในการรันครั้งแรกเพื่อ cache ฟอนต์ หรือดาวน์โหลดไฟล์ `.ttf` มาใส่ในโปรเจกต์ (`assets/fonts`) และประกาศใน `pubspec.yaml` เพื่อความชัวร์

---

## 4. การเชื่อมต่อฐานข้อมูล (Database Connection)

### Issue: เปิดแอปแล้วค้าง หรือขึ้น "Connection Refused"
**อาการ (Symptom):**  
เปิดแอปแล้วหน้าจอขาว หรือหมุนติ้วๆ ไม่ไปหน้าถัดไป

**สาเหตุ (Cause):**  
แอปพยายามเชื่อมต่อ MySQL ทันทีที่เปิด หาก IP Address เปลี่ยน (เช่น DHCP เปลี่ยน) หรือ Server ปิดอยู่ แอปจะรอจนกว่าจะ Timeout (ซึ่งอาจนานมาก)

**วิธีแก้ไข (Solution):**  
- ตรวจสอบค่า `db_host` ใน `SettingsService`
- ควรตั้งค่า IP ของเครื่อง Server ให้เป็น Static IP (Fix IP)
- แอปควรมีปุ่ม "Offline Mode" หรือเข้าหน้าตั้งค่าได้ทันทีหากเชื่อมต่อไม่ได้ (Timeout ควรจะสั้นลง)
