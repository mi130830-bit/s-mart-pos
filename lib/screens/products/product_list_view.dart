import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../models/unit.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/unit_repository.dart';
import '../../services/alert_service.dart';
import 'dialogs/product_form/product_form_dialog.dart';


import 'package:provider/provider.dart';
import '../../utils/barcode_utils.dart'; // Added
import '../../state/auth_provider.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/thai_aware_search_field.dart'; // ✅ Thai keyboard detection
import 'master_data_management_screen.dart'; // Added
import '../../repositories/product_type_repository.dart'; // Added
import '../../models/product_type.dart'; // Added

// Enum สำหรับ VAT Type
enum VatType {
// ... (enum remains same)
  noVat(0, 'No VAT'),
  vatIn(1, 'VAT Included (รวม VAT)'),
  vatOut(2, 'VAT Excluded (ไม่รวม VAT)');

  final int value;
  final String label;
  const VatType(this.value, this.label);

  static VatType fromInt(int val) {
    return VatType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => VatType.noVat,
    );
  }
}

class ProductListSection extends StatefulWidget {
  const ProductListSection({super.key});

  @override
  State<ProductListSection> createState() => _ProductListSectionState();
}

class _ProductListSectionState extends State<ProductListSection> {
// ... (ProductListSection remains same)
  final ProductRepository _productRepo = ProductRepository();
  final UnitRepository _unitRepo = UnitRepository();
  // ...
  List<Product> _products = [];
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  List<Unit> _units = [];

  // ✅ Filter Logic
  final ProductTypeRepository _typeRepo = ProductTypeRepository();
  List<ProductType> _productTypes = [];
  int? _filterTypeId; // null = All

  int _currentPage = 1;
  final int _pageSize = 8;
  int _totalItems = 0;
  ProductSortOption _currentSort = ProductSortOption.recent;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // ... logic same ...
    setState(() => _isLoading = true);
    try {
      String searchTerm = _searchCtrl.text.trim();

      // 1. Initial Search
      var products = await _productRepo.getProductsPaginated(
        _currentPage,
        _pageSize,
        searchTerm: searchTerm.isEmpty ? null : searchTerm,
        productTypeId: _filterTypeId, // ✅ Filter
        sortOption: _currentSort,
      );
      var total = await _productRepo.getProductCount(
        searchTerm: searchTerm.isEmpty ? null : searchTerm,
        productTypeId: _filterTypeId, // ✅ Filter
      );

      // 2. Barcode Fix Logic (if no result and looks like Thai)
      if (products.isEmpty &&
          searchTerm.isNotEmpty &&
          BarcodeUtils.isThaiInput(searchTerm)) {
        final fixedTerm = BarcodeUtils.fixThaiInput(searchTerm);
        if (fixedTerm != searchTerm) {
          final fixedProducts = await _productRepo.getProductsPaginated(
            _currentPage,
            _pageSize,
            searchTerm: fixedTerm,
            productTypeId: _filterTypeId, // ✅ Filter
            sortOption: _currentSort,
          );
          // If found with fixed term, use it
          if (fixedProducts.isNotEmpty) {
            products = fixedProducts;
            total = await _productRepo.getProductCount(
                searchTerm: fixedTerm, productTypeId: _filterTypeId);
          }
        }
      }

      final units = await _unitRepo.getAllUnits();
      final types = await _typeRepo.getAllProductTypes(); // ✅ Load Types

      if (mounted) {
        setState(() {
          _products = products;
          _totalItems = total;
          _units = units;
          _productTypes = types; // ✅ Update Types
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ Manual Sync
  Future<void> _syncData() async {
    setState(() => _isLoading = true);
    // 1. Fetch from MySQL & Save Batch to Isar
    final allProducts = await _productRepo.getAllProducts(forceRefresh: true);

    if (allProducts.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'ดึงข้อมูลสำเร็จ ${allProducts.length} รายการ (Updated Isar)')));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'ไม่สามารถเชื่อมต่อ Server ได้ (แสดงข้อมูล Offline ล่าสุด)')));
      }
    }

    // 2. Reload UI (from Isar or MySQL)
    await _loadData();
  }

  // ✅ Feature Badge Widget
  Widget _buildFeatureBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ... methods same ...
  void _onSearchChanged(String query) {
    if (_currentPage != 1) {
      _currentPage = 1;
    }
    _loadData();
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadData();
  }

  void _refreshProducts() {
    _loadData();
  }

  bool _isNearExpiry(DateTime? expiryDate) {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final difference = expiryDate.difference(now).inDays;
    return difference <= 30;
  }

  Future<void> _confirmDelete(Product product) async {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('คุณต้องการลบสินค้า "${product.name}" หรือไม่?'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'ระบุเหตุผลการลบ (บังคับ)',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'เลิกจำหน่าย', child: Text('เลิกจำหน่าย')),
                  DropdownMenuItem(value: 'คีย์ผิด', child: Text('คีย์ผิด')),
                ],
                onChanged: (val) {
                  if (val != null) reasonCtrl.text = val;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณาเลือกเหตุผล';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'ข้อมูลจะถูกย้ายไปถังขยะ และลบถาวรใน 15 วัน',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('ลบสินค้า'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _productRepo.deleteProduct(product.id,
          reason: reasonCtrl.text.trim());
      if (!mounted) return;

      if (success) {
        AlertService.show(
          context: context,
          message: 'ลบสินค้าเรียบร้อย (ย้ายไปถังขยะ)',
          type: 'success',
        );
        _refreshProducts();
      } else {
        AlertService.show(
          context: context,
          message: 'เกิดข้อผิดพลาดในการลบสินค้า',
          type: 'error',
        );
      }
    }
  }

  Future<void> _showProductDialog([Product? product]) async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          ProductFormDialog(repo: _productRepo, product: product),
    );

    if (result != null) {
      _refreshProducts();
      if (!mounted) return;
    }
  }

