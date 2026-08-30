/* ==========================================================================
   METAL SHEET STUDIO MODULE (ลอน 760 สั่งตัดตามขนาด & หลายขนาดความยาว)
   ========================================================================== */

let metalSheetOptions = {
    'MS-760-AZ030': { id: 6556, barcode: 'MS-760-AZ030', name: 'แผ่นหลังคาเมทัลชีท ลอน 760 (อลูซิงค์ 0.30 มม.)', price: 80.0 },
    'MS-760-AZ035': { id: 6557, barcode: 'MS-760-AZ035', name: 'แผ่นหลังคาเมทัลชีท ลอน 760 (อลูซิงค์ 0.35 มม.)', price: 95.0 },
    'MS-760-COL035': { id: 6558, barcode: 'MS-760-COL035', name: 'แผ่นหลังคาเมทัลชีท ลอน 760 (เคลือบสี 0.35 มม.)', price: 105.0 },
    'MS-760-COL040': { id: 6559, barcode: 'MS-760-COL040', name: 'แผ่นหลังคาเมทัลชีท ลอน 760 (เคลือบสี 0.40 มม.)', price: 120.0 },
    'MS-OPT-PE5MM': { id: 6560, barcode: 'MS-OPT-PE5MM', name: 'เสริมฉนวนกันความร้อน PE Foam (5 มม.)', price: 25.0 },
    'MS-OPT-PU25MM': { id: 6561, barcode: 'MS-OPT-PU25MM', name: 'เสริมฉนวนกันความร้อน PU Foam (25 มม.)', price: 70.0 }
};

let currentMetalBarcode = 'MS-760-AZ030';
let currentMetalColor = 'อลูซิงค์ธรรมชาติ';
let currentInsulationBarcode = 'NONE';
let currentInsulationPrice = 0.0;
let currentInsulationName = 'ไม่ติดฉนวน';

// Multi-Length Cut List State
let metalCutRows = [
    { id: 1, length: 3.50, qty: 10 }
];
let nextCutRowId = 2;

async function fetchMetalSheetOptions() {
    try {
        const res = await fetch(`${API_BASE}/metal-sheet-options`);
        const json = await res.json();
        if (json.status === 'success' && json.data) {
            metalSheetOptions = { ...metalSheetOptions, ...json.data };
            updateMetalPriceTags();
        }
    } catch (e) {
        console.warn('Unable to load live metal sheet options from server:', e);
    }
}

function updateMetalPriceTags() {
    if (metalSheetOptions['MS-760-AZ030']) {
        const el = document.getElementById('priceTagMsAZ030');
        if (el) el.innerText = `฿${formatMoney(metalSheetOptions['MS-760-AZ030'].price)} / ม.`;
    }
    if (metalSheetOptions['MS-760-AZ035']) {
        const el = document.getElementById('priceTagMsAZ035');
        if (el) el.innerText = `฿${formatMoney(metalSheetOptions['MS-760-AZ035'].price)} / ม.`;
    }
    if (metalSheetOptions['MS-760-COL035']) {
        const el = document.getElementById('priceTagMsCOL035');
        if (el) el.innerText = `฿${formatMoney(metalSheetOptions['MS-760-COL035'].price)} / ม.`;
    }
    if (metalSheetOptions['MS-760-COL040']) {
        const el = document.getElementById('priceTagMsCOL040');
        if (el) el.innerText = `฿${formatMoney(metalSheetOptions['MS-760-COL040'].price)} / ม.`;
    }
    if (metalSheetOptions['MS-OPT-PE5MM']) {
        const el = document.getElementById('priceTagPe');
        if (el) el.innerText = `+฿${formatMoney(metalSheetOptions['MS-OPT-PE5MM'].price)} / ม.`;
    }
    if (metalSheetOptions['MS-OPT-PU25MM']) {
        const el = document.getElementById('priceTagPu');
        if (el) el.innerText = `+฿${formatMoney(metalSheetOptions['MS-OPT-PU25MM'].price)} / ม.`;
    }
    recalcMetalSheetTotal();
}

