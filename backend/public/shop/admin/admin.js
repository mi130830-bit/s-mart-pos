const state = {
  products: [],
  categories: [],
  categoryCounts: {},
  selected: new Map(),
  activeCategory: 'all',
  keyword: '',
  viewMode: 'all',
};
const apiBase = '/api/v1';
const $ = (id) => document.getElementById(id);
let searchTimer;

function money(value) {
  return Number(value || 0).toLocaleString('th-TH', { maximumFractionDigits: 2 });
}

function escapeHtml(value) {
  return String(value || '').replace(/[&<>"']/g, (char) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;'
  }[char]));
}

function iconFor(name = '') {
  const text = name.toLowerCase();
  if (/ท่อ|ประปา|ข้อต่อ/.test(text)) return '🚰';
  if (/ปูน|อิฐ|ทราย|หิน/.test(text)) return '🧱';
  if (/สี|เคมี/.test(text)) return '🎨';
  if (/ไฟ|หลอด/.test(text)) return '⚡';
  if (/ค้อน|ประแจ|น็อต|ตะปู|เครื่องมือ/.test(text)) return '🔨';
  return '📦';
}

function token() {
  return sessionStorage.getItem('access_token') || '';
}

async function request(path, options = {}) {
  const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
  if (token()) headers.Authorization = `Bearer ${token()}`;
  const response = await fetch(`${apiBase}${path}`, { ...options, headers });
  let data = {};
  try { data = await response.json(); } catch (_) { data = {}; }
  if (!response.ok) {
    const error = new Error(response.status === 401 || response.status === 403
      ? 'บัญชีนี้ไม่มีสิทธิ์ทำรายการ หรือเซสชันหมดอายุ'
      : (data.error || data.message || 'ไม่สามารถโหลดข้อมูลได้'));
    error.status = response.status;
    error.data = data;
    throw error;
  }
  return data;
}

function showNotice(message, success = false) {
  const box = $('notice');
  box.textContent = message;
  box.className = `notice ${success ? 'success' : ''}`;
}

function productsPath() {
  const params = new URLSearchParams({ limit: '500' });
  if (state.activeCategory !== 'all') params.set('category_id', state.activeCategory);
  if (state.keyword.trim()) params.set('q', state.keyword.trim());
  return `/products?${params.toString()}`;
}

function renderCategories() {
  const list = $('categoryList');

  let html = `<div class="category-row ${state.activeCategory === 'all' ? 'active' : ''}">
    <button class="category-button ${state.activeCategory === 'all' ? 'active' : ''}" data-category="all">
      <span><span class="cat-emoji-badge">⭐</span>สินค้าแนะนำ</span>
      <small>${state.activeCategory === 'all' ? state.products.length : '...'}</small>
    </button>
  </div>`;

  html += state.categories.map((category) => {
    const count = state.categoryCounts[String(category.id)] ?? '...';
    return `<div class="category-row ${state.activeCategory === String(category.id) ? 'active' : ''}">
      <button class="category-button ${state.activeCategory === String(category.id) ? 'active' : ''}" data-category="${escapeHtml(category.id)}">
        <span><span class="cat-emoji-badge">${escapeHtml(category.emoji || '📦')}</span>${escapeHtml(category.name)}</span>
        <small>${count}</small>
      </button>
    </div>`;
  }).join('');

  list.innerHTML = html;

  list.querySelectorAll('[data-category]').forEach((button) => {
    button.addEventListener('click', () => selectCategory(button.dataset.category));
  });
}

function openAddCategoryModal() {
  $('modalCatId').value = '';
  $('modalCatName').value = '';
  $('modalCatEmoji').value = '📦';
  $('categoryModalTitle').textContent = 'เพิ่มหมวดหมู่ใหม่';
  $('categoryModal').classList.remove('hidden');
  setTimeout(() => $('modalCatName').focus(), 50);
}

function openEditCategoryModal(id) {
  const cat = state.categories.find((c) => String(c.id) === String(id));
  if (!cat) return;
  $('modalCatId').value = cat.id;
  $('modalCatName').value = cat.name;
  $('modalCatEmoji').value = cat.emoji || '📦';
  $('categoryModalTitle').textContent = 'แก้ไขหมวดหมู่';
  $('categoryModal').classList.remove('hidden');
  setTimeout(() => $('modalCatName').focus(), 50);
}

function closeCategoryModal() {
  $('categoryModal').classList.add('hidden');
}

function handleCategoryFormSubmit(e) {
  e.preventDefault();
  const id = $('modalCatId').value.trim();
  const name = $('modalCatName').value.trim();
  const emoji = $('modalCatEmoji').value.trim() || '📦';
  if (!name) return;

  if (id) {
    const cat = state.categories.find((c) => String(c.id) === id);
    if (cat) {
      cat.name = name;
      cat.emoji = emoji;
    }
  } else {
    const newId = 'cat_' + Date.now();
    state.categories.push({ id: newId, name, emoji });
    state.activeCategory = newId;
  }

  closeCategoryModal();
  renderCategories();
  save();
}

