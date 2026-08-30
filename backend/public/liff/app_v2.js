const LIFF_ID = "2009815377-VjmykeWs";
const REWARD_CATALOG_API = "/api/v1/rewards";
const MEMBER_API = "/api/v1/rewards-member";
const MEMBERSHIP_API = "/api/v1/membership-member";

// State
let currentUser = null;
let currentRewards = [];
let activeTab = 'catalog'; // 'catalog' | 'coupons' | 'history'

document.addEventListener("DOMContentLoaded", () => {
    initializeLiff();
    document.getElementById('retry-btn').addEventListener('click', loadData);
    document.getElementById('submit-reg-btn').addEventListener('click', submitRegistration);
    document.getElementById('tab-catalog').addEventListener('click', () => switchTab('catalog'));
    document.getElementById('tab-coupons').addEventListener('click', () => switchTab('coupons'));
    document.getElementById('tab-history').addEventListener('click', () => switchTab('history'));
});

async function initializeLiff() {
    try {
        if (LIFF_ID === "YOUR_LIFF_ID_HERE") {
            showError("ยังไม่ได้ตั้งค่า LIFF ID ในไฟล์ app.js");
            return;
        }
        await liff.init({ liffId: LIFF_ID });
        if (!liff.isLoggedIn()) {
            liff.login();
            return;
        }
        await consumePairingFromUrl();
        await loadData();
    } catch (err) {
        console.error("LIFF Initialization failed", err);
        showError("ไม่สามารถเชื่อมต่อกับ LINE ได้: " + err.message);
    }
}

async function loadData() {
    showLoading();
    try {
        const profile = await liff.getProfile();
        const customerRes = await fetch(`${MEMBER_API}/me`, {
            headers: liffAuthHeaders()
        });
        if (!customerRes.ok) {
            showRegistrationForm(profile.displayName);
            return;
        }
        currentUser = await customerRes.json();

        document.getElementById('profile-img').src = profile.pictureUrl || 'https://via.placeholder.com/150';
        document.getElementById('profile-name').textContent = currentUser.name;
        document.getElementById('user-points').textContent = parseInt(currentUser.currentPoints || 0).toLocaleString();

        document.getElementById('tab-bar').classList.remove('hidden');

        if (activeTab === 'catalog') {
            await loadCatalog();
        } else if (activeTab === 'coupons') {
            await loadCoupons();
        } else if (activeTab === 'history') {
            await loadHistory();
        }

    } catch (err) {
        console.error("Load Data Error:", err);
        showError("เกิดข้อผิดพลาด กรุณาปิดแล้วเปิดใหม่อีกครั้งครับ\n(" + err.message + ")");
    }
}


async function loadCatalog() {
    const rewardsRes = await fetch(REWARD_CATALOG_API);
    if (!rewardsRes.ok) throw new Error("ไม่สามารถโหลดรายการของรางวัลได้");
    currentRewards = await rewardsRes.json();
    renderRewards();
}

async function loadCoupons() {
    hideLoading();
    const grid = document.getElementById('rewards-grid');
    grid.innerHTML = '<div class="loading-inline"><div class="spinner-sm"></div></div>';
    grid.classList.remove('hidden');
    try {
        const res = await fetch(`${MEMBER_API}/my-coupons`, { headers: liffAuthHeaders() });
        const coupons = await res.json();
        renderCoupons(coupons);
    } catch (e) {
        grid.innerHTML = `<p style="text-align:center;color:var(--text-muted)">ไม่สามารถโหลดคูปองได้</p>`;
    }
}

async function loadHistory() {
    hideLoading();
    const grid = document.getElementById('rewards-grid');
    grid.innerHTML = '<div class="loading-inline"><div class="spinner-sm"></div></div>';
    grid.classList.remove('hidden');
    try {
        const res = await fetch(`${MEMBER_API}/my-history`, { headers: liffAuthHeaders() });
        const history = await res.json();
        renderHistory(history);
    } catch (e) {
        grid.innerHTML = `<p style="text-align:center;color:var(--text-muted)">ไม่สามารถโหลดประวัติได้</p>`;
    }
}

