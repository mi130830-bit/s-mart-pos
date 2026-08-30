/* ==========================================================================
   PAINT STUDIO MODULE (Beger Cool 2in1)
   ========================================================================== */

let selectedPaintProductId = 6549; // Default 1 GL (~3.5 ลิตร)
let selectedPaintSizeLabel = "1 แกลลอน (~3.5 ลิตร)";
let selectedPaintSizeKey = "1gl";
let selectedPaintQty = 1;
let matchedPaintProduct = null;
let paintLookupTimer = null;

function openPaintStudio() {
    const modal = document.getElementById("paintStudioModal");
    if (!modal) return;
    modal.classList.remove("hidden");
    const codeInput = document.getElementById("paintColorCodeInput");
    if (codeInput) {
        codeInput.value = "";
        setTimeout(() => codeInput.focus(), 150);
    }
    matchedPaintProduct = null;
    checkPaintCodeLookup();
}

function closePaintStudio() {
    const modal = document.getElementById("paintStudioModal");
    if (modal) modal.classList.add("hidden");
}

function selectPaintSize(productId, sizeLabel, el) {
    selectedPaintProductId = productId;
    selectedPaintSizeLabel = sizeLabel;
    if (productId === 6555) selectedPaintSizeKey = "0.25gl";
    else if (productId === 6550) selectedPaintSizeKey = "2.5gl";
    else selectedPaintSizeKey = "1gl";

    document.querySelectorAll(".paint-size-option").forEach(opt => opt.classList.remove("active"));
    if (el) el.classList.add("active");
    checkPaintCodeLookup();
}

function adjustPaintQty(delta) {
    const qtyInput = document.getElementById("paintQtyInput");
    if (!qtyInput) return;
    let val = parseInt(qtyInput.value || "1", 10) + delta;
    if (val < 1) val = 1;
    if (val > 100) val = 100;
    selectedPaintQty = val;
    qtyInput.value = val;
}

function checkPaintCodeLookup() {
    const codeInput = document.getElementById("paintColorCodeInput");
    const badge = document.getElementById("paintLookupBadge");
    const hint = document.getElementById("paintLookupHint");
    if (!codeInput || !badge) return;

    if (paintLookupTimer) clearTimeout(paintLookupTimer);

    const rawCode = codeInput.value.trim();
    if (!rawCode) {
        matchedPaintProduct = null;
        badge.className = "paint-lookup-badge pending";
        badge.innerText = "รอเช็คราคา";
        if (hint) hint.innerHTML = "ℹ️ หากเป็นรหัสสีที่ยังไม่มีในระบบ ทางร้านจะโทรติดต่อกลับเพื่อพูดคุยรายละเอียดและแจ้งราคาให้ทราบโดยตรงครับ";
        return;
    }

    badge.className = "paint-lookup-badge pending";
    badge.innerText = "กำลังค้นหา...";

    paintLookupTimer = setTimeout(async () => {
        try {
            const res = await fetch(`${API_BASE}/paint-lookup?code=${encodeURIComponent(rawCode)}&size=${encodeURIComponent(selectedPaintSizeKey)}`);
            const json = await res.json();

            if (json.status === "success" && json.found && json.product && json.product.price > 0) {
                matchedPaintProduct = json.product;
                badge.className = "paint-lookup-badge found";
                badge.innerText = `฿${formatMoney(matchedPaintProduct.price)}`;
                if (hint) {
                    const stockText = matchedPaintProduct.stock > 0 ? ` (คงเหลือ ${matchedPaintProduct.stock} ถัง)` : ' (สต็อก 0 ถัง)';
                    hint.innerHTML = `✅ พบราคาในระบบ: <strong>${escapeHtml(matchedPaintProduct.name)}</strong> · <strong>฿${formatMoney(matchedPaintProduct.price)}</strong>${stockText} (สั่งซื้อได้ทันที)`;
                }
            } else {
                matchedPaintProduct = null;
                badge.className = "paint-lookup-badge pending";
                badge.innerText = "รอเช็คราคา";
                if (hint) hint.innerHTML = "📞 รหัสสีผสมใหม่: เมื่อสั่งซื้อแล้ว <strong>ทางร้านจะโทรติดต่อกลับเพื่อพูดคุยและแจ้งราคาโดยตรงครับ</strong>";
            }
        } catch (e) {
            console.error("Paint lookup API error:", e);
            matchedPaintProduct = null;
            badge.className = "paint-lookup-badge pending";
            badge.innerText = "รอเช็คราคา";
        }
    }, 250);
}

function confirmPaintToCart() {
    const codeInput = document.getElementById("paintColorCodeInput");
    const code = codeInput ? codeInput.value.trim() : "";
    if (!code) {
        Swal.fire({
            title: "กรุณาระบุรหัสสี",
            text: "โปรดระบุรหัสเฉดสี เช่น 141-4, OW3-3 หรือชื่อเฉดสีที่ต้องการครับ",
            icon: "warning",
            confirmButtonColor: "#0284c7"
        });
        return;
    }

    const productId = matchedPaintProduct ? matchedPaintProduct.id : selectedPaintProductId;
    const price = matchedPaintProduct ? matchedPaintProduct.price : 0;
    const isPricePending = !matchedPaintProduct || price <= 0;
    const displayName = matchedPaintProduct ? matchedPaintProduct.name : `สีผสม Beger Cool 2in1 (กึ่งเงา) รหัส ${code} [${selectedPaintSizeLabel}]`;

    invalidateCartRequest();

    cart[productId] = {
        id: productId,
        name: displayName,
        price: price,
        quantity: selectedPaintQty,
        colorCode: code,
        sizeLabel: selectedPaintSizeLabel,
        isPricePending: isPricePending,
        isCustomTint: true,
        barcode: matchedPaintProduct ? matchedPaintProduct.barcode : "",
        sheen: "กึ่งเงา (Semi-Gloss)"
    };

    saveCartToStorage();
    updateCartUI();
    closePaintStudio();

    Swal.fire({
        title: "เพิ่มลงตะกร้าแล้ว!",
        html: `
            <strong>${escapeHtml(displayName)}</strong><br>จำนวน ${selectedPaintQty} ถัง
            ${!isPricePending ? `<br><span style="color:#0284c7;font-size:14px;font-weight:800;">ยอดรวม: ฿${formatMoney(price * selectedPaintQty)}</span>` : '<br><span style="color:#d97706;font-size:12px;font-weight:700;">(อยู่ระหว่างเช็คราคา ทางร้านจะโทรติดต่อกลับเพื่อแจ้งยอดครับ)</span>'}
            <div style="margin-top: 10px; text-align: left; background: #fffbeb; border: 1px solid #fde68a; padding: 8px 12px; border-radius: 8px; font-size: 11px; color: #92400e; line-height: 1.4;">
                ⚠️ <strong>ข้อควรทราบ:</strong> สีบนหน้าจออาจคลาดเคลื่อนจากสีจริง และสีผสมคอมพิวเตอร์เป็นสินค้าสั่งทำเฉพาะ ไม่สามารถเปลี่ยนหรือคืนได้ครับ
            </div>
        `,
        icon: "success",
        timer: 3500,
        showConfirmButton: false
    });
}
