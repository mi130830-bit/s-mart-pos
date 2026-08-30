/* ==========================================================================
   MEMBER & LINE LIFF AUTH MODULE (Multi-Channel Login & Session Persistence)
   ========================================================================== */

const LIFF_ID = "2009815377-VjmykeWs";
const MEMBER_PROFILE_STORAGE_KEY = "smartpos_shop_member_profile";
const MEMBER_TOKEN_STORAGE_KEY = "smartpos_shop_liff_token";

async function initLiffAuth() {
    // 1. Instant Session Hydration from LocalStorage (เปิดค้างไว้ / รีเฟรชก็ยังจำได้ 100%)
    loadSavedMemberSession();

    // 2. LIFF Silent Auth (เมื่อเปิดใน LINE OA หรือผ่าน LINE In-App Browser)
    try {
        if (typeof liff === "undefined") {
            console.log("LIFF SDK not available, running in guest / saved session mode.");
            updateUserUI();
            return;
        }

        await liff.init({ liffId: LIFF_ID });

        if (liff.isLoggedIn()) {
            liffIdToken = liff.getIDToken();
            if (liffIdToken) {
                localStorage.setItem(MEMBER_TOKEN_STORAGE_KEY, liffIdToken);
            }
            const profile = await liff.getProfile();
            currentUser.lineUserId = profile.userId;
            currentUser.lineDisplayName = profile.displayName;
            currentUser.linePictureUrl = profile.pictureUrl || "";
            currentUser.name = profile.displayName;
            currentUser.isLoggedIn = true;

            await fetchCustomerProfile();
        } else {
            console.log("User is guest / external browser");
            updateUserUI();
        }
    } catch (err) {
        console.warn("LIFF initialization error / fallback to saved session:", err);
        updateUserUI();
    }
}

function liffBearerHeaders(includeJson = false) {
    const headers = {};
    const token = liffIdToken || localStorage.getItem(MEMBER_TOKEN_STORAGE_KEY);
    if (token) headers.Authorization = `Bearer ${token}`;
    if (includeJson) headers["Content-Type"] = "application/json";
    return headers;
}

function loadSavedMemberSession() {
    try {
        const saved = localStorage.getItem(MEMBER_PROFILE_STORAGE_KEY);
        if (saved) {
            const parsed = JSON.parse(saved);
            if (parsed && (parsed.name || parsed.phone)) {
                currentUser = { ...currentUser, ...parsed, isLoggedIn: true };
                currentMember = parsed;
                prefillCustomerForm(currentUser);
                updateUserUI();
            }
        }
    } catch (e) {
        console.warn("Error reading member session from storage:", e);
    }
}

function saveMemberSession(memberData) {
    try {
        localStorage.setItem(MEMBER_PROFILE_STORAGE_KEY, JSON.stringify(memberData));
    } catch (e) {}
}

function clearMemberSession() {
    try {
        localStorage.removeItem(MEMBER_PROFILE_STORAGE_KEY);
        localStorage.removeItem(MEMBER_TOKEN_STORAGE_KEY);
        liffIdToken = null;
        currentMember = null;
        currentUser = {
            lineUserId: "",
            lineDisplayName: "",
            linePictureUrl: "",
            name: "",
            phone: "",
            address: "",
            memberTier: "ลูกค้าทั่วไป",
            points: 0,
            isLoggedIn: false
        };
        updateUserUI();
        renderMemberHome();
    } catch (e) {}
}

async function fetchCustomerProfile() {
    try {
        const res = await fetch(`/api/v1/shop-member/me`, {
            headers: liffBearerHeaders()
        });
        const json = await res.json();

        if (json.status === "success" && json.exists && json.customer) {
            const cust = json.customer;
            currentMember = cust;
            currentUser.name = cust.name || currentUser.name;
            currentUser.phone = cust.phone || "";
            currentUser.address = cust.address || "";
            currentUser.memberTier = cust.memberTier || "ลูกค้าทั่วไป";
            currentUser.points = cust.points || 0;

            saveMemberSession(currentUser);
            prefillCustomerForm(currentUser);
        } else {
            const nameInp = document.getElementById("custNameInput");
            if (nameInp && !nameInp.value) nameInp.value = currentUser.lineDisplayName;
        }
    } catch (err) {
        console.error("Error fetching customer profile:", err);
    } finally {
        updateUserUI();
        renderMemberHome();
    }
}

function prefillCustomerForm(user) {
    const nameInp = document.getElementById("custNameInput");
    const phoneInp = document.getElementById("custPhoneInput");
    const addrInp = document.getElementById("custAddressInput");
    
    if (nameInp && user.name) nameInp.value = user.name;
    if (phoneInp && user.phone) phoneInp.value = user.phone;
    if (addrInp && user.address) addrInp.value = user.address;

    if (user.gpsLocation || (currentMember && currentMember.shippingAddress)) {
        const gps = user.gpsLocation || (currentMember.shippingAddress.includes(",") ? currentMember.shippingAddress : "");
        if (gps) {
            const gpsInput = document.getElementById("custGpsInput");
            const gpsLink = document.getElementById("gpsMapLink");
            if (gpsInput) gpsInput.value = gps;
            if (gpsLink) {
                const safeMap = safeHttpUrl(gps.startsWith("http") ? gps : `https://www.google.com/maps?q=${encodeURIComponent(gps)}`);
                if (safeMap) { gpsLink.href = safeMap; gpsLink.classList.remove("hidden"); }
            }
        }
    }
}

function updateUserUI() {
    const avatarEl = document.getElementById("userAvatar");
    const nameEl = document.getElementById("userName");
    const tierEl = document.getElementById("userTier");
    const membershipBanner = document.getElementById("membershipBanner");

    if (!nameEl || !tierEl) return;

    if (currentUser.isLoggedIn) {
        nameEl.innerText = currentUser.name || currentUser.lineDisplayName || "ลูกค้าสมาชิก";
        const loyaltyLabel = currentMember?.loyaltyLevel === "CONTRACTOR_PLUS" ? "🛠️ ช่าง Pro+" : 
                             currentMember?.loyaltyLevel === "CONTRACTOR_PRO" ? "🛠️ ช่าง Pro" : 
                             currentMember?.loyaltySegment === "CONTRACTOR" ? "🛠️ ช่างรับเหมา" : 
                             currentMember?.isRegularCustomer ? "👑 ลูกค้าประจำ" : currentUser.memberTier;
        tierEl.innerText = `${loyaltyLabel}${currentUser.points > 0 ? ` · ${currentUser.points} แต้ม` : ''}`;
        if (currentUser.linePictureUrl && avatarEl) {
            const safeAvatar = safeHttpUrl(currentUser.linePictureUrl);
            if (safeAvatar) avatarEl.src = safeAvatar;
        }
    } else {
        nameEl.innerText = "ลูกค้าทั่วไป (คลิกเพื่อเข้าสู่ระบบ)";
        tierEl.innerText = "แตะเพื่อเข้าสู่ระบบ / เช็คแต้ม";
    }
    membershipBanner?.classList.toggle("hidden", !currentUser.isLoggedIn || Boolean(currentMember));
    if (membershipBanner) membershipBanner.onclick = () => switchTab("member");
}

/* =========================================================
   MULTI-CHANNEL LOGIN (LINE SSO / PHONE NUMBER)
   ========================================================= */

function openProfileInfo() {
    if (!currentUser.isLoggedIn) {
        showLoginOptionsModal();
        return;
    }

    Swal.fire({
        title: `👤 ${escapeHtml(currentUser.name || currentUser.lineDisplayName || "ลูกค้าสมาชิก")}`,
        html: `
            <div style="text-align: left; font-size: 14px; line-height: 1.8; background: #f0fdf4; border: 1.5px solid #a7f3d0; padding: 14px; border-radius: 12px; margin-bottom: 12px;">
                <p><strong>ระดับสมาชิก:</strong> <span style="color:#059669;font-weight:800;">${escapeHtml(currentUser.memberTier)}</span></p>
                <p><strong>แต้มสะสม:</strong> <span style="color:#047857;font-weight:800;">💎 ${currentUser.points} แต้ม</span></p>
                <p><strong>เบอร์โทรศัพท์:</strong> ${escapeHtml(currentUser.phone || 'ยังไม่ได้ระบุ')}</p>
                <p><strong>ที่อยู่จัดส่งประจำ:</strong> ${escapeHtml(currentUser.address || 'ยังไม่ได้ระบุ')}</p>
            </div>
            <button type="button" onclick="logoutMember()" style="background:#fee2e2;color:#b91c1c;border:1px solid #fca5a5;padding:8px 16px;border-radius:8px;font-size:13px;font-weight:700;cursor:pointer;width:100%;">
                🚪 ออกจากระบบ / สลับบัญชี
            </button>
        `,
        showConfirmButton: true,
        confirmButtonText: "ปิดหน้าต่าง",
        confirmButtonColor: "#059669",
    });
}