function switchTab(tab) {
    activeTab = tab;
    ['catalog', 'coupons', 'history'].forEach(t => {
        document.getElementById(`tab-${t}`).classList.toggle('active', t === tab);
    });
    if (currentUser) {
        showLoading();
        if (tab === 'catalog') loadCatalog();
        else if (tab === 'coupons') loadCoupons();
        else if (tab === 'history') loadHistory();
    }
}

function renderRewards() {
    const grid = document.getElementById('rewards-grid');
    grid.innerHTML = '';
    hideLoading();
    if (currentRewards.length === 0) {
        grid.innerHTML = `<div style="grid-column: 1 / -1; text-align: center; padding: 40px; color: var(--text-muted);"><div style="font-size: 40px; margin-bottom: 10px;">🎁</div><p>ขณะนี้ยังไม่มีของรางวัลเปิดให้แลก</p></div>`;
        grid.classList.remove('hidden');
        return;
    }
    currentRewards.forEach(reward => {
        const canAfford = currentUser.currentPoints >= reward.point_price;
        const isCoupon = reward.reward_type === 'COUPON';
        const btnClass = canAfford ? 'btn-redeem' : 'btn-redeem btn-disabled';
        const btnText = canAfford ? 'แลกรางวัล' : 'แต้มไม่พอ';
        const imageUrl = reward.image_url ? `/public${reward.image_url}` : 'https://via.placeholder.com/300x200?text=No+Image';
        const typeBadge = isCoupon ? `<span class="coupon-badge">🎟️ คูปองลด ฿${parseFloat(reward.discount_value).toFixed(0)}</span>` : '';

        const card = document.createElement('div');
        card.className = 'reward-card glass';
        card.innerHTML = `
            <div class="reward-image-wrapper">
                <img src="${imageUrl}" alt="${reward.name}" class="reward-image" onerror="this.src='https://via.placeholder.com/300x200?text=No+Image'">
                <div class="stock-badge">เหลือ ${reward.stock_quantity}</div>
                ${typeBadge}
            </div>
            <div class="reward-details">
                <h4 class="reward-name">${reward.name}</h4>
                <p class="reward-desc">${reward.description || ''}</p>
                <div class="reward-footer">
                    <div class="reward-cost">
                        <span class="crystal-icon">💎</span>
                        <span>${parseInt(reward.point_price).toLocaleString()}</span>
                    </div>
                    <button class="${btnClass}" ${!canAfford ? 'disabled' : ''} onclick="confirmRedeem(${reward.id}, '${reward.name}', ${reward.point_price}, '${reward.reward_type}', ${reward.discount_value || 0})">
                        ${btnText}
                    </button>
                </div>
            </div>
        `;
        grid.appendChild(card);
    });
    grid.classList.remove('hidden');
}

