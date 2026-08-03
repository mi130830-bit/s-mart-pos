const mysql = require("mysql2/promise");
const http = require("http");

const DB = { host: "127.0.0.1", port: 3306, user: "admin", password: "1234", database: "sorborikan" };
const API_BASE = "http://127.0.0.1:8080/api/v1";

async function createTestJob(conn) {
  console.log("\n📦 Step 1: สร้าง Test Data ใน MySQL...");
  let customerId;
  const [existCust] = await conn.execute("SELECT id FROM customer WHERE name = 'ลูกค้าทดสอบ (Test)' LIMIT 1");
  if (existCust.length > 0) {
    customerId = existCust[0].id;
    console.log("  ✅ ใช้ Customer เดิม id=" + customerId);
  } else {
    const [custResult] = await conn.execute(
      "INSERT INTO customer (name, phone, address, lat, lng) VALUES ('ลูกค้าทดสอบ (Test)', '0812345678', '123 ถ.ทดสอบ อ.เมือง', 13.7367, 100.5232)"
    );
    customerId = custResult.insertId;
    console.log("  ✅ สร้าง Customer ใหม่ id=" + customerId);
  }
  const [orderResult] = await conn.execute(
    "INSERT INTO `order` (customerId, grandTotal, deliveryType, paymentMethod, note, status, createdAt) VALUES (?, 1500.00, 'delivery', 'cash', 'ทดสอบระบบ S-Link', 'pending', NOW())",
    [customerId]
  );
  const orderId = orderResult.insertId;
  console.log("  ✅ สร้าง Order id=" + orderId);
  await conn.execute(
    "INSERT INTO orderitem (orderId, productName, quantity, price, total) VALUES (?, 'ปูนซีเมนต์ (ทดสอบ)', 10, 150.00, 1500.00)",
    [orderId]
  );
  console.log("  ✅ เพิ่มสินค้า: ปูนซีเมนต์ x10 = 1,500 บาท");
  const fakeFirebaseId = "test_job_" + Date.now();
  await conn.execute(
    "INSERT INTO delivery_jobs (orderId, firebaseJobId, status, createdAt) VALUES (?, ?, 'PENDING', NOW())",
    [orderId, fakeFirebaseId]
  );
  console.log("  ✅ สร้าง delivery_job → firebaseId=" + fakeFirebaseId);
  return { orderId, fakeFirebaseId };
}

function callApi(path) {
  return new Promise((resolve, reject) => {
    const url = API_BASE + path;
    console.log("\n🌐 เรียก API: GET " + url);
    http.get(url, (res) => {
      let data = "";
      res.on("data", chunk => data += chunk);
      res.on("end", () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
        catch (e) { resolve({ status: res.statusCode, body: data }); }
      });
    }).on("error", reject);
  });
}

async function cleanupTestData(conn, orderId) {
  console.log("\n🧹 Step 3: ลบข้อมูลทดสอบออก...");
  await conn.execute("DELETE FROM delivery_jobs WHERE orderId = ?", [orderId]);
  await conn.execute("DELETE FROM orderitem WHERE orderId = ?", [orderId]);
  await conn.execute("DELETE FROM `order` WHERE id = ?", [orderId]);
  console.log("  ✅ ลบ Order #" + orderId + " และ Job ออกแล้ว (ไม่กระทบข้อมูลจริง)");
}

async function main() {
  console.log("🚀 ทดสอบระบบ Delivery Job (End-to-End)");
  console.log("==========================================");
  const conn = await mysql.createConnection(DB);
  let orderId;
  try {
    const { orderId: oid, fakeFirebaseId } = await createTestJob(conn);
    orderId = oid;
    console.log("\n📱 Step 2: ดึง Active Jobs ผ่าน API (จำลองฝั่ง S-Link คนขับรถ)...");
    const result = await callApi("/jobs/active");
    if (result.status === 200 && result.body.success) {
      const jobs = result.body.data;
      console.log("  📊 พบงานทั้งหมด " + jobs.length + " งานใน queue");
      const testJob = jobs.find(j => String(j.orderId) === String(orderId));
      if (testJob) {
        console.log("\n  🎉🎉 พบ Test Job สำเร็จ! รายละเอียดที่คนขับจะเห็นใน S-Link:");
        console.log("  ┌─────────────────────────────────────────");
        console.log("  │ orderId       : " + testJob.orderId);
        console.log("  │ firebaseJobId : " + testJob.firebaseJobId);
        console.log("  │ status        : " + testJob.status);
        console.log("  │ jobType       : " + testJob.jobType);
        console.log("  │ paymentMethod : " + testJob.paymentMethod);
        console.log("  │ totalAmount   : " + testJob.totalAmount + " บาท");
        console.log("  │ note          : " + testJob.note);
        console.log("  ├─── ข้อมูลลูกค้า ────────────────────────");
        console.log("  │ ชื่อ          : " + testJob.customer?.name);
        console.log("  │ โทร           : " + testJob.customer?.phone);
        console.log("  │ ที่อยู่        : " + testJob.customer?.address);
        console.log("  │ lat/lng       : " + testJob.customer?.lat + ", " + testJob.customer?.lng);
        console.log("  ├─── สินค้า ──────────────────────────────");
        (testJob.items || []).forEach((item, i) => {
          console.log("  │ [" + (i+1) + "] " + item.name + " x" + item.qty + " = " + item.total + " บาท");
        });
        console.log("  └─────────────────────────────────────────");
        console.log("\n  ✅✅✅ ระบบ Delivery Job ทำงานได้ปกติ!");
        console.log("  ✅✅✅ คนขับรถจะเห็นงานนี้ครบถ้วนใน S-Link!\n");
      } else {
        console.log("\n  ⚠️  ไม่พบ Test Job ในรายการ (orderId=" + orderId + ")");
        console.log("  → ลอง debug ดู jobs ที่ได้กลับมา:");
        console.log(JSON.stringify(jobs.slice(0, 3), null, 2));
      }
    } else {
      console.log("\n  ❌ API ตอบกลับ status=" + result.status);
      if (result.body && result.body.error) console.log("  error: " + result.body.error);
      console.log("  ⚠️  Backend (server.dart) อาจยังไม่ได้รันอยู่ครับ!");
    }
  } catch (err) {
    console.error("\n❌ Error:", err.message);
    if (err.code === "ECONNREFUSED") console.log("  ⚠️  ต่อ Backend ไม่ได้ — รัน server.dart ก่อนนะครับ!");
    else if (err.code === "ENOTFOUND") console.log("  ⚠️  หา Host ไม่เจอ");
    else console.log("  stack:", err.stack);
  } finally {
    if (orderId) await cleanupTestData(conn, orderId);
    await conn.end();
    console.log("==========================================");
    console.log("✅ ทดสอบเสร็จสิ้น!");
  }
}

main();