function showLoginOptionsModal() {
    Swal.fire({
        title: "🔑 เข้าสู่ระบบสมาชิก",
        html: `
            <div style="text-align: left; font-size: 13px; color: #475569; margin-bottom: 16px; line-height: 1.6;">
                เข้าสู่ระบบเพื่อสะสมแต้ม ดูประวัติการสั่งซื้อ และรับสิทธิ์ราคาช่างพิเศษครับ
            </div>
            <div style="display: flex; flex-direction: column; gap: 10px;">
                <button type="button" id="btnPhoneLoginModal" style="background:#059669;color:#fff;border:none;padding:12px;border-radius:10px;font-size:14px;font-weight:800;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:8px;box-shadow:0 2px 8px rgba(5,150,105,0.3);">
                    📱 เคยซื้อที่ร้านแล้ว (เชื่อมโยงเบอร์เดิม)
                </button>
                <button type="button" id="btnRegisterModal" style="background:#f0fdf4;color:#047857;border:1.5px solid #059669;padding:12px;border-radius:10px;font-size:14px;font-weight:800;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:8px;">
                    📝 ลูกค้าใหม่ (ลงทะเบียนสมาชิก)
                </button>
                <button type="button" id="btnLineLoginModal" style="background:#06c755;color:#fff;border:none;padding:10px;border-radius:10px;font-size:13px;font-weight:700;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:8px;">
                    🟢 เข้าสู่ระบบด้วย LINE
                </button>
            </div>
        `,
        showConfirmButton: false,
        showCloseButton: true,
        didOpen: () => {
            document.getElementById("btnPhoneLoginModal")?.addEventListener("click", () => {
                Swal.close();
                promptPhoneLogin();
            });
            document.getElementById("btnRegisterModal")?.addEventListener("click", () => {
                Swal.close();
                promptNewMemberRegister();
            });
            document.getElementById("btnLineLoginModal")?.addEventListener("click", () => {
                Swal.close();
                loginWithLine();
            });
        }
    });
}

async function loginWithLine() {
    try {
        if (typeof liff === "undefined") {
            window.location.href = `https://liff.line.me/${LIFF_ID}`;
            return;
        }

        if (!liff.isReady) {
            await liff.init({ liffId: LIFF_ID });
        }

        if (liff.isLoggedIn()) {
            await fetchCustomerProfile();
            Swal.fire({
                title: "✅ เข้าสู่ระบบแล้ว",
                text: `ยินดีต้อนรับ ${currentUser.name || currentUser.lineDisplayName}`,
                icon: "success",
                timer: 1500,
                showConfirmButton: false
            });
            return;
        }

        const isLocalOrHttp = window.location.protocol === "http:" || 
                              window.location.hostname === "localhost" || 
                              window.location.hostname === "127.0.0.1";

        if (isLocalOrHttp) {
            Swal.fire({
                title: "🟢 เข้าสู่ระบบด้วย LINE",
                html: `
                    <p style="font-size:13px;color:#475569;line-height:1.6;margin-bottom:14px;">
                        การเข้าสู่ระบบด้วย LINE จำเป็นต้องเชื่อมต่อผ่าน LINE App หรือโดเมนที่มี HTTPS ครับ
                    </p>
                    <a href="https://liff.line.me/${LIFF_ID}" style="display:block;background:#06c755;color:#fff;padding:12px;border-radius:10px;text-decoration:none;font-weight:800;margin-bottom:10px;font-size:14px;box-shadow:0 2px 8px rgba(6,199,85,0.3);">
                        📲 เปิดหน้าเว็บผ่าน LINE App
                    </a>
                    <button type="button" onclick="Swal.close(); promptPhoneLogin();" style="background:#f0fdf4;color:#047857;border:1.5px solid #059669;padding:10px;border-radius:10px;font-size:13px;font-weight:700;width:100%;cursor:pointer;">
                        📱 หรือเข้าสู่ระบบด้วยเบอร์โทรศัพท์ (คลิกที่นี่)
                    </button>
                `,
                showConfirmButton: false,
                showCloseButton: true
            });
        } else {
            liff.login({ redirectUri: window.location.href });
        }
    } catch (err) {
        console.warn("LINE Login attempt error, redirecting to LIFF URL:", err);
        window.location.href = `https://liff.line.me/${LIFF_ID}`;
    }
}

function promptPhoneLogin(initialPhone = "") {
    Swal.fire({
        title: "📱 เชื่อมโยงเบอร์โทรศัพท์ / เข้าสู่ระบบ",
        html: `
            <div style="text-align:left;font-size:13px;padding:4px 0;">
                <label style="font-weight:700;color:#334155;display:block;margin-bottom:4px;">📱 เบอร์โทรศัพท์ที่เคยใช้กับทางร้าน</label>
                <input id="swalLoginPhone" class="swal2-input" type="tel" style="margin:0 0 12px;width:100%;font-size:15px;" placeholder="เช่น 0812345678" value="${escapeHtml(initialPhone)}" autofocus>
                
                <label style="font-weight:700;color:#334155;display:block;margin-bottom:4px;">🔒 รหัส PIN (4-6 หลัก)</label>
                <input id="swalLoginPin" class="swal2-input" type="password" maxlength="6" inputmode="numeric" style="margin:0 0 8px;width:100%;font-size:15px;letter-spacing:2px;" placeholder="กรอกรหัส PIN">
                
                <div style="background:#f0fdf4;border:1px solid #d1fae5;border-radius:8px;padding:8px 10px;margin-top:6px;">
                    <small style="color:#047857;display:block;font-size:11px;line-height:1.4;">
                        💡 <strong>สำหรับลูกค้าทุกคน:</strong> หากยังไม่เคยเปลี่ยนรหัส รหัสเริ่มต้นคือ <strong>เลขท้าย 4 ตัวของเบอร์โทรศัพท์</strong> ครับ
                    </small>
                </div>
            </div>
        `,
        showCancelButton: true,
        confirmButtonText: "🔗 ยืนยันเชื่อมโยง & เข้าสู่ระบบ",
        cancelButtonText: "ยกเลิก",
        confirmButtonColor: "#059669",
        preConfirm: () => {
            const phone = document.getElementById("swalLoginPhone")?.value?.trim() || "";
            const pin = document.getElementById("swalLoginPin")?.value?.trim() || "";
            if (!phone || phone.length < 8) {
                Swal.showValidationMessage("กรุณาระบุเบอร์โทรศัพท์ให้ถูกต้องครับ");
                return false;
            }
            if (!pin || pin.length < 4) {
                Swal.showValidationMessage("กรุณากรอกรหัส PIN อย่างน้อย 4 หลักครับ");
                return false;
            }
            return { phone, pin };
        }
    }).then(async (result) => {
        if (result.isConfirmed && result.value) {
            await performPhoneLogin(result.value.phone, result.value.pin);
        }
    });
}

async function performPhoneLogin(phoneNumber, pin) {
    try {
        Swal.fire({
            title: "กำลังตรวจสอบข้อมูล...",
            allowOutsideClick: false,
            didOpen: () => Swal.showLoading()
        });

        const res = await fetch(`${API_BASE}/phone-login`, {
            method: "POST",
            headers: liffBearerHeaders(true),
            body: JSON.stringify({
                phone: phoneNumber,
                pin: pin,
                lineUserId: currentUser.lineUserId,
                lineDisplayName: currentUser.lineDisplayName,
                linePictureUrl: currentUser.linePictureUrl
            })
        });

        const json = await res.json();

        if (json.status === "success" && json.exists && json.customer) {
            const cust = json.customer;
            currentUser = {
                ...currentUser,
                name: cust.name,
                phone: cust.phone,
                address: cust.address,
                memberTier: cust.memberTier || "ลูกค้าทั่วไป",
                points: cust.points || 0,
                isLoggedIn: true
            };
            currentMember = cust;

            saveMemberSession(currentUser);
            prefillCustomerForm(currentUser);
            updateUserUI();
            renderMemberHome();

            const isLinked = json.linkedLine || !!currentUser.lineUserId;
            Swal.fire({
                title: isLinked ? "🎉 เชื่อมโยงบัญชี LINE สำเร็จ!" : "🎉 เข้าสู่ระบบสำเร็จ!",
                html: `
                    ยินดีต้อนรับ <strong>${escapeHtml(cust.name)}</strong><br>
                    ระดับสมาชิก: <span style="color:#059669;font-weight:800;">${escapeHtml(cust.memberTier)}</span><br>
                    แต้มสะสม: <span style="color:#047857;font-weight:800;">💎 ${cust.points} แต้ม</span>
                    ${isLinked ? '<br><small style="color:#047857;display:block;margin-top:4px;">✨ ครั้งต่อไปเปิด LINE จะเข้าสู่ระบบอัตโนมัติทันที</small>' : ''}
                `,
                icon: "success",
                confirmButtonColor: "#059669",
                confirmButtonText: "🛒 ไปเลือกซื้อสินค้า"
            }).then(() => {
                if (typeof switchTab === "function") switchTab("shop");
            });
        } else if (json.code === "INVALID_PIN") {
            Swal.fire({
                title: "รหัส PIN ไม่ถูกต้อง",
                html: `
                    รหัส PIN ที่ระบุไม่ถูกต้องครับ<br>
                    <small style="color:#64748b;display:block;margin-top:6px;">
                        💡 รหัสเริ่มต้นคือ <strong>เลขท้าย 4 ตัวของเบอร์โทรศัพท์</strong> (หากยังไม่เคยเปลี่ยนรหัส)
                    </small>
                `,
                icon: "error",
                confirmButtonText: "ลองใหม่อีกครั้ง",
                confirmButtonColor: "#059669"
            }).then(() => {
                promptPhoneLogin(phoneNumber);
            });
        } else {
            Swal.fire({
                title: "ไม่พบเบอร์โทรนี้ในระบบ",
                text: "เบอร์นี้ยังไม่มีประวัติในระบบสมาชิก ต้องการสมัครสมาชิกใหม่หรือไม่ครับ",
                icon: "info",
                showCancelButton: true,
                confirmButtonText: "📝 สมัครสมาชิกใหม่",
                cancelButtonText: "ปิด",
                confirmButtonColor: "#059669"
            }).then((res) => {
                if (res.isConfirmed) {
                    promptNewMemberRegister(phoneNumber);
                }
            });
        }
    } catch (e) {
        console.error("Phone login error:", e);
        Swal.fire("เกิดข้อผิดพลาด", "ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ในขณะนี้", "error");
    }
}