function renderCoupons(coupons) {
    const grid = document.getElementById('rewards-grid');
    grid.innerHTML = '';
    if (!coupons || coupons.length === 0) {
        grid.innerHTML = `<div style="text-align:center;padding:40px;color:var(--text-muted)"><div style="font-size:48px;margin-bottom:16px">🎟️</div><p>คุณยังไม่มีคูปองในขณะนี้</p><p style="font-size:12px;margin-top:8px">แลกแต้มเพื่อรับคูปองส่วนลด</p></div>`;
        grid.classList.remove('hidden');
        return;
    }
    coupons.forEach(coupon => {
        const isActive = coupon.status === 'ACTIVE';
        const isUsed = coupon.status === 'USED';
        const expiresDate = coupon.expires_at ? new Date(coupon.expires_at).toLocaleDateString('th-TH', { day: 'numeric', month: 'short', year: 'numeric' }) : '-';
        const discount = parseFloat(coupon.discount_value || 0).toFixed(0);

        const card = document.createElement('div');
        card.className = `coupon-card glass ${!isActive ? 'coupon-inactive' : ''}`;
        card.innerHTML = `
            <div class="coupon-header">
                <div class="coupon-icon">🎟️</div>
                <div>
                    <div class="coupon-name">${coupon.reward_name || 'คูปองส่วนลด'}</div>
                    <div class="coupon-discount">ลด ฿${discount}</div>
                </div>
                <span class="coupon-status-badge ${isActive ? 'status-active' : isUsed ? 'status-used' : 'status-expired'}">
                    ${isActive ? 'ใช้ได้' : isUsed ? 'ใช้แล้ว' : 'หมดอายุ'}
                </span>
            </div>
            ${isActive ? `
            <div class="coupon-qr-wrapper">
                <img src="https://api.qrserver.com/v1/create-qr-code/?size=160x160&margin=0&color=0f172a&bgcolor=ffffff&data=${encodeURIComponent(coupon.coupon_code)}" class="coupon-qr" alt="QR Code">
                <div class="coupon-code-text">${coupon.coupon_code}</div>
            </div>
            ` : `<div class="coupon-qr-wrapper"><div class="coupon-code-text" style="opacity:0.4">${coupon.coupon_code}</div></div>`}
            <div class="coupon-footer">
                <span>📅 ${isUsed ? `ใช้แล้ว` : `หมดอายุ ${expiresDate}`}</span>
            </div>
        `;
        grid.appendChild(card);


    });
    grid.classList.remove('hidden');
}