function moveCategory(id, direction) {
  const index = state.categories.findIndex((c) => String(c.id) === String(id));
  if (index === -1) return;
  if (direction === 'up' && index > 0) {
    const temp = state.categories[index];
    state.categories[index] = state.categories[index - 1];
    state.categories[index - 1] = temp;
  } else if (direction === 'down' && index < state.categories.length - 1) {
    const temp = state.categories[index];
    state.categories[index] = state.categories[index + 1];
    state.categories[index + 1] = temp;
  }
  renderCategories();
  save();
}

function deleteCategory(id) {
  const cat = state.categories.find((c) => String(c.id) === String(id));
  if (!cat) return;
  if (!confirm(`คุณต้องการลบหมวดหมู่ "${cat.name}" ใช่หรือไม่?`)) return;

  state.categories = state.categories.filter((c) => String(c.id) !== String(id));
  // Remove items in this category or let them unassign
  for (const [pid, item] of state.selected.entries()) {
    if (String(item.categoryId) === String(id)) {
      state.selected.delete(pid);
    }
  }
  if (state.activeCategory === String(id)) {
    state.activeCategory = 'all';
  }
  updateCount();
  renderCategories();
  selectCategory(state.activeCategory);
  save();
}

function moveProduct(productId, direction) {
  const selectedList = [...state.selected.values()];
  const idStr = String(productId);

  const currentCategoryItems = selectedList.filter((item) => {
    if (state.activeCategory === 'all') return true;
    return String(item.categoryId) === state.activeCategory;
  });

  const catIndex = currentCategoryItems.findIndex((item) => String(item.productId) === idStr);
  if (catIndex === -1) return;

  const targetCatIndex = direction === 'prev' ? catIndex - 1 : catIndex + 1;
  if (targetCatIndex < 0 || targetCatIndex >= currentCategoryItems.length) return;

  const currentItem = currentCategoryItems[catIndex];
  const targetItem = currentCategoryItems[targetCatIndex];

  const fullIndexA = selectedList.findIndex((item) => String(item.productId) === String(currentItem.productId));
  const fullIndexB = selectedList.findIndex((item) => String(item.productId) === String(targetItem.productId));

  if (fullIndexA !== -1 && fullIndexB !== -1) {
    selectedList[fullIndexA] = targetItem;
    selectedList[fullIndexB] = currentItem;

    state.selected = new Map(selectedList.map((item) => [String(item.productId), item]));
    renderProducts();
    save();
  }
}

function renderProducts() {
  const grid = $('productsGrid');
  const currentCategoryName = state.categories.find((category) => String(category.id) === state.activeCategory)?.name || 'สินค้าในหมวด';
  const title = state.activeCategory === 'all' ? '⭐ สินค้าแนะนำ' : currentCategoryName;
  $('productsTitle').textContent = title;

  const displayProducts = state.products.map((product) => {
    const id = String(product.id);
    const selectedItem = state.selected.get(id);
    return {
      ...product,
      isSelected: Boolean(selectedItem),
      tag: selectedItem ? (selectedItem.tag || '⭐ สินค้าแนะนำ') : '⭐ สินค้าแนะนำ',
      badgeColor: selectedItem ? (selectedItem.badgeColor || '#168a68') : '#168a68',
    };
  });

  if (!displayProducts.length) {
    grid.innerHTML = '<div class="empty">ไม่พบสินค้าที่เปิดใช้งานในหมวดนี้</div>';
    return;
  }

  const showReorder = false;

  grid.innerHTML = displayProducts.map((product, index) => {
    const id = String(product.id);
    const selected = Boolean(product.isSelected);
    const isFirst = index === 0;
    const isLast = index === displayProducts.length - 1;

    return `<article class="product-card ${selected ? 'selected' : ''}">
      <div class="product-top">
        <div class="product-icon">${iconFor(product.categoryName || product.name)}</div>
        <div class="product-top-right">
          ${showReorder ? `
            <div class="card-order-actions">
              ${!isFirst ? `<button type="button" class="prod-order-btn" data-prod-move-prev="${escapeHtml(id)}" title="เลื่อนไปข้างหน้า (ซ้าย)">◀</button>` : ''}
              ${!isLast ? `<button type="button" class="prod-order-btn" data-prod-move-next="${escapeHtml(id)}" title="เลื่อนไปข้างหลัง (ขวา)">▶</button>` : ''}
            </div>
          ` : ''}
          <input class="check" type="checkbox" data-select="${escapeHtml(id)}" ${selected ? 'checked' : ''} aria-label="เลือก ${escapeHtml(product.name)}">
        </div>
      </div>
      <h3>${escapeHtml(product.name || 'ไม่มีชื่อสินค้า')}</h3>
      <div class="product-meta"><span>${escapeHtml(product.categoryName || 'สินค้าทั่วไป')}</span><span>คงเหลือ ${product.stockQuantity || 0}</span></div>
      <div class="product-price">฿${money(product.price || product.retailPrice)}</div>
      ${selected ? `<div class="feature-fields">
        <input data-tag="${escapeHtml(id)}" value="${escapeHtml(product.tag || '⭐ สินค้าแนะนำ')}" placeholder="ป้ายกำกับ เช่น ⭐ สินค้าแนะนำ" aria-label="ป้ายสินค้าเด่น">
        <input data-color="${escapeHtml(id)}" type="color" value="${product.badgeColor || '#168a68'}" aria-label="สีป้าย">
      </div>` : ''}
    </article>`;
  }).join('');

  grid.querySelectorAll('[data-select]').forEach((input) => input.addEventListener('change', () => toggleProduct(input.dataset.select, input.checked)));
  grid.querySelectorAll('[data-tag]').forEach((input) => input.addEventListener('input', () => updateSelectedField(input.dataset.tag, 'tag', input.value)));
  grid.querySelectorAll('[data-color]').forEach((input) => input.addEventListener('input', () => updateSelectedField(input.dataset.color, 'color', input.value)));
  grid.querySelectorAll('[data-prod-move-prev]').forEach((btn) => btn.addEventListener('click', () => moveProduct(btn.dataset.prodMovePrev, 'prev')));
  grid.querySelectorAll('[data-prod-move-next]').forEach((btn) => btn.addEventListener('click', () => moveProduct(btn.dataset.prodMoveNext, 'next')));
}