function promptNewMemberRegister(initialPhone = "") {
    const prefillName = currentUser.lineDisplayName || "";
    Swal.fire({
        title: "📝 สมัครสมาชิกใหม่",
        html: `
            <div style="text-align:left;font-size:13px;padding:4px 0;">
                <label style="font-weight:700;color:#334155;display:block;margin-bottom:4px;">👤 ชื่อ - นามสกุล *</label>
                <input id="swalRegName" class="swal2-input" type="text" style="margin:0 0 12px;width:100%;font-size:14px;" placeholder="เช่น ช่างสมชาย ใจดี" value="${escapeHtml(prefillName)}" autofocus>
                
                <label style="font-weight:700;color:#334155;display:block;margin-bottom:4px;">📱 เบอร์โทรศัพท์ *</label>
                <input id="swalRegPhone" class="swal2-input" type="tel" style="margin:0 0 12px;width:100%;font-size:14px;" placeholder="เช่น 0812345678" value="${escapeHtml(initialPhone)}">
                
                <label style="font-weight:700;color:#334155;display:block;margin-bottom:4px;">🔒 กำหนดรหัส PIN (4-6 หลัก)</label>
                <input id="swalRegPin" class="swal2-input" type="password" maxlength="6" inputmode="numeric" style="margin:0 0 8px;width:100%;font-size:14px;letter-spacing:2px;" placeholder="เว้นว่าง = ใช้เลขท้าย 4 ตัวของเบอร์">
                
                <div style="background:#f0fdf4;border:1px solid #d1fae5;border-radius:8px;padding:8px 10px;margin-top:6px;">
                    <small style="color:#047857;display:block;font-size:11px;line-height:1.4;">
                        🎁 สมัครสมาชิกเพื่อสะสมแต้มทุกการสั่งซื้อ และรับสิทธิประโยชน์ราคาส่ง
                    </small>
                </div>
            </div>
        `,
        showCancelButton: true,
        confirmButtonText: "✅ ยืนยันสมัครสมาชิก",
        cancelButtonText: "ยกเลิก",
        confirmButtonColor: "#059669",
        preConfirm: () => {
            const name = document.getElementById("swalRegName")?.value?.trim() || "";
            const phone = document.getElementById("swalRegPhone")?.value?.trim() || "";
            const pin = document.getElementById("swalRegPin")?.value?.trim() || "";
            if (!name) {
                Swal.showValidationMessage("กรุณาระบุชื่อ-นามสกุลครับ");
                return false;
            }
            if (!phone || phone.length < 9) {
                Swal.showValidationMessage("กรุณาระบุเบอร์โทรศัพท์ให้ถูกต้อง (9-10 หลัก) ครับ");
                return false;
            }
            return { name, phone, pin };
        }
    }).then(async (result) => {
        if (result.isConfirmed && result.value) {
            await performNewMemberRegister(result.value.name, result.value.phone, result.value.pin);
        }
    });
}

async function performNewMemberRegister(name, phone, pin) {
    try {
        Swal.fire({
            title: "กำลังลงทะเบียนสมาชิก...",
            allowOutsideClick: false,
            didOpen: () => Swal.showLoading()
        });

        const res = await fetch(`${API_BASE}/register`, {
            method: "POST",
            headers: liffBearerHeaders(true),
            body: JSON.stringify({
                name: name,
                phone: phone,
                pin: pin,
                lineUserId: currentUser.lineUserId,
                lineDisplayName: currentUser.lineDisplayName,
                linePictureUrl: currentUser.linePictureUrl
            })
        });

        const json = await res.json();

        if (json.status === "success" && json.customer) {
            const cust = json.customer;
            currentUser = {
                ...currentUser,
                name: cust.name,
                phone: cust.phone,
                address: cust.address,
                memberTier: cust.memberTier || "ลูกค้าทั่วไป",
                points: cust.points || 0,
                isLoggedIn: true
            };
            currentMember = cust;

            saveMemberSession(currentUser);
            prefillCustomerForm(currentUser);
            updateUserUI();
            renderMemberHome();

            Swal.fire({
                title: "🎉 สมัครสมาชิกสำเร็จ!",
                html: `
                    ยินดีต้อนรับคุณ <strong>${escapeHtml(cust.name)}</strong><br>
                    รหัสสมาชิก: <span style="color:#059669;font-weight:800;">${escapeHtml(cust.memberCode || '')}</span><br>
                    ระบบได้เชื่อมโยงบัญชี LINE ของท่านเรียบร้อยแล้วครับ
                `,
                icon: "success",
                confirmButtonColor: "#059669",
                confirmButtonText: "🛒 ไปเลือกซื้อสินค้า"
            }).then(() => {
                if (typeof switchTab === "function") switchTab("shop");
            });
        } else if (json.code === "PHONE_EXISTS") {
            Swal.fire({
                title: "เบอร์โทรนี้ลงทะเบียนไว้แล้ว",
                text: json.message || "พบเบอร์โทรนี้ในระบบแล้วครับ",
                icon: "info",
                showCancelButton: true,
                confirmButtonText: "📱 เชื่อมโยงเบอร์เดิม",
                cancelButtonText: "ปิด",
                confirmButtonColor: "#059669"
            }).then((res) => {
                if (res.isConfirmed) {
                    promptPhoneLogin(phone);
                }
            });
        } else {
            Swal.fire("ไม่สามารถสมัครสมาชิกได้", json.message || "เกิดข้อผิดพลาดในการลงทะเบียน", "warning");
        }
    } catch (e) {
        console.error("Register error:", e);
        Swal.fire("เกิดข้อผิดพลาด", "ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ในขณะนี้", "error");
    }
}

function logoutMember() {
    Swal.fire({
        title: "ยืนยันการออกจากระบบ?",
        text: "คุณต้องการออกจากระบบและล้างข้อมูลสมาชิกบนอุปกรณ์นี้ใช่หรือไม่",
        icon: "question",
        showCancelButton: true,
        confirmButtonText: "ออกจากระบบ",
        cancelButtonText: "ยกเลิก",
        confirmButtonColor: "#dc2626"
    }).then((result) => {
        if (result.isConfirmed) {
            clearMemberSession();
            renderMemberProfileView();
            if (typeof switchTab === "function") switchTab("member");
            Swal.fire({
                title: "ออกจากระบบเรียบร้อย",
                icon: "success",
                timer: 1500,
                showConfirmButton: false
            });
        }
    });
}

function renderMemberHome() {
    const card = document.getElementById("memberStatusCard");
    if (!card) return;

    if (!currentUser.isLoggedIn) {
        card.innerHTML = `
            <div class="member-guest-box" style="padding:16px;text-align:center;background:#f0fdf4;border:1.5px solid #a7f3d0;border-radius:12px;">
                <p style="font-size:14px;color:#065f46;font-weight:700;margin-bottom:12px;">เข้าสู่ระบบเพื่อสะสมแต้มและสิทธิประโยชน์สมาชิก</p>
                <div style="display:flex;gap:8px;justify-content:center;">
                    <button type="button" class="btn-primary" onclick="showLoginOptionsModal()" style="background:#059669;color:#fff;border:none;padding:8px 16px;border-radius:8px;font-weight:800;cursor:pointer;">
                        🔑 เข้าสู่ระบบสมาชิก
                    </button>
                </div>
            </div>
        `;
        return;
    }

    card.innerHTML = `
        <div class="member-profile-header" style="display:flex;align-items:center;gap:12px;background:#f0fdf4;border:1.5px solid #a7f3d0;padding:16px;border-radius:12px;">
            ${currentUser.linePictureUrl ? `<img src="${escapeHtml(currentUser.linePictureUrl)}" class="member-avatar" style="width:48px;height:48px;border-radius:50%;">` : '<div style="width:48px;height:48px;border-radius:50%;background:#059669;color:#fff;display:flex;align-items:center;justify-content:center;font-size:20px;">👤</div>'}
            <div style="flex:1;">
                <h4 style="margin:0;color:#0f172a;font-size:16px;font-weight:800;">${escapeHtml(currentUser.name || currentUser.lineDisplayName)}</h4>
                <div style="display:flex;gap:8px;align-items:center;margin-top:4px;">
                    <span class="member-badge" style="background:#059669;color:#fff;padding:2px 8px;border-radius:9999px;font-size:11px;font-weight:800;">${escapeHtml(currentUser.memberTier)}</span>
                    <strong style="color:#047857;font-size:13px;">💎 ${currentUser.points} แต้ม</strong>
                </div>
            </div>
            <button type="button" onclick="logoutMember()" style="background:none;border:1px solid #cbd5e1;color:#64748b;padding:4px 8px;border-radius:6px;font-size:11px;cursor:pointer;">ออก</button>
        </div>
    `;
}

async function handlePairingFromUrl() {
    const urlParams = new URLSearchParams(window.location.search);
    const pairToken = urlParams.get("pair");
    if (pairToken) {
        console.log("Found pair token in URL:", pairToken);
    }
}

/* =========================================================
   REWARDS & COUPONS MODULE (STOREFRONT)
   ========================================================= */

let storeRewards = [];
let myRedeemedCoupons = [];
let currentRewardFilter = 'ALL';

