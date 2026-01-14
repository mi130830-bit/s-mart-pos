import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; // Added
import '../../models/product.dart';
import '../../models/supplier.dart';
import '../../models/unit.dart';
import '../../models/product_component.dart';
import '../../models/product_price_tier.dart'; // Added
import '../../models/product_barcode.dart'; // Added
import '../../repositories/product_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../repositories/unit_repository.dart';
import '../../repositories/product_component_repository.dart';
import '../../repositories/product_price_tier_repository.dart'; // Added
import '../../services/alert_service.dart';
import 'widgets/product_search_dialog_for_select.dart';
import 'widgets/supplier_search_dialog.dart';

import 'widgets/component_row.dart'; // Added
import 'package:provider/provider.dart';
import '../../utils/barcode_utils.dart'; // Added
import '../../state/auth_provider.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/confirm_dialog.dart';
import 'master_data_management_screen.dart'; // Added
import '../../repositories/product_type_repository.dart'; // Added
import '../../models/product_type.dart'; // Added
import '../../services/settings_service.dart';
import '../../widgets/dialogs/admin_auth_dialog.dart';

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

  int _currentPage = 1;
  final int _pageSize = 15;
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
        sortOption: _currentSort,
      );
      var total = await _productRepo.getProductCount(
        searchTerm: searchTerm.isEmpty ? null : searchTerm,
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
            sortOption: _currentSort,
          );
          // If found with fixed term, use it
          if (fixedProducts.isNotEmpty) {
            products = fixedProducts;
            total = await _productRepo.getProductCount(searchTerm: fixedTerm);
          }
        }
      }

      final units = await _unitRepo.getAllUnits();

      if (mounted) {
        setState(() {
          _products = products;
          _totalItems = total;
          _units = units;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
    final confirm = await ConfirmDialog.show(
      context,
      title: 'ยืนยันการลบ',
      content: 'คุณต้องการลบสินค้า "${product.name}" หรือไม่?',
      isDestructive: true,
      confirmText: 'ลบ',
    );

    if (confirm == true) {
      final success = await _productRepo.deleteProduct(product.id);
      if (!mounted) return;

      if (success) {
        _refreshProducts();
      } else {
        // Error handling
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
                  child: CustomTextField(
                    controller: _searchCtrl,
                    label: 'ค้นหาสินค้า (ชื่อ, บาร์โค้ด, ตัวย่อ)',
                    prefixIcon: Icons.search,
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
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'คัดลอกบาร์โค้ดแล้ว'),
                                                  duration:
                                                      Duration(seconds: 1)),
                                            );
                                          },
                                          child: const Icon(Icons.copy,
                                              size: 16, color: Colors.blueGrey),
                                        ),
                                      ),
                                    Text(' | ขาย: ${p.retailPrice}'),
                                  ],
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

class ProductFormDialog extends StatefulWidget {
  final ProductRepository repo;
  final Product? product;

  const ProductFormDialog({super.key, required this.repo, this.product});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _nameCtrl;
  // ...
  late TextEditingController _barcodeCtrl;
  late TextEditingController _aliasCtrl;
  final TextEditingController _supplierNameCtrl = TextEditingController();
  final TextEditingController _unitNameCtrl = TextEditingController(); // Added
  final TextEditingController _typeNameCtrl =
      TextEditingController(); // Product Type Search

  late TextEditingController _costCtrl;
  late TextEditingController _retailPriceCtrl;
  late TextEditingController _wholesalePriceCtrl;
  late TextEditingController _memberRetailPriceCtrl;
  late TextEditingController _memberWholesalePriceCtrl;

  late TextEditingController _stockCtrl;
  late TextEditingController _reorderPointCtrl;
  late TextEditingController _pointsCtrl;

  bool _trackStock = true;

  VatType _selectedVat = VatType.noVat;
  int? _selectedUnitId;
  int? _selectedSupplierId;
  DateTime? _expiryDate;

  final SupplierRepository _supplierRepo = SupplierRepository();
  final UnitRepository _unitRepo = UnitRepository();
  final ProductComponentRepository _componentRepo =
      ProductComponentRepository();
  final ProductPriceTierRepository _tierRepo =
      ProductPriceTierRepository(); // New

  List<Supplier> _suppliers = [];
  List<Unit> _units = [];
  List<ProductComponent> _components = []; // BOM List
  List<ProductPriceTier> _priceTiers = []; // Price Tier List
  List<ProductBarcode> _extraBarcodes = []; // Added

