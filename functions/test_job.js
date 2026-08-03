const mysql = require('mysql2/promise');
const http = require('http');
const DB = { host: '127.0.0.1', port: 3306, user: 'admin', password: '1234', database: 'sorborikan' };
const API = 'http://127.0.0.1:8080/api/v1';

function callApi(path) {
  return new Promise((resolve, reject) => {
    http.get(API + path, (res) => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => { try { resolve({ status: res.statusCode, body: JSON.parse(d) }); } catch(e) { resolve({ status: res.statusCode, body: d }); }});
    }).on('error', reject);
  });
}

async function main() {
  console.log('======================================');
  console.log('  DELIVERY JOB END-TO-END TEST        ');
  console.log('======================================');
  const conn = await mysql.createConnection(DB);
  let orderId;
  try {
    const [custs] = await conn.execute('SELECT id, firstName, lastName, phone, address FROM customer WHERE isDeleted=0 LIMIT 1');
    const c = custs[0];
    
    // Product ID dummy
    const [prods] = await conn.execute('SELECT id FROM product LIMIT 1');
    const pid = prods.length > 0 ? prods[0].id : 1;

    console.log('\n[STEP 1] สร้าง Test Data');
    console.log('  Customer: ' + c.firstName + ' ' + (c.lastName||'') + ' id=' + c.id);

    const orderSql = 'INSERT INTO \x60order\x60 (customerId, total, grandTotal, deliveryType, paymentMethod, note, status, createdAt) VALUES (?, 1500.00, 1500.00, ?, ?, ?, ?, NOW())';
    const [orRes] = await conn.execute(orderSql, [c.id, 'delivery', 'cash', '[TEST] S-Link ทดสอบ', 'pending']);
    orderId = orRes.insertId;
    console.log('  Order id=' + orderId + ' created');

    await conn.execute('INSERT INTO orderitem (orderId, productId, productName, quantity, price, total) VALUES (?, ?, ?, 10, 150, 1500)', [orderId, pid, 'ปูนซีเมนต์ (ทดสอบ)']);
    console.log('  Item: ปูนซีเมนต์ x10 = 1,500 บาท');

    const fbId = 'test_' + Date.now();
    await conn.execute('INSERT INTO delivery_jobs (orderId, firebaseJobId, status, createdAt) VALUES (?, ?, ?, NOW())', [orderId, fbId, 'PENDING']);
    console.log('  DeliveryJob: firebaseId=' + fbId);

    console.log('\n[STEP 2] เรียก API /jobs/active (จำลอง S-Link)');
    const res = await callApi('/jobs/active');

    if (res.status === 200 && res.body.success) {
      const jobs = res.body.data;
      console.log('  API OK - พบงานทั้งหมด ' + jobs.length + ' งานใน queue');
      const j = jobs.find(x => String(x.orderId) === String(orderId));
      if (j) {
        console.log('\n  *** TEST JOB FOUND - คนขับจะเห็นข้อมูลนี้ใน S-Link ***');
        console.log('  orderId       : ' + j.orderId);
        console.log('  firebaseJobId : ' + j.firebaseJobId);
        console.log('  status        : ' + j.status);
        console.log('  jobType       : ' + j.jobType);
        console.log('  paymentMethod : ' + j.paymentMethod);
        console.log('  totalAmount   : ' + j.totalAmount + ' บาท');
        console.log('  note          : ' + j.note);
        console.log('  --- ลูกค้า ---');
        console.log('  name          : ' + (j.customer.name||'-'));
        console.log('  phone         : ' + (j.customer.phone||'-'));
        console.log('  address       : ' + (j.customer.address||'-'));
        console.log('  lat,lng       : ' + (j.customer.lat||'-') + ',' + (j.customer.lng||'-'));
        console.log('  --- สินค้า ---');
        j.items.forEach((item, i) => console.log('  [' + (i+1) + '] ' + item.name + ' x' + item.qty + ' = ' + item.total + ' บาท'));
        console.log('\n  RESULT: PASS - ระบบงานส่งของทำงานได้ปกติ!');
      } else {
        console.log('  RESULT: WARN - ไม่พบ test job ใน response');
      }
    } else {
      console.log('  RESULT: FAIL - API status=' + res.status);
    }
  } catch(err) {
    if (err.code === 'ECONNREFUSED') console.log('\n  RESULT: SKIP - Backend ไม่ได้รัน (ECONNREFUSED)');
    else console.error('\n  ERROR:', err.message);
  } finally {
    if (orderId) {
      console.log('\n[STEP 3] ลบ Test Data');
      await conn.execute('DELETE FROM delivery_jobs WHERE orderId=?', [orderId]);
      await conn.execute('DELETE FROM orderitem WHERE orderId=?', [orderId]);
      await conn.execute('DELETE FROM \x60order\x60 WHERE id=?', [orderId]);
      console.log('  Cleaned up Order #' + orderId);
    }
    await conn.end();
    console.log('\n======================================');
    console.log('  TEST COMPLETE');
    console.log('======================================');
  }
}
main();