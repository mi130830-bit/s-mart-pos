import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../models/product.dart';
import '../../../../models/supplier.dart';
import '../../../../models/unit.dart';
import '../../../../models/product_component.dart';
import '../../../../models/product_price_tier.dart';
import '../../../../models/product_barcode.dart';
import '../../../../repositories/product_repository.dart';
import '../../../../repositories/supplier_repository.dart';
import '../../../../repositories/unit_repository.dart';
import '../../../../repositories/product_component_repository.dart';
import '../../../../repositories/product_price_tier_repository.dart';
import '../../../../services/alert_service.dart';
import '../../widgets/product_search_dialog_for_select.dart';
import '../../widgets/supplier_search_dialog.dart';
import '../../widgets/component_row.dart';
import 'package:provider/provider.dart';
import '../../../../state/auth_provider.dart';
import '../../../../widgets/common/custom_text_field.dart';
import '../../../../widgets/common/custom_buttons.dart';
import '../../../../repositories/product_type_repository.dart';
import '../../../../repositories/shelf_repository.dart';
import '../../../../repositories/stock_repository.dart';
import '../../../../repositories/sales_repository.dart';
import '../../../../models/product_type.dart';
import '../../../../models/shelf.dart';
import '../../../../services/settings_service.dart';
import '../../../../widgets/dialogs/admin_pin_dialog.dart';

import '../../product_list_view.dart';

// --- PART FILES ---
part 'extensions/product_form_actions_extension.dart';
part 'layouts/product_form_left_column.dart';
part 'layouts/product_form_right_column.dart';
part 'tabs/product_linkage_tab.dart';
part 'tabs/product_price_tier_tab.dart';
part 'tabs/product_unit_barcode_tab.dart';
part 'tabs/product_stock_history_tab.dart';
part 'tabs/product_sales_history_tab.dart';

class ProductFormDialog extends StatefulWidget {
  final ProductRepository repo;
  final Product? product;
  final bool delayedSave; // New parameter

  const ProductFormDialog({
    super.key,
    required this.repo,
    this.product,
    this.delayedSave = false, // Default to false (normal behavior)
  });

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _barcodeCtrl;
  late TextEditingController _aliasCtrl;
  final TextEditingController _supplierNameCtrl = TextEditingController();
  final TextEditingController _unitNameCtrl = TextEditingController();
  final TextEditingController _typeNameCtrl = TextEditingController();

  late TextEditingController _costCtrl;
  late TextEditingController _retailPriceCtrl;
  late TextEditingController _wholesalePriceCtrl;
  late TextEditingController _memberRetailPriceCtrl;
  late TextEditingController _memberWholesalePriceCtrl;

  late TextEditingController _stockCtrl;
  late TextEditingController _reorderPointCtrl;
  late TextEditingController _pointsCtrl;
  late TextEditingController _shelfCtrl;

  bool _trackStock = true;
  bool _isActiveProduct = true;
  bool _isWarehouseItem = false;

  VatType _selectedVat = VatType.noVat;
  int? _selectedUnitId;
  int? _selectedSupplierId;
  DateTime? _expiryDate;

  final SupplierRepository _supplierRepo = SupplierRepository();
  final UnitRepository _unitRepo = UnitRepository();
  final ProductComponentRepository _componentRepo = ProductComponentRepository();
  final ProductPriceTierRepository _tierRepo = ProductPriceTierRepository();
  final ProductTypeRepository _typeRepo = ProductTypeRepository();
  final ShelfRepository _shelfRepo = ShelfRepository();

  List<Supplier> _suppliers = [];
  List<Unit> _units = [];
  List<ProductComponent> _components = [];
  List<ProductPriceTier> _priceTiers = [];
  List<ProductBarcode> _extraBarcodes = [];
  List<ProductType> _productTypes = [];
  List<Shelf> _shelves = [];