  // Product Types
  final ProductTypeRepository _typeRepo = ProductTypeRepository();
  List<ProductType> _productTypes = [];
  int? _selectedTypeId; // 0=General, 1=Weighing
  // String? _imagePath; // Unused
  int _activeTab = 0; // 0=Linkage, 1=Price Tier, 2=Units
  XFile? _pickedImage;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    // Pick an image.
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _aliasCtrl = TextEditingController(text: p?.alias ?? '');

    // Prices
    _costCtrl = TextEditingController(text: p?.costPrice.toString() ?? '0');
    _retailPriceCtrl = TextEditingController(
      text: p?.retailPrice.toString() ?? '0',
    );
    _wholesalePriceCtrl = TextEditingController(
      text: p?.wholesalePrice?.toString() ?? '0',
    );
    _memberRetailPriceCtrl = TextEditingController(
      text: p?.memberRetailPrice?.toString() ?? '0',
    );
    _memberWholesalePriceCtrl = TextEditingController(
      text: p?.memberWholesalePrice?.toString() ?? '0',
    );

    // Stock & Points
    _stockCtrl = TextEditingController(
      text: p?.stockQuantity.toString() ?? '0',
    );
    _reorderPointCtrl = TextEditingController(
      text: p?.reorderPoint?.toString() ?? '0',
    );
    _pointsCtrl = TextEditingController(text: p?.points.toString() ?? '0');

    _trackStock = p?.trackStock ?? true;

    _expiryDate = p?.expiryDate;

    _selectedVat = VatType.fromInt(p?.vatType ?? 0);

    // _selectedUnitId = p?.unitId; // ไม่ต้องกำหนดตรงนี้ รอ _loadInitialData