async function loadProducts() {
  const response = await request(productsPath());
  const currentCategoryName = state.categories.find((category) => String(category.id) === String(state.activeCategory))?.name || '';
  const products = Array.isArray(response) ? response : (response.data || []);
  state.products = products.map((product) => ({
    ...product,
    categoryName: product.categoryName || currentCategoryName,
  }));
  renderCategories();
  renderProducts();
}

async function loadCategoryCounts() {
  state.categoryCounts = Object.fromEntries(state.categories.map((category) => [
    String(category.id),
    Number(category.productCount || 0),
  ]));
  renderCategories();
}

async function selectCategory(categoryId) {
  state.activeCategory = categoryId;
  state.viewMode = 'all';
  state.keyword = '';
  $('productSearch').value = '';
  $('clearSearch').classList.add('hidden');
  renderCategories();
  $('productsGrid').innerHTML = '<div class="loading">กำลังโหลดสินค้า...</div>';
  try { await loadProducts(); } catch (error) { showNotice(error.message); }
}

function toggleProduct(id, checked) {
  if (checked) {
    if (state.activeCategory === 'all') {
      showNotice('กรุณาเลือกหมวดสินค้าด้านซ้ายก่อน เพื่อให้สินค้าแสดงถูกหมวดบนหน้า Shop');
      renderProducts();
      return;
    }
    const product = state.products.find((item) => String(item.id) === id);
    const catId = state.activeCategory;
    const catName = state.categories.find((item) => String(item.id) === catId)?.name || (product ? product.categoryName : 'สินค้าแนะนำ');

    state.selected.set(id, {
      productId: id,
      categoryId: catId,
      categoryName: catName,
      tag: '⭐ สินค้าแนะนำ',
      badgeColor: '#168a68',
      name: product ? product.name : '',
      price: product ? (product.price || product.retailPrice) : 0,
      stockQuantity: product ? product.stockQuantity : 0,
    });
  } else {
    state.selected.delete(id);
  }
  updateCount();
  renderProducts();
}

function updateSelectedField(id, field, value) {
  const item = state.selected.get(id);
  if (!item) return;
  if (field === 'tag') item.tag = value;
  if (field === 'color') item.badgeColor = value;
}

function updateCount() { $('selectedCount').textContent = state.selected.size; }

async function load() {
  try {
    const [featuredRes, categoryRes] = await Promise.all([
      request('/shop-admin/featured'),
      request('/products/categories'),
    ]);
    state.categories = categoryRes.data || [];
    const items = featuredRes.data?.items || (Array.isArray(featuredRes.data) ? featuredRes.data : []);
    items.forEach((item) => state.selected.set(String(item.productId), item));
    $('authPanel').classList.add('hidden');
    $('adminApp').classList.remove('hidden');
    $('logoutButton').classList.remove('hidden');
    await loadProducts();
    updateCount();
    loadCategoryCounts();
  } catch (error) {
    if (token()) $('loginError').textContent = error.message;
  }
}

async function save() {
  const payload = {
    categories: state.categories,
    items: [...state.selected.values()].map((item) => ({
      productId: String(item.productId),
      categoryId: String(item.categoryId || (state.categories[0] ? state.categories[0].id : 'sand_rock_cement')),
      categoryName: String(item.categoryName || 'สินค้าแนะนำ'),
      tag: String(item.tag || '⭐ สินค้าแนะนำ'),
      badgeColor: String(item.badgeColor || '#168a68'),
    }))
  };

  try {
    $('saveButton').disabled = true;
    $('saveStatus').textContent = 'กำลังบันทึก...';
    await request('/shop-admin/featured', { method: 'PUT', body: JSON.stringify(payload) });
    $('saveStatus').textContent = 'บันทึกแล้ว';
    showNotice(`บันทึกสินค้าเด่นและหมวดหมู่เรียบร้อยแล้ว (${payload.items.length} รายการ, ${payload.categories.length} หมวดหมู่)`, true);
  } catch (error) {
    showNotice(error.message);
  } finally {
    $('saveButton').disabled = false;
    setTimeout(() => $('saveStatus').textContent = 'พร้อมจัดการหน้าร้าน', 2500);
  }
}