async function loadRewardsAndCoupons() {
    renderRewardsUserHeader();
    await Promise.all([fetchStoreRewards(), fetchMyCoupons()]);
    renderRewardsList();
}

function renderRewardsUserHeader() {
    const header = document.getElementById("rewardsUserHeader");
    if (!header) return;

    if (currentUser.isLoggedIn) {
        header.innerHTML = `
            <div style="background:linear-gradient(135deg, #065f46, #059669);color:#fff;border-radius:18px;padding:16px 20px;display:flex;align-items:center;justify-content:space-between;box-shadow:0 6px 20px rgba(5,150,105,0.18);margin-bottom:16px;">
                <div>
                    <span style="color:#a7f3d0;font-size:12px;font-weight:700;display:block;">แต้มสะสมของคุณ</span>
                    <strong style="font-size:26px;letter-spacing:-0.5px;color:#fff;">💎 ${Number(currentUser.points || 0).toLocaleString('th-TH')} แต้ม</strong>
                </div>
                <div style="text-align:right;">
                    <span style="background:rgba(255,255,255,0.2);color:#fff;padding:4px 10px;border-radius:999px;font-size:12px;font-weight:800;display:inline-block;margin-bottom:4px;">
                        ${escapeHtml(currentUser.memberTier || 'ลูกค้าทั่วไป')}
                    </span>
                    <small style="display:block;color:#d1fae5;font-size:11px;">ใช้แลกรับส่วนลดได้ทันที</small>
                </div>
            </div>
        `;
    } else {
        header.innerHTML = `
            <div style="background:#f0fdf4;border:1.5px solid #a7f3d0;border-radius:18px;padding:16px;text-align:center;margin-bottom:16px;">
                <p style="font-size:14px;color:#065f46;font-weight:800;margin-bottom:6px;">🎁 แลกของพรีเมียม & คูปองส่วนลดพิเศษ</p>
                <p style="font-size:12px;color:#475569;margin-bottom:12px;">เข้าสู่ระบบสมาชิกเพื่อตรวจสอบแต้มสะสมและกดแลกรับของรางวัล</p>
                <button type="button" onclick="showLoginOptionsModal()" style="background:#059669;color:#fff;border:none;padding:10px 20px;border-radius:10px;font-weight:800;font-size:13px;cursor:pointer;box-shadow:0 2px 8px rgba(5,150,105,0.25);">
                    🔑 เข้าสู่ระบบสมาชิก
                </button>
            </div>
        `;
    }
}

async function fetchStoreRewards() {
    try {
        const headers = currentUser.isLoggedIn ? liffBearerHeaders() : {};
        const res = await fetch(`/api/v1/rewards`, { headers });
        const json = await res.json();
        storeRewards = Array.isArray(json) ? json : [];
    } catch (e) {
        console.error("Error fetching rewards:", e);
        storeRewards = [];
    }
}

async function fetchMyCoupons() {
    if (!currentUser.isLoggedIn) {
        myRedeemedCoupons = [];
        updateMyCouponsBadge();
        return;
    }
    try {
        const res = await fetch(`/api/v1/rewards-member/my-coupons`, {
            headers: liffBearerHeaders()
        });
        const json = await res.json();
        myRedeemedCoupons = Array.isArray(json) ? json : (json.coupons || []);
        updateMyCouponsBadge();
    } catch (e) {
        console.error("Error fetching my coupons:", e);
        myRedeemedCoupons = [];
        updateMyCouponsBadge();
    }
}

function updateMyCouponsBadge() {
    const badge = document.getElementById("myCouponsBadge");
    if (badge) {
        const activeCount = myRedeemedCoupons.filter(c => c.status === 'ACTIVE').length;
        if (activeCount > 0) {
            badge.innerText = activeCount;
            badge.style.display = "inline-block";
        } else {
            badge.style.display = "none";
        }
    }
}

function filterRewardType(type) {
    currentRewardFilter = type;
    document.getElementById("rewTabAll")?.classList.toggle("active", type === "ALL");
    document.getElementById("rewTabFreeClaim")?.classList.toggle("active", type === "FREE_CLAIM");
    document.getElementById("rewTabCoupons")?.classList.toggle("active", type === "DISCOUNT_COUPON");
    document.getElementById("rewTabGifts")?.classList.toggle("active", type === "GIFT");
    document.getElementById("rewTabMyCoupons")?.classList.toggle("active", type === "MY_COUPONS");

    const rewardsContent = document.getElementById("rewardsContent");
    const myCouponsContainer = document.getElementById("myCouponsListContainer");

    if (type === "MY_COUPONS") {
        rewardsContent?.classList.add("hidden");
        myCouponsContainer?.classList.remove("hidden");
        renderMyCouponsList();
    } else {
        rewardsContent?.classList.remove("hidden");
        myCouponsContainer?.classList.add("hidden");
        renderRewardsList();
    }
}

function renderRewardsList() {
    const content = document.getElementById("rewardsContent");
    if (!content) return;

    let filtered = storeRewards;
    if (currentRewardFilter === "FREE_CLAIM") {
        filtered = storeRewards.filter(r => r.claim_type === "FREE_CLAIM");
    } else if (currentRewardFilter === "DISCOUNT_COUPON") {
        filtered = storeRewards.filter(r => (r.reward_type === "DISCOUNT_COUPON" || r.reward_type === "FREE_DELIVERY") && r.claim_type !== "FREE_CLAIM");
    } else if (currentRewardFilter === "GIFT") {
        filtered = storeRewards.filter(r => (r.reward_type === "GIFT" || !r.reward_type) && r.claim_type !== "FREE_CLAIM");
    }

    if (!filtered.length) {
        content.innerHTML = '<div class="member-empty">ยังไม่มีของรางวัลในหมวดนี้</div>';
        return;
    }

    content.innerHTML = filtered.map(r => {
        const isCoupon = r.reward_type === "DISCOUNT_COUPON";
        const isFreeDelivery = r.reward_type === "FREE_DELIVERY";
        const isFreeClaim = r.claim_type === "FREE_CLAIM";
        const hasEnoughPoints = currentUser.isLoggedIn && Number(currentUser.points || 0) >= Number(r.point_price || 0);
        const limitPerUser = Number(r.claim_limit_per_user || 0);
        const isLimitReached = r.is_claim_limit_reached || (currentUser.isLoggedIn && limitPerUser > 0 && Number(r.user_claimed_count || 0) >= limitPerUser);
        const isOutOfStock = Number(r.stock_quantity || 0) <= 0;
        const limitText = limitPerUser > 0 ? `จำกัด ${limitPerUser} ใบ/คน` : 'ไม่จำกัดสิทธิ์';

        return `
            <div class="member-item" style="display:flex;flex-direction:column;border:1px solid #e2e8f0;border-radius:16px;padding:12px;background:#fff;box-shadow:0 2px 8px rgba(0,0,0,0.04);position:relative;">
                ${isFreeClaim ? 
                    `<span style="position:absolute;top:16px;right:16px;background:#fef3c7;color:#92400e;font-size:10px;font-weight:800;padding:2px 8px;border-radius:999px;border:1px solid #fde68a;">🎁 รับฟรี (${limitText})</span>` :
                    (limitPerUser > 0 ? `<span style="position:absolute;top:16px;right:16px;background:#e0e7ff;color:#3730a3;font-size:10px;font-weight:800;padding:2px 8px;border-radius:999px;border:1px solid #c7d2fe;">💎 ${limitText}</span>` : '')
                }
                <div style="height:100px;border-radius:10px;background:${isFreeClaim ? '#fef3c7' : isCoupon ? '#e0f2fe' : isFreeDelivery ? '#e0f2fe' : '#f0fdf4'};display:flex;align-items:center;justify-content:center;margin-bottom:8px;overflow:hidden;">
                    ${r.image_url ? `<img src="${escapeHtml(r.image_url)}" style="width:100%;height:100%;object-fit:cover;">` : `<span style="font-size:36px;">${isFreeClaim ? '🎁' : isCoupon ? '🎟️' : isFreeDelivery ? '🚚' : '🏆'}</span>`}
                </div>
                <h3 style="font-size:14px;font-weight:800;color:#0f172a;margin:0 0 4px;line-height:1.3;">${escapeHtml(r.name)}</h3>
                <p style="font-size:11px;color:#64748b;margin:0 0 8px;line-height:1.4;flex:1;">${escapeHtml(r.description || '')}</p>
                <div style="display:flex;align-items:center;justify-content:space-between;margin-top:auto;padding-top:6px;border-top:1px dashed #e2e8f0;">
                    ${isFreeClaim ? 
                        `<span style="font-size:13px;font-weight:900;color:#d97706;">🎁 แจกฟรี!</span>` :
                        `<span style="font-size:13px;font-weight:900;color:#059669;">💎 ${Number(r.point_price).toLocaleString('th-TH')} แต้ม</span>`
                    }
                    <small style="color:#94a3b8;font-size:10px;">เหลือ ${r.stock_quantity || 0} ชิ้น</small>
                </div>
                ${isFreeClaim ? `
                    <button type="button" class="member-action ${isLimitReached || isOutOfStock ? 'secondary' : ''}" style="margin-top:8px;padding:8px;font-size:12px;${!isLimitReached && !isOutOfStock ? 'background:#d97706;color:#fff;border:none;' : ''}" ${isLimitReached || isOutOfStock ? 'disabled' : ''} onclick="${currentUser.isLoggedIn ? `claimCoupon(${r.id})` : 'showLoginOptionsModal()'}">
                        ${!currentUser.isLoggedIn ? '🔑 เข้าสู่ระบบเพื่อรับคูปอง' : (isOutOfStock ? 'คูปองหมดแล้ว' : isLimitReached ? '✅ รับสิทธิ์ครบแล้ว' : '🎁 กดรับคูปองฟรี')}
                    </button>
                ` : `
                    <button type="button" class="member-action ${hasEnoughPoints && !isOutOfStock && !isLimitReached ? '' : 'secondary'}" style="margin-top:8px;padding:8px;font-size:12px;" ${!hasEnoughPoints || isOutOfStock || isLimitReached ? 'disabled' : ''} onclick="${currentUser.isLoggedIn ? `redeemReward(${r.id})` : 'showLoginOptionsModal()'}">
                        ${!currentUser.isLoggedIn ? '🔑 เข้าสู่ระบบเพื่อแลก' : (isOutOfStock ? 'ของรางวัลหมดแล้ว' : isLimitReached ? '✅ แลกสิทธิ์ครบแล้ว' : hasEnoughPoints ? '✨ แลกรางวัลนี้' : 'แต้มไม่เพียงพอ')}
                    </button>
                `}
            </div>
        `;
    }).join('');
}

