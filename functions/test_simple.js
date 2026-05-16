// Simple test script - ใช้ Firebase Admin SDK อัปเดต Firestore
// รัน: node test_simple.js

const admin = require('firebase-admin');

// ใช้ Default credentials (ต้อง login ด้วย firebase login ก่อน)
admin.initializeApp({
    projectId: 'fir-link-a8266'
});

const db = admin.firestore();

async function testCloudFunctions() {
    console.log('🧪 Testing Cloud Functions...\n');

    try {
        // 1. หา job ที่มีอยู่แล้ว หรือสร้างใหม่
        const testJobRef = db.collection('jobs').doc('test_manual_' + Date.now());

        console.log('1️⃣ Creating test job...');
        await testJobRef.set({
            customer_id: 'test_customer_123',
            status: 'pending',
            order_id: 9999,
            created_at: new Date(),
            test: true
        });
        console.log('   ✅ Created job:', testJobRef.id, '\n');

        // รอ 2 วินาที
        console.log('⏳ Waiting 2 seconds...\n');
        await sleep(2000);

        // 2. อัปเดตเป็น "shipping" (Stage 2)
        console.log('2️⃣ Updating status to "shipping" (Stage 2)...');
        await testJobRef.update({
            status: 'shipping',
            is_departure_approved: true,
            updated_at: new Date()
        });
        console.log('   ✅ Updated to SHIPPING');
        console.log('   🔥 Cloud Function "notifyShipping" should trigger!\n');

        // รอ 5 วินาที
        console.log('⏳ Waiting 5 seconds for Cloud Function...\n');
        await sleep(5000);

        // 3. อัปเดตเป็น "completed" (Stage 3)
        console.log('3️⃣ Updating status to "completed" (Stage 3)...');
        await testJobRef.update({
            status: 'completed',
            updated_at: new Date()
        });
        console.log('   ✅ Updated to COMPLETED');
        console.log('   🔥 Cloud Function "notifyCompleted" should trigger!\n');

        // รอ 3 วินาที
        console.log('⏳ Waiting 3 seconds...\n');
        await sleep(3000);

        console.log('🎉 Test complete!\n');
        console.log('📊 Check logs with:');
        console.log('   firebase functions:log\n');
        console.log('⚠️  Note: Line messages will NOT be sent because');
        console.log('   test_customer_123 does not have line_user_id\n');
        console.log('💡 To test with real Line notification:');
        console.log('   1. Create real job from POS Desktop');
        console.log('   2. Use S-Link app to update status\n');

    } catch (error) {
        console.error('❌ Error:', error);
    }

    process.exit(0);
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

testCloudFunctions();