function renderHistory(history) {
    const grid = document.getElementById('rewards-grid');
    grid.innerHTML = '';
    if (!history || history.length === 0) {
        grid.innerHTML = `<div style="text-align:center;padding:40px;color:var(--text-muted)"><div style="font-size:48px;margin-bottom:16px">📋</div><p>ยังไม่มีประวัติการแลกรางวัล</p></div>`;
        grid.classList.remove('hidden');
        return;
    }
    history.forEach(item => {
        const date = item.redeemed_at ? new Date(item.redeemed_at).toLocaleDateString('th-TH', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '-';
        const isFulfilled = item.status === 'FULFILLED';
        const isCoupon = item.reward_type === 'COUPON';
        const couponUsed = item.coupon_status === 'USED';

        let statusBadge = '';
        if (isCoupon) {
            statusBadge = couponUsed
                ? `<span class="history-badge badge-done">ใช้แล้ว ✅</span>`
                : item.coupon_status === 'EXPIRED'
                    ? `<span class="history-badge badge-expired">หมดอายุ</span>`
                    : `<span class="history-badge badge-pending">รอใช้งาน 🎟️</span>`;
        } else {
            statusBadge = isFulfilled
                ? `<span class="history-badge badge-done">ได้รับแล้ว ✅</span>`
                : `<span class="history-badge badge-pending">รอรับของ 🟡</span>`;
        }

        const div = document.createElement('div');
        div.className = 'history-item glass';
        div.innerHTML = `
            <div class="history-icon">${isCoupon ? '🎟️' : '🎁'}</div>
            <div class="history-info">
                <div class="history-name">${item.reward_name || '-'}</div>
                <div class="history-date">${date}</div>
            </div>
            <div class="history-right">
                <div class="history-points">-${item.points_used} 💎</div>
                ${statusBadge}
            </div>
        `;
        grid.appendChild(div);
    });
    grid.classList.remove('hidden');
}

function confirmRedeem(rewardId, rewardName, pointPrice, rewardType, discountValue) {
    const isCoupon = rewardType === 'COUPON';
    const typeNote = isCoupon ? `<br><small style="color:var(--gold-color)">🎟️ คุณจะได้รับคูปองส่วนลด ฿${parseFloat(discountValue).toFixed(0)}</small>` : '';
    Swal.fire({
        title: 'ยืนยันการแลกรางวัล',
        html: `คุณต้องการใช้ <b>${parseInt(pointPrice).toLocaleString()} คริสตัล</b><br>เพื่อแลกรับ <b>${rewardName}</b> ใช่หรือไม่?${typeNote}`,
        icon: 'question',
        showCancelButton: true,
        confirmButtonColor: '#f59e0b',
        cancelButtonColor: '#64748b',
        confirmButtonText: 'ยืนยันการแลก',
        cancelButtonText: 'ยกเลิก',
        background: '#1e293b',
        color: '#f8fafc',
        reverseButtons: true
    }).then(result => {
        if (result.isConfirmed) processRedemption(rewardId, rewardType);
    });
}

async function processRedemption(rewardId, rewardType) {
    Swal.fire({ title: 'กำลังดำเนินการ...', allowOutsideClick: false, background: '#1e293b', color: '#f8fafc', didOpen: () => Swal.showLoading() });
    try {
        const response = await fetch(`${MEMBER_API}/redeem`, {
            method: 'POST',
            headers: liffAuthHeaders(true),
            body: JSON.stringify({ rewardId })
        });
        const data = await response.json();
        if (response.ok && data.success) {
            currentUser.currentPoints = data.remainingPoints;
            document.getElementById('user-points').textContent = parseInt(data.remainingPoints).toLocaleString();

            if (data.rewardType === 'COUPON' && data.couponCode) {
                // Show coupon code immediately
                Swal.fire({
                    title: '🎟️ ได้รับคูปองแล้ว!',
                    html: `<p>คูปองส่วนลด <b>฿${parseFloat(data.discountValue).toFixed(0)}</b></p>
                           <div style="margin:16px 0;font-size:24px;font-weight:bold;letter-spacing:4px;color:#f59e0b">${data.couponCode}</div>
                           <p style="font-size:13px;color:#94a3b8">ดูคูปอง QR ได้ที่แท็บ "คูปองของฉัน"</p>`,
                    icon: 'success',
                    background: '#1e293b',
                    color: '#f8fafc',
                    confirmButtonColor: '#f59e0b',
                    confirmButtonText: 'ดูคูปองของฉัน',
                }).then(() => {
                    switchTab('coupons');
                    loadData();
                });
            } else {
                Swal.fire({
                    title: 'สำเร็จ!',
                    text: 'แลกรางวัลเรียบร้อยแล้ว กดยืนยันเพื่อกลับสู่หน้าแรก',
                    icon: 'success',
                    background: '#1e293b',
                    color: '#f8fafc',
                    confirmButtonColor: '#10b981'
                }).then(() => loadData());
            }
        } else {
            throw new Error(data.error || 'เกิดข้อผิดพลาดไม่ทราบสาเหตุ');
        }
    } catch (err) {
        Swal.fire({ title: 'ผิดพลาด', text: err.message, icon: 'error', background: '#1e293b', color: '#f8fafc', confirmButtonColor: '#ef4444' });
    }
}

function showRegistrationForm(displayName) {
    hideLoading();
    document.getElementById('tab-bar').classList.add('hidden');
    document.getElementById('profile-name').textContent = "ต้องการเชื่อมต่อสมาชิก?";
    document.getElementById('reg-name').value = displayName || "";
    document.getElementById('registration-form').classList.remove('hidden');
    document.getElementById('rewards-grid').classList.add('hidden');
}

async function submitRegistration() {
    const phone = document.getElementById('reg-phone').value.trim();
    const name = document.getElementById('reg-name').value.trim();
    const address = document.getElementById('reg-address')?.value.trim() || '';
    const shippingAddress = document.getElementById('reg-shipping-address')?.value.trim() || '';
    if (!phone || phone.length < 10) {
        Swal.fire({ icon: 'warning', title: 'ข้อมูลไม่ครบ', text: 'กรุณากรอกเบอร์โทรศัพท์ 10 หลัก', background: '#1e293b', color: '#f8fafc' });
        return;
    }
    Swal.fire({ title: 'กำลังเชื่อมต่อ...', allowOutsideClick: false, background: '#1e293b', color: '#f8fafc', didOpen: () => Swal.showLoading() });
    try {
        const requestUuid = membershipRequestUuid();
        const response = await fetch(`${MEMBERSHIP_API}/signup`, {
            method: 'POST',
            headers: liffAuthHeaders(true),
            body: JSON.stringify({ phone, name, address, shippingAddress, requestUuid })
        });
        const result = await response.json();
        if (response.status === 202 && result.success) {
            localStorage.removeItem('membership_signup_request_uuid');
            Swal.fire({
                icon: 'info',
                title: 'ส่งคำขอแล้ว',
                text: result.message || 'พนักงานจะตรวจสอบสมาชิกเดิมให้ครับ',
                background: '#1e293b',
                color: '#f8fafc'
            });
        } else if (response.ok && result.success) {
            localStorage.removeItem('membership_signup_request_uuid');
            Swal.fire({ icon: 'success', title: 'สำเร็จ!', text: result.message, background: '#1e293b', color: '#f8fafc' }).then(() => {
                document.getElementById('registration-form').classList.add('hidden');
                loadData();
            });
        } else {
            throw new Error(result.error || 'เกิดข้อผิดพลาดในการเชื่อมต่อ');
        }
    } catch (err) {
        Swal.fire({ icon: 'error', title: 'ผิดพลาด', text: err.message, background: '#1e293b', color: '#f8fafc' });
    }
}

function membershipRequestUuid() {
    let value = localStorage.getItem('membership_signup_request_uuid');
    const validUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!value || !validUuid.test(value)) {
        value = (window.crypto && window.crypto.randomUUID)
            ? window.crypto.randomUUID()
            : fallbackUuidV4();
        localStorage.setItem('membership_signup_request_uuid', value);
    }
    return value;
}