function renderMyCouponsList() {
    const container = document.getElementById("myCouponsListContainer");
    if (!container) return;

    if (!currentUser.isLoggedIn) {
        container.innerHTML = `
            <div class="member-empty">
                <p style="font-weight:700;margin-bottom:8px;">กรุณาเข้าสู่ระบบเพื่อดูคูปองของคุณ</p>
                <button type="button" onclick="showLoginOptionsModal()" style="background:#059669;color:#fff;border:none;padding:8px 16px;border-radius:8px;font-weight:700;cursor:pointer;">เข้าสู่ระบบ</button>
            </div>
        `;
        return;
    }

    if (!myRedeemedCoupons.length) {
        container.innerHTML = `
            <div class="member-empty">
                <span style="font-size:32px;display:block;margin-bottom:8px;">🎟️</span>
                <p style="font-weight:700;color:#0f172a;margin-bottom:4px;">ยังไม่มีคูปองที่แลกไว้</p>
                <p style="font-size:12px;color:#64748b;margin-bottom:12px;">ใช้แต้มแลกรับคูปองส่วนลดเพื่อใช้เป็นส่วนลดสั่งซื้อสินค้าได้ครับ</p>
                <button type="button" onclick="filterRewardType('DISCOUNT_COUPON')" style="background:#059669;color:#fff;border:none;padding:8px 16px;border-radius:8px;font-size:12px;font-weight:700;cursor:pointer;">
                    ดูคูปองส่วนลดที่แลกได้
                </button>
            </div>
        `;
        return;
    }

    container.innerHTML = myRedeemedCoupons.map(c => {
        const isActive = c.status === 'ACTIVE';
        const isUsed = c.status === 'USED';
        const statusText = isActive ? '✅ พร้อมใช้งาน' : isUsed ? '🎟️ ใช้งานแล้ว' : '⌛ หมดอายุ';
        const statusColor = isActive ? '#166534' : isUsed ? '#64748b' : '#991b1b';
        const statusBg = isActive ? '#dcfce7' : isUsed ? '#f1f5f9' : '#fee2e2';

        return `
            <div class="history-row" style="background:#fff;border:1.5px solid ${isActive ? '#a7f3d0' : '#e2e8f0'};border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:8px;">
                <div style="display:flex;justify-content:space-between;align-items:flex-start;">
                    <div>
                        <strong style="font-size:15px;color:#0f172a;">${escapeHtml(c.reward_name || 'คูปองส่วนลด')}</strong>
                        <div style="font-size:18px;font-weight:900;color:#059669;margin-top:2px;">ส่วนลด ฿${Number(c.discount_value || 0).toLocaleString('th-TH')}</div>
                    </div>
                    <span style="font-size:11px;font-weight:800;padding:3px 8px;border-radius:999px;background:${statusBg};color:${statusColor};">
                        ${statusText}
                    </span>
                </div>
                <div style="background:#f8fafc;border:1px dashed #cbd5e1;border-radius:8px;padding:8px 12px;display:flex;align-items:center;justify-content:space-between;">
                    <div>
                        <small style="color:#64748b;display:block;font-size:10px;">รหัสคูปอง (Coupon Code)</small>
                        <strong style="font-family:monospace;font-size:15px;color:#0f172a;letter-spacing:1px;">${escapeHtml(c.coupon_code || '')}</strong>
                    </div>
                    ${isActive ? `
                        <button type="button" onclick="copyCouponCode('${escapeHtml(c.coupon_code || '')}')" style="background:#059669;color:#fff;border:none;padding:6px 12px;border-radius:6px;font-size:11px;font-weight:700;cursor:pointer;">
                            📋 คัดลอก
                        </button>
                    ` : ''}
                </div>
                <div style="display:flex;justify-content:space-between;align-items:center;font-size:11px;color:#94a3b8;">
                    <span>แลกเมื่อ: ${new Date(c.created_at || c.redeemed_at || Date.now()).toLocaleDateString('th-TH')}</span>
                    <span>หมดอายุ: ${c.expires_at ? new Date(c.expires_at).toLocaleDateString('th-TH') : 'ไม่มีวันหมดอายุ'}</span>
                </div>
            </div>
        `;
    }).join('');
}

function copyCouponCode(code) {
    if (navigator.clipboard) {
        navigator.clipboard.writeText(code);
        Swal.fire({
            title: "📋 คัดลอกรหัสคูปองแล้ว",
            text: `รหัส ${code} พร้อมนำไปใส่ในหมายเหตุสั่งซื้อแล้วครับ`,
            icon: "success",
            timer: 1500,
            showConfirmButton: false
        });
    } else {
        Swal.fire("รหัสคูปอง", code, "info");
    }
}

async function redeemReward(rewardId) {
    if (!currentUser.isLoggedIn) {
        showLoginOptionsModal();
        return;
    }

    const reward = storeRewards.find(r => Number(r.id) === Number(rewardId));
    if (!reward) return;

    if (Number(currentUser.points || 0) < Number(reward.point_price || 0)) {
        Swal.fire({
            title: "แต้มสะสมไม่เพียงพอ",
            html: `ของรางวัลนี้ใช้ <strong>${reward.point_price} แต้ม</strong><br>คุณมีแต้มสะสมปัจจุบัน <strong>${currentUser.points} แต้ม</strong>`,
            icon: "warning",
            confirmButtonColor: "#059669"
        });
        return;
    }

    Swal.fire({
        title: "ยืนยันการแลกรางวัล?",
        html: `คุณต้องการใช้ <strong style="color:#059669;">💎 ${reward.point_price} แต้ม</strong><br>เพื่อแลกรับ <strong>"${escapeHtml(reward.name)}"</strong> ใช่หรือไม่`,
        icon: "question",
        showCancelButton: true,
        confirmButtonText: "✅ ยืนยันแลกแต้ม",
        cancelButtonText: "ยกเลิก",
        confirmButtonColor: "#059669"
    }).then(async (result) => {
        if (result.isConfirmed) {
            try {
                Swal.fire({ title: "กำลังดำเนินการ...", allowOutsideClick: false, didOpen: () => Swal.showLoading() });
                const res = await fetch(`/api/v1/rewards-member/redeem`, {
                    method: "POST",
                    headers: liffBearerHeaders(true),
                    body: JSON.stringify({
                        rewardId: reward.id,
                        clientRequestId: globalThis.crypto?.randomUUID ? globalThis.crypto.randomUUID() : `req_${Date.now()}`
                    })
                });

                const json = await res.json();
                if (res.ok && json.success) {
                    await fetchCustomerProfile();
                    await loadRewardsAndCoupons();

                    Swal.fire({
                        title: "🎉 แลกรางวัลสำเร็จ!",
                        html: `
                            คุณได้รับ <strong>${escapeHtml(reward.name)}</strong> เรียบร้อยแล้ว!<br>
                            ${json.couponCode ? `<div style="background:#f0fdf4;border:1.5px solid #a7f3d0;border-radius:10px;padding:10px;margin-top:10px;"><small>รหัสคูปองของคุณ:</small><br><strong style="font-family:monospace;font-size:18px;color:#059669;">${json.couponCode}</strong></div>` : 'สามารถติดต่อรับของได้ที่เคาน์เตอร์หน้าร้านครับ'}
                        `,
                        icon: "success",
                        confirmButtonText: "ดูคูปองของฉัน",
                        confirmButtonColor: "#059669"
                    }).then(() => {
                        filterRewardType("MY_COUPONS");
                    });
                } else {
                    Swal.fire("ไม่สามารถแลกได้", json.error || "เกิดข้อผิดพลาดในการแลกรางวัล", "error");
                }
            } catch (err) {
                console.error("Redeem error:", err);
                Swal.fire("เกิดข้อผิดพลาด", "ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ในขณะนี้", "error");
            }
        }
    });
}

