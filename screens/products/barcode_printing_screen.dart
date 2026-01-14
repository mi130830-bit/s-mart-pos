import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../repositories/product_repository.dart';
import '../../services/printing/barcode_print_service.dart';

import '../../services/pdf/barcode_label_pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import '../../services/printing/label_printer_service.dart';
import '../../models/label_config.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';

class BarcodePrintingScreen extends StatefulWidget {
  const BarcodePrintingScreen({super.key});

  @override
  State<BarcodePrintingScreen> createState() => _BarcodePrintingScreenState();
}

class _BarcodePrintingScreenState extends State<BarcodePrintingScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final BarcodePrintService _barcodePrintService = BarcodePrintService();

  // List<Product> _allProducts = []; // Removed to save memory
  List<Product> _filteredProducts = [];
  final Map<int, int> _printCounts = {}; // productId -> count
  final Map<int, Product> _selectedProductsCache =
      {}; // Cache to display selected items
  bool _isLoading = true;
  String _orientation = 'landscape';
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
    // ✅ Load state from Service
    setState(() {
      _printCounts.addAll(_barcodePrintService.printQueue);
      _selectedProductsCache.addAll(_barcodePrintService.productCache);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts({String searchTerm = ''}) async {
    setState(() => _isLoading = true);
    try {
      // Load only top 50 matches or recent items to prevent UI freeze
      final products = await _productRepo.getProductsPaginated(
        1,
        50,
        searchTerm: searchTerm,
      );
      if (mounted) {
        setState(() {
          _filteredProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadProducts(searchTerm: query);
    });
  }

  void _updateCount(int productId, int delta) {
    setState(() {
      int current = _printCounts[productId] ?? 0;
      int next = current + delta;

      // Cache product if selecting
      if (delta > 0) {
        try {
          final p = _filteredProducts.firstWhere((p) => p.id == productId);
          _selectedProductsCache[productId] = p;
        } catch (_) {
          // If not in filtered list, it should be in cache already if previously selected
        }
      }

      if (next <= 0) {
        _printCounts.remove(productId);
      } else {
        _printCounts[productId] = next;
      }
      // ✅ Sync with Service
      _barcodePrintService.updateQueue(
          productId,
          next,
          next > 0
              ? _filteredProducts.firstWhere((p) => p.id == productId,
                  orElse: () => _selectedProductsCache[productId]!)
              : null);
    });
  }

  void _updateCountExact(int productId, int value) {
    if (value <= 0) {
      setState(() {
        _printCounts.remove(productId);
      });
    } else {
      setState(() {
        _printCounts[productId] = value;
      });
    }
  }

  Future<void> _showEditQuantityDialog(int productId, int currentQty) async {
    final controller = TextEditingController(text: '$currentQty');
    // Auto-select text
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ระบุจำนวน'),
        content: CustomTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          label: 'จำนวนบาร์โค้ด',
          onSubmitted: (_) {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          CustomButton(
            onPressed: () => Navigator.of(context).pop(),
            label: 'ยกเลิก',
            type: ButtonType.secondary,
          ),
          CustomButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            label: 'ตกลง',
            type: ButtonType.primary,
          ),
        ],
      ),
    );

    final newVal = int.tryParse(controller.text);
    if (newVal != null) {
      _updateCountExact(productId, newVal);
    }
  }

  Future<void> _handlePrint() async {
    if (_printCounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกสินค้าที่ต้องการพิมพ์')),
      );
      return;
    }

    final List<Map<String, dynamic>> productData = [];
    for (var entry in _printCounts.entries) {
      Product? product;
      try {
        product = _filteredProducts.firstWhere((p) => p.id == entry.key);
      } catch (_) {
        // If not in current filtered list, we might need to fetch it or finding it in previously loaded items.
        // But for simplicity, we assume we don't clear selections when searching.
        // However, if we cleared _allProducts, we might miss it.
        // Better strategy: Ensure we keep selected products in memory or fetch them by ID.
        // For now, let's look it up from Repo if missing (safest).
        product = await _productRepo.getProductById(entry.key);
      }

      if (product != null) {
        for (int i = 0; i < entry.value; i++) {
          productData.add({
            'barcode': product.barcode ?? '',
            'name': product.name,
            'retailPrice': product.retailPrice,
            'wholesalePrice': product.wholesalePrice,
          });
        }
      }
    }

    try {
      final template = await _barcodePrintService.getSelectedTemplate();
      if (template == null) {
        throw Exception('กรุณาเลือกแม่แบบบาร์โค้ดในหน้าตั้งค่าก่อน');
      }

      final pdfBytes = await BarcodeLabelPdf.generateFromTemplate(
        template: template,
        products: productData,
      );

      final prefs = await SharedPreferences.getInstance();

      // ✅ 1. Try to resolve printer from Smart Mapping first
      String? savedPrinterName;
      if (template.paperWidth == 103.1 && template.paperHeight == 27.4) {
        final config =
            await LabelPrinterService().getConfig(LabelType.barcode406x108);
        savedPrinterName = config.printerName;
        debugPrint(
            '🎯 Resolved from Smart Mapping (4.06x1.08): $savedPrinterName');
      } else if (template.paperWidth == 32 && template.paperHeight == 25) {
        final config =
            await LabelPrinterService().getConfig(LabelType.barcode32x25);
        savedPrinterName = config.printerName;
        debugPrint('🎯 Resolved from Smart Mapping (32x25): $savedPrinterName');
      }

      // ✅ 2. Fallback to global barcode printer setting
      if (savedPrinterName == null || savedPrinterName.isEmpty) {
        savedPrinterName = prefs.getString('printer_barcode_name');
        debugPrint(
            '🎯 No Smart Mapping found, using global barcode printer: $savedPrinterName');
      }

      // Special Case: Auto-fallback if the user types anything related to PDF
      bool isVirtual = false;
      if (savedPrinterName != null) {
        final String pLower = savedPrinterName.toLowerCase();
        if (pLower.contains('pdf') ||
            pLower.contains('writer') ||
            pLower.contains('virtual') ||
            pLower.contains('save') ||
            pLower.contains('document') ||
            pLower.contains('one-note') ||
            pLower.contains('microsoft') ||
            pLower.contains('oxps')) {
          isVirtual = true;
        }
      }

      final useCurrentSettings =
          prefs.getBool('barcode_use_current_settings') ?? false;

      // Default: Use Template Size
      PdfPageFormat pageFormat = PdfPageFormat(
        template.paperWidth * PdfPageFormat.mm,
        template.paperHeight * PdfPageFormat.mm,
        marginAll: 0,
      );

      // Apply selected orientation override
      if (_orientation == 'landscape') {
        pageFormat = pageFormat.landscape;
      } else {
        pageFormat = pageFormat.portrait;
      }

      if (savedPrinterName != null) {
        final printers = await Printing.listPrinters();
        final printer = printers.firstWhere(
            (p) => p.name == savedPrinterName || p.url == savedPrinterName,
            orElse: () => printers.first);

        debugPrint('🖨️ Selected Printer: $savedPrinterName');
        final String pName = printer.name.toLowerCase();
        debugPrint('🔍 Detected Printer Name (Lower): $pName');

        // Check if printer is definitely virtual
        if (isVirtual ||
            pName.contains('pdf') ||
            pName.contains('writer') ||
            pName.contains('virtual') ||
            pName.contains('save') ||
            pName.contains('document') ||
            pName.contains('microsoft')) {
          debugPrint('📑 Using layoutPdf for Virtual/PDF Printer');
          await Printing.layoutPdf(
            onLayout: (format) async => pdfBytes,
            name: 'Barcodes_${DateTime.now().millisecondsSinceEpoch}',
            format: pageFormat, // ✅ บังคับขนาดตาม Template
            usePrinterSettings:
                false, // ✅ สำคัญ: ห้ามใช้ค่าจาก Driver เพราะมักเป็น A4
          );
        } else {
          debugPrint('🏎️ Using directPrintPdf for Physical Printer');
          await Printing.directPrintPdf(
            printer: printer,
            onLayout: (format) async => pdfBytes,
            name: 'Barcodes_${DateTime.now().millisecondsSinceEpoch}',
            format: pageFormat,
            usePrinterSettings: useCurrentSettings,
          );
        }
      } else {
        // No printer selected, fall back to layout (preview)
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'Barcodes_${DateTime.now().millisecondsSinceEpoch}',
          format: pageFormat,
          usePrinterSettings: false,
        );
      }

      // ✅ Success Notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ ส่งคำสั่งพิมพ์เรียบร้อยแล้ว (Success)'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _printCounts.values.fold(0, (sum, val) => sum + val);

    return Scaffold(
      appBar: AppBar(
        title: const Text('พิมพ์บาร์โค้ด (Print Barcode)'),
      ),
      body: Row(
        children: [
          // ---------------- LEFT SIDE: Product Selection ----------------
          Expanded(
            flex: 5,
            child: Column(
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.grey.shade200,
                  width: double.infinity,
                  child: const Text(
                    '1. เลือกสินค้าที่ต้องการ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CustomTextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    hint: 'ค้นหาชื่อสินค้าหรือรหัสบาร์โค้ด...',
                    prefixIcon: Icons.search,
                  ),
                ),

                // Product List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _filteredProducts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final p = _filteredProducts[index];
                            final inQueue = _printCounts.containsKey(p.id);
                            final qty = _printCounts[p.id] ?? 0;

                            return ListTile(
                              title: Text(p.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                  '${p.barcode ?? "-"} | ${p.retailPrice} ฿',
                                  style: TextStyle(color: Colors.grey[600])),
                              trailing: inQueue
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'เลือกแล้ว ($qty)',
                                        style: TextStyle(
                                            color: Colors.green.shade800,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  : CustomButton(
                                      onPressed: () => _updateCount(p.id, 1),
                                      label: 'เพิ่ม',
                                      type: ButtonType.secondary,
                                    ),
                              onTap: () {
                                // Tap entire row to add
                                _updateCount(p.id, 1);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),

          // ---------------- RIGHT SIDE: Queue & Action ----------------
          Expanded(
            flex: 4,
            child: Column(
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.blue.shade50,
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '2. รายการที่เลือก (คิวการพิมพ์)',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (_printCounts.isNotEmpty)
                        CustomButton(
                          onPressed: () {
                            setState(() {
                              _printCounts.clear();
                              _barcodePrintService
                                  .clearQueue(); // ✅ Clear Service
                            });
                          },
                          icon: Icons.delete_sweep,
                          label: 'ล้างทั้งหมด',
                          type: ButtonType.danger,
                        )
                    ],
                  ),
                ),

                // Selected List
                Expanded(
                  child: _printCounts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.print_disabled,
                                  size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 10),
                              Text('ยังไม่มีรายการสินค้า',
                                  style:
                                      TextStyle(color: Colors.grey.shade500)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _printCounts.length,
                          itemBuilder: (context, index) {
                            final productId =
                                _printCounts.keys.elementAt(index);
                            final qty = _printCounts[productId]!;

                            // Retrieve from cache, or dummy if missing
                            final product = _selectedProductsCache[productId] ??
                                Product(
                                  id: productId,
                                  name: 'Unknown Product',
                                  barcode: '',
                                  costPrice: 0,
                                  retailPrice: 0,
                                  vatType: 1,
                                  points: 0,
                                  stockQuantity: 0,
                                  productType: 0, // 0 = General
                                );

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(product.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          Text(product.barcode ?? '-',
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle,
                                          color: Colors.grey),
                                      onPressed: () =>
                                          _updateCount(productId, -1),
                                    ),
                                    InkWell(
                                      onTap: () => _showEditQuantityDialog(
                                          productId, qty),
                                      borderRadius: BorderRadius.circular(4),
                                      child: Container(
                                        width:
                                            50, // Slightly wider for easier tapping
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '$qty',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle,
                                          color: Colors.blue),
                                      onPressed: () =>
                                          _updateCount(productId, 1),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          _printCounts.remove(productId);
                                          _barcodePrintService.updateQueue(
                                              productId,
                                              0); // ✅ Remove from Service
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Bottom Panel
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      // Orientation Selector
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('แนวการพิมพ์:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            DropdownButton<String>(
                              value: _orientation,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(
                                  value: 'landscape',
                                  child: Row(
                                    children: [
                                      Icon(Icons.landscape,
                                          size: 16, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('แนวนอน (Landscape)'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'portrait',
                                  child: Row(
                                    children: [
                                      Icon(Icons.portrait,
                                          size: 16, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('แนวตั้ง (Portrait)'),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _orientation = val);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('จำนวนรายการที่เลือก:',
                              style: TextStyle(fontSize: 14)),
                          Text('${_printCounts.length}',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('จำนวนสติ๊กเกอร์ทั้งหมด:',
                              style: TextStyle(fontSize: 16)),
                          Text('$selectedCount',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: CustomButton(
                          onPressed: _printCounts.isEmpty ? null : _handlePrint,
                          icon: Icons.print,
                          label: 'สั่งพิมพ์บาร์โค้ด',
                          type: ButtonType.primary,
                          backgroundColor: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
