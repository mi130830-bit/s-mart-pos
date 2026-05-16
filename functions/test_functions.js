const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('../firebase-service-account.json'); // ต้องมีไฟล์นี้

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function testNotifications() {
    console.log('🧪 Starting Cloud Functions Test...\n');

    try {
        // 1. สร้างหรือหางานทดสอบ
        const testJobId = 'test_job_' + Date.now();

        console.log('📝 Creating test job:', testJobId);

        // สร้างงานใหม่
        await db.collection('jobs').doc(testJobId).set({
            customer_id: 'test_customer',
            status: 'pending',
            created_at: admin.firestore.FieldValue.serverTimestamp(),
            order_id: 9999,
            test: true
        });

        console.log('✅ Test job created\n');

        // รอ 3 วินาที
        await new Promise(resolve => setTimeout(resolve, 3000));

        // 2. จำลอง Stage 2: ปล่อยรถ (shipping)
        console.log('🚚 Simulating Stage 2: Shipping...');
        await db.collection('jobs').doc(testJobId).update({
            status: 'shipping',
            updated_at: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log('✅ Updated status to "shipping"');
        console.log('   → Cloud Function "notifyShipping" should trigger now\n');

        // รอ 5 วินาที
        await new Promise(resolve => setTimeout(resolve, 5000));

        // 3. จำลอง Stage 3: จบงาน (completed)
        console.log('📦 Simulating Stage 3: Completed...');
        await db.collection('jobs').doc(testJobId).update({
            status: 'completed',
            updated_at: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log('✅ Updated status to "completed"');
        console.log('   → Cloud Function "notifyCompleted" should trigger now\n');

        // รอ 3 วินาที
        await new Promise(resolve => setTimeout(resolve, 3000));

        console.log('🎉 Test complete!');
        console.log('\nNext steps:');
        console.log('1. Check Firebase Functions logs:');
        console.log('   firebase functions:log --only notifyShipping,notifyCompleted');
        console.log('2. Or visit: https://console.firebase.google.com/project/fir-link-a8266/functions/logs');
        console.log('\nNote: Line messages will only be sent if customer has line_user_id');

    } catch (error) {
        console.error('❌ Error:', error);
    }

    process.exit(0);
}

testNotifications();