$('productSearch').addEventListener('input', (event) => {
  state.keyword = event.target.value;
  $('clearSearch').classList.toggle('hidden', !state.keyword);
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => loadProducts().catch((error) => showNotice(error.message)), 250);
});
$('clearSearch').addEventListener('click', () => { $('productSearch').value = ''; state.keyword = ''; $('clearSearch').classList.add('hidden'); loadProducts(); $('productSearch').focus(); });
$('saveButton').addEventListener('click', save);

// Category Modal Event Listeners
if ($('addCategoryBtn')) $('addCategoryBtn').addEventListener('click', openAddCategoryModal);
if ($('closeCategoryModal')) $('closeCategoryModal').addEventListener('click', closeCategoryModal);
if ($('cancelCategoryModal')) $('cancelCategoryModal').addEventListener('click', closeCategoryModal);
if ($('categoryForm')) $('categoryForm').addEventListener('submit', handleCategoryFormSubmit);
document.querySelectorAll('.quick-emoji').forEach((btn) => {
  btn.addEventListener('click', () => {
    $('modalCatEmoji').value = btn.textContent.trim();
  });
});

$('loginForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  $('loginError').textContent = 'กำลังเข้าสู่ระบบ...';
  try {
    const response = await fetch(`${apiBase}/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ username: $('username').value, password: $('password').value }) });
    const data = await response.json();
    if (!response.ok || !data.token) throw new Error(data.error || 'เข้าสู่ระบบไม่สำเร็จ');
    sessionStorage.setItem('access_token', data.token);
    load();
  } catch (error) { $('loginError').textContent = error.message; }
});
if (token()) load();

let tierSettingsVersion = 0;

function createUuid() {
  if (globalThis.crypto?.randomUUID) return globalThis.crypto.randomUUID();
  const bytes = new Uint8Array(16);
  if (globalThis.crypto?.getRandomValues) globalThis.crypto.getRandomValues(bytes);
  else for (let index = 0; index < bytes.length; index += 1) bytes[index] = Math.floor(Math.random() * 256);
  bytes[6] = (bytes[6] & 15) | 64; bytes[8] = (bytes[8] & 63) | 128;
  const hex = [...bytes].map((byte) => byte.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

document.querySelectorAll('[data-admin-tab]').forEach((button) => button.addEventListener('click', async () => {
  const tab = button.dataset.adminTab;
  document.querySelectorAll('[data-admin-tab]').forEach((item) => item.classList.toggle('active', item === button));
  document.querySelectorAll('[data-admin-panel]').forEach((panel) => panel.classList.toggle('hidden', panel.dataset.adminPanel !== tab));
  if (tab === 'rewards') await loadRewardsAdmin();
  if (tab === 'tier') await loadTierSettings();
  if (tab === 'members') await loadPendingRequests();
}));

$('logoutButton').addEventListener('click', () => {
  sessionStorage.removeItem('access_token');
  location.reload();
});

async function loadTierSettings() {
  try {
    const response = await request('/tier-settings');
    const settings = response.data || {};
    tierSettingsVersion = Number(settings.settingsVersion || 0);
    $('tierEnabled').checked = Boolean(settings.enabled);
    $('tierThreshold').value = settings.monthlyThreshold ?? 10000;
    $('tierMultiplier').value = settings.pointsMultiplier ?? 2;
    $('contractorThreshold1').value = settings.contractorThreshold1 ?? 20000;
    $('contractorMultiplier1').value = settings.contractorMultiplier1 ?? 2.5;
    $('contractorThreshold2').value = settings.contractorThreshold2 ?? 50000;
    $('contractorMultiplier2').value = settings.contractorMultiplier2 ?? 3;
    $('tierBenefitTh').value = settings.benefitTextTh || '';
    $('tierBenefitEn').value = settings.benefitTextEn || '';
  } catch (error) { showNotice(error.message); }
}

$('tierSettingsForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  try {
    const response = await request('/tier-settings', { method: 'PUT', body: JSON.stringify({
      enabled: $('tierEnabled').checked,
      monthlyThreshold: Number($('tierThreshold').value),
      pointsMultiplier: Number($('tierMultiplier').value),
      contractorThreshold1: Number($('contractorThreshold1').value),
      contractorMultiplier1: Number($('contractorMultiplier1').value),
      contractorThreshold2: Number($('contractorThreshold2').value),
      contractorMultiplier2: Number($('contractorMultiplier2').value),
      benefitTextTh: $('tierBenefitTh').value.trim(),
      benefitTextEn: $('tierBenefitEn').value.trim(),
      settingsVersion: tierSettingsVersion,
    }) });
    tierSettingsVersion = Number(response.data?.settingsVersion || tierSettingsVersion + 1);
    showNotice('บันทึกการตั้งค่าระดับสมาชิกแล้ว', true);
  } catch (error) {
    showNotice(error.status === 409 ? 'มีผู้แก้การตั้งค่าก่อนหน้า ระบบกำลังโหลดค่าใหม่' : error.message);
    if (error.status === 409) await loadTierSettings();
  }
});

$('quickCreateForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  const box = $('quickCreateResult'); box.textContent = 'กำลังตรวจสอบ...';
  try {
    const result = await request('/membership-admin/customers/quick-create', {
      method: 'POST',
      body: JSON.stringify({
        name: $('quickName').value.trim(),
        phone: $('quickPhone').value.trim(),
        address: $('quickAddress').value.trim(),
        shippingAddress: $('quickShippingAddress').value.trim(),
        requestUuid: createUuid()
      })
    });
    box.textContent = `สร้างสมาชิกแล้ว #${result.customerId}`;
    $('quickCreateForm').reset();
    await showPairing(Number(result.customerId), box);
  } catch (error) {
    if (error.status === 409 && Array.isArray(error.data?.candidates)) {
      box.innerHTML = `<div class="notice">พบสมาชิกที่ใช้เบอร์นี้แล้ว ระบบไม่สร้างหรือรวมอัตโนมัติ</div>${renderCustomerRows(error.data.candidates)}`;
      bindCustomerActions(box);
    } else box.textContent = error.message;
  }
});

