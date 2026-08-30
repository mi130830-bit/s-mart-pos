/**
 * S-MART SHOP - CLIENT MAIN CORE (Clean Modular Orchestrator)
 * Modules: paint-studio.js, metalsheet-studio.js, cart.js, shop-member.js
 */

// Global Configuration
const API_BASE = "/api/v1/shop";

// Global App State
let currentUser = {
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

let allProducts = [];
let featuredProducts = [];
let categories = [];
let currentCategory = "all";
let searchKeyword = "";
let cart = {};
let selectedDeliveryType = "delivery";
let searchDebounceTimer = null;
let liffIdToken = null;
let cartClientRequestId = null;
let currentMember = null;
let selectedCouponCode = "";
let memberCoupons = [];
const loadedTabs = new Set();

// Initialize Application
document.addEventListener("DOMContentLoaded", async () => {
    loadCartFromStorage();
    if (typeof initCustomerInfoPersistence === "function") {
        initCustomerInfoPersistence();
    }
    initEventListeners();
    updateCartUI();
    await initLiffAuth();
    await fetchShopData();
    initUnifiedNavigation();
    await handlePairingFromUrl();

    // 🚀 Smart Startup Routing:
    // ถ้ายังไม่ได้ล็อกอิน ให้เริ่มที่หน้าล็อกอิน/ต้อนรับสมาชิก (member tab)
    // แต่ถ้าเคยล็อกอินจำไว้ในเครื่องแล้ว หรือล็อกอินผ่าน LINE ให้เข้าหน้าขาย (shop tab) เลยทันที
    if (!currentUser.isLoggedIn) {
        switchTab("member");
    } else {
        switchTab("shop");
    }
});

/* =========================================================
   1. DATA FETCHING & RENDERING (FEATURED & CATALOG)
   ========================================================= */

async function fetchShopData() {
    try {
        await Promise.all([
            fetchShopInfo(),
            fetchCategories(),
            fetchFeaturedProducts(),
            fetchProducts()
        ]);
    } catch (e) {
        console.error("Error loading shop data:", e);
    }
}

async function fetchShopInfo() {
    try {
        const res = await fetch(`${API_BASE}/info`);
        const json = await res.json();
        if (json.status === "success" && json.data) {
            const info = json.data;
            window.currentShopInfo = info;
            if (info.name) {
                const storeNameEl = document.getElementById("storeName");
                if (storeNameEl) storeNameEl.textContent = info.name;
                document.title = `${info.name} | แค็ตตาล็อกและสั่งซื้อสินค้า`;
            }
            if (info.shortName) {
                const badgeEl = document.getElementById("storeBadge");
                if (badgeEl) badgeEl.textContent = info.shortName;
            }
            if (info.address) {
                const taglineEl = document.getElementById("storeTagline");
                if (taglineEl) {
                    const firstLine = info.address.split("\n")[0].trim();
                    taglineEl.textContent = firstLine || "จำหน่ายวัสดุก่อสร้าง อุปกรณ์ไฟฟ้าและประปา";
                }
            }
            if (typeof setShopCoordinates === "function" && info.latitude && info.longitude) {
                setShopCoordinates(Number(info.latitude), Number(info.longitude));
            }
            if (typeof renderMemberProfileView === "function" && document.getElementById("memberProfileHub")) {
                renderMemberProfileView();
            }
        }
    } catch (e) {
        console.warn("Could not fetch shop info:", e);
    }
}

async function fetchCategories() {
    try {
        const res = await fetch(`${API_BASE}/categories`);
        const json = await res.json();
        if (json.status === "success" && Array.isArray(json.data)) {
            categories = json.data;
            renderCategories();
        }
    } catch (e) {
        console.warn("Could not fetch categories:", e);
    }
}

function renderCategories() {
    const list = document.getElementById("categoryList");
    if (!list) return;

    let html = `<button class="cat-pill ${currentCategory === 'all' ? 'active' : ''}" data-cat="all">⭐ สินค้าแนะนำ</button>`;

    categories.forEach(c => {
        const emoji = c.emoji || getCategoryEmoji(c.name);
        html += `<button class="cat-pill ${currentCategory === String(c.id) || currentCategory === c.name ? 'active' : ''}" data-cat="${c.id}">${emoji} ${escapeHtml(c.name)}</button>`;
    });

    list.innerHTML = html;

    list.querySelectorAll(".cat-pill").forEach(btn => {
        btn.addEventListener("click", () => {
            list.querySelectorAll(".cat-pill").forEach(b => b.classList.remove("active"));
            btn.classList.add("active");
            currentCategory = btn.getAttribute("data-cat");
            fetchProducts();
        });
    });
}

function getCategoryEmoji(name) {
    if (!name) return "📦";
    if (name.includes("สี")) return "🎨";
    if (name.includes("เหล็ก") || name.includes("หลังคา")) return "🏗️";
    if (name.includes("ท่อ") || name.includes("PVC")) return "🚰";
    if (name.includes("ปูน") || name.includes("หิน") || name.includes("ทราย")) return "🪨";
    if (name.includes("ไม้") || name.includes("บอร์ด")) return "🏠";
    if (name.includes("ไฟ")) return "⚡";
    if (name.includes("ช่าง") || name.includes("เครื่องมือ")) return "🔨";
    if (name.includes("น็อต") || name.includes("สกรู") || name.includes("ตะปู")) return "🔩";
    if (name.includes("เสา")) return "🏛️";
    return "📦";
}

async function fetchFeaturedProducts() {
    try {
        const res = await fetch(`${API_BASE}/featured`);
        const json = await res.json();
        if (json.status === "success" && Array.isArray(json.data)) {
            featuredProducts = json.data;
            renderFeatured();
        }
    } catch (e) {
        console.warn("Could not fetch featured products:", e);
    }
}

function renderFeatured() {
    const container = document.getElementById("featuredProductsList");
    if (!container) return;

    if (!featuredProducts || featuredProducts.length === 0) {
        container.innerHTML = `<p style="color:#94a3b8;font-size:13px;">ไม่มีรายการสินค้าแนะนำในขณะนี้</p>`;
        return;
    }

    container.innerHTML = featuredProducts.map(p => {
        const inCartQty = cart[p.id]?.quantity || 0;
        return `
            <div class="featured-item-card" onclick="addToCart('${p.id}')">
                <div class="featured-item-info">
                    <strong>${escapeHtml(p.name)}</strong>
                    <span>฿${formatMoney(p.retailPrice)}</span>
                </div>
                <button type="button" class="btn-add-featured ${inCartQty > 0 ? 'in-cart' : ''}">
                    ${inCartQty > 0 ? `✓ ในตะกร้า (${inCartQty})` : '+ ใส่ตะกร้า'}
                </button>
            </div>
        `;
    }).join('');
}

function openFeaturedSheet() {
    const sheet = document.getElementById("featuredSheet");
    if (sheet) sheet.classList.remove("hidden");
}

function closeFeaturedSheet() {
    const sheet = document.getElementById("featuredSheet");
    if (sheet) sheet.classList.add("hidden");
}

async function fetchProducts() {
    const grid = document.getElementById("productGrid");
    const noProds = document.getElementById("noProducts");

    try {
        let url = `${API_BASE}/products?category_id=${encodeURIComponent(currentCategory)}&category=${encodeURIComponent(currentCategory)}`;
        if (searchKeyword) {
            url += `&q=${encodeURIComponent(searchKeyword)}&search=${encodeURIComponent(searchKeyword)}`;
        }

        const res = await fetch(url);
        const json = await res.json();

        if (json.status === "success" && Array.isArray(json.data)) {
            allProducts = json.data;
            renderProductGrid();
            if (noProds) {
                noProds.classList.toggle("hidden", allProducts.length > 0);
            }
        }
    } catch (e) {
        console.error("Error fetching products:", e);
    }
}

function renderProductGrid() {
    const grid = document.getElementById("productGrid");
    if (!grid) return;

    const isPaintCategory = currentCategory === "paints_coatings" || 
                            currentCategory === "10" || 
                            String(currentCategory).includes("สี") || 
                            String(currentCategory).toLowerCase().includes("paint") ||
                            (categories.find(c => String(c.id) === String(currentCategory))?.name?.includes("สี") ?? false) ||
                            (searchKeyword && searchKeyword.includes("สี"));

    const isMetalSheetCategory = currentCategory === "roofing_steel" || 
                                 currentCategory === "steel" ||
                                 currentCategory === "4" || 
                                 currentCategory === "roof_metalsheet" ||
                                 String(currentCategory).includes("หลังคา") || 
                                 String(currentCategory).includes("เหล็ก") || 
                                 (categories.find(c => String(c.id) === String(currentCategory))?.name?.includes("หลังคา") ?? false) ||
                                 (categories.find(c => String(c.id) === String(currentCategory))?.name?.includes("เหล็ก") ?? false) ||
                                 (searchKeyword && (searchKeyword.includes("เมทัล") || searchKeyword.includes("หลังคา") || searchKeyword.includes("ชีท") || searchKeyword.includes("ลอน") || searchKeyword.includes("เหล็ก")));

    // Control top banners cleanly (single banner source of truth)
    const paintBanner = document.getElementById("paintStudioBanner");
    if (paintBanner) {
        paintBanner.style.display = isPaintCategory ? "flex" : "none";
    }

    const metalBanner = document.getElementById("metalSheetStudioBanner");
    if (metalBanner) {
        metalBanner.style.display = isMetalSheetCategory ? "flex" : "none";
    }

    grid.innerHTML = allProducts.map(p => {
        const inCartQty = cart[p.id]?.quantity || 0;
        const hasImg = p.imageUrl && p.imageUrl.trim().length > 0;
        const unitText = p.unit ? ` / ${escapeHtml(p.unit)}` : '';
        const outOfStock = isOutOfStock(p);

        return `
            <div class="product-card ${outOfStock ? 'is-out-of-stock' : ''}" id="productCard-${p.id}">
                <div class="product-img-wrapper">
                    ${hasImg ? 
                        `<img src="${escapeHtml(p.imageUrl)}" alt="${escapeHtml(p.name)}" class="product-img" loading="lazy">` : 
                        `<div class="product-img-fallback">${getCategoryEmoji(p.categoryName || '')}</div>`
                    }
                    ${outOfStock ? `<div class="out-of-stock-badge">สินค้าหมด</div>` : ''}
                </div>
                <div class="product-card-body">
                    <div class="product-title" title="${escapeHtml(p.name)}">${escapeHtml(p.name)}</div>
                    <div class="product-price-row">
                        <span class="product-price">฿${formatMoney(p.retailPrice)}</span>
                        <span class="product-unit">${unitText}</span>
                    </div>
                </div>
                <div class="product-card-footer">
                    ${inCartQty > 0 ? `
                        <div class="grid-qty-stepper">
                            <button type="button" onclick="changeCartQty('${p.id}', -1)" aria-label="ลดจำนวน">−</button>
                            <input type="number" class="qty-input" value="${inCartQty}" min="1" step="1" inputmode="numeric" onfocus="this.select()" onchange="setCartQty('${p.id}', this.value, this)" onkeyup="if(event.key==='Enter') this.blur()" aria-label="ระบุจำนวน">
                            <button type="button" onclick="changeCartQty('${p.id}', 1)" ${outOfStock ? 'disabled' : ''} aria-label="เพิ่มจำนวน">+</button>
                        </div>
                    ` : `
                        <button type="button" class="btn-add-cart" onclick="addToCart('${p.id}')" ${outOfStock ? 'disabled' : ''}>
                            ${outOfStock ? 'สินค้าหมด' : '+ ใส่ตะกร้า'}
                        </button>
                    `}
                </div>
            </div>
        `;
    }).join('');
}

function isOutOfStock(p) {
    if (p.stockQuantity === null || p.stockQuantity === undefined) return false;
    return Number(p.stockQuantity) <= 0;
}

/* =========================================================
   2. UNIFIED NAVIGATION & EVENT LISTENERS
   ========================================================= */

function initUnifiedNavigation() {
    document.querySelectorAll(".tab-button, .bottom-nav-item").forEach(btn => {
        btn.addEventListener("click", () => {
            const tabName = btn.getAttribute("data-tab");
            if (tabName) switchTab(tabName);
        });
    });
}

function switchTab(tabName) {
    document.querySelectorAll(".tab-button, .bottom-nav-item").forEach(b => {
        b.classList.toggle("active", b.getAttribute("data-tab") === tabName);
    });

    document.querySelectorAll("[data-tab-panel]").forEach(c => {
        const isActive = c.getAttribute("data-tab-panel") === tabName;
        c.classList.toggle("active", isActive);
        if (isActive) {
            c.removeAttribute("hidden");
            window.scrollTo({ top: 0, behavior: 'smooth' });
        } else {
            c.setAttribute("hidden", "true");
        }
    });

    if (tabName === "rewards") {
        if (typeof loadRewardsAndCoupons === "function") loadRewardsAndCoupons();
    } else if (tabName === "history") {
        if (typeof loadMemberHistory === "function") loadMemberHistory();
    } else if (tabName === "member") {
        if (typeof renderMemberProfileView === "function") renderMemberProfileView();
    }
}

function initEventListeners() {
    const searchInput = document.getElementById("searchInput");
    if (searchInput) {
        searchInput.addEventListener("input", (e) => {
            if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
            searchDebounceTimer = setTimeout(() => {
                searchKeyword = e.target.value.trim();
                fetchProducts();
            }, 300);
        });
    }
}

/* =========================================================
   3. UTILITY FUNCTIONS
   ========================================================= */

function formatMoney(amount) {
    const num = Number(amount) || 0;
    return num.toLocaleString("th-TH", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function formatQuantity(qty) {
    const num = Number(qty) || 0;
    return num % 1 === 0 ? num.toString() : num.toFixed(2);
}

function escapeHtml(str) {
    if (!str) return "";
    return String(str)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

function safeHttpUrl(url) {
    if (!url) return "";
    url = url.trim();
    if (url.startsWith("http://") || url.startsWith("https://")) {
        return url;
    }
    return "";
}
