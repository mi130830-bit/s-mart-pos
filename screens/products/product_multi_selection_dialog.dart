import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../repositories/product_repository.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/custom_text_field.dart';

class ProductMultiSelectionDialog extends StatefulWidget {
  final List<int> initialSelectedIds;
  final ProductRepository? repo;

  const ProductMultiSelectionDialog({
    super.key,
    required this.initialSelectedIds,
    this.repo,
  });

  @override
  State<ProductMultiSelectionDialog> createState() =>
      _ProductMultiSelectionDialogState();
}

class _ProductMultiSelectionDialogState
    extends State<ProductMultiSelectionDialog> {
  // Data
  final List<Product> _products = [];
  final Map<int, Product> _selectedMap = {}; // ID -> Product needed for return

  // Pagination & Search
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const int _pageSize = 50;
  String _searchQuery = '';
  Timer? _debounce;
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  late ProductRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = widget.repo ?? ProductRepository();

    // Setup Scroll Listener
    _scrollCtrl.addListener(_onScroll);

    // Initial Load
    _loadInitialSelected(); // Load full objects for initial IDs
    _loadProducts(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadProducts();
    }
  }

  Future<void> _loadInitialSelected() async {
    if (widget.initialSelectedIds.isEmpty) return;

    // Fetch full objects for initial IDs because we don't have them
    // We can use a loop of getProductById or a generic getProductsByIds if available.
    // Since getProductsByIds is not in repo, we'll loop for now or add it.
    // Loop is okay for small selections. For large, we should add WHERE IN (...) query.
    // Assuming selection is usually < 100 items.

    // Better approach: just rely on what we have. If the user doesn't scroll to them,
    // we might need to fetch them ONLY if they hit Save.
    // BUT we need to show them as "Checked" if they appear in the list.
    // So we just need the IDs for the UI check.
    // But for the RETURN value, we need Product objects.

    // Strategy:
    // 1. Keep IDs in a Set for UI toggle checks.
    // 2. Keep Map<int, Product> for the final return.
    // 3. When loading list, if a product is in the Set but not in Map, add it to Map.
    // 4. For initial IDs that might NOT be in the loaded list, we fetch them specifically.

    for (var id in widget.initialSelectedIds) {
      final p = await _repo.getProductById(id);
      if (p != null && mounted) {
        setState(() {
          _selectedMap[id] = p;
        });
      }
    }
  }

  Future<void> _loadProducts({bool reset = false}) async {
    if (_isLoading) return;
    if (reset) {
      _currentPage = 1;
      _products.clear();
      _hasMore = true;
    }

    setState(() => _isLoading = true);

    try {
      final newProducts = await _repo.getProductsPaginatedLight(
        _currentPage,
        _pageSize,
        searchTerm: _searchQuery,
      );

      if (mounted) {
        setState(() {
          if (newProducts.isEmpty) {
            _hasMore = false;
          } else {
            _products.addAll(newProducts);
            _currentPage++;
            if (newProducts.length < _pageSize) {
              _hasMore = false;
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = value.trim();
        });
        _loadProducts(reset: true);
      }
    });
  }

  void _toggleSelection(Product p) {
    setState(() {
      if (_selectedMap.containsKey(p.id)) {
        _selectedMap.remove(p.id);
      } else {
        _selectedMap[p.id] = p;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Text(
                    'เลือกสินค้าที่ยกเว้น (Exclude Products)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: CustomTextField(
                controller: _searchCtrl,
                hint: 'ค้นหา (ชื่อ, Barcode)',
                prefixIcon: Icons.search,
                onChanged: _onSearchChanged,
              ),
            ),

            // List
            Expanded(
              child: _products.isEmpty && !_isLoading
                  ? const Center(child: Text('ไม่พบสินค้า'))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      itemCount: _products.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _products.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final p = _products[index];
                        final isSelected = _selectedMap.containsKey(p.id);

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(p),
                          title: Text(p.name),
                          subtitle: Text(
                              '${p.barcode ?? '-'} | ${p.retailPrice} ฿ | Stock: ${p.stockQuantity}'),
                          secondary: isSelected
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : null,
                        );
                      },
                    ),
            ),

            const Divider(height: 1),

            // Footer / Actions
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('เลือกแล้ว ${_selectedMap.length} รายการ'),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('ยกเลิก'),
                      ),
                      const SizedBox(width: 10),
                      CustomButton(
                        label: 'บันทึก',
                        icon: Icons.save,
                        type: ButtonType.primary,
                        onPressed: () {
                          Navigator.pop(context, _selectedMap.values.toList());
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
