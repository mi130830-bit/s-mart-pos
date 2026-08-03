/**
 * migrate_users_to_mysql.js
 * ดึงข้อมูล Users จาก Firestore แล้วสร้างใน MySQL
 * รัน: node migrate_users_to_mysql.js
 */

const https = require('https');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');

const FIREBASE_PROJECT_ID = 'fir-link-a8266';
const FIREBASE_API_KEY    = 'AIzaSyAgZBvyhGZ8xMzYoKWHgxmhPeRxv2_ISaw';
const DEFAULT_PASSWORD    = '123456';

const DB_CONFIG = {
  host: '127.0.0.1', port: 3306,
  user: 'admin', password: '1234', database: 'sorborikan',
};

function mapRole(r) {
  if (!r) return 'CASHIER';
  if (r.toLowerCase() === 'admin') return 'ADMIN';
  return 'CASHIER';
}

async function fetchFirestoreUsers() {
  return new Promise((resolve, reject) => {
    const url = 'https://firestore.googleapis.com/v1/projects/' + FIREBASE_PROJECT_ID + '/databases/(default)/documents/users?pageSize=300&key=' + FIREBASE_API_KEY;
    https.get(url, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => { try { resolve(JSON.parse(data)); } catch(e) { reject(e); } });
    }).on('error', reject);
  });
}

function extractField(f) {
  if (!f) return null;
  if (f.stringValue !== undefined) return f.stringValue;
  if (f.integerValue !== undefined) return f.integerValue;
  return null;
}

async function main() {
  console.log('Fetching users from Firestore...');
  const fsResult = await fetchFirestoreUsers();
  const docs = fsResult.documents || [];
  console.log('Found ' + docs.length + ' users\n');

  const conn = await mysql.createConnection(DB_CONFIG);
  const salt = await bcrypt.genSalt(10);
  const defaultHash = await bcrypt.hash(DEFAULT_PASSWORD, salt);

  let created = 0, skipped = 0;
  for (const doc of docs) {
    const fields = doc.fields || {};
    const name    = extractField(fields.name) || extractField(fields.displayName) || 'Unknown';
    const email   = extractField(fields.email) || '';
    const role    = mapRole(extractField(fields.role));
    const docId   = doc.name.split('/').pop();
    let username  = email.includes('@') ? email.split('@')[0] : email;
    if (!username) username = 'user_' + docId.substring(0, 8);

    const [existing] = await conn.execute('SELECT id FROM user WHERE username = ?', [username]);
    if (existing.length > 0) { console.log('SKIP: ' + username); skipped++; continue; }

    const [r] = await conn.execute(
      'INSERT INTO user (username, passwordHash, displayName, role, isActive) VALUES (?, ?, ?, ?, 1)',
      [username, defaultHash, name, role]
    );
    console.log('CREATED: ' + username + ' (' + name + ') id=' + r.insertId);
    created++;
  }
  await conn.end();
  console.log('\nDone! created=' + created + ' skipped=' + skipped);
  console.log('Default password: ' + DEFAULT_PASSWORD);
}

main().catch(e => { console.error(e); process.exit(1); });