$('memberSearchForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  const box = $('memberSearchResults'); box.innerHTML = '<div class="loading">กำลังค้นหา...</div>';
  try {
    const response = await request(`/membership-admin/customers/search?q=${encodeURIComponent($('memberSearchInput').value.trim())}`);
    box.innerHTML = renderCustomerRows(response.data || []);
    bindCustomerActions(box);
  } catch (error) { box.textContent = error.message; }
});

function renderCustomerRows(customers) {
  if (!customers.length) return '<div class="empty">ไม่พบสมาชิก</div>';
  return customers.map((customer) => {
    const id = Number.parseInt(customer.id, 10);
    return `<article class="admin-list-item"><div><strong>${escapeHtml(customer.name || 'สมาชิก')} · ${escapeHtml(customer.memberCode || '')}</strong><small>${escapeHtml(customer.phoneMasked || '')} · ${Number(customer.currentPoints || 0).toLocaleString('th-TH')} แต้ม · ${escapeHtml(customer.linkedStatus || '')}</small>${customer.hasDebt ? '<small class="debt-warning">⚠️ มียอดค้างชำระ โปรดตรวจสอบก่อนผูกบัญชี</small>' : ''}</div><div class="admin-actions"><button data-pair-customer="${Number.isSafeInteger(id) ? id : ''}" ${customer.linkedStatus === 'LINKED' ? 'disabled' : ''}>ออก QR ผูก LINE</button></div></article>`;
  }).join('');
}

function bindCustomerActions(root) {
  root.querySelectorAll('[data-pair-customer]').forEach((button) => button.addEventListener('click', () => showPairing(Number(button.dataset.pairCustomer), button.closest('.admin-list-item'))));
}

async function showPairing(customerId, host) {
  if (!Number.isSafeInteger(customerId) || customerId <= 0) return;
  try {
    const result = await request(`/membership-admin/customers/${customerId}/pairing`, { method: 'POST', body: JSON.stringify({ requestUuid: createUuid() }) });
    const link = new URL('/shop/', location.origin); link.searchParams.set('tab', 'member'); link.searchParams.set('pair', result.pairingToken);
    const resultBox = document.createElement('div'); resultBox.className = 'pairing-result'; resultBox.innerHTML = '<strong>QR ใช้ได้ครั้งเดียว ภายใน 5 นาที</strong><div class="pairing-qr"></div><small>ให้ลูกค้าสแกนและตรวจข้อมูลปิดบังก่อนยืนยัน</small>';
    host.appendChild(resultBox);
    renderLocalQr(resultBox.querySelector('.pairing-qr'), link.href);
    setTimeout(() => { resultBox.textContent = 'QR หมดอายุแล้ว กรุณาออกใหม่'; }, Math.min(300, Number(result.expiresInSeconds || 300)) * 1000);
  } catch (error) { showNotice(error.message); }
}

async function loadPendingRequests() {
  const box = $('pendingRequests'); box.innerHTML = '<div class="loading">กำลังโหลด...</div>';
  try {
    const response = await request('/membership-admin/requests?status=PENDING');
    const requests = response.data || [];
    box.innerHTML = requests.length ? requests.map((item) => `<article class="admin-list-item"><div><strong>${escapeHtml(item.line_display_name || 'LINE user')} → ${escapeHtml(item.candidateName || 'รอตรวจสอบ')}</strong><small>${escapeHtml(item.candidateMemberCode || '')} · ${escapeHtml(item.phoneMasked || '')} · ${Number(item.candidatePoints || 0).toLocaleString('th-TH')} แต้ม</small>${item.candidateHasDebt ? '<small class="debt-warning">⚠️ บัญชีนี้มียอดหนี้ โปรดตรวจหลักฐานก่อนอนุมัติ</small>' : ''}<small>${escapeHtml(item.request_type || '')} · ${escapeHtml(item.created_at || '')}</small></div><div class="admin-actions"><button data-approve="${escapeHtml(item.request_uuid)}">อนุมัติ</button><button class="danger" data-reject="${escapeHtml(item.request_uuid)}">ปฏิเสธ</button></div></article>`).join('') : '<div class="empty">ไม่มีคำขอรอตรวจสอบ</div>';
    box.querySelectorAll('[data-approve]').forEach((button) => button.addEventListener('click', () => decideRequest(button.dataset.approve, true)));
    box.querySelectorAll('[data-reject]').forEach((button) => button.addEventListener('click', () => decideRequest(button.dataset.reject, false)));
  } catch (error) { box.textContent = error.message; }
}

