import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../models/unit.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/unit_repository.dart';
import '../../services/alert_service.dart';
import 'dialogs/product_form/product_form_dialog.dart';

import 'package:provider/provider.dart';
import '../../utils/barcode_utils.dart';
import '../../state/auth_provider.dart';
import 'master_data_management_screen.dart';
import '../../repositories/product_type_repository.dart';
import '../../models/product_type.dart';
import 'widgets/product_filter_bar.dart';
import 'widgets/product_table.dart';

// Enum สำหรับ VAT Type
enum VatType {
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
  final ProductRepository _productRepo = ProductRepository();
  final UnitRepository _unitRepo = UnitRepository();

  List<Product> _products = [];
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  List<Unit> _units = [];

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
    setState(() => _isLoading = true);
    try {
      String searchTerm = _searchCtrl.text.trim();

      // 1. Initial Search
      var products = await _productRepo.getProductsPaginated(
        _currentPage,
        _pageSize,
        searchTerm: searchTerm.isEmpty ? null : searchTerm,
        productTypeId: _filterTypeId,
        sortOption: _currentSort,
      );
      var total = await _productRepo.getProductCount(
        searchTerm: searchTerm.isEmpty ? null : searchTerm,
        productTypeId: _filterTypeId,
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
            productTypeId: _filterTypeId,
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
      final types = await _typeRepo.getAllProductTypes();

      if (mounted) {
        setState(() {
          _products = products;
          _totalItems = total;
          _units = units;
          _productTypes = types;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncData() async {
    setState(() => _isLoading = true);
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

    await _loadData();
  }

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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.isAdmin;

    return Scaffold(
      floatingActionButton: isAdmin
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
            child: ProductFilterBar(
              searchCtrl: _searchCtrl,
              currentSort: _currentSort,
              filterTypeId: _filterTypeId,
              productTypes: _productTypes,
              onSearchChanged: _onSearchChanged,
              onSortChanged: (sort) {
                setState(() {
                  _currentSort = sort;
                  _currentPage = 1;
                });
                _loadData();
              },
              onFilterTypeChanged: (typeId) {
                setState(() {
                  _filterTypeId = typeId;
                  _currentPage = 1;
                });
                _loadData();
              },
              onSyncData: _syncData,
              onManageMasterData: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MasterDataManagementScreen()),
                ).then((_) => _loadData());
              },
              hasMasterDataPermission: authProvider.hasPermission('manage_master_data'),
            ),
          ),

          // List + Pagination
          Expanded(
            child: ProductTable(
              products: _products,
              units: _units,
              isLoading: _isLoading,
              isAdmin: isAdmin,
              totalItems: _totalItems,
              currentPage: _currentPage,
              pageSize: _pageSize,
              onEditProduct: _showProductDialog,
              onDeleteProduct: _confirmDelete,
              onToggleWarehouseItem: (product, newValue) async {
                final updated = product.copyWith(isWarehouseItem: newValue);
                setState(() {
                  final idx = _products.indexWhere((p) => p.id == product.id);
                  if (idx != -1) {
                    _products[idx] = updated;
                  }
                });
                await _productRepo.saveProduct(updated);
              },
              onPageChanged: _goToPage,
            ),
          ),
        ],
      ),
    );
  }
}