function openMetalSheetStudio() {
    const modal = document.getElementById('metalSheetStudioModal');
    if (!modal) return;
    modal.classList.remove('hidden');

    if (!metalCutRows || metalCutRows.length === 0) {
        metalCutRows = [{ id: 1, length: 3.50, qty: 10 }];
        nextCutRowId = 2;
    }

    renderCutRows();
    fetchMetalSheetOptions();
    recalcMetalSheetTotal();
}

function closeMetalSheetStudio() {
    const modal = document.getElementById('metalSheetStudioModal');
    if (modal) modal.classList.add('hidden');
}

function selectMetalType(barcode, el) {
    currentMetalBarcode = barcode;
    document.querySelectorAll('.metal-type-option').forEach(opt => opt.classList.remove('active'));
    if (el) el.classList.add('active');

    const colorGroup = document.getElementById('metalColorGroup');
    if (barcode.includes('COL')) {
        if (colorGroup) colorGroup.style.display = 'flex';
        if (currentMetalColor === 'อลูซิงค์ธรรมชาติ') currentMetalColor = 'น้ำเงิน';
    } else {
        if (colorGroup) colorGroup.style.display = 'none';
        currentMetalColor = 'อลูซิงค์ธรรมชาติ';
    }
    recalcMetalSheetTotal();
}

function selectMetalColor(colorName, el) {
    currentMetalColor = colorName;
    document.querySelectorAll('.metal-color-option').forEach(opt => opt.classList.remove('active'));
    if (el) el.classList.add('active');
    recalcMetalSheetTotal();
}

function selectMetalInsulation(insulationCode, addPrice, el) {
    currentInsulationBarcode = insulationCode;
    currentInsulationPrice = (insulationCode !== 'NONE' && metalSheetOptions[insulationCode]) ? metalSheetOptions[insulationCode].price : addPrice;
    currentInsulationName = insulationCode === 'NONE' ? 'ไม่ติดฉนวน' : (insulationCode === 'MS-OPT-PE5MM' ? 'บุฉนวน PE (5 มม.)' : 'บุฉนวน PU (25 มม.)');
    
    document.querySelectorAll('.metal-insulation-option').forEach(opt => opt.classList.remove('active'));
    if (el) el.classList.add('active');
    recalcMetalSheetTotal();
}

/* =========================================================
   MULTI-LENGTH CUT LIST METHODS
   ========================================================= */

function renderCutRows() {
    const container = document.getElementById('metalCutListContainer');
    if (!container) return;

    container.innerHTML = metalCutRows.map((row, index) => {
        const subMeters = (row.length * row.qty).toFixed(2);
        return `
            <div class="metal-cut-row" data-id="${row.id}">
                <div class="cut-row-main">
                    <span class="cut-row-badge">#${index + 1}</span>
                    
                    <div class="cut-length-input-wrap">
                        <input type="number" step="0.05" min="0.5" max="15.0" value="${row.length.toFixed(2)}" 
                               oninput="updateRowLength(${row.id}, this.value)">
                        <span class="unit-text">ม.</span>
                    </div>

                    <span class="cut-multiply">×</span>

                    <div class="cut-qty-stepper">
                        <button type="button" class="cut-qty-btn" onclick="adjustRowQty(${row.id}, -1)">-</button>
                        <input type="number" min="1" max="500" value="${row.qty}" 
                               oninput="updateRowQty(${row.id}, this.value)">
                        <button type="button" class="cut-qty-btn" onclick="adjustRowQty(${row.id}, 1)">+</button>
                    </div>

                    <span class="cut-subtotal-meters" id="cutSubMeters_${row.id}">${subMeters} ม.</span>

                    ${metalCutRows.length > 1 ? `
                        <button type="button" class="cut-remove-row-btn" onclick="removeCutRow(${row.id})" title="ลบรายการนี้">🗑️</button>
                    ` : `<span style="width: 24px;"></span>`}
                </div>

                <div class="cut-row-presets">
                    <button type="button" class="preset-btn ${row.length === 2.0 ? 'active' : ''}" onclick="setRowPreset(${row.id}, 2.00)">2.0ม.</button>
                    <button type="button" class="preset-btn ${row.length === 3.0 ? 'active' : ''}" onclick="setRowPreset(${row.id}, 3.00)">3.0ม.</button>
                    <button type="button" class="preset-btn ${row.length === 3.5 ? 'active' : ''}" onclick="setRowPreset(${row.id}, 3.50)">3.5ม.</button>
                    <button type="button" class="preset-btn ${row.length === 4.0 ? 'active' : ''}" onclick="setRowPreset(${row.id}, 4.00)">4.0ม.</button>
                    <button type="button" class="preset-btn ${row.length === 5.0 ? 'active' : ''}" onclick="setRowPreset(${row.id}, 5.00)">5.0ม.</button>
                    <button type="button" class="preset-btn ${row.length === 6.0 ? 'active' : ''}" onclick="setRowPreset(${row.id}, 6.00)">6.0ม.</button>
                </div>
            </div>
        `;
    }).join('');
}