async function claimCoupon(rewardId) {
    if (!currentUser.isLoggedIn) {
        showLoginOptionsModal();
        return;
    }

    const reward = storeRewards.find(r => Number(r.id) === Number(rewardId));
    if (!reward) return;

    Swal.fire({
        title: "🎁 ยืนยันรับคูปองฟรี?",
        html: `คุณต้องการกดรับคูปอง <strong>"${escapeHtml(reward.name)}"</strong> ใช่หรือไม่<br><small style="color:#059669;">(สิทธิ์ฟรี ไม่มีค่าใช้จ่ายและไม่หักแต้มสะสม)</small>`,
        icon: "question",
        showCancelButton: true,
        confirmButtonText: "🎁 ยืนยันรับคูปอง",
        cancelButtonText: "ยกเลิก",
        confirmButtonColor: "#d97706"
    }).then(async (result) => {
        if (result.isConfirmed) {
            try {
                Swal.fire({ title: "กำลังดำเนินการ...", allowOutsideClick: false, didOpen: () => Swal.showLoading() });
                const res = await fetch(`/api/v1/rewards-member/claim`, {
                    method: "POST",
                    headers: liffBearerHeaders(true),
                    body: JSON.stringify({
                        rewardId: reward.id,
                        clientRequestId: globalThis.crypto?.randomUUID ? globalThis.crypto.randomUUID() : `req_claim_${Date.now()}`
                    })
                });

                const json = await res.json();
                if (res.ok && json.success) {
                    await fetchCustomerProfile();
                    await loadRewardsAndCoupons();

                    Swal.fire({
                        title: "🎉 รับคูปองสำเร็จ!",
                        html: `
                            คุณได้รับคูปอง <strong>${escapeHtml(reward.name)}</strong> เรียบร้อยแล้ว!<br>
                            ${json.couponCode ? `<div style="background:#f0fdf4;border:1.5px solid #a7f3d0;border-radius:10px;padding:10px;margin-top:10px;"><small>รหัสคูปองของคุณ:</small><br><strong style="font-family:monospace;font-size:20px;color:#059669;letter-spacing:1px;">${json.couponCode}</strong></div>` : ''}
                        `,
                        icon: "success",
                        confirmButtonText: "ดูคูปองของฉัน",
                        confirmButtonColor: "#059669"
                    }).then(() => {
                        filterRewardType("MY_COUPONS");
                    });
                } else {
                    const errMsg = json.code === 'ALREADY_CLAIMED_MAX' ? 'คุณได้รับสิทธิ์คูปองนี้ครบตามจำนวนที่กำหนดแล้วครับ' :
                                   json.code === 'OUT_OF_STOCK' ? 'ขออภัย คูปองนี้ถูกรับครบตามจำนวนแล้ว' :
                                   (json.error || "เกิดข้อผิดพลาดในการรับคูปอง");
                    Swal.fire("ไม่สามารถรับคูปองได้", errMsg, "warning");
                }
            } catch (err) {
                console.error("Claim coupon error:", err);
                Swal.fire("เกิดข้อผิดพลาด", "ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ในขณะนี้", "error");
            }
        }
    });
}

/* =========================================================
   MEMBER PROFILE HUB VIEW
   ========================================================= */