async function decideRequest(uuid, approve) {
  if (!/^[0-9a-f-]{36}$/i.test(uuid || '')) return;
  if (!confirm(approve ? 'ยืนยันอนุมัติการผูกบัญชีนี้?' : 'ยืนยันปฏิเสธคำขอนี้?')) return;
  try {
    await request(`/membership-admin/requests/${encodeURIComponent(uuid)}/${approve ? 'approve' : 'reject'}`, { method: 'POST', body: JSON.stringify(approve ? {} : { reason: 'Rejected by staff review' }) });
    await loadPendingRequests();
  } catch (error) { showNotice(error.message); }
}

function renderLocalQr(container, value) {
  container.textContent = '';
  if (typeof QRCode === 'function') new QRCode(container, { text: String(value), width: 160, height: 160, correctLevel: QRCode.CorrectLevel.M });
  else container.textContent = String(value);
}

$('refreshPending').addEventListener('click', loadPendingRequests);

/* =========================================================
   REWARDS & COUPONS MANAGEMENT (ADMIN)
   ========================================================= */

let allAdminRewards = [];
let allAdminRedemptions = [];

async function loadRewardsAdmin() {
  await Promise.all([loadAdminRewardsList(), loadAdminRedemptionsList()]);
}

async function loadAdminRewardsList() {
  const grid = $('rewardsAdminGrid');
  if (!grid) return;
  grid.innerHTML = '<div class="loading">กำลังโหลดรายการของรางวัล...</div>';
  try {
    const list = await request('/rewards-admin/rewards');
    allAdminRewards = Array.isArray(list) ? list : [];
    renderAdminRewardsGrid();
  } catch (error) {
    grid.innerHTML = `<div class="empty">เกิดข้อผิดพลาด: ${escapeHtml(error.message)}</div>`;
  }
}

function renderAdminRewardsGrid() {
  const grid = $('rewardsAdminGrid');
  if (!grid) return;
  if (!allAdminRewards.length) {
    grid.innerHTML = '<div class="empty">ยังไม่มีรายการของรางวัล/คูปองในระบบ กดปุ่ม [+ เพิ่มรางวัล / คูปองใหม่] เพื่อเริ่มต้น</div>';
    return;
  }
  grid.innerHTML = allAdminRewards.map((r) => {
    const isCoupon = r.reward_type === 'DISCOUNT_COUPON';
    const isFreeDelivery = r.reward_type === 'FREE_DELIVERY';
    const isFreeClaim = r.claim_type === 'FREE_CLAIM';
    const typeLabel = isCoupon ? `🎟️ คูปองส่วนลด ฿${money(r.discount_value)}` : 
                      isFreeDelivery ? '🚚 คูปองส่งฟรี' : '🎁 ของพรีเมียม';
    const isActive = Number(r.is_active) === 1;
    const limitText = Number(r.claim_limit_per_user) > 0 ? `จำกัด ${r.claim_limit_per_user} ใบ/คน` : 'ไม่จำกัดสิทธิ์';

    return `
      <article class="product-card" style="position:relative;border:1.5px solid ${isActive ? '#bbf7d0' : '#e2e8f0'};background:${isActive ? '#fff' : '#f8fafc'};display:flex;flex-direction:column;">
        <div class="product-top">
          <div class="product-icon" style="background:${isFreeClaim ? '#fef3c7' : isCoupon ? '#e0f2fe' : '#ecfdf5'};">
            ${r.image_url ? `<img src="${escapeHtml(r.image_url)}" style="width:100%;height:100%;object-fit:cover;border-radius:10px;">` : (isCoupon ? '🎟️' : isFreeDelivery ? '🚚' : '🎁')}
          </div>
          <div style="display:flex;flex-direction:column;align-items:flex-end;gap:4px;">
            <span style="font-size:11px;font-weight:800;padding:3px 8px;border-radius:999px;background:${isActive ? '#dcfce7' : '#fee2e2'};color:${isActive ? '#166534' : '#991b1b'};">
              ${isActive ? '✅ ใช้งานอยู่' : '❌ ปิดใช้งาน'}
            </span>
            <span style="font-size:10px;font-weight:700;padding:2px 6px;border-radius:6px;background:${isFreeClaim ? '#fef3c7' : '#e0e7ff'};color:${isFreeClaim ? '#92400e' : '#3730a3'};">
              ${isFreeClaim ? `🎁 แจกฟรี (${limitText})` : (Number(r.claim_limit_per_user) > 0 ? `💎 ใช้แต้ม (${limitText})` : '💎 ใช้แต้ม (ไม่จำกัด)')}
            </span>
          </div>
        </div>
        <h3 style="margin:10px 0 4px;font-size:15px;font-weight:700;color:#0f172a;">${escapeHtml(r.name)}</h3>
        <p style="font-size:12px;color:#64748b;margin:0 0 10px;line-height:1.4;">${escapeHtml(r.description || typeLabel)}</p>
        <div style="background:#f1f5f9;padding:8px 10px;border-radius:8px;font-size:12px;display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;margin-top:auto;">
          ${isFreeClaim ? 
            `<span>สิทธิ์: <strong style="color:#d97706;font-size:13px;">🎁 กดรับฟรี</strong></span>` :
            `<span>แต้มที่ใช้: <strong style="color:#059669;font-size:14px;">💎 ${Number(r.point_price).toLocaleString('th-TH')}</strong></span>`
          }
          <span>คงเหลือ: <strong>${r.stock_quantity}</strong> ชิ้น</span>
        </div>
        <div style="display:flex;gap:6px;">
          <button type="button" class="primary-button" style="flex:1;height:34px;font-size:12px;padding:0 8px;background:#059669;" onclick="openEditRewardModal(${r.id})">✏️ แก้ไข</button>
          <button type="button" class="cancel-button" style="height:34px;font-size:12px;padding:0 10px;color:#dc2626;border-color:#fecaca;" onclick="deleteReward(${r.id})">🗑️</button>
        </div>
      </article>
    `;
  }).join('');
}

