/* ==========================================================================
   CART & CHECKOUT MODULE
   ========================================================================== */

const CART_REQUEST_ID_KEY = "smartpos_shop_cart_request_id";
let shopLat = 16.160189;
let shopLng = 100.802307;

function setShopCoordinates(lat, lng) {
    if (Number.isFinite(lat) && Number.isFinite(lng) && lat !== 0 && lng !== 0) {
        shopLat = lat;
        shopLng = lng;
        updateCartUI();
    }
}

function addToCart(productId) {
    const product = allProducts.find(p => String(p.id) === String(productId)) || 
                    featuredProducts.find(p => String(p.id) === String(productId));
    if (!product) return;

    invalidateCartRequest();

    if (cart[productId]) {
        cart[productId].quantity += 1;
    } else {
        cart[productId] = {
            id: product.id,
            name: product.name,
            price: Number(product.retailPrice) || 0,
            unit: product.unit || "",
            imageUrl: product.imageUrl || "",
            categoryName: product.categoryName || "",
            quantity: 1
        };
    }

    saveCartToStorage();
    updateCartUI();
    updateCardFooter(productId);
    renderFeatured();
}

function changeCartQty(productId, delta) {
    if (!cart[productId]) return;
    invalidateCartRequest();

    const newQty = cart[productId].quantity + delta;
    if (newQty <= 0) {
        removeFromCart(productId);
        return;
    }

    setCartQty(productId, newQty);
}

function removeFromCart(productId) {
    if (!cart[productId]) return;
    invalidateCartRequest();
    delete cart[productId];
    saveCartToStorage();
    updateCartUI();
    updateCardFooter(productId);
    renderFeatured();
}

function setCartQty(productId, rawQuantity, input) {
    const item = cart[productId];
    if (!item) return;
    const quantity = Number(rawQuantity);
    if (!Number.isFinite(quantity) || quantity <= 0) {
        if (input) input.value = formatQuantity(item.quantity);
        return;
    } else {
        const product = allProducts.find((p) => String(p.id) === String(productId)) ||
            featuredProducts.find((p) => String(p.id) === String(productId));
        const stock = Number(product?.stockQuantity);
        if (Number.isFinite(stock) && quantity > stock) {
            if (input) input.value = formatQuantity(item.quantity);
            Swal.fire("จำนวนเกินสต็อก", `สินค้านี้เหลือ ${formatQuantity(stock)} หน่วย`, "warning");
            return;
        }
        item.quantity = Math.round(quantity * 1000) / 1000;
    }

    saveCartToStorage();
    updateCartUI();
    updateCardFooter(productId);
    renderFeatured();
}

function updateCardFooter(productId) {
    const card = document.getElementById(`productCard-${productId}`);
    if (!card) return;
    const footer = card.querySelector('.product-card-footer');
    if (!footer) return;

    const inCartQty = cart[productId]?.quantity || 0;
    const product = allProducts.find(p => String(p.id) === String(productId));
    const outOfStock = product ? isOutOfStock(product) : false;

    if (inCartQty > 0) {
        footer.innerHTML = `
            <div class="grid-qty-stepper">
                <button type="button" onclick="changeCartQty('${productId}', -1)" aria-label="ลดจำนวน">−</button>
                <input type="number" class="qty-input" value="${inCartQty}" min="1" step="1" inputmode="numeric" onfocus="this.select()" onchange="setCartQty('${productId}', this.value, this)" onkeyup="if(event.key==='Enter') this.blur()" aria-label="ระบุจำนวน">
                <button type="button" onclick="changeCartQty('${productId}', 1)" ${outOfStock ? 'disabled' : ''} aria-label="เพิ่มจำนวน">+</button>
            </div>
        `;
    } else {
        footer.innerHTML = `
            <button type="button" class="btn-add-cart" onclick="addToCart('${productId}')" ${outOfStock ? 'disabled' : ''}>
                ${outOfStock ? 'สินค้าหมด' : '+ ใส่ตะกร้า'}
            </button>
        `;
    }
}

function saveCartToStorage() {
    try {
        localStorage.setItem("smartpos_shop_cart", JSON.stringify(cart));
    } catch (e) {}
}

function loadCartFromStorage() {
    try {
        const saved = localStorage.getItem("smartpos_shop_cart");
        if (saved) {
            cart = JSON.parse(saved);
        }
    } catch (e) {
        cart = {};
    }
}

const SAVED_CUSTOMER_KEY = "smartpos_saved_customer_info";

