# Firebase Cloud Functions - Line Notifications

## 📋 คำอธิบาย
Cloud Functions สำหรับส่งแจ้งเตือน Line OA ในขั้นตอน Stage 2 (กำลังส่ง) และ Stage 3 (ส่งเสร็จ)

## 🚀 การติดตั้ง

### 1. เข้าโฟลเดอร์ Functions
```bash
cd functions
```

### 2. ติดตั้ง Dependencies
```bash
npm install
```

### 3. ตั้งค่า Backend API URL
⚠️ **สำคัญมาก**: ต้องตั้งค่า URL ของ Backend API ที่จะเรียกส่ง Line

```bash
firebase functions:config:set backend.api_url="http://your-api-url:8080"
```

**หมายเหตุ**: ถ้า Backend API รันบนเครื่องเดียวกับ POS Desktop (localhost) คุณจะต้อง:
- **วิธีที่ 1**: ใช้ Public URL (เช่น ngrok, Cloudflare Tunnel)
- **วิธีที่ 2**: Deploy Backend API ขึ้น Cloud (Render, Railway, etc.)

เพราะว่า Cloud Functions รันบน Google Cloud ไม่สามารถเข้าถึง localhost ของคุณได้

### 4. Deploy ขึ้น Firebase
```bash
firebase deploy --only functions
```

## 🔍 ตรวจสอบ Logs
```bash
# ดู Logs แบบเรียลไทม์
firebase functions:log --only notifyShipping,notifyCompleted

# หรือดูผ่าน Firebase Console
# https://console.firebase.google.com/project/YOUR_PROJECT/functions/logs
```

## 🧪 ทดสอบ

### ทดสอบ Stage 2 (Shipping)
1. สร้างงานจาก POS Desktop
2. ไปที่แอป S-Link บนมือถือ
3. กดปุ่ม "ปล่อยรถ" หรืออัปเดต status เป็น "shipping"
4. ตรวจสอบว่าลูกค้าได้รับ Line "กำลังเดินทางจัดส่ง"

### ทดสอบ Stage 3 (Completed)
1. ที่แอป S-Link บนมือถือ
2. กดปุ่ม "จบงาน" หรืออัปเดต status เป็น "completed"
3. ตรวจสอบว่าลูกค้าได้รับ Line "จัดส่งถึงมือท่าน"

## ⚠️ Troubleshooting

### ไม่ส่ง Line
1. ตรวจสอบ logs: `firebase functions:log`
2. ตรวจสอบว่า customer มี `line_user_id` หรือไม่
3. ตรวจสอบว่า Backend API URL ถูกต้องหรือไม่

### Backend API ไม่ตอบสนอง
- ตรวจสอบว่า API รันอยู่หรือไม่
- ตรวจสอบว่าสามารถเข้าถึงจาก Public Internet ได้หรือไม่
- ถ้าใช้ localhost ต้องใช้ ngrok หรือ Cloudflare Tunnel

## 📊 ค่าใช้จ่ายโดยประมาณ
- Firestore Writes: ~10-20 ครั้ง/วัน (จาก S-Link App)
- Firestore Reads: ~10-20 ครั้ง/วัน (Cloud Functions อ่าน customer)
- Function Invocations: ~10-20 ครั้ง/วัน
- **รวม**: ~20-50 บาท/เดือน (สำหรับร้านขนาดกลาง ~100 ออเดอร์/วัน)