async function loadAdminRedemptionsList() {
  const listEl = $('redemptionsAdminList');
  if (!listEl) return;
  listEl.innerHTML = '<div class="loading">กำลังโหลดประวัติการแลกแต้ม...</div>';
  try {
    const list = await request('/rewards-admin/redemptions');
    allAdminRedemptions = Array.isArray(list) ? list : [];
    renderAdminRedemptionsList();
  } catch (error) {
    listEl.innerHTML = `<div class="empty">เกิดข้อผิดพลาด: ${escapeHtml(error.message)}</div>`;
  }
}

function renderAdminRedemptionsList() {
  const listEl = $('redemptionsAdminList');
  if (!listEl) return;
  if (!allAdminRedemptions.length) {
    listEl.innerHTML = '<div class="empty">ยังไม่มีประวัติการแลกแต้มจากลูกค้า</div>';
    return;
  }
  listEl.innerHTML = allAdminRedemptions.map((item) => {
    const isFulfilled = item.status === 'FULFILLED';
    const isUsed = item.coupon_status === 'USED';
    const statusText = isFulfilled ? '✅ มอบของแล้ว' : isUsed ? '🎟️ ใช้งานคูปองแล้ว' : '⏳ รอมอบของ / รอใช้งาน';
    const statusColor = isFulfilled || isUsed ? '#166534' : '#b45309';
    const statusBg = isFulfilled || isUsed ? '#dcfce7' : '#fef3c7';

    return `
      <article class="admin-list-item">
        <div>
          <strong>${escapeHtml(item.reward_name)}</strong>
          <small>👤 ลูกค้า: <strong>${escapeHtml(item.firstName || '')} ${escapeHtml(item.lastName || '')}</strong> (โทร: ${escapeHtml(item.phone || '-')})</small>
          <small>💎 ใช้แต้ม: <strong>${item.points_used} แต้ม</strong> · วันที่แลก: ${new Date(item.redeemed_at).toLocaleString('th-TH')}</small>
          ${item.coupon_code ? `<small style="font-family:monospace;font-weight:700;color:#059669;">🎟️ รหัสคูปอง: ${escapeHtml(item.coupon_code)} (มูลค่า ฿${money(item.discount_value)})</small>` : ''}
          <div style="margin-top:6px;">
            <span style="font-size:11px;font-weight:800;padding:2px 8px;border-radius:999px;background:${statusBg};color:${statusColor};">
              ${statusText}
            </span>
          </div>
        </div>
        <div class="admin-actions">
          ${!isFulfilled && !isUsed ? `
            <button type="button" style="background:#059669;color:#fff;" onclick="fulfillRedemption(${item.id})">✅ ยืนยันมอบของ</button>
          ` : ''}
        </div>
      </article>
    `;
  }).join('');
}

function openAddRewardModal() {
  $('modalRewardId').value = '';
  $('modalClaimType').value = 'POINTS_REDEEM';
  $('modalClaimLimit').value = '1';
  $('modalRewardType').value = 'DISCOUNT_COUPON';
  $('modalRewardName').value = '';
  $('modalRewardDesc').value = '';
  $('modalPointPrice').value = '50';
  $('modalDiscountValue').value = '50';
  $('modalStockQuantity').value = '10';
  $('modalImageUrl').value = '';
  $('modalIsActive').value = '1';
  $('rewardModalTitle').textContent = 'เพิ่มของรางวัล / คูปองใหม่';
  toggleRewardTypeFields();
  $('rewardModal').classList.remove('hidden');
}

