// สคริปต์ Debug - เช็คข้อมูลใน Firestore
// รัน: node debug_firestore.js ddYz9nbhZIkKgXwIrs4q

const admin = require('firebase-admin');

// Init Firebase
admin.initializeApp({
    projectId: 'fir-link-a8266'
});

const db = admin.firestore();

async function debugJob(jobId) {
    console.log('🔍 Debugging Job:', jobId, '\n');

    try {
        // 1. ดึงข้อมูล Job
        const jobDoc = await db.collection('jobs').doc(jobId).get();

        if (!jobDoc.exists) {
            console.error('❌ Job not found!');
            return;
        }

        const jobData = jobDoc.data();
        console.log('📦 Job Data:');
        console.log('   status:', jobData.status);
        console.log('   customer_id:', jobData.customer_id);
        console.log('   order_id:', jobData.order_id);
        console.log('');

        // 2. ดึงข้อมูล Customer
        if (jobData.customer_id) {
            const customerDoc = await db.collection('customers').doc(jobData.customer_id).get();

            if (!customerDoc.exists) {
                console.error('❌ Customer not found!');
                return;
            }

            const customerData = customerDoc.data();
            console.log('👤 Customer Data:');
            console.log('   name:', customerData.name);
            console.log('   phone:', customerData.phone);
            console.log('   line_user_id:', customerData.line_user_id || '❌ MISSING!');
            console.log('');

            if (!customerData.line_user_id) {
                console.error('⚠️  PROBLEM FOUND: Customer does not have line_user_id!');
                console.log('   This is why Line notifications are not being sent.\n');
            } else {
                console.log('✅ Customer has line_user_id\n');
            }
        } else {
            console.error('❌ Job does not have customer_id!');
        }

    } catch (error) {
        console.error('❌ Error:', error);
    }

    process.exit(0);
}

// รับ Job ID จาก argument
const jobId = process.argv[2] || 'ddYz9nbhZIkKgXwIrs4q';
debugJob(jobId);