function addCutRow() {
    // Default length for new row
    let newLength = 3.00;
    if (metalCutRows.length > 0) {
        newLength = metalCutRows[metalCutRows.length - 1].length;
    }
    metalCutRows.push({
        id: nextCutRowId++,
        length: newLength,
        qty: 5
    });
    renderCutRows();
    recalcMetalSheetTotal();
}

function removeCutRow(rowId) {
    if (metalCutRows.length <= 1) return;
    metalCutRows = metalCutRows.filter(r => r.id !== rowId);
    renderCutRows();
    recalcMetalSheetTotal();
}

function updateRowLength(rowId, val) {
    const row = metalCutRows.find(r => r.id === rowId);
    if (!row) return;
    let len = parseFloat(val);
    if (isNaN(len) || len < 0.1) len = 0.5;
    row.length = len;

    const subEl = document.getElementById(`cutSubMeters_${rowId}`);
    if (subEl) subEl.innerText = `${(row.length * row.qty).toFixed(2)} ม.`;

    recalcMetalSheetTotal();
}

function updateRowQty(rowId, val) {
    const row = metalCutRows.find(r => r.id === rowId);
    if (!row) return;
    let qty = parseInt(val, 10);
    if (isNaN(qty) || qty < 1) qty = 1;
    row.qty = qty;

    const subEl = document.getElementById(`cutSubMeters_${rowId}`);
    if (subEl) subEl.innerText = `${(row.length * row.qty).toFixed(2)} ม.`;

    recalcMetalSheetTotal();
}

function adjustRowQty(rowId, delta) {
    const row = metalCutRows.find(r => r.id === rowId);
    if (!row) return;
    let val = row.qty + delta;
    if (val < 1) val = 1;
    if (val > 500) val = 500;
    row.qty = val;

    renderCutRows();
    recalcMetalSheetTotal();
}

function setRowPreset(rowId, meters) {
    const row = metalCutRows.find(r => r.id === rowId);
    if (!row) return;
    row.length = meters;
    renderCutRows();
    recalcMetalSheetTotal();
}

function recalcMetalSheetTotal() {
    let totalMeters = 0;
    let totalSheets = 0;

    metalCutRows.forEach(row => {
        totalMeters += (row.length * row.qty);
        totalSheets += row.qty;
    });

    const baseProduct = metalSheetOptions[currentMetalBarcode] || { price: 80.0, name: 'แผ่นหลังคาเมทัลชีท ลอน 760' };
    const basePricePerMeter = baseProduct.price;
    const unitPricePerMeter = basePricePerMeter + currentInsulationPrice;
    const totalPrice = totalMeters * unitPricePerMeter;

    const summaryBadge = document.getElementById('msCutSummaryBadge');
    if (summaryBadge) {
        summaryBadge.innerText = `${metalCutRows.length} ขนาด · ${totalSheets} แผ่น · รวม ${totalMeters.toFixed(2)} เมตร`;
    }

    const priceBadge = document.getElementById('msTotalPriceBadge');
    if (priceBadge) priceBadge.innerText = `฿${formatMoney(totalPrice)}`;

    const subtext = document.getElementById('msCalcBreakdownText');
    if (subtext) {
        const insulationText = currentInsulationPrice > 0 ? ` + ฉนวน ฿${formatMoney(currentInsulationPrice)}` : '';
        subtext.innerText = `(ความยาวรวม ${totalMeters.toFixed(2)} ม. x ฿${formatMoney(unitPricePerMeter)}/ม.${insulationText})`;
    }
}

