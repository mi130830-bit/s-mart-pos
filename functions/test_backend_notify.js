const axios = require('axios');

// Config
const BACKEND_URL = 'https://pristine-loyce-lucratively.ngrok-free.dev'; // Ngrok URL ปัจจุบัน
const ORDER_ID = '1279'; // ใส่ Order ID ที่มีอยู่จริงใน MySQL และมี Line User ID

async function testNotifications() {
    console.log(`🧪 Testing Notifications for Order #${ORDER_ID}...`);
    console.log(`🌐 Backend: ${BACKEND_URL}`);

    // Test Stage 2
    try {
        console.log('\n🚚 Testing Stage 2 (Shipping)...');
        const res2 = await axios.post(`${BACKEND_URL}/api/v1/line/notify-stage2/${ORDER_ID}`);
        console.log('✅ Stage 2 Result:', res2.status, res2.data);
    } catch (e) {
        console.error('❌ Stage 2 Failed:', e.response ? e.response.data : e.message);
    }

    // Wait 2 seconds
    await new Promise(r => setTimeout(r, 2000));

    // Test Stage 3
    try {
        console.log('\n📦 Testing Stage 3 (Completed)...');
        const res3 = await axios.post(`${BACKEND_URL}/api/v1/line/notify-stage3/${ORDER_ID}`);
        console.log('✅ Stage 3 Result:', res3.status, res3.data);
    } catch (e) {
        console.error('❌ Stage 3 Failed:', e.response ? e.response.data : e.message);
    }
}

testNotifications();
