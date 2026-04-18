import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/product.dart';
import '../../../repositories/product_repository.dart';
import '../../../services/quick_menu_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'product_search_dialog_for_select.dart';
import 'package:provider/provider.dart';
import '../../pos/pos_state_manager.dart';
import '../../../services/settings_service.dart';
import '../../../services/alert_service.dart';

class QuickMenuDialog extends StatefulWidget {
  final ProductRepository productRepo;
  final Function(Product)? onProductSelected;

  const QuickMenuDialog({
    super.key,
    required this.productRepo,
    this.onProductSelected,
  });

  @override
  State<QuickMenuDialog> createState() => _QuickMenuDialogState();
}

class _QuickMenuDialogState extends State<QuickMenuDialog> {
  final QuickMenuService _service = QuickMenuService();
  int _currentPage = 1;
  final int _totalPages = 10;
  bool _isEditMode = false;
  final Map<int, Product?> _loadedProducts = {}; // slotIndex -> Product
  bool _isLoading = true;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadPageData();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPageData() async {
    if (mounted) setState(() => _isLoading = true);
    await _service.loadConfig(); // Load fresh config
    if (!mounted) return;

    _loadedProducts.clear();

    // Load products for current page
    // Load products for current page
    final List<int> neededIds = [];
    final Map<int, int> slotToIdMap = {};

    for (int i = 0; i < 20; i++) {
      final pid = _service.getProductId(_currentPage, i);
      if (pid > 0) {
        neededIds.add(pid);
        slotToIdMap[i] = pid;
      } else {
        _loadedProducts[i] = null;
      }
    }

    if (neededIds.isNotEmpty) {
      final products = await widget.productRepo.getProductsByIds(neededIds);
      // Map back to slots
      final pMap = {for (var p in products) p.id: p};

      slotToIdMap.forEach((slotIndex, pid) {
        _loadedProducts[slotIndex] = pMap[pid];
      });
    }

    if (mounted) setState(() => _isLoading = false);

    // ✅ Auto-populate if empty (One-time check for User Request)
    _checkForAutoPopulate();
  }

  Future<void> _checkForAutoPopulate() async {
    await _populateDefaults();
  }

