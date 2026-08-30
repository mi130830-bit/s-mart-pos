# Membership migration operations / การดูแล Migration สมาชิก

## English

On startup the backend applies migrations `20260825_001` through
`20260825_006` once and records them in `schema_migrations`. They add secure
LINE ownership, coupon reservation, idempotent redemption, paid-order loyalty
audits, and customer/contractor monthly tiers. The identity migration only backfills a LINE subject
when exactly one active customer owns it. Duplicate legacy subjects are not
changed; the server logs only their group count and never their identity.

Before deployment, back up MySQL and confirm the application account can run
`CREATE TABLE` and `INSERT`. If startup fails, keep the service offline, inspect
the database error, restore or correct permissions, then restart. Do not mark a
migration as applied manually.

## ภาษาไทย

เมื่อ Backend เริ่มทำงาน ระบบจะรัน Migration `20260825_001` ถึง
`20260825_006` เพียงครั้งเดียวและบันทึกใน `schema_migrations` เพื่อเพิ่มการผูก
LINE อย่างปลอดภัย การจองคูปอง การแลกรางวัลแบบไม่ซ้ำ บันทึกแต้มตามยอดชำระจริง
และระดับรายเดือนของลูกค้ากับช่าง ระบบจะย้ายข้อมูล LINE เดิมเฉพาะกรณีที่พบลูกค้าที่ใช้งานอยู่
เพียงหนึ่งรายเท่านั้น หากพบข้อมูลซ้ำจะไม่แก้ไขและบันทึก Log เฉพาะจำนวนกลุ่ม
โดยไม่เปิดเผยตัวตน

ก่อนติดตั้งให้สำรอง MySQL และตรวจว่าสิทธิ์ของบัญชีแอปรองรับ `CREATE TABLE`
และ `INSERT` หาก Migration ล้มเหลว ให้คง Backend ไว้ในสถานะปิด ตรวจสอบสาเหตุ
แก้สิทธิ์หรือกู้ฐานข้อมูล แล้วจึงเริ่มใหม่ ห้ามบันทึกว่า Migration สำเร็จด้วยมือ