function saveCustomerInfoToStorage() {
    const nameInp = document.getElementById("custNameInput");
    const phoneInp = document.getElementById("custPhoneInput");
    const addrInp = document.getElementById("custAddressInput");
    const gpsInp = document.getElementById("custGpsInput");
    const info = {
        name: nameInp ? nameInp.value.trim() : "",
        phone: phoneInp ? phoneInp.value.trim() : "",
        address: addrInp ? addrInp.value.trim() : "",
        gps: gpsInp ? gpsInp.value.trim() : ""
    };
    if (info.name || info.phone || info.address || info.gps) {
        try {
            localStorage.setItem(SAVED_CUSTOMER_KEY, JSON.stringify(info));
        } catch (_) {}
    }
}

function loadSavedCustomerInfo() {
    try {
        const saved = localStorage.getItem(SAVED_CUSTOMER_KEY);
        if (saved) {
            const info = JSON.parse(saved);
            const nameInp = document.getElementById("custNameInput");
            const phoneInp = document.getElementById("custPhoneInput");
            const addrInp = document.getElementById("custAddressInput");
            const gpsInp = document.getElementById("custGpsInput");
            const gpsLink = document.getElementById("gpsMapLink");

            if (nameInp && !nameInp.value && info.name) nameInp.value = info.name;
            if (phoneInp && !phoneInp.value && info.phone) phoneInp.value = info.phone;
            if (addrInp && !addrInp.value && info.address) addrInp.value = info.address;
            if (gpsInp && !gpsInp.value && info.gps) {
                gpsInp.value = info.gps;
                if (gpsLink) {
                    const safeMap = safeHttpUrl(info.gps.startsWith("http") ? info.gps : `https://www.google.com/maps?q=${encodeURIComponent(info.gps)}`);
                    if (safeMap) {
                        gpsLink.href = safeMap;
                        gpsLink.classList.remove("hidden");
                    }
                }
            }
        }
    } catch (_) {}
}

function initCustomerInfoPersistence() {
    loadSavedCustomerInfo();
    const fields = ["custNameInput", "custPhoneInput", "custAddressInput", "custGpsInput"];
    fields.forEach(id => {
        const el = document.getElementById(id);
        if (el) {
            el.addEventListener("input", () => saveCustomerInfoToStorage());
            el.addEventListener("change", () => saveCustomerInfoToStorage());
            el.addEventListener("blur", () => saveCustomerInfoToStorage());
        }
    });
}

