import sys

file_path = r'C:\pos_desktop\ESP32_Fingerprint\ESP32_Fingerprint.ino'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

replacements = {
    '"ค้นหาเซนเซอร์..."': '"Finding Sensor..."',
    '"กรุณารอสักครู่"': '"Please Wait..."',
    '"เซนเซอร์พร้อม ✓"': '"Sensor Ready"',
    '"!! ไม่พบเซนเซอร์ !!"': '"!! NO SENSOR !!"',
    '"1.เช็คไฟเลี้ยงบอร์ด"': '"1. Check Power"',
    '"2.ลองสลับสาย TX/RX"': '"2. Swap TX/RX"',
    '"รอตรวจจับใหม่..."': '"Retrying..."',
    '"S.Mart POS พร้อม"': '"S.Mart POS Ready"',
    '"วางนิ้วเพื่อสแกน"': '"Place your finger"',
    '"กำลังเชื่อม WiFi..."': '"Connecting WiFi..."',
    '"WiFi เชื่อมแล้ว ✓"': '"WiFi Connected!"',
    '"WiFi ล้มเหลว"': '"WiFi Failed"',
    '"ทำงานแบบออฟไลน์"': '"Offline Mode"',
    '"!! เซนเซอร์หลุด !!"': '"!! SENSOR LOST !!"',
    '"ตรวจสอบสายไฟด่วน!"': '"Check Wiring!"',
    '"รอการเชื่อมต่อใหม่..."': '"Reconnecting..."',
    '"ล้างข้อมูลสำเร็จ ✓"': '"DB Cleared OK"',
    '"ฐานข้อมูลว่างเปล่า"': '"Database Empty"',
    '"== เลิกงานนอกเวลา =="': '"== EARLY CLOCKOUT =="',
    '"กรุณาสแกนนิ้วยืนยัน"': '"Scan to Confirm"',
    '"== ลงทะเบียน =="': '"== ENROLL MODE =="',
    '"รอคำสั่งจาก POS..."': '"Waiting for POS..."',
    '"กรุณาเลือกพนักงาน"': '"Select Employee"',
    '"วางนิ้วมุมตรงก่อน"': '"Place Finger"',
    '"กำลังสแกน..."': '"Scanning..."',
    '"วางนิ้วให้แน่น"': '"Hold Finger"',
    '"ภาพไม่ชัด"': '"Image Unclear"',
    '"กรุณาวางนิ้วใหม่"': '"Try Again"',
    '"!! ไม่พบ POS !!"': '"!! NO POS !!"',
    '"กรุณาตรวจสอบระบบ"': '"Check System"',
    '"ภาพนิ้วไม่ชัด"': '"Image Unclear"',
    '"สแกนสำเร็จ ✓"': '"Scan Success!"',
    '"บันทึกเวลาแล้ว"': '"Time Recorded"',
    '"ไม่พบข้อมูล !"': '"Not Found!"',
    '"ลายนิ้วมือไม่ตรง"': '"Finger Mismatch"',
    '"กรุณาสแกนใหม่"': '"Scan Again"',
    '"กรุณาวางใหม่"': '"Place Again"',
    '"เลิกงานยืนยัน ✓"': '"Clock Out OK!"',
    '"บันทึกเวลาเลิกงานแล้ว"': '"Time Recorded"',
    '"ลงทะเบียน: "': '"Enroll: "',
    '"ลงทะเบียนสำเร็จ ✓"': '"Enroll Success!"',
    '"นิ้วขยับมาก"': '"Finger Moved"',
    '"วางนิ้วเดิมใหม่"': '"Place Same Finger"',
    '"ลงทะเบียนล้มเหลว"': '"Enroll Failed"',
    '"กรุณาลองใหม่"': '"Try Again"',
    '"POS: เชื่อมต่อแล้ว ✓"': '"POS: Connected"',
    '"POS: ไม่ได้เชื่อมต่อ"': '"POS: Disconnected"',
    '"กดปุ่มอีกครั้งเพื่อยกเลิก"': '"Press to Cancel"'
}

for old_str, new_str in replacements.items():
    content = content.replace(old_str, new_str)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Done")