function openEditRewardModal(id) {
  const r = allAdminRewards.find((item) => Number(item.id) === Number(id));
  if (!r) return;
  $('modalRewardId').value = r.id;
  $('modalClaimType').value = r.claim_type || 'POINTS_REDEEM';
  $('modalClaimLimit').value = r.claim_limit_per_user !== undefined ? r.claim_limit_per_user : 1;
  $('modalRewardType').value = r.reward_type || 'DISCOUNT_COUPON';
  $('modalRewardName').value = r.name || '';
  $('modalRewardDesc').value = r.description || '';
  $('modalPointPrice').value = r.point_price || 0;
  $('modalDiscountValue').value = r.discount_value || 0;
  $('modalStockQuantity').value = r.stock_quantity || 0;
  $('modalImageUrl').value = r.image_url || '';
  $('modalIsActive').value = r.is_active == 1 ? '1' : '0';
  $('rewardModalTitle').textContent = 'แก้ไขของรางวัล / คูปอง';
  toggleRewardTypeFields();
  $('rewardModal').classList.remove('hidden');
}

function closeRewardModal() {
  $('rewardModal').classList.add('hidden');
}

function toggleRewardTypeFields() {
  const claimType = $('modalClaimType')?.value || 'POINTS_REDEEM';
  const rewardType = $('modalRewardType')?.value || 'DISCOUNT_COUPON';
  const claimLimitWrap = $('claimLimitWrap');
  const pointPriceWrap = $('pointPriceWrap');
  const discountValueWrap = $('discountValueWrap');
  const pointPriceInput = $('modalPointPrice');

  if (claimLimitWrap) claimLimitWrap.style.display = 'grid';

  if (claimType === 'FREE_CLAIM') {
    if (pointPriceWrap) pointPriceWrap.style.display = 'none';
    if (pointPriceInput) {
      pointPriceInput.value = '0';
      pointPriceInput.removeAttribute('required');
    }
  } else {
    if (pointPriceWrap) pointPriceWrap.style.display = 'grid';
    if (pointPriceInput) {
      pointPriceInput.setAttribute('required', 'required');
      if (Number(pointPriceInput.value) === 0) pointPriceInput.value = '50';
    }
  }

  if (discountValueWrap) {
    discountValueWrap.style.display = (rewardType === 'DISCOUNT_COUPON' || rewardType === 'FREE_DELIVERY') ? 'grid' : 'none';
  }
}

async function deleteReward(id) {
  if (!confirm('ยืนยันการปิดใช้งานรางวัลนี้?')) return;
  try {
    await request(`/rewards-admin/rewards/${id}`, { method: 'DELETE' });
    showNotice('ปิดใช้งานของรางวัลแล้ว', true);
    await loadAdminRewardsList();
  } catch (err) {
    showNotice(err.message);
  }
}

async function fulfillRedemption(id) {
  if (!confirm('ยืนยันว่าได้มอบของรางวัลให้ลูกค้าเรียบร้อยแล้ว?')) return;
  try {
    await request(`/rewards-admin/redemptions/${id}/fulfill`, { method: 'PATCH' });
    showNotice('ยืนยันมอบของรางวัลสำเร็จ', true);
    await loadAdminRedemptionsList();
  } catch (err) {
    showNotice(err.message);
  }
}

function switchRewardsSubtab(subtab) {
  $('subtabRewardsList')?.classList.toggle('active', subtab === 'list');
  $('subtabRedemptionsList')?.classList.toggle('active', subtab === 'redemptions');
  $('rewardsListContainer')?.classList.toggle('hidden', subtab !== 'list');
  $('redemptionsListContainer')?.classList.toggle('hidden', subtab !== 'redemptions');
}

// Reward Form Submission
$('rewardForm')?.addEventListener('submit', async (event) => {
  event.preventDefault();
  const id = $('modalRewardId').value;
  const isEdit = Boolean(id);
  const claimType = $('modalClaimType').value;
  const pointPrice = claimType === 'FREE_CLAIM' ? 0 : Number($('modalPointPrice').value || 0);

  const payload = {
    name: $('modalRewardName').value.trim(),
    description: $('modalRewardDesc').value.trim(),
    claim_type: claimType,
    claim_limit_per_user: Number($('modalClaimLimit').value || 1),
    point_price: pointPrice,
    stock_quantity: Number($('modalStockQuantity').value || 0),
    image_url: $('modalImageUrl').value.trim(),
    reward_type: $('modalRewardType').value,
    discount_value: Number($('modalDiscountValue').value || 0),
    is_active: $('modalIsActive').value === '1' ? 1 : 0
  };

  try {
    if (isEdit) {
      await request(`/rewards-admin/rewards/${id}`, { method: 'PUT', body: JSON.stringify(payload) });
      showNotice('แก้ไขข้อมูลรางวัลสำเร็จแล้ว', true);
    } else {
      await request('/rewards-admin/rewards', { method: 'POST', body: JSON.stringify(payload) });
      showNotice('เพิ่มของรางวัลใหม่สำเร็จแล้ว', true);
    }
    closeRewardModal();
    await loadAdminRewardsList();
  } catch (err) {
    showNotice(err.message);
  }
});

$('addRewardBtn')?.addEventListener('click', openAddRewardModal);
$('refreshRewardsBtn')?.addEventListener('click', loadRewardsAdmin);
$('closeRewardModal')?.addEventListener('click', closeRewardModal);
$('cancelRewardModal')?.addEventListener('click', closeRewardModal);

