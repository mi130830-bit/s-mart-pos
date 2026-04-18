import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/stock_repository.dart';
import '../../services/telegram_service.dart';
import '../../services/alert_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/dialogs/admin_auth_dialog.dart';

// Import ไฟล์เพื่อนบ้านโดยตรง
import 'stock_ledger_views.dart';
import 'product_selection_dialog.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';

import 'cloud_stock_import_dialog.dart';

class AdjustmentItem {
  final Product product;
  final double systemQty;
  final double countedQty;
  final String note;

  AdjustmentItem({
    required this.product,
    required this.systemQty,
    required this.countedQty,
    this.note = '',
  });

  double get diff => countedQty - systemQty;

  String get type {
    if (diff > 0) return 'OVER'; // เกิน
    if (diff < 0) return 'SHORT'; // ขาด
    return 'MATCH'; // ตรง
  }
}

class StockAdjustmentSection extends StatefulWidget {
  const StockAdjustmentSection({super.key});

  @override
  State<StockAdjustmentSection> createState() => _StockAdjustmentSectionState();
}

class _StockAdjustmentSectionState extends State<StockAdjustmentSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabMgr;

  @override
  void initState() {
    super.initState();
    _tabMgr = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabMgr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header & Tabs
        Container(
          color: Colors.indigo.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabMgr,
                  isScrollable: true,
                  labelColor: Colors.deepPurple,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.deepPurple,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.playlist_add_check),
                      text: 'ทำรายการเช็ค (Check Stock)',
                    ),
                    Tab(
                      icon: Icon(Icons.history),
                      text: 'ประวัติการเช็ค (History)',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabMgr,
            children: const [
              _CheckStockPage(),
              StockAdjustmentHistoryView(),
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckStockPage extends StatefulWidget {
  const _CheckStockPage();

  @override
  State<_CheckStockPage> createState() => _CheckStockPageState();
}

class _CheckStockPageState extends State<_CheckStockPage> {
  final ProductRepository _repo = ProductRepository();
  final StockRepository _stockRepo = StockRepository();
  final List<AdjustmentItem> _pendingItems = [];
  final _dialogFormKey = GlobalKey<FormState>();
  final TextEditingController _dialogCountedQtyCtrl = TextEditingController();
  final TextEditingController _dialogNoteCtrl = TextEditingController();

  Product? _dialogSelectedProduct;

  // สไตล์สำหรับ Input Field ที่ปรับให้ใหญ่ขึ้น
  InputDecoration _bigInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 16),
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    );
  }

  TextStyle get _bigTextStyle => const TextStyle(fontSize: 18);

  Future<void> _openCloudImportDialog() async {
    final List<Map<String, dynamic>>? importedItems = await showDialog(
      context: context,
      builder: (context) => const CloudStockImportDialog(),
    );

    if (importedItems != null && importedItems.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        for (var item in importedItems) {
          // Map to Product Model - but product is a Map<String, dynamic> here?
          // No, query returns Map. We need to convert to Product object if AdjustmentItem requires it.
          // Or pass map to AdjustmentItem?

          // Wait, AdjustmentItem requires `Product` object.
          // CloudStockImportDialog returns `product` as Map from `res.first`.
          // We need to convert Map -> Product.

          final prodMap = item['product'] as Map<String, dynamic>;
          // Fix: MySQL binary/int/double handling for Product.fromJson might be tricky if not standardized.
          // Let's rely on Product.fromMap if exists or create dummy.
          // Product.fromMap expects specific keys.

          try {
            // Hotfix: Ensure proper types
            prodMap['stockQuantity'] =
                double.tryParse(prodMap['stockQuantity'].toString()) ?? 0.0;
            // Add other defaulting needed for Product model

            final product = Product.fromJson(prodMap);

            _pendingItems.add(AdjustmentItem(
              product: product,
              systemQty: item['systemQty'], // Use the one from import time
              countedQty: item['actualQty'],
              note: 'Import from Cloud',
            ));
          } catch (e) {
            debugPrint('⚠️ Product Map Error: $e');
          }
        }
      });

      AlertService.show(
          context: context,
          message:
              'นำเข้า ${importedItems.length} รายการแล้ว กรุณากดบันทึกอีกครั้ง',
          type: 'info');
    }
  }

  Future<void> _openAddItemDialog() async {
    _dialogCountedQtyCtrl.clear();
    _dialogNoteCtrl.clear();
    _dialogSelectedProduct = null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text(
              'เช็คสต็อก (Check Stock)',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 450,
              child: Form(
                key: _dialogFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      // --- ส่วนเลือกสินค้า ---
                      InkWell(
                        onTap: () async {
                          // Note: We don't fetch getAllProducts() here anymore to prevent UI Freeze.
                          // We pass the repo to the dialog instead.
                          if (!context.mounted) {
                            return;
                          }
                          final picked = await showDialog<Product>(
                            context: context,
                            builder: (c) => ProductSelectionDialog(repo: _repo),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              _dialogSelectedProduct = picked;
                              // Auto fill counted with system? No, keep empty to force count.
                              // But showing System Qty is important.
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: _bigInputDecoration('สินค้า').copyWith(
                            suffixIcon:
                                const Icon(Icons.arrow_drop_down, size: 28),
                          ),
                          child: Text(
                            _dialogSelectedProduct != null
                                ? _dialogSelectedProduct!.name
                                : 'แตะเพื่อเลือกสินค้า...',
                            style: _bigTextStyle.copyWith(
                              color: _dialogSelectedProduct == null
                                  ? Colors.grey.shade600
                                  : Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      if (_dialogSelectedProduct != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('จำนวนในระบบ (System):',
                                  style: TextStyle(fontSize: 16)),
                              Text(
                                _dialogSelectedProduct!.stockQuantity
                                    .toStringAsFixed(0),
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // --- ช่องจำนวนที่นับได้ ---
                      CustomTextField(
                        controller: _dialogCountedQtyCtrl,
                        label: 'จำนวนที่นับได้จริง (Counted)',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'กรุณาระบุจำนวนที่นับได้';
                          }
                          if (double.tryParse(v) == null) {
                            return 'ตัวเลขไม่ถูกต้อง';
                          }
                          if (double.parse(v) < 0) {
                            return 'ต้องไม่ติดลบ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // --- ช่องหมายเหตุ ---
                      CustomTextField(
                        controller: _dialogNoteCtrl,
                        label: 'หมายเหตุ',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actionsPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            actions: [
              CustomButton(
                label: 'ยกเลิก',
                type: ButtonType.secondary,
                onPressed: () => Navigator.pop(context),
              ),
              CustomButton(
                label: 'เพิ่มรายการ',
                type: ButtonType.primary,
                onPressed: () {
                  if (_dialogSelectedProduct != null &&
                      _dialogFormKey.currentState!.validate()) {
                    double counted = double.parse(_dialogCountedQtyCtrl.text);
                    double system = _dialogSelectedProduct!.stockQuantity;

                    setState(() {
                      _pendingItems.add(
                        AdjustmentItem(
                          product: _dialogSelectedProduct!,
                          systemQty: system,
                          countedQty: counted,
                          note: _dialogNoteCtrl.text,
                        ),
                      );
                    });
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveAllAdjustments() async {
    debugPrint('DEBUG: _saveAllAdjustments called'); // Console Log

    // ✅ Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการปรับปรุงสต็อก'),
        content: Text(
            'คุณต้องการบันทึกการปรับปรุงสต็อกจำนวน ${_pendingItems.length} รายการ หรือไม่?\n\n'
            '⚠️ สต็อกสินค้าจะถูกเปลี่ยนแปลงตามยอดที่นับจริงทันที'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return; // Fix async gap

    if (_pendingItems.isEmpty) {
      return;
    }

    // ✅ Allow diff == 0 (Verified items) to be processed
    final itemsToAdjust = List<AdjustmentItem>.from(_pendingItems);

    if (itemsToAdjust.isEmpty) {
      return;
    }

    // ✅ Security Check
    if (SettingsService().requireAdminForStockAdjust) {
      final authorized = await AdminAuthDialog.show(context);
      if (!authorized) return;
    }

    if (!mounted) return;

    int successCount = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    for (var item in itemsToAdjust) {
      // ✅ ใช้ updateStockToExact เพื่อความ Idempotent (กดซ้ำก็ยอดไม่เพี้ยน)
      bool success = await _stockRepo.updateStockToExact(
        item.product.id,
        item.countedQty,
        note: item.note.isNotEmpty
            ? item.note
            : 'Stock Check: System=${item.systemQty.toStringAsFixed(0)}, Counted=${item.countedQty.toStringAsFixed(0)}',
      );

      if (success) {
        successCount++;
      }
    }

    if (!mounted) {
      return;
    }
    Navigator.pop(context);
    AlertService.show(
      context: context,
      message: 'บันทึกสำเร็จ $successCount รายการ',
      type: 'success',
    );

    // ✅ ส่งแจ้งเตือน Telegram
    try {
      if (successCount > 0 &&
          await TelegramService()
              .shouldNotify(TelegramService.keyNotifyStockAdjust)) {
        String msg = '🔧 *ปรับปรุงสต็อก (Check Stock)*\n'
            '━━━━━━━━━━━━━━━━━━\n'
            '📅 รายการที่ตรวจนับ: $successCount รายการ\n';

        // แสดงตัวอย่าง 5 รายการแรก
        for (var i = 0;
            i < (itemsToAdjust.length > 5 ? 5 : itemsToAdjust.length);
            i++) {
          final item = itemsToAdjust[i];
          final diff = item.diff;
          final isPos = diff > 0;
          final isZero = diff == 0;

          final String changeText = isZero
              ? "✅ Verified"
              : "${isPos ? "+" : ""}${diff.toStringAsFixed(0)}";

          msg +=
              '📦 ${item.product.name}: $changeText (Sys:${item.systemQty.toStringAsFixed(0)}->Cnt:${item.countedQty.toStringAsFixed(0)})\n';
        }
        if (itemsToAdjust.length > 5) {
          msg += '... และรายการอื่นอีก ${itemsToAdjust.length - 5} รายการ\n';
        }
        msg += '━━━━━━━━━━━━━━━━━━';
        TelegramService().sendMessage(msg);
      }
    } catch (e) {
      debugPrint('Telegram Stock Adjust Error: $e');
    }

    setState(() {
      _pendingItems.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'รายการเช็คสต็อก (Stock Check)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  CustomButton(
                    onPressed: _openAddItemDialog,
                    icon: Icons.playlist_add_check,
                    label: 'เพิ่มรายการเช็ค',
                    type: ButtonType.primary,
                  ),
                  const SizedBox(width: 12),
                  CustomButton(
                    onPressed: _openCloudImportDialog,
                    icon: Icons.cloud_download,
                    label: 'ดึงใบงาน S_MartPOS',
                    backgroundColor: Colors.teal,
                    type: ButtonType.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: _pendingItems.isEmpty
              ? const Center(
                  child: Text('ยังไม่มีรายการที่เช็ค',
                      style: TextStyle(fontSize: 18, color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: _pendingItems.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final item = _pendingItems[index];
                    final diff = item.diff;
                    final isMerch = diff == 0;
                    final isOver = diff > 0;

                    Color cardColor = Colors.white;
                    if (isOver) {
                      cardColor = Colors.green.shade50;
                    } else if (!isMerch) {
                      cardColor = Colors.red.shade50; // Short
                    }

                    return Card(
                      color: cardColor,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            // Product Info
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  if (item.note.isNotEmpty)
                                    Text('Note: ${item.note}',
                                        style: TextStyle(
                                            color: Colors.grey.shade700)),
                                ],
                              ),
                            ),
                            // Stats
                            Expanded(
                              flex: 3,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatColumn(
                                      'System',
                                      item.systemQty.toStringAsFixed(0),
                                      Colors.black),
                                  const Icon(Icons.arrow_forward,
                                      color: Colors.grey),
                                  _buildStatColumn(
                                      'Counted',
                                      item.countedQty.toStringAsFixed(0),
                                      Colors.blue.shade800),
                                  _buildStatColumn(
                                      'Diff',
                                      '${diff > 0 ? "+" : ""}${diff.toStringAsFixed(0)}',
                                      isMerch
                                          ? Colors.grey
                                          : (isOver
                                              ? Colors.green
                                              : Colors.red)),
                                ],
                              ),
                            ),
                            // Delete
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () =>
                                  setState(() => _pendingItems.removeAt(index)),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [
            BoxShadow(
                color: Colors.grey.withValues(alpha: 0.2),
                blurRadius: 5,
                offset: const Offset(0, -3))
          ]),
          child: SizedBox(
            width: double.infinity,
            height: 60,
            child: CustomButton(
              onPressed: _pendingItems.isEmpty ? null : _saveAllAdjustments,
              icon: Icons.save,
              label: 'บันทึกผลการตรวจนับ (${_pendingItems.length})',
              type: ButtonType.primary,
              backgroundColor: Colors.blue
                  .shade700, // Keep specific color if needed or rely on type
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
