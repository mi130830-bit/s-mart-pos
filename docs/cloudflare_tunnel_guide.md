# 🚀 คู่มือติดตั้ง Cloudflare Tunnel สำหรับ POS Mini

## 📋 สิ่งที่ต้องเตรียม

- ✅ เครื่อง Windows ที่ติดตั้ง MySQL (เครื่องแม่)
- ✅ บัญชี Cloudflare (สมัครฟรีที่ https://dash.cloudflare.com/sign-up)
- ✅ สิทธิ์ Admin ในการติดตั้งโปรแกรม

---

## 📥 Step 1: ดาวน์โหลด cloudflared

### วิธีที่ 1: ดาวน์โหลดโดยตรง
1. ไปที่ https://github.com/cloudflare/cloudflared/releases
2. ดาวน์โหลด `cloudflared-windows-amd64.exe`
3. เปลี่ยนชื่อไฟล์เป็น `cloudflared.exe`
4. ย้ายไฟล์ไปที่ `C:\Windows\System32\` (ใช้สิทธิ์ Admin)

### วิธีที่ 2: ใช้ PowerShell (แนะนำ)
```powershell
# เปิด PowerShell แบบ Administrator
# Download cloudflared
Invoke-WebRequest -Uri "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -OutFile "C:\Windows\System32\cloudflared.exe"
```

### ตรวจสอบการติดตั้ง
```powershell
cloudflared --version
```

ถ้าแสดงเวอร์ชันออกมา แปลว่าติดตั้งสำเร็จ! ✅

---

## 🔑 Step 2: Login เข้า Cloudflare

```powershell
cloudflared tunnel login
```

1. Browser จะเปิดขึ้นมาอัตโนมัติ
2. เลือก Domain ที่ต้องการใช้ (ถ้าไม่มี ให้กด "Add a site")
3. Authorize cloudflared
4. หน้าต่าง Browser จะแสดง "Success!" ✅

---

## 🌐 Step 3: สร้าง Tunnel

```powershell
# สร้าง Tunnel ชื่อ "pos-mini"
cloudflared tunnel create pos-mini
```

จะได้ Tunnel ID กลับมา เช่น: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`

**เก็บ ID นี้ไว้!** จะใช้ในขั้นตอนถัดไป

---

## ⚙️ Step 4: สร้างไฟล์ Config

สร้างไฟล์ `config.yml` ที่ `C:\Users\<YourUsername>\.cloudflared\config.yml`

```yaml
tunnel: <TUNNEL_ID>
credentials-file: C:\Users\<YourUsername>\.cloudflared\<TUNNEL_ID>.json

ingress:
  # Route สำหรับ API Backend
  - hostname: api-pos.yourdomain.com
    service: http://localhost:8080
  
  # Catch-all rule (จำเป็น)
  - service: http_status:404
```

**แทนที่**:
- `<TUNNEL_ID>` → Tunnel ID จาก Step 3
- `<YourUsername>` → ชื่อ User Windows ของคุณ
- `api-pos.yourdomain.com` → Domain ที่ต้องการใช้

---

## 🔗 Step 5: สร้าง DNS Record

```powershell
cloudflared tunnel route dns pos-mini api-pos.yourdomain.com
```

คำสั่งนี้จะสร้าง CNAME record ใน Cloudflare DNS อัตโนมัติ

---

## ▶️ Step 6: Run Tunnel (ทดสอบ)

```powershell
cloudflared tunnel run pos-mini
```

ถ้าเห็น:
```
INF Connection registered connIndex=0
INF Connection registered connIndex=1
INF Connection registered connIndex=2
INF Connection registered connIndex=3
```

แปลว่าสำเร็จ! 🎉

---

## 🔄 Step 7: ติดตั้งเป็น Windows Service (Run ตลอดเวลา)

```powershell
# ติดตั้งเป็น Service
cloudflared service install

# Start Service
cloudflared service start
```

ตรวจสอบสถานะ:
```powershell
Get-Service cloudflared
```

ควรแสดง `Running` ✅

---

## ✅ Step 8: ทดสอบการเชื่อมต่อ

### 1. สร้างไฟล์ทดสอบ `test.html`
```html
<!DOCTYPE html>
<html>
<head>
    <title>Test API</title>
</head>
<body>
    <h1>Cloudflare Tunnel Test</h1>
    <button onclick="testAPI()">Test API</button>
    <pre id="result"></pre>
    
    <script>
        function testAPI() {
            fetch('https://api-pos.yourdomain.com/health')
                .then(r => r.json())
                .then(data => {
                    document.getElementById('result').textContent = 
                        JSON.stringify(data, null, 2);
                })
                .catch(err => {
                    document.getElementById('result').textContent = 
                        'Error: ' + err.message;
                });
        }
    </script>
</body>
</html>
```

### 2. เปิด `test.html` ในเบราว์เซอร์
### 3. กดปุ่ม "Test API"
### 4. ถ้าได้ผลลัพธ์กลับมา → **สำเร็จ!** 🎉

---

## 🛑 หยุด Tunnel

```powershell
# หยุด Service
cloudflared service stop

# ลบ Service (ถ้าต้องการ)
cloudflared service uninstall
```

---

## 🔧 Troubleshooting

### ปัญหา: "cannot find tunnel"
**แก้ไข**: ตรวจสอบว่า `config.yml` มี Tunnel ID ถูกต้อง

### ปัญหา: "connection failed"
**แก้ไข**: 
1. ตรวจสอบว่า Backend API (port 8080) ทำงานอยู่
2. ตรวจสอบ Firewall (Windows Defender)

### ปัญหา: "DNS resolution failed"
**แก้ไข**: รอ DNS propagate (5-10 นาที)

---

## 📝 Next Steps

เมื่อติดตั้ง Tunnel สำเร็จแล้ว:
1. ✅ สร้าง Backend API (Dart Server) - ดูคู่มือถัดไป
2. ✅ ทดสอบการเรียก API จากภายนอก
3. ✅ เริ่มสร้าง Web POS Mini UI

---

## 💡 Tips

- **ใช้ Free Domain**: สามารถใช้ `.cloudflare.com` ฟรี (ไม่ต้องซื้อ Domain)
- **Monitor Tunnel**: ดูสถานะที่ https://dash.cloudflare.com
- **Logs**: ดู logs ที่ `C:\Users\<YourUsername>\.cloudflared\`

---

**พร้อมแล้วใช่ไหมคะ?** ลุยสร้าง Backend API ต่อเลย! 🚀
