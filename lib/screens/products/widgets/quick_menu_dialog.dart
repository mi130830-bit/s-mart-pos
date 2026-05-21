import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/product.dart';
import '../../../repositories/product_repository.dart';
import '../../../services/quick_menu_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'product_search_dialog_for_select.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../pos/pos_state_manager.dart';

import '../../../services/alert_service.dart';
import '../../../widgets/dialogs/admin_pin_dialog.dart';
import 'quick_menu/quick_menu_grid_item.dart';
import 'quick_menu/quick_menu_header.dart';
import 'quick_menu/quick_menu_pagination.dart';
import 'quick_menu/default_quick_menu_provider.dart';
import 'quick_menu/quick_menu_keyboard_mapper.dart';

class QuickMenuDialog extends ConsumerStatefulWidget {
  final ProductRepository productRepo;
  final Function(Product)? onProductSelected;

  const QuickMenuDialog({
    super.key,
    required this.productRepo,
    this.onProductSelected,
  });

  @override
  ConsumerState<QuickMenuDialog> createState() => _QuickMenuDialogState();
}

class _QuickMenuDialogState extends ConsumerState<QuickMenuDialog> {
  final QuickMenuService _service = QuickMenuService();
  int _currentPage = 1;
  final int _totalPages = 10;
  bool _isEditMode = false;
  final Map<int, Product?> _loadedProducts = {}; // slotIndex -> Product
  bool _isLoading = true;
  final FocusNode _focusNode = FocusNode();

  // ✅ Auto-Refresh: อัปเดตราคาเมื่อมีการเปลี่ยนแปลงจากเครื่องอื่นใน LAN
  Timer? _priceRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadPageData();
    _focusNode.requestFocus();
    // ✅ Auto-Refresh ราคาทุก 30 วินาที (กรณีเครื่องแม่หรือเครื่องลูกเปลี่ยนราคา)
    _priceRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_isEditMode) {
        _refreshPricesOnly();
      }
    });
  }

  @override
  void dispose() {
    _priceRefreshTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  /// Refresh เฉพาะราคาของสินค้าที่โหลดอยู่ (ไม่โหลด config ใหม่)
  /// ใช้เมื่อต้องการอัปเดตราคาจาก MySQL โดยไม่รบกวน UX
  Future<void> _refreshPricesOnly() async {
    final existingIds = _loadedProducts.values
        .where((p) => p != null)
        .map((p) => p!.id)
        .toList();
    if (existingIds.isEmpty) return;

    try {
      // forceRefresh: true เพื่อข้าม Isar Cache และดึงจาก MySQL โดยตรง
      final fresh = await widget.productRepo.getProductsByIds(existingIds);
      if (!mounted) return;

      final freshMap = {for (var p in fresh) p.id: p};
      bool hasChange = false;

      for (var entry in _loadedProducts.entries) {
        final oldProduct = entry.value;
        if (oldProduct == null) continue;
        final newProduct = freshMap[oldProduct.id];
        if (newProduct != null &&
            newProduct.retailPrice != oldProduct.retailPrice) {
          _loadedProducts[entry.key] = newProduct;
          hasChange = true;
          debugPrint(
              '🔄 [QuickMenu] Price updated: ${oldProduct.name} '
              '${oldProduct.retailPrice} → ${newProduct.retailPrice}');
        }
      }

      if (hasChange && mounted) setState(() {});
    } catch (e) {
      debugPrint('⚠️ [QuickMenu] Price refresh failed: $e');
    }
  }

  Future<void> _loadPageData() async {
    if (mounted) setState(() => _isLoading = true);
    await _service.loadConfig(); // Load fresh config from MySQL
    if (!mounted) return;

    _loadedProducts.clear();

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
      // ✅ MySQL-First: getProductsByIds ดึงจาก MySQL ก่อนเสมอ (ราคาล่าสุด)
      final products = await widget.productRepo.getProductsByIds(neededIds);
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
      for (final page in pagesToPopulate) {
        final codes = DefaultQuickMenuProvider.defaultBarcodes[page];
        if (codes != null) {
          neededBarcodes.addAll(codes.where((c) => c.isNotEmpty));
        }
      }

      // Fetch ONLY needed products
      final foundProducts = await widget.productRepo
          .getProductsByBarcodes(neededBarcodes.toList());
      final Map<String, int> barcodeMap = {};
      for (var p in foundProducts) {
        if (p.barcode != null) barcodeMap[p.barcode!] = p.id;
      }

      int populatedCount = 0;

      for (final page in pagesToPopulate) {
        final codes = DefaultQuickMenuProvider.defaultBarcodes[page];
        final pageName = DefaultQuickMenuProvider.pageNames[page];
        if (codes != null) {
          for (int i = 0; i < codes.length; i++) {
            final code = codes[i];
            if (code.isNotEmpty && barcodeMap.containsKey(code)) {
              await _service.setProductId(page, i, barcodeMap[code]!);
            }
          }
          if (pageName != null) {
            await _service.setPageName(page, pageName);
          }
          populatedCount++;
        }
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
    bool confirmed = await AdminPinDialog.show(
      context,
      title: 'ยืนยันการลบสินค้า',
      message: 'กรุณาใส่รหัสผ่านผู้ดูแลระบบ (Admin) เพื่อยืนยันการลบ',
    );

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
    ref.watch(posProvider);
    final posState = ref.read(posProvider.notifier);

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
            if (event is KeyDownEvent && !_isEditMode) {
              final slot = QuickMenuKeyboardMapper.getSlotIndex(event.logicalKey);
              if (slot != null) {
                _handleSlotClick(slot);
              }
            }
          },
          child: Container(
            width: 900,
            height: 700,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                QuickMenuHeader(
                  pageName: _service.getPageName(_currentPage),
                  isEditMode: _isEditMode,
                  onEditModeChanged: (val) => setState(() => _isEditMode = val),
                  onRenamePage: _isEditMode ? _handleRenamePage : null,
                  onRestoreDefaults: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('คืนค่าเริ่มต้น?'),
                        content: const Text(
                            'ต้องการโหลดรายการสินค้าแนะนำ (ปูน, เหล็ก, PVC) กลับมาใหม่หรือไม่?\n(รายการที่แก้ไขเองจะถูกทับ)'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
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
                  onClose: () => Navigator.of(context).pop(),
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
                            double quantityInCart = 0.0;
                            if (product != null) {
                              quantityInCart = posState.cart
                                  .where((item) => item.productId == product.id)
                                  .fold(
                                      0.0,
                                      (sum, item) =>
                                          sum + item.quantity.toDouble());
                            }
                            return QuickMenuGridItem(
                              product: product,
                              isEditMode: _isEditMode,
                              hotkey: _getHotkeyLabel(i),
                              quantityInCart: quantityInCart,
                              onTap: () => _handleSlotClick(i),
                              onDelete: () => _handleClearSlot(i),
                            );
                          },
                        ),
                ),

                // Footer Pagination
                const SizedBox(height: 10),
                const SizedBox(height: 10),
                QuickMenuPagination(
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  getPageName: _service.getPageName,
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                    _loadPageData();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getHotkeyLabel(int index) {
    return QuickMenuKeyboardMapper.getLabel(index);
  }
}
