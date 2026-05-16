const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

/**
 * Cloud Function: แจ้งเตือน Stage 2 (กำลังส่ง)
 * Trigger: เมื่อ jobs collection มีการอัปเดต status เป็น 'shipping' หรือ is_departure_approved = true
 */
exports.notifyShipping = functions.firestore
    .document('jobs/{jobId}')
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();

        const wasDepartureApproved = before.is_departure_approved === true;
        const isDepartureApproved = after.is_departure_approved === true;

        const wasNotShipping = !['shipping', 'enroute', 'en_route'].includes(before.status?.toLowerCase());
        const isNowShipping = ['shipping', 'enroute', 'en_route'].includes(after.status?.toLowerCase())
            || isDepartureApproved;
        const notCompleted = after.status?.toLowerCase() !== 'completed';

        const shouldTrigger = (wasNotShipping && isNowShipping && notCompleted)
            || (!wasDepartureApproved && isDepartureApproved && notCompleted);

        if (shouldTrigger && !before.stage2_notified) {
            console.log(`🚀 Stage 2 Trigger: Job ${context.params.jobId}`);

            try {
                // อัปเดตแฟล็กเพื่อไม่ให้แจ้งเตือนซ้ำ
                await change.after.ref.update({ stage2_notified: true });

                const orderId = after.order_id;
                if (!orderId) {
                    console.warn('⚠️ No order_id in job');
                    return null;
                }

                // เรียก Backend API
                // TODO: Update this URL every time Cloudflare Tunnel restarts (Quick Tunnel)
                const apiUrl = 'https://api.namecheap.work';
                const url = `${apiUrl}/api/v1/line/notify-stage2/${orderId}`;

                console.log(`📤 Calling Backend: POST ${url}`);

                const response = await axios.post(url, {}, {
                    headers: { 'Content-Type': 'application/json' },
                    timeout: 10000
                });

                console.log(`✅ Stage 2 Response: ${response.status} - ${response.data}`);
                return null;
            } catch (error) {
                console.error(`❌ Stage 2 Error: ${error.message}`);
                return null;
            }
        }

        return null;
    });

/**
 * Cloud Function: แจ้งเตือน Stage 3 (ส่งเสร็จ)
 * Trigger: เมื่อ jobs collection มีการอัปเดต status เป็น 'completed'
 */
exports.notifyCompleted = functions.firestore
    .document('jobs/{jobId}')
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();

        const wasNotCompleted = before.status?.toLowerCase() !== 'completed';
        const isNowCompleted = after.status?.toLowerCase() === 'completed';

        if (wasNotCompleted && isNowCompleted && !before.stage3_notified) {
            console.log(`🚀 Stage 3 Trigger: Job ${context.params.jobId}`);

            try {
                // อัปเดตแฟล็กเพื่อไม่ให้แจ้งเตือนซ้ำ
                await change.after.ref.update({ stage3_notified: true });

                const orderId = after.order_id;
                if (!orderId) {
                    console.warn('⚠️ No order_id in job');
                    return null;
                }

                // เรียก Backend API
                // TODO: Update this URL every time Cloudflare Tunnel restarts (Quick Tunnel)
                const apiUrl = 'https://api.namecheap.work';
                const url = `${apiUrl}/api/v1/line/notify-stage3/${orderId}`;

                console.log(`📤 Calling Backend: POST ${url}`);

                const payload = {
                    imageUrl: after.proof_image_url || null,
                    locationUrl: after.location_link || null
                };

                const response = await axios.post(url, payload, {
                    headers: { 'Content-Type': 'application/json' },
                    timeout: 10000
                });

                console.log(`✅ Stage 3 Response: ${response.status} - ${response.data}`);
                return null;
            } catch (error) {
                console.error(`❌ Stage 3 Error: ${error.message}`);
                return null;
            }
        }

        return null;
    });