function renderMemberProfileView() {
    const hub = document.getElementById("memberProfileHub");
    if (!hub) return;

    const shopName = window.currentShopInfo?.name || 'ร้าน ส.บริการ ท่าข้าม';
    const shopAddr = window.currentShopInfo?.address || '923/1 ม.1 ต.ท่าข้าม อ.ชนแดน จ.เพชรบูรณ์ 67150';
    const phoneList = (window.currentShopInfo?.phone ? window.currentShopInfo.phone.split(',') : ['085-1377402', '086-1991923']).map(p => p.trim()).filter(Boolean);

    const phoneButtonsHtml = phoneList.map(p => {
        const clean = p.replace(/[^0-9]/g, '');
        return `<a href="tel:${clean}" style="flex:1;min-width:130px;text-decoration:none;background:#f0fdf4;color:#047857;border:1px solid #a7f3d0;padding:10px;border-radius:10px;text-align:center;font-weight:700;font-size:13px;display:inline-flex;align-items:center;justify-content:center;gap:4px;">📞 โทร ${escapeHtml(p)}</a>`;
    }).join('');

    if (!currentUser.isLoggedIn) {
        const isFromLine = !!currentUser.lineUserId;
        hub.innerHTML = `
            <div class="member-hero" style="text-align:center;padding:24px 16px;">
                ${isFromLine && currentUser.linePictureUrl ? `
                    <img src="${escapeHtml(currentUser.linePictureUrl)}" style="width:60px;height:60px;border-radius:50%;border:3px solid #10b981;margin-bottom:8px;object-fit:cover;">
                    <div style="font-size:13px;color:#047857;font-weight:700;margin-bottom:4px;">🟢 บัญชี LINE: ${escapeHtml(currentUser.lineDisplayName)}</div>
                ` : `
                    <span style="font-size:44px;display:block;margin-bottom:8px;">👤</span>
                `}
                <h2 style="font-size:22px;color:#065f46;margin-bottom:6px;">ศูนย์สมาชิก S-Mart Member</h2>
                <p style="font-size:13px;color:#64748b;margin-bottom:18px;line-height:1.5;">
                    เข้าสู่ระบบเพื่อสะสมแต้มทุกยอดซื้อ เช็คระดับช่างรับเหมา และรับสิทธิพิเศษราคาส่ง
                </p>
                <div style="display:flex;flex-direction:column;gap:10px;max-width:330px;margin:0 auto;">
                    <button type="button" onclick="promptPhoneLogin()" style="background:#059669;color:#fff;border:none;padding:13px;border-radius:12px;font-weight:800;font-size:14px;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:8px;box-shadow:0 3px 10px rgba(5,150,105,0.3);">
                        📱 เคยซื้อที่ร้านแล้ว (เชื่อมโยงเบอร์เดิม)
                    </button>
                    <button type="button" onclick="promptNewMemberRegister()" style="background:#f0fdf4;color:#047857;border:1.5px solid #059669;padding:12px;border-radius:12px;font-weight:800;font-size:14px;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:8px;">
                        📝 ลูกค้าใหม่ (ลงทะเบียนสมาชิก)
                    </button>
                    ${!isFromLine ? `
                        <button type="button" onclick="loginWithLine()" style="background:#06c755;color:#fff;border:none;padding:11px;border-radius:12px;font-weight:800;font-size:13px;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:8px;box-shadow:0 2px 8px rgba(6,199,85,0.25);">
                            🟢 เข้าสู่ระบบด้วย LINE
                        </button>
                    ` : ''}
                    <button type="button" onclick="switchTab('shop')" style="background:transparent;color:#059669;border:1px dashed #059669;padding:10px;border-radius:12px;font-weight:700;font-size:13px;cursor:pointer;margin-top:2px;">
                        🛒 เลือกดูสินค้าเลย (ไม่ล็อกอิน)
                    </button>
                </div>
            </div>

            <!-- Tier Preview Card -->
            <div class="member-card-panel" style="margin-top:14px;">
                <h3 style="font-size:15px;font-weight:800;color:#0f172a;margin-bottom:12px;">🏆 ระดับสมาชิก & สิทธิประโยชน์</h3>
                <div style="display:grid;gap:10px;">
                    <div style="display:flex;align-items:center;gap:12px;background:#f8fafc;padding:12px;border-radius:10px;border:1px solid #e2e8f0;">
                        <span style="font-size:24px;">👤</span>
                        <div>
                            <strong style="font-size:13px;color:#0f172a;">สมาชิกทั่วไป (Member)</strong>
                            <small style="display:block;color:#64748b;font-size:11px;">สะสมแต้มทุกการสั่งซื้อ นำแต้มมาแลกของรางวัล</small>
                        </div>
                    </div>
                    <div style="display:flex;align-items:center;gap:12px;background:#f0fdf4;padding:12px;border-radius:10px;border:1px solid #a7f3d0;">
                        <span style="font-size:24px;">🛠️</span>
                        <div>
                            <strong style="font-size:13px;color:#065f46;">ช่างประจำ / ช่าง Pro (Contractor)</strong>
                            <small style="display:block;color:#047857;font-size:11px;">แต้มคูณ 2.0x + สิทธิ์สั่งของราคาส่งพิเศษ + วางบิลประจำเดือน</small>
                        </div>
                    </div>
                    <div style="display:flex;align-items:center;gap:12px;background:#fffbeb;padding:12px;border-radius:10px;border:1px solid #fde68a;">
                        <span style="font-size:24px;">👑</span>
                        <div>
                            <strong style="font-size:13px;color:#b45309;">VIP Contractor Pro+</strong>
                            <small style="display:block;color:#92400e;font-size:11px;">แต้มคูณ 2.5x + บริการจัดส่งด่วนฟรีถึงหน้างาน + ทีมช่างดูแลเฉพาะ</small>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Store Info Card -->
            <div class="member-card-panel" style="margin-top:14px;background:#fff;">
                <h3 style="font-size:15px;font-weight:800;color:#0f172a;margin-bottom:10px;">🏪 ${escapeHtml(shopName)}</h3>
                <p style="font-size:12px;color:#475569;margin-bottom:8px;line-height:1.5;">
                    📍 ${escapeHtml(shopAddr)}<br>
                    ⏰ เปิดบริการ: จันทร์ - เสาร์ 07:30 - 17:30 น.
                </p>
                <div style="display:flex;flex-wrap:wrap;gap:8px;margin-top:12px;">
                    ${phoneButtonsHtml}
                    <a href="https://line.me/R/ti/p/@smartpos" target="_blank" style="flex:1;min-width:130px;text-decoration:none;background:#06c755;color:#fff;padding:10px;border-radius:10px;text-align:center;font-weight:700;font-size:13px;display:inline-flex;align-items:center;justify-content:center;gap:4px;">
                        💬 แชท LINE OA
                    </a>
                </div>
            </div>
        `;
        return;
    }

    // Logged-in State
    const loyaltyLabel = currentMember?.loyaltyLevel === "CONTRACTOR_PLUS" ? "👑 VIP Contractor Pro+" : 
                         currentMember?.loyaltyLevel === "CONTRACTOR_PRO" ? "🛠️ ช่าง Pro" : 
                         currentMember?.loyaltySegment === "CONTRACTOR" ? "🛠️ ช่างรับเหมา" : 
                         currentMember?.isRegularCustomer ? "👑 ลูกค้าประจำ" : currentUser.memberTier;

    const multiplier = currentMember?.pointsMultiplier ? Number(currentMember.pointsMultiplier) : 1.0;
    const multText = multiplier > 1 ? `x${multiplier.toFixed(1).replace('.0', '')}` : 'x1.0';
    const isSpecialMult = multiplier > 1;

    const monthlySpend = Number(currentMember?.monthlySpend || 0);
    const targetThreshold = Number(currentMember?.nextThreshold || currentMember?.threshold || 10000);
    const progressPercent = targetThreshold > 0 ? Math.min(100, Math.round((monthlySpend / targetThreshold) * 100)) : 100;
    const remainingToTarget = Math.max(0, targetThreshold - monthlySpend);

    hub.innerHTML = `
        <!-- Digital Member Card -->
        <div class="digital-card" style="background:linear-gradient(135deg, #064e3b 0%, #059669 100%);color:#fff;border-radius:20px;padding:20px;box-shadow:0 10px 25px rgba(5,150,105,0.22);margin-bottom:14px;position:relative;overflow:hidden;">
            <div style="display:flex;justify-content:space-between;align-items:flex-start;">
                <div style="display:flex;align-items:center;gap:12px;">
                    ${currentUser.linePictureUrl ? `<img src="${escapeHtml(currentUser.linePictureUrl)}" style="width:52px;height:52px;border-radius:50%;border:2px solid #fff;box-shadow:0 2px 8px rgba(0,0,0,0.2);">` : '<div style="width:52px;height:52px;border-radius:50%;background:rgba(255,255,255,0.2);display:flex;align-items:center;justify-content:center;font-size:24px;border:2px solid #fff;">👤</div>'}
                    <div>
                        <h3 style="margin:0;font-size:18px;font-weight:800;color:#fff;">${escapeHtml(currentUser.name || currentUser.lineDisplayName)}</h3>
                        <small style="color:#d1fae5;font-size:12px;">รหัสสมาชิก: ${escapeHtml(currentMember?.memberCode || 'MEM-ONLINE')}</small>
                    </div>
                </div>
                <span style="background:rgba(255,255,255,0.2);padding:4px 10px;border-radius:999px;font-size:11px;font-weight:800;color:#fff;">
                    ${loyaltyLabel}
                </span>
            </div>
            
            <div style="display:flex;justify-content:space-between;align-items:flex-end;margin-top:20px;padding-top:14px;border-top:1px solid rgba(255,255,255,0.2);">
                <div>
                    <span style="font-size:11px;color:#d1fae5;display:block;">แต้มสะสมพร้อมใช้</span>
                    <strong style="font-size:28px;letter-spacing:-0.5px;color:#fff;">💎 ${Number(currentUser.points || 0).toLocaleString('th-TH')}</strong>
                </div>
                <button type="button" onclick="switchTab('rewards')" style="background:#fff;color:#065f46;border:none;padding:8px 14px;border-radius:8px;font-size:12px;font-weight:800;cursor:pointer;box-shadow:0 2px 6px rgba(0,0,0,0.15);">
                    🎁 แลกของรางวัล
                </button>
            </div>
        </div>

        <!-- Tier Privileges Card -->
        <div class="member-card-panel" style="background:#fff;border:1px solid #a7f3d0;border-radius:18px;padding:16px;margin-bottom:14px;">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
                <h4 style="margin:0;font-size:15px;font-weight:800;color:#065f46;">⭐ สิทธิประโยชน์ของคุณ</h4>
                <span style="font-size:11px;color:#047857;font-weight:700;background:#d1fae5;padding:2px 8px;border-radius:999px;">${loyaltyLabel}</span>
            </div>
            <div style="display:grid;grid-template-columns:repeat(3, 1fr);gap:8px;text-align:center;">
                <div style="background:${isSpecialMult ? '#ecfdf5' : '#f8fafc'};padding:10px 6px;border-radius:10px;border:1px solid ${isSpecialMult ? '#6ee7b7' : '#e2e8f0'};">
                    <span style="font-size:20px;display:block;margin-bottom:2px;">💎</span>
                    <strong style="font-size:12px;color:${isSpecialMult ? '#047857' : '#334155'};display:block;">แต้มคูณ ${multText}</strong>
                    <small style="font-size:10px;color:#64748b;">${isSpecialMult ? 'สิทธิ์แต้มพิเศษ' : 'อัตราปกติ (100บ.=1แต้ม)'}</small>
                </div>
                <div style="background:#f0fdf4;padding:10px 6px;border-radius:10px;border:1px solid #d1fae5;">
                    <span style="font-size:20px;display:block;margin-bottom:2px;">🏷️</span>
                    <strong style="font-size:12px;color:#065f46;display:block;">ราคาสมาชิก</strong>
                    <small style="font-size:10px;color:#64748b;">ส่วนลดพิเศษ</small>
                </div>
                <div style="background:#f0fdf4;padding:10px 6px;border-radius:10px;border:1px solid #d1fae5;">
                    <span style="font-size:20px;display:block;margin-bottom:2px;">🚚</span>
                    <strong style="font-size:12px;color:#065f46;display:block;">ส่งถึงหน้างาน</strong>
                    <small style="font-size:10px;color:#64748b;">ติดตาม Live GPS</small>
                </div>
            </div>
        </div>

        <!-- Monthly Spend & Tier Progress Card -->
        <div class="member-card-panel" style="background:#fff;border:1px solid #e2e8f0;border-radius:18px;padding:16px;margin-bottom:14px;">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">
                <h4 style="margin:0;font-size:14px;font-weight:800;color:#0f172a;">📊 ยอดชำระสะสมเดือนนี้</h4>
                <strong style="font-size:13px;color:#047857;">฿${monthlySpend.toLocaleString('th-TH')} / ฿${targetThreshold.toLocaleString('th-TH')}</strong>
            </div>

            <!-- Progress Bar -->
            <div style="background:#e2e8f0;border-radius:999px;height:10px;overflow:hidden;margin-bottom:10px;position:relative;">
                <div style="background:linear-gradient(90deg, #10b981, #059669);height:100%;width:${progressPercent}%;border-radius:999px;transition:width 0.5s ease;"></div>
            </div>

            <p style="font-size:12px;color:#475569;margin:0 0 10px;line-height:1.5;">
                ${isSpecialMult ? 
                    `🎉 <strong>ยอดชำระครบตามเป้าหมายแล้ว!</strong> คุณได้รับสิทธิ์แต้มพิเศษ <strong>คูณ ${multText}</strong> สำหรับทุกยอดชำระในเดือนนี้` : 
                    `สะสมยอดซื้อชำระแล้วอีก <strong style="color:#d97706;">฿${remainingToTarget.toLocaleString('th-TH')}</strong> ภายในเดือนนี้ เพื่อรับสิทธิ์ <strong>แต้มคูณ x2</strong>`}
            </p>
            <div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;padding:8px 10px;font-size:11px;color:#64748b;line-height:1.4;">
                🛡️ <em>ระบบจะคำนวณแต้มและยอดสะสมจาก <strong>บิลที่ชำระเงินสำเร็จแล้วเท่านั้น</strong> (ไม่นับออเดอร์ค้างชำระ เพื่อป้องกันการกดสั่งเล่น)</em>
            </div>
        </div>

        <!-- Saved Delivery Address Card -->
        <div class="member-card-panel" style="background:#fff;border:1px solid #e2e8f0;border-radius:18px;padding:16px;margin-bottom:14px;">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;">
                <h4 style="margin:0;font-size:15px;font-weight:800;color:#0f172a;">📍 ข้อมูลจัดส่งประจำ</h4>
                <button type="button" onclick="promptEditDeliveryAddress()" style="background:none;border:1px solid #059669;color:#059669;padding:3px 8px;border-radius:6px;font-size:11px;font-weight:700;cursor:pointer;">
                    ✏️ แก้ไข
                </button>
            </div>
            <p style="font-size:13px;color:#334155;margin:0 0 6px;line-height:1.5;">
                <strong>เบอร์โทร:</strong> ${escapeHtml(currentUser.phone || 'ยังไม่ได้ระบุ')}<br>
                <strong>ที่อยู่:</strong> ${escapeHtml(currentUser.address || 'ยังไม่ได้ระบุที่อยู่จัดส่ง')}
            </p>
            ${currentUser.gpsLocation ? `
                <div style="margin-top:8px;">
                    <a href="https://www.google.com/maps?q=${encodeURIComponent(currentUser.gpsLocation)}" target="_blank" style="display:inline-flex;align-items:center;gap:4px;color:#059669;font-size:12px;font-weight:700;text-decoration:none;">
                        📍 ดูพิกัดแผนที่บน Google Maps ↗
                    </a>
                </div>
            ` : ''}
        </div>

        <!-- Security & PIN Settings Card -->
        <div class="member-card-panel" style="background:#fff;border:1px solid #e2e8f0;border-radius:18px;padding:16px;margin-bottom:14px;">
            <div style="display:flex;justify-content:space-between;align-items:center;">
                <div>
                    <h4 style="margin:0 0 2px;font-size:14px;font-weight:800;color:#0f172a;">🔒 รหัส PIN เข้าสู่ระบบ</h4>
                    <small style="color:#64748b;font-size:11px;">ใช้สำหรับล็อกอินด้วยเบอร์โทรศัพท์บนคอมพิวเตอร์</small>
                </div>
                <button type="button" onclick="promptChangePin()" style="background:#f0fdf4;border:1px solid #a7f3d0;color:#047857;padding:6px 12px;border-radius:8px;font-size:12px;font-weight:700;cursor:pointer;">
                    🔑 เปลี่ยนรหัส PIN
                </button>
            </div>
        </div>

        <!-- Store Contact & Help -->
        <div class="member-card-panel" style="background:#fff;border:1px solid #e2e8f0;border-radius:18px;padding:16px;margin-bottom:14px;">
            <h4 style="margin:0 0 10px;font-size:15px;font-weight:800;color:#0f172a;">🏪 ติดต่อ${escapeHtml(shopName)}</h4>
            <div style="display:flex;flex-wrap:wrap;gap:8px;">
                ${phoneButtonsHtml}
                <button type="button" onclick="logoutMember()" style="flex:1;min-width:130px;background:#fee2e2;color:#b91c1c;border:1px solid #fca5a5;padding:10px;border-radius:10px;font-weight:700;font-size:13px;cursor:pointer;">
                    🚪 ออกจากระบบ
                </button>
            </div>
        </div>
    `;
}