function confirmMetalSheetToCart() {
    let totalMeters = 0;
    let totalSheets = 0;

    metalCutRows.forEach(row => {
        totalMeters += (row.length * row.qty);
        totalSheets += row.qty;
    });

    if (totalMeters <= 0 || totalSheets <= 0) {
        Swal.fire('ข้อมูลไม่ถูกต้อง', 'กรุณาระบุความยาวและจำนวนแผ่นให้ถูกต้องครับ', 'warning');
        return;
    }

    const baseProduct = metalSheetOptions[currentMetalBarcode] || { id: 6556, price: 80.0, name: 'แผ่นหลังคาเมทัลชีท ลอน 760 (อลูซิงค์ 0.30 มม.)' };
    const basePricePerMeter = baseProduct.price;
    const unitPricePerMeter = basePricePerMeter + currentInsulationPrice;
    const totalPrice = totalMeters * unitPricePerMeter;

    const customNoteInput = document.getElementById('msCustomNote');
    const customNote = customNoteInput ? customNoteInput.value.trim() : '';

    const colorLabel = currentMetalBarcode.includes('COL') ? ` สี${currentMetalColor}` : '';
    const insulationLabel = currentInsulationPrice > 0 ? ` + ${currentInsulationName}` : '';
    
    // Format cut breakdown string, e.g. "3.50ม.x10แผ่น, 2.00ม.x5แผ่น, 1.85ม.x3แผ่น"
    const cutBreakdown = metalCutRows.map(r => `${r.length.toFixed(2)}ม.x${r.qty}แผ่น`).join(', ');
    const displayName = `${baseProduct.name}${colorLabel}${insulationLabel} [${cutBreakdown}] รวม ${totalMeters.toFixed(2)} ม. (${totalSheets} แผ่น)`;

    invalidateCartRequest();

    const cartKey = `ms_${baseProduct.id}_${Date.now()}_${Math.floor(Math.random()*1000)}`;

    cart[cartKey] = {
        id: baseProduct.id,
        name: displayName,
        price: totalPrice,
        quantity: 1,
        unitPricePerMeter: unitPricePerMeter,
        totalMeters: totalMeters,
        sheetCount: totalSheets,
        cutList: JSON.parse(JSON.stringify(metalCutRows)),
        cutBreakdown: cutBreakdown,
        color: currentMetalColor,
        insulation: currentInsulationName,
        customNote: customNote,
        isMetalSheet: true,
        unit: 'ชุด'
    };

    saveCartToStorage();
    updateCartUI();
    closeMetalSheetStudio();

    Swal.fire({
        title: "เพิ่มลงตะกร้าแล้ว!",
        html: `
            <strong>${escapeHtml(displayName)}</strong><br>
            <span style="color:#ea580c;font-size:16px;font-weight:800;">ยอดรวม: ฿${formatMoney(totalPrice)}</span>
            <div style="margin-top: 10px; text-align: left; background: #fff7ed; border: 1px solid #fed7aa; padding: 8px 12px; border-radius: 8px; font-size: 11px; color: #9a3412; line-height: 1.4;">
                ⚠️ <strong>ข้อควรทราบ:</strong> แผ่นเมทัลชีทสั่งตัดตามขนาดความยาวเฉพาะบุคคล ไม่สามารถเปลี่ยนหรือคืนได้หลังตัดแผ่นครับ
            </div>
        `,
        icon: "success",
        timer: 4000,
        showConfirmButton: false
    });
}