function fallbackUuidV4() {
    const bytes = new Uint8Array(16);
    if (window.crypto && window.crypto.getRandomValues) {
        window.crypto.getRandomValues(bytes);
    } else {
        for (let index = 0; index < bytes.length; index += 1) {
            bytes[index] = Math.floor(Math.random() * 256);
        }
    }
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    const hex = Array.from(bytes, byte => byte.toString(16).padStart(2, '0')).join('');
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

async function consumePairingFromUrl() {
    const params = new URLSearchParams(window.location.search);
    const token = params.get('pair');
    if (!token) return;
    try {
        const response = await fetch(`${MEMBERSHIP_API}/pairing/consume`, {
            method: 'POST',
            headers: liffAuthHeaders(true),
            body: JSON.stringify({ token })
        });
        const result = await response.json();
        if (!response.ok || !result.success) {
            throw new Error(result.error || 'QR นี้ไม่สามารถใช้งานได้');
        }
        params.delete('pair');
        const query = params.toString();
        history.replaceState({}, '', `${window.location.pathname}${query ? `?${query}` : ''}${window.location.hash}`);
        await Swal.fire({
            icon: 'success',
            title: 'ผูกสมาชิกสำเร็จ',
            text: 'บัญชี LINE นี้เชื่อมกับสมาชิกเรียบร้อยแล้ว',
            background: '#1e293b',
            color: '#f8fafc'
        });
    } catch (err) {
        await Swal.fire({
            icon: 'error',
            title: 'ไม่สามารถใช้ QR ได้',
            text: err.message,
            background: '#1e293b',
            color: '#f8fafc'
        });
    }
}

function liffAuthHeaders(includeJson = false) {
    const token = liff.getIDToken();
    const headers = token ? { Authorization: `Bearer ${token}` } : {};
    if (includeJson) headers['Content-Type'] = 'application/json';
    return headers;
}

function showLoading() {
    document.getElementById('loading-spinner').classList.remove('hidden');
    document.getElementById('rewards-grid').classList.add('hidden');
    document.getElementById('error-message').classList.add('hidden');
    document.getElementById('registration-form').classList.add('hidden');
}

function hideLoading() {
    document.getElementById('loading-spinner').classList.add('hidden');
}

function showError(message) {
    hideLoading();
    document.getElementById('tab-bar').classList.add('hidden');
    document.getElementById('rewards-grid').classList.add('hidden');
    const errorContainer = document.getElementById('error-message');
    document.getElementById('error-text').textContent = message;
    errorContainer.classList.remove('hidden');
}
