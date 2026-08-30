# Backend security configuration / การตั้งค่าความปลอดภัย Backend

These environment variables are required before enabling the protected LINE
and staff routes. Missing values cause protected requests to fail closed.

ต้องตั้งค่าตัวแปรเหล่านี้ก่อนเปิดใช้เส้นทาง LINE และเส้นทางพนักงานที่ได้รับ
การป้องกัน หากไม่มีค่า ระบบจะปฏิเสธคำขอเพื่อความปลอดภัย

```dotenv
LINE_LOGIN_CHANNEL_ID=
LINE_CHANNEL_SECRET=
LINE_CHANNEL_TOKEN=
JWT_ACCESS_SECRET=
JWT_REFRESH_SECRET=
INTERNAL_API_SECRET=
```

`INTERNAL_API_SECRET` must be the same strong random value in the backend,
desktop POS process, and delivery Cloud Functions. Only loopback requests may
omit it. Rotate it together across all services; never put it in web pages or
MySQL.

`INTERNAL_API_SECRET` ต้องเป็นค่าสุ่มที่ยาวและตรงกันใน Backend, โปรแกรม POS
และ Cloud Functions งานจัดส่ง ยกเว้นคำขอภายในเครื่องเดียวกันเท่านั้นที่ไม่ต้อง
ส่งค่านี้ การเปลี่ยนคีย์ต้องเปลี่ยนพร้อมกันทุกบริการ และห้ามใส่คีย์ในหน้าเว็บ
หรือฐานข้อมูล MySQL

Never commit real values. Restart the backend after changing the environment.
ห้ามบันทึกค่าจริงลง Git และให้รีสตาร์ต Backend หลังแก้ไขค่า environment