function promptChangePin() {
    if (!currentUser.isLoggedIn || !currentUser.phone) {
        Swal.fire("กรุณาเข้าสู่ระบบก่อนครับ", "", "info");
        return;
    }

    Swal.fire({
        title: "🔒 ตั้งค่า / เปลี่ยนรหัส PIN",
        html: `
            <div style="text-align:left;font-size:13px;padding:4px 0;">
                <label style="font-weight:700;color:#334155;display:block;margin-bottom:4px;">รหัส PIN ปัจจุบัน</label>
                <input id="swalCurrentPin" class="swal2-input" type="password" maxlength="6" inputmode="numeric" style="margin:0 0 6px;width:100%;font-size:15px;" placeholder="รหัส PIN ปัจจุบัน">
                <small style="color:#64748b;display:block;font-size:10px;margin-bottom:12px;">
                    💡 รหัสเริ่มต้นคือ <strong>เลขท้าย 4 ตัวของเบอร์โทรศัพท์</strong> (หากยังไม่เคยเปลี่ยน)
                </small>

                <label style="font-weight:700;color:#334155;display:block;margin-bottom:4px;">รหัส PIN ใหม่ (ตัวเลข 4-6 หลัก)</label>
                <input id="swalNewPin" class="swal2-input" type="password" maxlength="6" inputmode="numeric" style="margin:0 0 12px;width:100%;font-size:15px;" placeholder="ตั้งรหัส PIN ใหม่ 4-6 หลัก">

                <label style="font-weight:700;color:#334155;display:block;margin-bottom:4px;">ยืนยันรหัส PIN ใหม่อีกครั้ง</label>
                <input id="swalConfirmNewPin" class="swal2-input" type="password" maxlength="6" inputmode="numeric" style="margin:0 0 8px;width:100%;font-size:15px;" placeholder="กรอกรหัส PIN ใหม่อีกครั้ง">
            </div>
        `,
        showCancelButton: true,
        confirmButtonText: "💾 บันทึกรหัส PIN ใหม่",
        cancelButtonText: "ยกเลิก",
        confirmButtonColor: "#059669",
        preConfirm: () => {
            const currentPin = document.getElementById("swalCurrentPin")?.value?.trim() || "";
            const newPin = document.getElementById("swalNewPin")?.value?.trim() || "";
            const confirmPin = document.getElementById("swalConfirmNewPin")?.value?.trim() || "";

            if (!currentPin) {
                Swal.showValidationMessage("กรุณากรอกรหัส PIN ปัจจุบันครับ");
                return false;
            }
            if (!newPin || newPin.length < 4 || newPin.length > 6 || !/^[0-9]+$/.test(newPin)) {
                Swal.showValidationMessage("รหัส PIN ใหม่ต้องเป็นตัวเลข 4 ถึง 6 หลักครับ");
                return false;
            }
            if (newPin !== confirmPin) {
                Swal.showValidationMessage("รหัส PIN ใหม่และการยืนยันไม่ตรงกันครับ");
                return false;
            }
            return { currentPin, newPin };
        }
    }).then(async (result) => {
        if (result.isConfirmed && result.value) {
            try {
                Swal.fire({ title: "กำลังบันทึก...", allowOutsideClick: false, didOpen: () => Swal.showLoading() });
                const res = await fetch(`${API_BASE}/change-pin`, {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({
                        phone: currentUser.phone,
                        currentPin: result.value.currentPin,
                        newPin: result.value.newPin
                    })
                });
                const json = await res.json();
                if (json.status === "success") {
                    Swal.fire("🎉 สำเร็จ", json.message || "เปลี่ยนรหัส PIN เรียบร้อยแล้วครับ", "success");
                } else {
                    Swal.fire("ไม่สามารถเปลี่ยนรหัสได้", json.message || "รหัส PIN เดิมไม่ถูกต้อง", "error");
                }
            } catch (e) {
                console.error("Change PIN error:", e);
                Swal.fire("เกิดข้อผิดพลาด", "ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ในขณะนี้", "error");
            }
        }
    });
}

function promptEditDeliveryAddress() {
    Swal.fire({
        title: "✏️ ปรับปรุงที่อยู่จัดส่ง",
        html: `
            <div style="text-align:left;font-size:13px;">
                <label style="font-weight:700;color:#334155;display:block;margin-bottom:4px;">เบอร์โทรศัพท์ติดต่อ</label>
                <input id="swalPhone" class="swal2-input" style="margin:0 0 12px;width:100%;" value="${escapeHtml(currentUser.phone || '')}" placeholder="เช่น 0812345678">
                
                <label style="font-weight:700;color:#334155;display:block;margin-bottom:4px;">ที่อยู่จัดส่ง (บ้านเลขที่ / ซอย / หน้างาน)</label>
                <textarea id="swalAddress" class="swal2-textarea" style="margin:0 0 12px;width:100%;height:80px;" placeholder="ระบุที่อยู่จัดส่ง">${escapeHtml(currentUser.address || '')}</textarea>
            </div>
        `,
        showCancelButton: true,
        confirmButtonText: "💾 บันทึกข้อมูล",
        cancelButtonText: "ยกเลิก",
        confirmButtonColor: "#059669",
        preConfirm: () => {
            const phone = document.getElementById("swalPhone")?.value.trim();
            const address = document.getElementById("swalAddress")?.value.trim();
            if (!phone) {
                Swal.showValidationMessage("กรุณาระบุเบอร์โทรศัพท์");
                return false;
            }
            return { phone, address };
        }
    }).then((result) => {
        if (result.isConfirmed && result.value) {
            currentUser.phone = result.value.phone;
            currentUser.address = result.value.address;
            saveMemberSession(currentUser);
            prefillCustomerForm(currentUser);
            renderMemberProfileView();
            Swal.fire({
                title: "บันทึกเรียบร้อย",
                icon: "success",
                timer: 1500,
                showConfirmButton: false
            });
        }
    });
}

/* =========================================================
   MEMBER HISTORY
   ========================================================= */

async function loadMemberHistory() {
    const listEl = document.getElementById("historyContent");
    if (!listEl) return;

    if (!currentUser.isLoggedIn) {
        listEl.innerHTML = `
            <div class="member-empty">
                <span style="font-size:32px;display:block;margin-bottom:8px;">📋</span>
                <p style="font-weight:700;color:#0f172a;margin-bottom:4px;">เข้าสู่ระบบเพื่อดูประวัติการสั่งซื้อ</p>
                <button type="button" onclick="showLoginOptionsModal()" style="background:#059669;color:#fff;border:none;padding:8px 16px;border-radius:8px;font-weight:700;font-size:12px;cursor:pointer;margin-top:8px;">
                    🔑 เข้าสู่ระบบสมาชิก
                </button>
            </div>
        `;
        return;
    }

    listEl.innerHTML = '<div class="member-empty">กำลังโหลดประวัติ...</div>';
    try {
        const res = await fetch(`/api/v1/rewards-member/my-history`, {
            headers: liffBearerHeaders()
        });
        const json = await res.json();
        const history = Array.isArray(json) ? json : (json.history || []);

        if (!history.length) {
            listEl.innerHTML = '<div class="member-empty">ยังไม่มีประวัติการสั่งซื้อหรือการแลกรางวัล</div>';
            return;
        }

        listEl.innerHTML = history.map(item => {
            return `
                <div class="history-row" style="background:#fff;border:1px solid #e2e8f0;border-radius:14px;padding:12px 14px;">
                    <div>
                        <strong style="font-size:14px;color:#0f172a;">${escapeHtml(item.title || item.reward_name || 'รายการ')}</strong>
                        <small style="color:#64748b;display:block;margin-top:2px;">${escapeHtml(item.details || '')} · ${new Date(item.created_at || item.redeemed_at || Date.now()).toLocaleDateString('th-TH')}</small>
                    </div>
                    <span style="font-size:11px;font-weight:800;padding:2px 8px;border-radius:999px;background:#f0fdf4;color:#047857;">
                        ${escapeHtml(item.status || 'สำเร็จ')}
                    </span>
                </div>
            `;
        }).join('');
    } catch (e) {
        console.error("Error loading history:", e);
        listEl.innerHTML = '<div class="member-empty">ไม่สามารถโหลดประวัติได้ในขณะนี้</div>';
    }
}