  int? _selectedTypeId; // 0=General, 1=Weighing
  int _activeTab = 0; // 0=Linkage, 1=Price Tier, 2=Units, 3=StockIn History, 4=Sales History

  // History Tab State
  List<Map<String, dynamic>>? _stockInHistory;
  List<Map<String, dynamic>>? _salesHistory;
  bool _loadingHistory = false;
  XFile? _pickedImage;

  // Keys to Fix Focus Jumping
  Key _typeFieldKey = UniqueKey();
  Key _unitFieldKey = UniqueKey();
  Key _shelfFieldKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _shelfCtrl = TextEditingController(text: p?.shelfLocation ?? '');
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _aliasCtrl = TextEditingController(text: p?.alias ?? '');

    // Prices
    _costCtrl = TextEditingController(text: p?.costPrice.toString() ?? '0');
    _retailPriceCtrl = TextEditingController(text: p?.retailPrice.toString() ?? '0');
    _wholesalePriceCtrl = TextEditingController(text: p?.wholesalePrice?.toString() ?? '0');
    _memberRetailPriceCtrl = TextEditingController(text: p?.memberRetailPrice?.toString() ?? '0');
    _memberWholesalePriceCtrl = TextEditingController(text: p?.memberWholesalePrice?.toString() ?? '0');

    // Stock & Points
    _stockCtrl = TextEditingController(text: p?.stockQuantity.toString() ?? '0');
    _reorderPointCtrl = TextEditingController(text: p?.reorderPoint?.toString() ?? '0');
    _pointsCtrl = TextEditingController(text: p?.points.toString() ?? '0');

    _trackStock = p?.trackStock ?? true;
    _isActiveProduct = p?.isActive ?? true;
    _isWarehouseItem = p?.isWarehouseItem ?? false;
    _expiryDate = p?.expiryDate;
    _selectedVat = VatType.fromInt(p?.vatType ?? 0);

    _loadInitialData();
    if (p != null) {
      _loadComponents(p.id);
      _loadTiers(p.id);
      _loadBarcodes(p.id);
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
    _shelfCtrl.dispose();
    super.dispose();
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
                            flex: 5,
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
                            flex: 5,
                            child: Container(
                              color: Colors.white,
                              child: Column(
                                children: [
                                  // Right Header (Tabs simulation)
                                  Container(
                                    color: Colors.blue[50],
                                    width: double.infinity, // Ensure container takes full width
                                    child: Wrap(
                                      children: [
                                        InkWell(
                                          onTap: () =>
                                              setState(() => _activeTab = 0),
                                          child: _buildTabHeader(
                                              'การเชื่อมโยง',
                                              _activeTab == 0,
                                              icon: Icons.link),
                                        ),
                                        InkWell(
                                          onTap: () =>
                                              setState(() => _activeTab = 1),
                                          child: _buildTabHeader(
                                              'ราคาหลายระดับ', _activeTab == 1,
                                              icon: Icons.attach_money),
                                        ),
                                        InkWell(
                                          onTap: () =>
                                              setState(() => _activeTab = 2),
                                          child: _buildTabHeader(
                                              'หน่วยเสริม',
                                              _activeTab == 2,
                                              icon: Icons.view_module),
                                        ),
                                        if (widget.product != null) ...[
                                          InkWell(
                                            onTap: () {
                                              setState(() => _activeTab = 3);
                                              if (_stockInHistory == null) {
                                                _loadStockInHistory();
                                              }
                                            },
                                            child: _buildTabHeader(
                                                'ประวัติรับเข้า',
                                                _activeTab == 3,
                                                icon: Icons.move_to_inbox),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              setState(() => _activeTab = 4);
                                              if (_salesHistory == null) {
                                                _loadSalesHistory();
                                              }
                                            },
                                            child: _buildTabHeader(
                                                'ประวัติการขาย',
                                                _activeTab == 4,
                                                icon: Icons.receipt_long),
                                          ),
                                        ],
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
}