    _loadInitialData();
    if (p != null) {
      _loadComponents(p.id);
      _loadTiers(p.id);
      _loadBarcodes(p.id); // Added
    }
  }

  Future<void> _loadComponents(int parentId) async {
    final comps = await _componentRepo.getComponentsByParentId(parentId);
    if (mounted) {
      setState(() {
        _components = comps;
      });
    }
  }

  Future<void> _loadTiers(int productId) async {
    final tiers = await _tierRepo.getTiersByProductId(productId);
    if (mounted) {
      setState(() {
        _priceTiers = tiers;
      });
    }
  }

  Future<void> _loadBarcodes(int productId) async {
    final barcodes = await widget.repo.getProductBarcodesByProductId(productId);
    if (mounted) {
      setState(() {
        _extraBarcodes = barcodes;
      });
    }
  }

  Future<void> _loadInitialData() async {
    final suppliers = await _supplierRepo.getAllSuppliers();
    final units = await _unitRepo.getAllUnits();
    final types = await _typeRepo.getAllProductTypes(); // Load types

    if (!mounted) return;
    setState(() {
      _suppliers = suppliers;
      _units = units;
      _productTypes = types;

      // Init selected Type
      // Default to 0 (General) if null, but ensure 0 is in the list
      _selectedTypeId = widget.product?.productType ?? 0;

      // Ensure selected type exists in list, otherwise default to first available
      if (!_productTypes.any((t) => t.id == _selectedTypeId)) {
        if (_productTypes.isNotEmpty) {
          // Try to find ID 0 specifically first? No, if it's not in the list, we can't select it.
          // If 0 is missing, pick the first one.
          _selectedTypeId = _productTypes.first.id;
        } else {
          // If list is empty, we have a problem. But let's keep 0 and hope items reload?
          // Or handle empty list in build.
          _selectedTypeId = 0;
        }
      }

      // Update Type Name Controller
      if (_selectedTypeId != null) {
        final existingType =
            _productTypes.where((t) => t.id == _selectedTypeId).toList();
        if (existingType.isNotEmpty) {
          _typeNameCtrl.text = existingType.first.name;
        } else {
          _typeNameCtrl.clear();
        }
      }

      // Check Supplier ID
      final productSupplierId = widget.product?.supplierId;
      if (productSupplierId != null &&
          suppliers.any((s) => s.id == productSupplierId)) {
        _selectedSupplierId = productSupplierId;
      } else {
        _selectedSupplierId = null;
      }
      // UPDATE TEXT CONTROLLER
      if (_selectedSupplierId != null) {
        final found = _suppliers.firstWhere((s) => s.id == _selectedSupplierId);
        _supplierNameCtrl.text = found.name;
      } else {
        _supplierNameCtrl.clear();
      }

      // Validate unit selection and set controller text
      final productUnitId = widget.product?.unitId;
      // If we haven't selected one yet (first load), try to use the product's unit
      if (_selectedUnitId == null && productUnitId != null) {
        if (units.any((u) => u.id == productUnitId)) {
          _selectedUnitId = productUnitId;
        }
      }

      if (_selectedUnitId != null) {
        final existing = units.where((u) => u.id == _selectedUnitId).toList();
        if (existing.isNotEmpty) {
          _unitNameCtrl.text = existing.first.name;
        } else {
          _selectedUnitId = null; // Reset if invalid
          _unitNameCtrl.text = '';
        }
      } else {
        _selectedUnitId = null;
        _unitNameCtrl.text = '';
      }
    });
  }

  // ฟังก์ชันเพิ่มหน่วยนับใหม่
  Future<void> _addNewUnit() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เพิ่มหน่วยนับใหม่'),
        content: CustomTextField(
          controller: ctrl,
          label: 'ชื่อหน่วยนับ (เช่น ชิ้น, กล่อง)',
          autofocus: true,
        ),
        actions: [
          CustomButton(
            label: 'ยกเลิก',
            type: ButtonType.secondary,
            onPressed: () => Navigator.pop(ctx),
          ),
          CustomButton(
            label: 'บันทึก',
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final newId = await _unitRepo.saveUnit(result);
      if (newId > 0) {
        await _loadInitialData(); // Reload list
        setState(() {
          _selectedUnitId = newId; // Auto select new unit
        });
      }
    }
  }

  // ฟังก์ชันเพิ่มประเภทสินค้าใหม่
  Future<void> _addNewProductType() async {
    final nameCtrl = TextEditingController();
    bool isWeighing = false;

    final result = await showDialog<ProductType>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('เพิ่มประเภทสินค้าใหม่'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: nameCtrl,
                  label: 'ชื่อประเภท (เช่น ผัก, เครื่องดื่ม)',
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('ต้องชั่งน้ำหนัก'),
                  value: isWeighing,
                  onChanged: (val) {
                    setState(() => isWeighing = val ?? false);
                  },
                ),
              ],
            ),
            actions: [
              CustomButton(
                label: 'ยกเลิก',
                type: ButtonType.secondary,
                onPressed: () => Navigator.pop(ctx),
              ),
              CustomButton(
                label: 'บันทึก',
                onPressed: () {
                  if (nameCtrl.text.isNotEmpty) {
                    Navigator.pop(
                        ctx,
                        ProductType(
                            id: 0,
                            name: nameCtrl.text.trim(),
                            isWeighing: isWeighing));
                  }
                },
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      final newId = await _typeRepo.saveProductType(result);
      if (newId > 0) {
        await _loadInitialData(); // Reload list
        setState(() {
          _selectedTypeId = newId; // Auto select new type
        });
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _aliasCtrl.dispose();
    _costCtrl.dispose();
    _retailPriceCtrl.dispose();
    _wholesalePriceCtrl.dispose();
    _memberRetailPriceCtrl.dispose();
    _memberWholesalePriceCtrl.dispose();
    _stockCtrl.dispose();
    _reorderPointCtrl.dispose();
    _pointsCtrl.dispose();
    _supplierNameCtrl.dispose();
    _unitNameCtrl.dispose();
    _typeNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _openSupplierSearch() async {
    final selectedInfo = await showDialog<Supplier>(
      context: context,
      builder: (ctx) => const SupplierSearchDialog(),
    );

    if (selectedInfo != null) {
      setState(() {
        _selectedSupplierId = selectedInfo.id;
        _supplierNameCtrl.text = selectedInfo.name;
      });
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      // Auto-generate barcode if empty
      String? barcode = _barcodeCtrl.text.trim();
      if (barcode.isEmpty) {
        // Generate 8-digit barcode
        barcode = (DateTime.now().millisecondsSinceEpoch % 100000000)
            .toString()
            .padLeft(8, '0');
      }

      final newStock = double.tryParse(_stockCtrl.text) ?? 0.0;
      final oldStock = widget.product?.stockQuantity ?? 0.0;

      // ✅ Security Check: If stock changed
      if (newStock != oldStock &&
          SettingsService().requireAdminForStockAdjust) {
        debugPrint(
            'Stock changed from $oldStock to $newStock. Requesting Admin Auth.');
        final authorized = await AdminAuthDialog.show(context);
        if (!authorized) return;
      }

      final newProduct = Product(
        id: widget.product?.id ?? 0,
        name: _nameCtrl.text,
        barcode: barcode,
        alias: _aliasCtrl.text.isEmpty ? null : _aliasCtrl.text,
        productType: _selectedTypeId ?? 0, // Dynamic Type
        costPrice: double.tryParse(_costCtrl.text) ?? 0.0,
        retailPrice: double.tryParse(_retailPriceCtrl.text) ?? 0.0,
        wholesalePrice: double.tryParse(_wholesalePriceCtrl.text),
        memberRetailPrice: double.tryParse(_memberRetailPriceCtrl.text),
        memberWholesalePrice: double.tryParse(_memberWholesalePriceCtrl.text),
        vatType: _selectedVat.value,
        stockQuantity: newStock,
        trackStock: _trackStock,
        allowPriceEdit: false,
        reorderPoint: double.tryParse(_reorderPointCtrl.text),
        points: int.tryParse(_pointsCtrl.text) ?? 0,
        supplierId: _selectedSupplierId,
        unitId: _selectedUnitId,
        categoryId: widget.product?.categoryId,
        imageUrl: _pickedImage?.path ?? widget.product?.imageUrl, // Save Image
        expiryDate: _expiryDate,
      );

      try {
        final productId = await widget.repo.saveProduct(newProduct);
        if (!mounted) return;

        if (productId > 0) {
          // Check if we need to save tiers
          // Note: The ID in _priceTiers might be dummy if new,
          // but repo should handle insertions.
          for (var tier in _priceTiers) {
            tier.productId = productId; // Ensure linked to saved product
          }

          await Future.wait([
            _componentRepo.updateComponents(productId, _components),
            _tierRepo.updateTiers(productId, _priceTiers),
            widget.repo.updateProductBarcodes(productId, _extraBarcodes),
          ]);

          if (!mounted) return;
          // Return the saved product with the new ID
          Navigator.of(context).pop(newProduct.copyWith(id: productId));
        } else {
          if (!mounted) return;
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(
          //     content: Text('บันทึกไม่สำเร็จ'),
          //     backgroundColor: Colors.red,
          //   ),
          // );
        }
      } catch (e) {
        if (!mounted) return;
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        // );
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const Divider(height: 10, thickness: 1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.all(16),
        child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () {
                Navigator.of(context).pop(null);
              },
            },
            child: Focus(
              autofocus: true,
              child: Container(
                width: 1400, // Increased width
                height: 800,
                padding: const EdgeInsets.all(0),
                child: Column(
                  children: [
                    // --- Header ---
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        border: Border(
                            bottom: BorderSide(color: Colors.grey, width: 0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.product == null
                                ? 'เพิ่มการเชื่อมโยงสินค้า (New Product)'
                                : 'แก้ไขสินค้า (Edit Product)',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),

                    // --- Body (Split View) ---
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- LEFT COLUMN: Product Info ---
                          Expanded(
                            flex: 5, // 50% width (Increased from 4)
                            child: Container(
                              color: Colors.grey[50], // Light background
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildLeftColumnContent(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const VerticalDivider(width: 1, thickness: 1),

                          // --- RIGHT COLUMN: Linkage / Components ---
                          Expanded(
                            flex: 5, // 50% width (Decreased from 6)
                            child: Container(
                              color: Colors.white,
                              child: Column(
                                children: [
                                  // Right Header (Tabs simulation)
                                  Container(
                                    color: Colors.blue[50],
                                    child: Row(
                                      children: [
                                        InkWell(
                                          onTap: () =>
                                              setState(() => _activeTab = 0),
                                          child: _buildTabHeader(
                                              'การเชื่อมโยง (Linkage)',
                                              _activeTab == 0),
                                        ),
                                        InkWell(
                                          onTap: () =>
                                              setState(() => _activeTab = 1),
                                          child: _buildTabHeader(
                                              'ราคาหลายระดับ', _activeTab == 1),
                                        ),
                                        InkWell(
                                          onTap: () =>
                                              setState(() => _activeTab = 2),
                                          child: _buildTabHeader(
                                              'หน่วยสินค้าเสริม (Units)',
                                              _activeTab == 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Right Content
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: _buildRightColumnContent(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- Footer ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        border: Border(
                            top: BorderSide(color: Colors.grey, width: 0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          CustomButton(
                            onPressed: () => Future.delayed(Duration.zero, () {
                              if (context.mounted) {
                                Navigator.of(context).pop(null);
                              }
                            }),
                            label: 'ยกเลิก',
                            type: ButtonType.secondary,
                          ),
                          const SizedBox(width: 16),
                          CustomButton(
                            onPressed: _save,
                            icon: Icons.save,
                            label: 'บันทึก',
                            type: ButtonType.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )));
  }

  Widget _buildTabHeader(String title, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.transparent,
        border: isActive
            ? const Border(top: BorderSide(color: Colors.blue, width: 3))
            : null,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive ? Colors.blue[800] : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildLeftColumnContent() {
    return Column(
      children: [
        // Image Placeholder & Basic Info Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Picker Box
            InkWell(
              onTap: _pickImage,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(8),
                  image: _pickedImage != null
                      ? DecorationImage(
                          image: FileImage(File(_pickedImage!.path)),
                          fit: BoxFit.cover,
                        )
                      : (widget.product?.imageUrl != null &&
                              widget.product!.imageUrl!.isNotEmpty)
                          ? DecorationImage(
                              image: FileImage(File(widget.product!.imageUrl!)),
                              fit: BoxFit.cover,
                            ) // Assuming local path for Desktop
                          : null,
                ),
                child: (_pickedImage == null &&
                        (widget.product?.imageUrl == null ||
                            widget.product!.imageUrl!.isEmpty))
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_a_photo, size: 32, color: Colors.grey),
                          SizedBox(height: 4),
                          Text('เลือกรูป',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  CustomTextField(
                    controller: _barcodeCtrl,
                    readOnly: widget.product?.barcode != null &&
                        widget.product!.barcode!.isNotEmpty,
                    label: 'รหัสบาร์โค้ด (Barcode)',
                    filled: widget.product?.barcode != null &&
                        widget.product!.barcode!.isNotEmpty,
                    fillColor: (widget.product?.barcode != null &&
                            widget.product!.barcode!.isNotEmpty)
                        ? Colors.grey[200]
                        : null,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _nameCtrl,
                    label: 'ชื่อสินค้า *',
                    validator: (v) =>
                        v == null || v.isEmpty ? 'กรุณากรอกชื่อ' : null,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _aliasCtrl,
                    label: 'ชื่อย่อ (Alias)',
                  ),
                  const SizedBox(height: 12),
                  // Product Type Dropdown
                  // Product Type Dropdown
                  // Product Type Searchable Dropdown
                  Row(
                    children: [
                      Expanded(
                        child: LayoutBuilder(builder: (context, constraints) {
                          return Autocomplete<ProductType>(
                            key: ValueKey(
                                _selectedTypeId), // Rebuild if ID changes
                            initialValue:
                                TextEditingValue(text: _typeNameCtrl.text),
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return _productTypes;
                              }
                              return _productTypes.where((ProductType option) {
                                return option.name.toLowerCase().contains(
                                    textEditingValue.text.toLowerCase());
                              });
                            },
                            displayStringForOption: (ProductType option) =>
                                option.name +
                                (option.isWeighing ? ' (ชั่งน้ำหนัก)' : ''),
                            onSelected: (ProductType selection) {
                              setState(() {
                                _selectedTypeId = selection.id;
                                _typeNameCtrl.text = selection.name;
                              });
                            },
                            fieldViewBuilder: (context, textEditingController,
                                focusNode, onFieldSubmitted) {
                              return CustomTextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                label: 'ประเภทสินค้า *',
                                suffixIcon: const Icon(Icons.arrow_drop_down),
                                onChanged: (val) {
                                  // Reset ID if user types something custom (though we force selection usually)
                                  // For Type, usually strict selection.
                                  // If val is empty, reset ID?
                                },
                                validator: (val) => _selectedTypeId == null
                                    ? 'กรุณาเลือกประเภท'
                                    : null,
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4.0,
                                  child: SizedBox(
                                    width: constraints.maxWidth,
                                    height: 300,
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      itemCount: options.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                        final ProductType option =
                                            options.elementAt(index);
                                        return ListTile(
                                          title: Text(option.name +
                                              (option.isWeighing
                                                  ? ' (ชั่งน้ำหนัก)'
                                                  : '')),
                                          onTap: () {
                                            onSelected(option);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addNewProductType,
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        tooltip: 'เพิ่มประเภทสินค้าใหม่',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Unit Search Field with Add Button
                  Row(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Autocomplete<Unit>(
                              initialValue:
                                  TextEditingValue(text: _unitNameCtrl.text),
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return _units;
                                }
                                return _units.where((Unit option) {
                                  return option.name.toLowerCase().contains(
                                      textEditingValue.text.toLowerCase());
                                });
                              },
                              displayStringForOption: (Unit option) =>
                                  option.name,
                              onSelected: (Unit selection) {
                                setState(() {
                                  _selectedUnitId = selection.id;
                                  _unitNameCtrl.text = selection.name;
                                });
                              },
                              fieldViewBuilder: (context, textEditingController,
                                  focusNode, onFieldSubmitted) {
                                return CustomTextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  label: 'หน่วยสินค้า *',
                                  suffixIcon: const Icon(Icons.arrow_drop_down),
                                  onChanged: (val) {
                                    // Reset ID if user types something new
                                    if (_selectedUnitId != null) {
                                      setState(() {
                                        _selectedUnitId = null;
                                      });
                                    }
                                  },
                                  validator: (val) => _selectedUnitId == null
                                      ? 'กรุณาเลือกหน่วย'
                                      : null,
                                );
                              },
                              optionsViewBuilder:
                                  (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    child: SizedBox(
                                      width: constraints.maxWidth,
                                      height: 200,
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        itemCount: options.length,
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                          final Unit option =
                                              options.elementAt(index);
                                          return ListTile(
                                            title: Text(option.name),
                                            onTap: () {
                                              onSelected(option);
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addNewUnit,
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        tooltip: 'เพิ่มหน่วยนับใหม่',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        // Prices Section
        _buildSectionTitle('ราคาต้นทุน & ขาย'),
        if (Provider.of<AuthProvider>(context).canViewCost) ...[
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _costCtrl,
                  keyboardType: TextInputType.number,
                  label: '* ต้นทุนสินค้า',
                  prefixText: '฿ ',
                  selectAllOnFocus: true, // ✅ Auto-select
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                ),
              ),
              const SizedBox(width: 24), // Spacer
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _retailPriceCtrl,
                keyboardType: TextInputType.number,
                label: '* ราคาปลีก',
                prefixText: '฿ ',
                selectAllOnFocus: true, // ✅ Auto-select
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomTextField(
                controller: _wholesalePriceCtrl,
                keyboardType: TextInputType.number,
                label: '* ราคาส่ง',
                prefixText: '฿ ',
                selectAllOnFocus: true, // ✅ Auto-select
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _memberRetailPriceCtrl,
                keyboardType: TextInputType.number,
                label: 'ราคาปลีกสมาชิก',
                prefixText: '฿ ',
                selectAllOnFocus: true, // ✅ Auto-select
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomTextField(
                controller: _memberWholesalePriceCtrl,
                keyboardType: TextInputType.number,
                label: 'ราคาส่งสมาชิก',
                prefixText: '฿ ',
                selectAllOnFocus: true, // ✅ Auto-select
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(),

        // Options
        CheckboxListTile(
          title: const Text('ไม่ตัดสต็อก'),
          value: !_trackStock, // Inverted logic for UI wording
          onChanged: (val) => setState(() => _trackStock = !val!),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),

        const SizedBox(height: 16),
        // Stock Quantity Field (Restored/Added)
        CustomTextField(
          controller: _stockCtrl,
          readOnly: _components.isNotEmpty, // Lock if linked to components
          label: _components.isNotEmpty
              ? 'จำนวนสต๊อก (อ้างอิงจากส่วนประกอบ)'
              : 'จำนวนสต๊อก',
          filled: _components.isNotEmpty,
          fillColor: _components.isNotEmpty ? Colors.grey[200] : null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          selectAllOnFocus: true, // ✅ Auto-select
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _reorderPointCtrl,
                label: 'จุดสั่งซื้อ (ต่ำกว่าแจ้งเตือน)',
                keyboardType: TextInputType.number,
                selectAllOnFocus: true, // ✅ Auto-select
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomTextField(
                controller: _pointsCtrl,
                label: 'แต้มสะสม',
                keyboardType: TextInputType.number,
                selectAllOnFocus: true, // ✅ Auto-select
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<VatType>(
                initialValue: _selectedVat, // Use initialValue instead of value
                decoration: const InputDecoration(
                  labelText: 'VAT',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                ),
                isExpanded: true,
                items: VatType.values
                    .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(v.label, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedVat = val);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomTextField(
                controller: _supplierNameCtrl,
                readOnly: true,
                label: 'ผู้ขาย',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _openSupplierSearch,
                ),
                onTap: _openSupplierSearch,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRightColumnContent() {
    if (_activeTab == 2) {
      return _buildUnitContent();
    }
    if (_activeTab == 1) {
      return _buildPriceTierContent();
    }
    return _buildLinkageContent();
  }

  Widget _buildUnitContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple[100]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'กำหนดหน่วยสินค้าย่อย (Multi-Unit/Packaging)',
                  style: TextStyle(color: Colors.purple[900]),
                ),
              ),
              CustomButton(
                onPressed: _addBarcode,
                icon: Icons.add,
                label: 'เพิ่มหน่วย',
                type: ButtonType.primary,
                backgroundColor: Colors.purple,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _extraBarcodes.isEmpty
              ? const Center(child: Text('ยังไม่มีหน่วยสินค้าเพิ่มเติม'))
              : ListView.separated(
                  itemCount: _extraBarcodes.length,
                  separatorBuilder: (ctx, i) =>
                      const Divider(height: 1, color: Colors.grey),
                  itemBuilder: (ctx, i) {
                    final b = _extraBarcodes[i];
                    return ListTile(
                      title: Text(
                          '${b.unitName} (${b.quantity.toStringAsFixed(0)} ชิ้น)'),
                      subtitle:
                          Text('Barcode: ${b.barcode} | ราคา: ${b.price}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _extraBarcodes.removeAt(i);
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _addBarcode() async {
    final barcodeCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เพิ่มหน่วยสินค้า'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              controller: barcodeCtrl,
              label: 'บาร์โค้ด (เช่น บาร์โค้ดแพ็ค)',
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: unitCtrl,
              label: 'ชื่อหน่วย (เช่น แพ็ค, โหล)',
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: priceCtrl,
              label: 'ราคาขายของหน่วยนี้',
              keyboardType: TextInputType.number,
              selectAllOnFocus: true, // ✅ Auto-select
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: qtyCtrl,
              label: 'จำนวนชิ้นในหน่วยนี้ (Conversion)',
              keyboardType: TextInputType.number,
              selectAllOnFocus: true, // ✅ Auto-select
            ),
          ],
        ),
        actions: [
          CustomButton(
            label: 'ยกเลิก',
            type: ButtonType.secondary,
            onPressed: () => Navigator.pop(ctx),
          ),
          CustomButton(
            label: 'เพิ่ม',
            onPressed: () {
              if (barcodeCtrl.text.isEmpty || unitCtrl.text.isEmpty) return;
              setState(() {
                _extraBarcodes.add(ProductBarcode(
                  productId: widget.product?.id ?? 0,
                  barcode: barcodeCtrl.text,
                  unitName: unitCtrl.text,
                  price: double.tryParse(priceCtrl.text) ?? 0,
                  quantity: double.tryParse(qtyCtrl.text) ?? 1,
                ));
              });
              Navigator.pop(ctx);
            },
          )
        ],
      ),
    );
  }

  Widget _buildLinkageContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search & Add
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'เชื่อมโยงส่วนประกอบเพื่อคำนวณต้นทุน',
                  style: TextStyle(color: Colors.blue[900]),
                ),
              ),
              CustomButton(
                onPressed: _addComponent,
                icon: Icons.search,
                label: 'ค้นหาสินค้าเชื่อมโยง',
                type: ButtonType.primary,
                backgroundColor: Colors.blue[700],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: Colors.grey[800],
          child: const Row(
            children: [
              Expanded(
                  flex: 4,
                  child: Text('ชื่อสินค้า',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 2,
                  child: Text('ต้นทุน/หน่วย',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 2,
                  child: Text('สัดส่วน (Qty)',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              SizedBox(
                  width: 40,
                  child: Text('ลบ',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center)),
            ],
          ),
        ),

        // List
        Expanded(
          child: _components.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.link_off, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('ยังไม่มีการเชื่อมโยงสินค้า',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 16)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _components.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final comp = _components[index];
                    return ComponentRow(
                      key: ValueKey(comp.childProductId),
                      component: comp,
                      index: index,
                      onQuantityChanged: (val) {
                        setState(() {
                          _components[index] = ProductComponent(
                            id: comp.id,
                            parentProductId: comp.parentProductId,
                            childProductId: comp.childProductId,
                            quantity: val,
                            childProductName: comp.childProductName,
                            childProductCost: comp.childProductCost,
                            childProductUnit: comp.childProductUnit,
                            childProductStock: comp.childProductStock,
                          );
                          _calculateCostAndStockFromComponents();
                        });
                      },
                      onDelete: () {
                        setState(() {
                          _components.removeAt(index);
                          _calculateCostAndStockFromComponents();
                        });
                      },
                    );
                  },
                ),
        ),

        // Summary Footer
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('รวมต้นทุนจากส่วนประกอบ:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '${_calculateTotalCostValue().toStringAsFixed(2)} บาท',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.blue),
              ),
            ],
          ),
        )
      ],
    );
  }

  double _calculateTotalCostValue() {
    double total = 0;
    for (var comp in _components) {
      total += (comp.childProductCost ?? 0) * comp.quantity;
    }
    return total;
  }

  // --- ฟังก์ชัน BOM ---
  Future<void> _addComponent() async {
    final selectedProduct = await showDialog<Product>(
      context: context,
      builder: (ctx) =>
          ProductSearchDialogForSelect(repo: widget.repo), // Pass repo here
    );

    if (selectedProduct != null) {
      if (_components.any((c) => c.childProductId == selectedProduct.id)) {
        if (!mounted) return;
        AlertService.show(
          context: context,
          message: 'สินค้านี้ถูกเพิ่มไปแล้ว',
          type: 'warning',
        );
        return;
      }

      if (widget.product != null && selectedProduct.id == widget.product!.id) {
        if (!mounted) return;
        AlertService.show(
          context: context,
          message: 'ไม่สามารถเลือกตัวเองเป็นส่วนประกอบได้',
          type: 'warning',
        );
        return;
      }

      // Find unit name
      String unitName = 'หน่วย';
      if (selectedProduct.unitId != null) {
        final foundUnit = _units.firstWhere(
          (u) => u.id == selectedProduct.unitId,
          orElse: () => Unit(id: 0, name: 'หน่วย'),
        );
        unitName = foundUnit.name;
      }

      setState(() {
        _components.add(ProductComponent(
          id: 0,
          parentProductId: widget.product?.id ?? 0,
          childProductId: selectedProduct.id,
          quantity: 1.0,
          childProductName: selectedProduct.name,
          childProductCost: selectedProduct.costPrice,
          childProductUnit: unitName,
          childProductStock: selectedProduct.stockQuantity, // Added stock
        ));
      });
      _calculateCostAndStockFromComponents(); // Update immediately
    }
  }

  void _calculateCostAndStockFromComponents() {
    double totalCost = 0;
    double maxPossibleStock = double.infinity;
    bool hasComponents = false;

    for (var comp in _components) {
      double childCost = comp.childProductCost ?? 0;
      totalCost += childCost * comp.quantity;

      // Stock Calculation
      if (comp.quantity > 0) {
        hasComponents = true;
        double childStock = comp.childProductStock ?? 0;
        double possible = childStock / comp.quantity;
        if (possible < maxPossibleStock) {
          maxPossibleStock = possible;
        }
      }
    }

    setState(() {
      _costCtrl.text = totalCost.toStringAsFixed(2);
      if (hasComponents && maxPossibleStock != double.infinity) {
        _stockCtrl.text = maxPossibleStock.floor().toString();
      }
    });

    AlertService.show(
      context: context,
      message:
          'คำนวณต้นทุน: $totalCost, สต็อกสูงสุด: ${hasComponents && maxPossibleStock != double.infinity ? maxPossibleStock.floor() : "N/A"}',
      type: 'info',
    );
  }

  Widget _buildPriceTierContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[100]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'กำหนดราคาขายตามจำนวนขั้นบันได (Volume Pricing)',
                  style: TextStyle(color: Colors.orange[900]),
                ),
              ),
              CustomButton(
                onPressed: _addPriceTier,
                icon: Icons.add,
                label: 'เพิ่มระดับราคา',
                type: ButtonType.primary,
                backgroundColor: Colors.orange[700],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: Colors.grey[800],
          child: const Row(
            children: [
              Expanded(
                  flex: 3,
                  child: Text('จำนวนขั้นต่ำ',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 3,
                  child: Text('ราคาต่อหน่วย',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 4,
                  child: Text('หมายเหตุ',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              SizedBox(
                  width: 40,
                  child: Text('ลบ',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center)),
            ],
          ),
        ),
        // List
        Expanded(
          child: _priceTiers.isEmpty
              ? Center(
                  child: Text('ยังไม่มีการกำหนดราคาระดับ',
                      style: TextStyle(color: Colors.grey[500])),
                )
              : ListView.separated(
                  itemCount: _priceTiers.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final tier = _priceTiers[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      color: index % 2 == 0 ? Colors.white : Colors.grey[50],
                      child: Row(
                        children: [
                          // Min Qty
                          Expanded(
                            flex: 3,
                            child: CustomTextField(
                              initialValue: tier.minQuantity.toString(),
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                tier.minQuantity = double.tryParse(val) ?? 0;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Price
                          Expanded(
                            flex: 3,
                            child: CustomTextField(
                              initialValue: tier.price.toString(),
                              keyboardType: TextInputType.number,
                              prefixText: '฿ ',
                              onChanged: (val) {
                                tier.price = double.tryParse(val) ?? 0;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Note
                          Expanded(
                            flex: 4,
                            child: CustomTextField(
                              initialValue: tier.note,
                              hint: 'เช่น ราคาส่งยกลัง',
                              onChanged: (val) {
                                tier.note = val;
                              },
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _priceTiers.removeAt(index);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _addPriceTier() {
    setState(() {
      _priceTiers.add(ProductPriceTier(
        id: 0,
        productId: widget.product?.id ?? 0,
        minQuantity: 10,
        price: 0,
        note: '',
      ));
    });
  }
}