function createClientRequestId() {
    if (window.crypto && typeof window.crypto.randomUUID === "function") {
        return window.crypto.randomUUID();
    }
    if (!window.crypto || typeof window.crypto.getRandomValues !== "function") {
        throw new Error("Secure UUID generation is unavailable");
    }
    const bytes = new Uint8Array(16);
    window.crypto.getRandomValues(bytes);
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    const hex = Array.from(bytes, b => b.toString(16).padStart(2, "0")).join("");
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function ensureCartClientRequestId() {
    if (cartClientRequestId) return cartClientRequestId;
    const saved = localStorage.getItem(CART_REQUEST_ID_KEY);
    cartClientRequestId = saved || createClientRequestId();
    localStorage.setItem(CART_REQUEST_ID_KEY, cartClientRequestId);
    return cartClientRequestId;
}

function invalidateCartRequest() {
    cartClientRequestId = null;
    localStorage.removeItem(CART_REQUEST_ID_KEY);
}

function completeCartRequest() {
    invalidateCartRequest();
}

function calculateRoadDistanceKm(lat, lng) {
    if (!lat || !lng) return 0;
    const R = 6371.0;
    const dLat = (lat - shopLat) * Math.PI / 180;
    const dLon = (lng - shopLng) * Math.PI / 180;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(shopLat * Math.PI / 180) * Math.cos(lat * Math.PI / 180) *
              Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    const directKm = R * c;
    return directKm * 1.35; // Road factor
}

function parseGpsInput(val) {
    if (!val) return null;
    val = val.trim();
    const match = val.match(/([0-9]+\.[0-9]+)\s*,\s*([0-9]+\.[0-9]+)/);
    if (match) {
        return { lat: parseFloat(match[1]), lng: parseFloat(match[2]) };
    }
    return null;
}

function hasHeavyMaterials() {
    return Object.values(cart).some(it => {
        const n = (it.name || '').toLowerCase();
        return n.includes('เสา') || n.includes('วงบ่อ') || n.includes('อิฐบล็อก') || n.includes('บล็อก') || n.includes('ท่อปูน') || n.includes('แผ่นพื้น') || n.includes('ถังน้ำ');
    });
}

function calculateDeliveryFee(distanceKm, estimatedProfit, isHeavy) {
    if (selectedDeliveryType === 'pickup') {
        return { fee: 0, isFree: true, label: "ไม่มีค่าจัดส่ง (รับเองที่ร้าน)", distanceKm: 0 };
    }

    if (!distanceKm || distanceKm <= 0) {
        return { fee: 0, isFree: false, label: "ปักหมุด GPS เพื่อประเมิน", distanceKm: 0 };
    }

    let fee = 0;
    if (distanceKm <= 5.0) {
        fee = 50;
    } else if (distanceKm <= 10.0) {
        fee = 100;
    } else if (distanceKm <= 15.0) {
        fee = 150;
    } else if (distanceKm <= 20.0) {
        fee = 200;
    } else if (distanceKm <= 30.0) {
        fee = 300;
    } else {
        fee = 300 + Math.round((distanceKm - 30) * 12);
    }

    let label = `฿${formatMoney(fee)} (ประเมิน)`;
    return { fee, isFree: false, label, distanceKm };
}

function updateCartUI() {
    const bar = document.getElementById("cartFloatingBar");
    const countBadge = document.getElementById("cartTotalCount");
    const priceVal = document.getElementById("cartTotalPrice");
    const sectionBadge = document.getElementById("cartSectionItemCount");
    const summaryCount = document.getElementById("summaryItemCount");
    const summarySubtotal = document.getElementById("summarySubtotal");
    const summaryShipping = document.getElementById("summaryShipping");
    const summaryTotal = document.getElementById("summaryTotal");
    const heavyNotice = document.getElementById("heavyGoodsNotice");

    let totalQty = 0;
    let subtotal = 0;
    let hasPendingPrice = false;

    Object.values(cart).forEach(it => {
        totalQty += it.quantity;
        if (it.isPricePending || it.price <= 0) {
            hasPendingPrice = true;
        } else {
            subtotal += (it.quantity * it.price);
        }
    });

    const estimatedProfit = subtotal * 0.28;
    const gpsVal = document.getElementById("custGpsInput")?.value || "";
    const coords = parseGpsInput(gpsVal);
    const distKm = coords ? calculateRoadDistanceKm(coords.lat, coords.lng) : 0;
    const isHeavy = hasHeavyMaterials();

    const deliv = calculateDeliveryFee(distKm, estimatedProfit, isHeavy);
    const totalNet = subtotal + deliv.fee;

    if (countBadge) countBadge.innerText = totalQty;
    if (priceVal) priceVal.innerHTML = `฿${formatMoney(totalNet)}${hasPendingPrice ? ' <small style="font-size:10px;color:#fef08a;">(+ รอเช็คราคาสี)</small>' : ''}`;
    if (sectionBadge) sectionBadge.innerText = `${totalQty} ชิ้น`;
    if (summaryCount) summaryCount.innerText = totalQty;
    if (summarySubtotal) {
        summarySubtotal.innerHTML = `฿${formatMoney(subtotal)}${hasPendingPrice ? ' <small style="color:#d97706;font-weight:700;">(+ มีรายการรอเช็คราคา)</small>' : ''}`;
    }
    if (summaryShipping) {
        summaryShipping.innerText = deliv.label;
        summaryShipping.className = deliv.isFree ? "free-badge" : "price-figure";
    }
    if (summaryTotal) {
        summaryTotal.innerHTML = `฿${formatMoney(totalNet)}${hasPendingPrice ? ' <small style="color:#d97706;font-size:11px;">(+ รอเช็คราคา)</small>' : ''}`;
    }

    if (heavyNotice) {
        if (isHeavy && distKm > 6.0) {
            heavyNotice.classList.remove("hidden");
        } else {
            heavyNotice.classList.add("hidden");
        }
    }

    if (bar) {
        if (totalQty > 0) {
            bar.classList.remove("hidden");
        } else {
            bar.classList.add("hidden");
        }
    }

    renderCartItems();
}

function renderCartItems() {
    const list = document.getElementById("inpageCartItemsList") || document.getElementById("cartItemsList");
    if (!list) return;

    const items = Object.values(cart);
    if (items.length === 0) {
        list.innerHTML = `
            <div class="empty-cart-state" id="emptyCartState">
                <div class="empty-cart-icon">🛒</div>
                <p class="empty-title" style="font-weight:700;margin-top:8px;color:#0f172a;">ยังไม่มีสินค้าในตะกร้า</p>
                <p class="empty-desc" style="font-size:12px;color:#64748b;margin-top:4px;">กดปุ่ม <strong>[ + ใส่ตะกร้า ]</strong> จากรายการสินค้าด้านบนเพื่อเริ่มสั่งซื้อ</p>
            </div>
        `;
        return;
    }

    list.innerHTML = items.map(it => {
        const itemTotal = it.isPricePending || it.price <= 0 ? 'รอเช็คราคา' : `฿${formatMoney(it.price * it.quantity)}`;
        return `
            <div class="cart-item-row" id="cartRow-${it.id}" style="margin-bottom:8px;">
                <div class="cart-item-info">
                    <div class="cart-item-title">${escapeHtml(it.name)}</div>
                    <div class="cart-item-sub">
                        ${it.isPricePending || it.price <= 0 ? '<span style="color:#d97706;font-weight:700;">(รอเช็คราคา)</span>' : `฿${formatMoney(it.price)} x ${it.quantity} = <strong>${itemTotal}</strong>`}
                    </div>
                </div>
                <div class="cart-item-stepper">
                    <button type="button" onclick="changeCartQty('${it.id}', -1)">-</button>
                    <input type="number" class="cart-qty-input" value="${it.quantity}" min="1" step="1" inputmode="numeric" onfocus="this.select()" onchange="setCartQty('${it.id}', this.value, this)" onkeyup="if(event.key==='Enter') this.blur()" aria-label="ระบุจำนวน">
                    <button type="button" onclick="changeCartQty('${it.id}', 1)">+</button>
                    <button type="button" class="cart-item-remove" onclick="removeFromCart('${it.id}')" title="ลบออกจากตะกร้า">🗑️</button>
                </div>
            </div>
        `;
    }).join('');
}

function openCartSheet() {
    const block = document.getElementById("cartItemsBlock");
    if (block) {
        block.classList.add("is-open");
        block.scrollIntoView({ behavior: 'smooth', block: 'start' });
        updateCartUI();
    }
}

function closeCartSheet() {
    const block = document.getElementById("cartItemsBlock");
    if (block) {
        block.classList.remove("is-open");
    }
}

function selectDeliveryType(type) {
    selectedDeliveryType = type;
    document.querySelectorAll(".delivery-type-btn").forEach(btn => {
        btn.classList.toggle("active", btn.getAttribute("data-type") === type);
    });
    updateCartUI();
}

function getCurrentGpsLocation() {
    const btn = document.getElementById("btnGetGps");
    const input = document.getElementById("custGpsInput");
    const link = document.getElementById("gpsMapLink");
    const notice = document.getElementById("gpsStatusNotice");

    if (!navigator.geolocation) {
        Swal.fire("ไม่รองรับ GPS", "อุปกรณ์ของคุณไม่รองรับการดึงพิกัดตำแหน่งครับ", "warning");
        return;
    }

    if (btn) {
        btn.disabled = true;
        btn.innerHTML = "⏳ กำลังจับสัญญาณ...";
    }
    if (notice) {
        notice.className = "gps-status-notice";
        notice.innerText = "กำลังค้นหาพิกัดดาวเทียม...";
        notice.classList.remove("hidden");
    }

    navigator.geolocation.getCurrentPosition(
        (pos) => {
            const lat = pos.coords.latitude;
            const lng = pos.coords.longitude;
            const coordsStr = `${lat.toFixed(6)}, ${lng.toFixed(6)}`;

            if (input) input.value = coordsStr;
            invalidateCartRequest();

            if (link) {
                const safeMap = safeHttpUrl(`https://www.google.com/maps?q=${coordsStr}`);
                if (safeMap) {
                    link.href = safeMap;
                    link.classList.remove("hidden");
                }
            }

            if (notice) {
                notice.className = "gps-status-notice success";
                notice.innerText = `✅ จับพิกัดสำเร็จ: ${coordsStr} (ความแม่นยำ ~${Math.round(pos.coords.accuracy)} ม.)`;
            }

            if (btn) {
                btn.disabled = false;
                btn.innerHTML = "📍 อัปเดตพิกัด GPS";
            }

            updateCartUI();
        },
        (err) => {
            console.warn("GPS error:", err);
            if (notice) {
                notice.className = "gps-status-notice error";
                notice.innerText = "⚠️ ไม่สามารถจับพิกัดได้ โปรดอนุญาตสิทธิ์เข้าถึงตำแหน่งที่ตั้ง หรือคัดลอกลิงก์ Google Maps มาวางแทนครับ";
            }
            if (btn) {
                btn.disabled = false;
                btn.innerHTML = "📍 ลองใหม่อีกครั้ง";
            }
        },
        { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
    );
}

async function submitOrder() {
    const items = Object.values(cart);
    if (items.length === 0) {
        Swal.fire("ตะกร้าว่างเปล่า", "กรุณาเลือกสินค้าก่อนยืนยันการสั่งซื้อครับ", "warning");
        return;
    }

    const nameInp = document.getElementById("custNameInput");
    const phoneInp = document.getElementById("custPhoneInput");
    const addrInp = document.getElementById("custAddressInput");
    const noteInp = document.getElementById("custNotesInput") || document.getElementById("custNoteInput");
    const gpsInp = document.getElementById("custGpsInput");
    const couponSelect = document.getElementById("checkoutCouponSelect");
    const couponCode = couponSelect ? couponSelect.value.trim() : "";

    const custName = nameInp ? nameInp.value.trim() : "";
    const custPhone = phoneInp ? phoneInp.value.trim() : "";
    const custAddress = addrInp ? addrInp.value.trim() : "";
    const custNote = noteInp ? noteInp.value.trim() : "";
    const custGps = gpsInp ? gpsInp.value.trim() : "";

    if (!custName) {
        Swal.fire("กรุณาระบุชื่อ", "โปรดระบุชื่อผู้ติดต่อสำหรับการจัดส่งครับ", "warning");
        return;
    }
    if (!custPhone) {
        Swal.fire("กรุณาระบุเบอร์โทร", "โปรดระบุเบอร์โทรศัพท์สำหรับติดต่อยืนยันออเดอร์ครับ", "warning");
        return;
    }
    if (selectedDeliveryType === 'delivery' && !custAddress) {
        Swal.fire("กรุณาระบุที่อยู่", "โปรดระบุที่อยู่จัดส่ง หรือจุดสังเกตหน้างานครับ", "warning");
        return;
    }

    let subtotal = 0;
    items.forEach(it => {
        if (!it.isPricePending && it.price > 0) {
            subtotal += (it.price * it.quantity);
        }
    });

    const coords = parseGpsInput(custGps);
    const distKm = coords ? calculateRoadDistanceKm(coords.lat, coords.lng) : 0;
    const deliv = calculateDeliveryFee(distKm, subtotal * 0.28, hasHeavyMaterials());
    const totalNet = subtotal + deliv.fee;

    const payload = {
        clientRequestId: ensureCartClientRequestId(),
        customerName: custName,
        customerPhone: custPhone,
        deliveryType: selectedDeliveryType || 'delivery',
        deliveryAddress: selectedDeliveryType === 'pickup' ? 'รับเองที่หน้าร้าน' : custAddress,
        deliveryFee: deliv.fee,
        gpsLocation: custGps,
        notes: custNote,
        totalAmount: totalNet,
        ...(couponCode ? { couponCode: couponCode } : {}),
        items: items.map(it => ({
            productId: parseInt(it.id, 10),
            name: it.name,
            price: parseFloat(it.price) || 0,
            quantity: parseFloat(it.quantity) || 1,
            isPricePending: Boolean(it.isPricePending),
            isCustomTint: Boolean(it.isCustomTint),
            isMetalSheet: Boolean(it.isMetalSheet),
            colorCode: it.colorCode || "",
            cutBreakdown: it.cutBreakdown || ""
        }))
    };

    try {
        Swal.fire({
            title: "กำลังส่งคำสั่งซื้อ...",
            allowOutsideClick: false,
            didOpen: () => Swal.showLoading()
        });

        const res = await fetch(`${API_BASE}/orders`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                ...(liffIdToken ? { "Authorization": `Bearer ${liffIdToken}` } : {})
            },
            body: JSON.stringify(payload)
        });

        const json = await res.json();

        if (json.status === "success" || json.orderId) {
            completeCartRequest();
            cart = {};
            saveCartToStorage();
            updateCartUI();
            closeCartSheet();

            Swal.fire({
                title: "🎉 สั่งซื้อสำเร็จ!",
                html: `
                    เลขที่ออเดอร์: <strong>#${json.orderNumber || json.orderId}</strong><br>
                    ยอดรวม: <strong>฿${formatMoney(json.grandTotal || totalNet)}</strong><br>
                    <p style="margin-top:8px;font-size:12px;color:#64748b;">ทางร้านได้รับรายการแล้ว และจะติดต่อกลับเพื่อยืนยันการจัดส่งครับ</p>
                `,
                icon: "success",
                confirmButtonColor: "#059669"
            });
        } else {
            Swal.fire("ไม่สามารถส่งออเดอร์ได้", json.message || "โปรดลองใหม่อีกครั้งครับ", "error");
        }
    } catch (err) {
        console.error("Checkout error:", err);
        Swal.fire("เกิดข้อผิดพลาด", "ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ โปรดตรวจสอบการเชื่อมต่ออินเทอร์เน็ตครับ", "error");
    }
}