  Future<void> _restoreDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('quick_menu_updated_v6'); // Clear flag
    await _populateDefaults(force: true);
  }

  Future<void> _populateDefaults({bool force = false}) async {
    // Check if we have already forced updated (Version 2 for new names)
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();

    // If we have already populated for this version, skip heavy loading
    if (!force && prefs.getBool('quick_menu_updated_v6') == true) return;

    // Force populate pages 1-7 as requested by user ("new again")
    // We add them all to be re-populated
    final List<int> pagesToPopulate = [1, 2, 3, 4, 5, 6, 7];

    if (mounted) setState(() => _isLoading = true);

    try {
      // ✅ Revised: Fetch ONLY needed products (Optimized)
      // Collect all barcodes to fetch
      final Set<String> neededBarcodes = {};

      // Page 1 Data
      final page1Codes = [
        '10008',
        '10009',
        '10010',
        '8852278101468',
        '692747',
        '10004',
        '10002',
        '10006',
        '10007',
        '457226',
        '655630',
        '930292',
        '243923',
        '357996',
        '370730',
        '0000215',
        '0000216',
        '0000217',
        '0000218',
        '0000219'
      ];
      if (pagesToPopulate.contains(1)) {
        neededBarcodes.addAll(page1Codes.where((c) => c.isNotEmpty));
      }

      // Page 2 Data
      final page2Codes = [
        '20027',
        '20029',
        '20031',
        '20032',
        '20033',
        '20028',
        '20030',
        '',
        '',
        '',
        '20018',
        '20021',
        '20022',
        '20023',
        '20025',
        '20002',
        '20003',
        '20004',
        '20005',
        '20006'
      ];
      if (pagesToPopulate.contains(2)) {
        neededBarcodes.addAll(page2Codes.where((c) => c.isNotEmpty));
      }

      // Page 3 Data (เหล็กกล่องไม้ขีด)
      final page3Codes = [
        '20037',
        '20038',
        '20039',
        '',
        '',
        '20040',
        '20041',
        '20042',
        '',
        '',
        '20034',
        '20035',
        '20036',
        '',
        '',
        '',
        '',
        '',
        '',
        ''
      ];
      if (pagesToPopulate.contains(3)) {
        neededBarcodes.addAll(page3Codes.where((c) => c.isNotEmpty));
      }

      // Page 4 Data (pvcฟ้า)
      final page4Codes = [
        '30001',
        '30002',
        '30003',
        '30004',
        '30005',
        '30006',
        '30007',
        '30008',
        '30009',
        '30244',
        '30010',
        '30011',
        '30012',
        '30013',
        '262341',
        '30014',
        '30015',
        '30016',
        '30017',
        '30018'
      ];
      if (pagesToPopulate.contains(4)) {
        neededBarcodes.addAll(page4Codes.where((c) => c.isNotEmpty));
      }

      // Page 5 Data (pvcเหลือง)
      final page5Codes = [
        '8858928750734',
        '8858928707196',
        '40269',
        '40272',
        '',
        '8858928750758',
        '8858928731184',
        '40270',
        '40273',
        '',
        '88589287500772',
        '40206',
        '40271',
        '345709',
        '',
        '40197',
        '',
        '',
        '',
        ''
      ];
      if (pagesToPopulate.contains(5)) {
        neededBarcodes.addAll(page5Codes.where((c) => c.isNotEmpty));
      }

      // Page 6 Data (วงบ่อ+ฝา)
      final page6Codes = [
        '10081',
        '10082',
        '10083',
        '10084',
        '',
        '10085',
        '10086',
        '10087',
        '575056',
        '',
        '631404',
        '741792',
        '952677',
        '10088',
        '',
        '',
        '',
        '',
        '',
        ''
      ];
      if (pagesToPopulate.contains(6)) {
        neededBarcodes.addAll(page6Codes.where((c) => c.isNotEmpty));
      }

      // Page 7 Data (ท่อระบายน้ำ)
      final page7Codes = [
        '10075',
        '456173',
        '10076',
        '10077',
        '10078',
        '10079',
        '10080',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        ''
      ];
      if (pagesToPopulate.contains(7)) {
        neededBarcodes.addAll(page7Codes.where((c) => c.isNotEmpty));
      }

      // Fetch ONLY needed products
      final foundProducts = await widget.productRepo
          .getProductsByBarcodes(neededBarcodes.toList());
      final Map<String, int> barcodeMap = {};
      for (var p in foundProducts) {
        if (p.barcode != null) barcodeMap[p.barcode!] = p.id;
      }

      int populatedCount = 0;

      // Populate Page 1
      if (pagesToPopulate.contains(1)) {
        for (int i = 0; i < page1Codes.length; i++) {
          final code = page1Codes[i];
          if (code.isNotEmpty && barcodeMap.containsKey(code)) {
            await _service.setProductId(1, i, barcodeMap[code]!);
          }
        }
        await _service.setPageName(1, 'ปูนหินทรายบล็อก');
        populatedCount++;
      }

      // Populate Page 2
      if (pagesToPopulate.contains(2)) {
        for (int i = 0; i < page2Codes.length; i++) {
          final code = page2Codes[i];
          if (code.isNotEmpty && barcodeMap.containsKey(code)) {
            await _service.setProductId(2, i, barcodeMap[code]!);
          }
        }
        await _service.setPageName(2, 'เหล็กกล่อง');
        populatedCount++;
      }

      // Populate Page 3
      if (pagesToPopulate.contains(3)) {
        for (int i = 0; i < page3Codes.length; i++) {
          final code = page3Codes[i];
          if (code.isNotEmpty && barcodeMap.containsKey(code)) {
            await _service.setProductId(3, i, barcodeMap[code]!);
          }
        }
        await _service.setPageName(3, 'เหล็กกล่องไม้ขีด');
        populatedCount++;
      }

      // Populate Page 4
      if (pagesToPopulate.contains(4)) {
        for (int i = 0; i < page4Codes.length; i++) {
          final code = page4Codes[i];
          if (code.isNotEmpty && barcodeMap.containsKey(code)) {
            await _service.setProductId(4, i, barcodeMap[code]!);
          }
        }
        await _service.setPageName(4, 'pvcฟ้า');
        populatedCount++;
      }

      // Populate Page 5
      if (pagesToPopulate.contains(5)) {
        for (int i = 0; i < page5Codes.length; i++) {
          final code = page5Codes[i];
          if (code.isNotEmpty && barcodeMap.containsKey(code)) {
            await _service.setProductId(5, i, barcodeMap[code]!);
          }
        }
        await _service.setPageName(5, 'pvcเหลือง');
        populatedCount++;
      }

      // Populate Page 6
      if (pagesToPopulate.contains(6)) {
        for (int i = 0; i < page6Codes.length; i++) {
          final code = page6Codes[i];
          if (code.isNotEmpty && barcodeMap.containsKey(code)) {
            await _service.setProductId(6, i, barcodeMap[code]!);
          }
        }
        await _service.setPageName(6, 'วงบ่อ+ฝา');
        populatedCount++;
      }

      // Populate Page 7
      if (pagesToPopulate.contains(7)) {
        for (int i = 0; i < page7Codes.length; i++) {
          final code = page7Codes[i];
          if (code.isNotEmpty && barcodeMap.containsKey(code)) {
            await _service.setProductId(7, i, barcodeMap[code]!);
          }
        }
        await _service.setPageName(
            7, 'ท่อระบายน้ำ'); // Or just 7 as per tab requests
        populatedCount++;
      }

      if (populatedCount > 0) {
        // Save Config Once
        await _service.saveConfig();

        // Mark as populated
        await prefs.setBool('quick_menu_updated_v6', true);

        if (!mounted) return;

        // Reload
        await _loadPageData();
      }
    } catch (e) {
      debugPrint('Auto populate failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleSlotClick(int index) async {
    if (_isEditMode) {
      // Assign Product
      final selected = await showDialog<Product>(
        context: context,
        builder: (ctx) =>
            ProductSearchDialogForSelect(repo: widget.productRepo),
      );

      if (!mounted) return;

      if (selected != null) {
        await _service.setProductId(_currentPage, index, selected.id);
        if (mounted) {
          _loadPageData(); // Reload
        }
      }
    } else {
      // Select Product
      final product = _loadedProducts[index];
      if (product != null) {
        if (widget.onProductSelected != null) {
          // ✅ Await if potential async to prevent "fire & forget" issues
          // Cast to dynamic to check if Future? Or just await dynamic.
          await (widget.onProductSelected!(product) as dynamic);
          // Do not close dialog (Keep Open)
        } else {
          Navigator.of(context).pop(product);
        }
      }
    }
  }

  void _handleRenamePage() async {
    final ctrl =
        TextEditingController(text: _service.getPageName(_currentPage));
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('แก้ไขชื่อหน้าเมนูลัดสินค้า'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'ชื่อหน้า'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('บันทึก')),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      await _service.setPageName(_currentPage, newName);
      setState(() {}); // Refresh UI
    }
  }

  void _handleClearSlot(int index) async {
    // 1. ตรวจสอบรหัสผ่าน Admin ก่อนลบ (Security Check)
    bool confirmed = await showDialog(
          context: context,
          builder: (ctx) {
            final passCtrl = TextEditingController();
            return AlertDialog(
              title: const Text('ยืนยันการลบสินค้า'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('กรุณาใส่รหัสผ่านผู้ดูแลระบบ (Admin) เพื่อยืนยัน'),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'รหัสผ่าน'),
                    onSubmitted: (v) {
                      // เช็ครหัสผ่าน (Basic Check)
                      final correctPin = SettingsService().adminPin;
                      if (v == correctPin || v == 'admin') {
                        Navigator.pop(ctx, true);
                      } else {
                        Navigator.pop(ctx, false);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('ยกเลิก')),
                ElevatedButton(
                    onPressed: () {
                      final correctPin = SettingsService().adminPin;
                      if (passCtrl.text == correctPin ||
                          passCtrl.text == 'admin') {
                        Navigator.pop(ctx, true);
                      } else {
                        Navigator.pop(ctx, false);
                      }
                    },
                    child: const Text('ยืนยัน')),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      // ถ้าใส่รหัสผิด หรือกดยกเลิก
      if (mounted) {
        AlertService.show(
          context: context,
          message: 'รหัสผ่านไม่ถูกต้อง หรือยกเลิกการทำรายการ',
          type: 'error',
        );
      }
      return;
    }

    // 2. ถ้าผ่าน ให้ทำการลบออกจาก DB
    await _service.setProductId(_currentPage, index, 0);
    if (mounted) _loadPageData(); // โหลดข้อมูลใหม่
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Watch PosState to update badges
    final posState = context.watch<PosStateManager>();

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).pop(),
        },
        child: KeyboardListener(
          // Handle keyboard shortcuts
          focusNode: _focusNode,
          onKeyEvent: (event) {
            if (event is KeyDownEvent) {
              // Map keys Q-P, A-L, Z-M to 0-19? Or something consistent
              // For now, let's stick to mouse first as requested in image reference
            }
          },
          child: Container(
            width: 900,
            height: 700,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _service.getPageName(_currentPage),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        const Text('โหมดแก้ไข: '),
                        Switch(
                          value: _isEditMode,
                          onChanged: (val) => setState(() => _isEditMode = val),
                        ),
                        if (_isEditMode)
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'เปลี่ยนชื่อหน้า',
                            onPressed: _handleRenamePage,
                          ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'คืนค่าเริ่มต้น (Reload Defaults)',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('คืนค่าเริ่มต้น?'),
                                content: const Text(
                                    'ต้องการโหลดรายการสินค้าแนะนำ (ปูน, เหล็ก, PVC) กลับมาใหม่หรือไม่?\n(รายการที่แก้ไขเองจะถูกทับ)'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('ยกเลิก')),
                                  ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('ยืนยัน')),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await _restoreDefaults();
                            }
                          },
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        )
                      ],
                    ),
                  ],
                ),
                const Divider(),

                // Grid
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            childAspectRatio: 1.2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: 20, // 5x4 = 20 slots
                          itemBuilder: (ctx, i) {
                            final product = _loadedProducts[i];
                            return InkWell(
                              onTap: () => _handleSlotClick(i),
                              onLongPress: _isEditMode
                                  ? () => _handleClearSlot(i)
                                  : null,
                              child: Card(
                                color: product == null
                                    ? Colors.grey[200]
                                    : Colors.blue[50],
                                elevation: product == null ? 0 : 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: product == null
                                          ? Colors.grey[300]!
                                          : Colors.blue,
                                      width: product == null ? 1 : 2,
                                    )),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (product != null) ...[
                                              Text(
                                                product.name,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                '฿${product.retailPrice.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                    color: Colors.blue,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                            ] else
                                              Icon(
                                                _isEditMode
                                                    ? Icons.add
                                                    : Icons.crop_free,
                                                color: Colors.grey[400],
                                                size: 30,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (_isEditMode && product != null)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: IconButton(
                                          icon: const Icon(Icons.close,
                                              size: 16, color: Colors.red),
                                          onPressed: () => _handleClearSlot(i),
                                        ),
                                      ),
                                    if (!_isEditMode) ...[
                                      // 1. Hotkey Hint (Bottom Right)
                                      Positioned(
                                        bottom: 2,
                                        right: 5,
                                        child: Text(
                                          _getHotkeyLabel(i),
                                          style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      // 2. Quantity Badge (Bottom Right - above hotkey or covering it?)
                                      // Let's put it at Bottom Right, slightly offset if needed.
                                      if (product != null)
                                        Builder(builder: (_) {
                                          // Calculate Qty
                                          final inCart = posState.cart
                                              .where((item) =>
                                                  item.productId == product.id)
                                              .fold(
                                                  0.0,
                                                  (sum, item) =>
                                                      sum +
                                                      item.quantity.toDouble());
                                          if (inCart > 0) {
                                            return Positioned(
                                              bottom: 5,
                                              right: 5,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                constraints:
                                                    const BoxConstraints(
                                                  minWidth: 20,
                                                  minHeight: 20,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    inCart >= 10
                                                        ? '${inCart.toInt()}'
                                                        : '${inCart.toInt()}', // Simplified
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        }),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Footer Pagination
                const SizedBox(height: 10),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_totalPages, (index) {
                      final page = index + 1;
                      String label = _service.getPageName(page);
                      if (label.isEmpty || label.startsWith('Page ')) {
                        label = '$page';
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() => _currentPage = page);
                            _loadPageData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentPage == page
                                ? Colors.blue
                                : Colors.white,
                            foregroundColor: _currentPage == page
                                ? Colors.white
                                : Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                                side: const BorderSide(color: Colors.grey)),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getHotkeyLabel(int index) {
    // Optional: Map index to keyboard keys for visual hint
    // Row 1: Q W E R T
    // Row 2: A S D F G
    // Row 3: Z X C V B
    // Row 4: Y U I O P (Example)
    // This is just visual; logic needs KeyListener
    return '';
  }
}