// ... build same ...
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Provider.of<AuthProvider>(context).isAdmin
          ? FloatingActionButton(
              onPressed: () => _showProductDialog(),
              tooltip: 'เพิ่มสินค้าใหม่',
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          // Header Actions (Search + Buttons)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: ThaiAwareSearchField(
                    controller: _searchCtrl,
                    label: 'ค้นหาสินค้า (ชื่อ, บาร์โค้ด, ตัวย่อ)',
                    onChanged: _onSearchChanged,
                    autofocus: true,
                  ),
                ),
                const SizedBox(width: 8),
                // Sort Button
                PopupMenuButton<ProductSortOption>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'เรียงลำดับ',
                  initialValue: _currentSort,
                  onSelected: (ProductSortOption result) {
                    setState(() {
                      _currentSort = result;
                      _currentPage = 1; // Reset to page 1
                    });
                    _loadData();
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<ProductSortOption>>[
                    const PopupMenuItem<ProductSortOption>(
                      value: ProductSortOption.recent,
                      child: Text('ล่าสุด (Default)'),
                    ),
                    const PopupMenuItem<ProductSortOption>(
                      value: ProductSortOption.nameAsc,
                      child: Text('ชื่อ (ก-ฮ)'),
                    ),
                    const PopupMenuItem<ProductSortOption>(
                      value: ProductSortOption.stockAsc,
                      child: Text('สต็อก (น้อย -> มาก)'),
                    ),
                    const PopupMenuItem<ProductSortOption>(
                      value: ProductSortOption.stockDesc,
                      child: Text('สต็อก (มาก -> น้อย)'),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // ✅ Filter Button (Product Type)
                PopupMenuButton<int?>(
                  icon: Icon(
                    Icons.filter_list,
                    color: _filterTypeId != null
                        ? Theme.of(context).primaryColor
                        : null,
                  ),
                  tooltip: 'กรองประเภทสินค้า',
                  initialValue: _filterTypeId,
                  onSelected: (int? result) {
                    setState(() {
                      _filterTypeId = result;
                      _currentPage = 1; // Reset page
                    });
                    _loadData();
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      const PopupMenuItem<int?>(
                        value: null,
                        child: Text('ทั้งหมด (All)'),
                      ),
                      const PopupMenuDivider(),
                      if (_productTypes.isEmpty)
                        const PopupMenuItem<int?>(
                          enabled: false,
                          value: null,
                          child: Text('(ไม่มีประเภทสินค้า)'),
                        ),
                      ..._productTypes.map((type) {
                        return PopupMenuItem<int?>(
                          value: type.id,
                          child: Text(type.name),
                        );
                      }),
                    ];
                  },
                ),
                const SizedBox(width: 8),
                // ✅ Sync Button
                IconButton(
                  onPressed: _syncData,
                  tooltip: 'ดึงข้อมูลล่าสุด (Sync)',
                  icon: const Icon(Icons.sync),
                ),
                const SizedBox(width: 8),
                if (Provider.of<AuthProvider>(context)
                    .hasPermission('manage_master_data'))
                  CustomButton(
                    label: 'จัดการข้อมูลหลัก',
                    icon: Icons.settings,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const MasterDataManagementScreen()),
                      ).then((_) => _loadData()); // Reload units/types
                    },
                  ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(child: Text('ไม่พบข้อมูลสินค้า'))
                    : ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 80),
                        separatorBuilder: (context, index) => const Divider(),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final p = _products[index];

                          bool isLowStock = p.trackStock &&
                              p.reorderPoint != null &&
                              p.stockQuantity <= p.reorderPoint!;

                          bool isExpired = _isNearExpiry(p.expiryDate);

                          final unitName = _units
                              .firstWhere(
                                (u) => u.id == p.unitId,
                                orElse: () => Unit(id: 0, name: 'หน่วย'),
                              )
                              .name;

                          return ListTile(
                            onTap: () => _showProductDialog(p),
                            leading: CircleAvatar(
                              // ... Logic same ...
                              backgroundColor: isExpired
                                  ? Colors.red.shade100
                                  : (isLowStock
                                      ? Colors.orange.shade100
                                      : Colors.teal.shade100),
                              child: Icon(
                                isExpired
                                    ? Icons.event_busy
                                    : (isLowStock
                                        ? Icons.warning_amber_rounded
                                        : Icons.inventory_2),
                                color: isExpired
                                    ? Colors.red
                                    : (isLowStock
                                        ? Colors.deepOrange
                                        : Colors.teal),
                              ),
                            ),
                            title: Text(
                              p.name,
                              style: TextStyle(
                                fontWeight: (isLowStock || isExpired)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isExpired
                                    ? Colors.red
                                    : (isLowStock
                                        ? Colors.deepOrange
                                        : Colors.black),
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Barcode: '),
                                    SelectableText(
                                        p.barcode ?? "-"), // Allow selection
                                    if (p.barcode != null &&
                                        p.barcode!.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 4.0),
                                        child: InkWell(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(
                                                text: p.barcode!));
                                            if (mounted) {
                                              AlertService.show(
                                                context: context,
                                                message: 'คัดลอกบาร์โค้ดแล้ว',
                                                type: 'success',
                                                duration:
                                                    const Duration(seconds: 1),
                                              );
                                            }
                                          },
                                          child: const Icon(Icons.copy,
                                              size: 16, color: Colors.blueGrey),
                                        ),
                                      ),
                                    Text(' | ขาย: ${p.retailPrice}'),
                                  ],
                                ),
                                // ✅ Feature Badges (Linked/Tier/ExtraUnit)
                                if (p.hasComponents || p.hasPriceTiers || p.hasExtraUnits)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        if (p.hasComponents)
                                          _buildFeatureBadge('เชื่อมโยง', Icons.link, Colors.purple),
                                        if (p.hasPriceTiers)
                                          _buildFeatureBadge('หลายราคา', Icons.link, Colors.indigo),
                                        if (p.hasExtraUnits)
                                          _buildFeatureBadge('หน่วยเสริม', Icons.view_module, Colors.teal),
                                      ],
                                    ),
                                  ),
                                if (isLowStock)
                                  Text(
                                    '⚠️ สต็อกต่ำกว่าจุดสั่งซื้อ (${p.reorderPoint!.toStringAsFixed(0)})',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                if (isExpired && p.expiryDate != null)
                                  Text(
                                    '⚠️ สินค้าใกล้หมดอายุ/หมดอายุ (${DateFormat('dd/MM/yyyy').format(p.expiryDate!)})',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ✅ 1. เพิ่มปุ่ม Toggle ของส่ง (Truck Icon)
                                if (Provider.of<AuthProvider>(context).isAdmin)
                                  IconButton(
                                    icon: Icon(
                                      Icons.local_shipping,
                                      color: p.isWarehouseItem
                                          ? Colors.deepOrange
                                          : Colors.grey.withValues(alpha: 0.3),
                                    ),
                                    tooltip: p.isWarehouseItem
                                        ? 'สินค้าส่ง (Warehouse Item)'
                                        : 'ไม่ใช่สินค้าส่ง',
                                    onPressed: () async {
                                      // Toggle Logic
                                      final updated = p.copyWith(
                                          isWarehouseItem: !p.isWarehouseItem);
                                      // Optimistic UI Update (List update)
                                      setState(() {
                                        _products[index] = updated;
                                      });
                                      // Save to DB
                                      await _productRepo.saveProduct(updated);
                                    },
                                  ),
                                Text(
                                  '${p.stockQuantity.toStringAsFixed(0)} $unitName',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isLowStock ? Colors.red : Colors.green,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (Provider.of<AuthProvider>(context)
                                    .isAdmin) ...[
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () => _showProductDialog(p),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _confirmDelete(p),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Pagination Controls
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: const Border(top: BorderSide(color: Colors.grey)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center content
              children: [
                Text('ทั้งหมด $_totalItems รายการ'),
                const SizedBox(width: 20), // Spacing
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _currentPage > 1
                          ? () => _goToPage(_currentPage - 1)
                          : null,
                    ),
                    Text(
                        'หน้า $_currentPage / ${(_totalItems / _pageSize).ceil() == 0 ? 1 : (_totalItems / _pageSize).ceil()}'),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _currentPage < (_totalItems / _pageSize).ceil()
                          ? () => _goToPage(_currentPage + 1)
                          : null,
                    ),
                  ],
                ),
                // Add some space at the end to account for FAB if needed,
                // but centering should move it away from the right corner enough.
                const SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

