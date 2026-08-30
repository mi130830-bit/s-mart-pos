import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../repositories/dead_stock_repository.dart';
import '../../repositories/product_repository.dart';
import '../../services/dead_stock_excel_service.dart';
import '../../services/alert_service.dart';
import 'dialogs/product_form/product_form_dialog.dart';

class DeadStockScreen extends StatefulWidget {
  const DeadStockScreen({super.key});

  @override
  State<DeadStockScreen> createState() => _DeadStockScreenState();
}

class _DeadStockScreenState extends State<DeadStockScreen> {
  final DeadStockRepository _repo = DeadStockRepository();
  final ProductRepository _productRepo = ProductRepository();
  final DeadStockExcelService _excelService = DeadStockExcelService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  // Filter State
  DeadStockFilter _filter = const DeadStockFilter(
    daysInactive: null, // Default: never moved
    stockFilter: 'has_stock', // Default: only items with stuck stock
  );

  // Data State
  bool _isLoading = true;
  bool _isExporting = false;
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _categories = [];
  DeadStockSummary _summary = const DeadStockSummary(
    totalItems: 0,
    totalQuantity: 0.0,
    totalCapital: 0.0,
  );

  // Pagination
  int _currentPage = 1;
  int _rowsPerPage = 25;

  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  final NumberFormat _numberFormat = NumberFormat('#,##0.##', 'en_US');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadInitialData();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final categories = await _repo.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
        });
      }
      await _fetchProducts();
    } catch (e) {
      debugPrint('❌ [DeadStockScreen] Error loading initial data: $e');
      if (mounted) {
        AlertService.show(
          context: context,
          message: 'เกิดข้อผิดพลาดในการโหลดข้อมูล: $e',
          type: 'error',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchProducts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final records = await _repo.getDeadStockProducts(_filter);
      final summary = _repo.computeSummary(records);
      if (mounted) {
        setState(() {
          _records = records;
          _summary = summary;
          _currentPage = 1; // Reset to page 1 on filter change
        });
      }
    } catch (e) {
      debugPrint('❌ [DeadStockScreen] Error fetching products: $e');
      if (mounted) {
        AlertService.show(
          context: context,
          message: 'ไม่สามารถดึงข้อมูลสินค้าไม่เคลื่อนไหว: $e',
          type: 'error',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _filter = _filter.copyWith(searchQuery: value);
      });
      _fetchProducts();
    });
  }

  Future<void> _exportToExcel() async {
    if (_records.isEmpty) {
      AlertService.show(
        context: context,
        message: 'ไม่มีข้อมูลสินค้าสำหรับส่งออก',
        type: 'warning',
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      String? categoryName;
      if (_filter.categoryId != null) {
        final cat = _categories.firstWhere(
          (c) => int.tryParse(c['id']?.toString() ?? '') == _filter.categoryId,
          orElse: () => {'name': ''},
        );
        categoryName = cat['name']?.toString();
      }

      final path = await _excelService.exportDeadStockReport(
        records: _records,
        filter: _filter,
        categoryName: categoryName,
      );

      if (mounted && path != null) {
        AlertService.show(
          context: context,
          message: 'ส่งออกรายงาน Excel สำเร็จ (${_records.length} รายการ)',
          type: 'success',
        );
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(
          context: context,
          message: 'เกิดข้อผิดพลาดในการส่งออก Excel: $e',
          type: 'error',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _editProduct(Map<String, dynamic> item) async {
    final int? productId = int.tryParse(item['id']?.toString() ?? '');
    if (productId == null) return;

    final product = await _productRepo.getProductById(productId);

    if (mounted) {
      final updatedProduct = await showDialog<Product>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ProductFormDialog(
          repo: _productRepo,
          product: product,
        ),
      );

      if (updatedProduct != null) {
        _fetchProducts();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FA),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildKpiCards(),
          const SizedBox(height: 16),
          _buildFilterBar(),
          const SizedBox(height: 16),
          Expanded(
            child: _buildTableCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCards() {
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            title: 'สินค้าไม่มีการเคลื่อนไหว',
            value: '${_numberFormat.format(_summary.totalItems)} รายการ',
            subtitle: _getFilterSubtitle(),
            icon: Icons.inventory_2_outlined,
            gradientColors: [const Color(0xFF455A64), const Color(0xFF263238)],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildKpiCard(
            title: 'สต็อกคงค้างรวม',
            value: '${_numberFormat.format(_summary.totalQuantity)} ชิ้น/หน่วย',
            subtitle: 'จำนวนสินค้าที่นอนนิ่งอยู่ในคลัง',
            icon: Icons.hourglass_bottom_rounded,
            gradientColors: [const Color(0xFFFF8F00), const Color(0xFFE65100)],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildKpiCard(
            title: 'มูลค่าเงินทุนที่จมอยู่ (Dead Stock)',
            value: '${_currencyFormat.format(_summary.totalCapital)} ฿',
            subtitle: 'ประเมินจากราคาทุนของสต็อกคงเหลือ',
            icon: Icons.monetization_on_outlined,
            gradientColors: [const Color(0xFFE53935), const Color(0xFFB71C1C)],
          ),
        ),
      ],
    );
  }

  String _getFilterSubtitle() {
    if (_filter.daysInactive == null) {
      return 'ไม่เคยมีการขายหรือปรับสต็อกเลย';
    }
    return 'ไม่มีการเคลื่อนไหวเกิน ${_filter.daysInactive} วัน';
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    // Sanitize category items to guarantee uniqueness and non-null values
    final List<DropdownMenuItem<int?>> categoryDropdownItems = [
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('📂 ทุกหมวดหมู่'),
      ),
    ];

    final Set<int> addedCatIds = {};
    for (var c in _categories) {
      final idRaw = c['id'];
      if (idRaw != null) {
        final id = int.tryParse(idRaw.toString());
        if (id != null && !addedCatIds.contains(id)) {
          addedCatIds.add(id);
          final name = c['name']?.toString() ?? 'หมวด #$id';
          categoryDropdownItems.add(
            DropdownMenuItem<int?>(
              value: id,
              child: Text(name),
            ),
          );
        }
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 1. Inactivity Period (Fixed width)
            _buildDropdown<int?>(
              label: 'ระยะเวลาไม่เคลื่อนไหว',
              value: _filter.daysInactive,
              width: 190,
              items: const [
                DropdownMenuItem<int?>(value: null, child: Text('⚡ ไม่เคยเคลื่อนไหวเลย')),
                DropdownMenuItem<int?>(value: 30, child: Text('⏳ 30 วันขึ้นไป')),
                DropdownMenuItem<int?>(value: 60, child: Text('⏳ 60 วันขึ้นไป')),
                DropdownMenuItem<int?>(value: 90, child: Text('⏳ 90 วันขึ้นไป (3 เดือน)')),
                DropdownMenuItem<int?>(value: 180, child: Text('⏳ 180 วันขึ้นไป (6 เดือน)')),
                DropdownMenuItem<int?>(value: 365, child: Text('⏳ 365 วันขึ้นไป (1 ปี)')),
              ],
              onChanged: (val) {
                setState(() {
                  _filter = _filter.copyWith(
                    daysInactive: val,
                    clearDaysInactive: val == null,
                  );
                });
                _fetchProducts();
              },
            ),
            const SizedBox(width: 12),

            // 2. Category (Fixed width)
            _buildDropdown<int?>(
              label: 'หมวดหมู่สินค้า',
              value: _filter.categoryId,
              width: 180,
              items: categoryDropdownItems,
              onChanged: (val) {
                setState(() {
                  _filter = _filter.copyWith(
                    categoryId: val,
                    clearCategory: val == null,
                  );
                });
                _fetchProducts();
              },
            ),
            const SizedBox(width: 12),

            // 3. Stock Status (Fixed width)
            _buildDropdown<String>(
              label: 'สถานะสต็อก',
              value: _filter.stockFilter,
              width: 180,
              items: const [
                DropdownMenuItem<String>(value: 'has_stock', child: Text('📦 มีสต็อกคงค้าง (> 0)')),
                DropdownMenuItem<String>(value: 'zero_stock', child: Text('0️⃣ สต็อกเป็น 0')),
                DropdownMenuItem<String>(value: 'all', child: Text('🌐 สต็อกทั้งหมด')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _filter = _filter.copyWith(stockFilter: val);
                  });
                  _fetchProducts();
                }
              },
            ),
            const SizedBox(width: 12),

            // 4. Live Search (Fills remaining space)
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'ค้นหาชื่อสินค้า หรือ บาร์โค้ด...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // 5. Export Excel Button
            ElevatedButton.icon(
              icon: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.file_download_outlined, size: 20),
              label: Text(_isExporting ? 'กำลังสร้างไฟล์...' : 'Export Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isExporting ? null : _exportToExcel,
            ),
            const SizedBox(width: 8),

            // 6. Refresh Button
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'รีเฟรชข้อมูล',
              onPressed: _isLoading ? null : _fetchProducts,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    double width = 180,
  }) {
    // Fallback if current value is not in items
    final bool hasMatchingValue = items.any((item) => item.value == value);
    final T effectiveValue = hasMatchingValue ? value : (items.isNotEmpty ? items.first.value as T : value);

    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: effectiveValue,
            items: items,
            onChanged: onChanged,
            isDense: true,
            isExpanded: true,
          ),
        ),
      ),
    );
  }

  Widget _buildTableCard() {
    if (_isLoading) {
      return const Card(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('กำลังสแกนและวิเคราะห์สินค้าไม่เคลื่อนไหว...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_records.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade400),
              const SizedBox(height: 16),
              const Text('ไม่พบรายการสินค้าที่ตรงกับเงื่อนไขการค้นหา',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 6),
              const Text('ลองปรับตัวกรองระยะเวลา หรือค้นหาด้วยคำอื่นดูครับ',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // Pagination slice
    final int startIndex = (_currentPage - 1) * _rowsPerPage;
    final int endIndex = (startIndex + _rowsPerPage > _records.length)
        ? _records.length
        : startIndex + _rowsPerPage;
    final List<Map<String, dynamic>> pageRecords = _records.sublist(startIndex, endIndex);
    final int totalPages = (_records.length / _rowsPerPage).ceil();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Table Header & Rows
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFECEFF1)),
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF263238)),
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 48,
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('ลำดับ')),
                    DataColumn(label: Text('บาร์โค้ด')),
                    DataColumn(label: Text('ชื่อสินค้า')),
                    DataColumn(label: Text('หมวดหมู่')),
                    DataColumn(label: Text('สต็อกคงเหลือ')),
                    DataColumn(label: Text('ราคาทุน')),
                    DataColumn(label: Text('ราคาขาย')),
                    DataColumn(label: Text('มูลค่าทุนรวม')),
                    DataColumn(label: Text('เคลื่อนไหวล่าสุด')),
                    DataColumn(label: Text('จัดการ')),
                  ],
                  rows: List.generate(pageRecords.length, (index) {
                    final r = pageRecords[index];
                    final globalIndex = startIndex + index + 1;
                    final qty = double.tryParse(r['stockQuantity']?.toString() ?? '0') ?? 0.0;
                    final cost = double.tryParse(r['costPrice']?.toString() ?? '0') ?? 0.0;
                    final price = double.tryParse(r['retailPrice']?.toString() ?? '0') ?? 0.0;
                    final capital = double.tryParse(r['totalCapital']?.toString() ?? '0') ?? 0.0;

                    final lastStock = r['lastStockAdjustmentDate']?.toString();
                    final lastSale = r['lastSaleDate']?.toString();
                    String lastMovementStr = '-';
                    Color movementColor = Colors.grey;

                    if (lastSale != null && lastSale.isNotEmpty) {
                      try {
                        final dt = DateTime.parse(lastSale);
                        lastMovementStr = 'ขาย: ${DateFormat('dd/MM/yy').format(dt)}';
                        movementColor = Colors.blue.shade700;
                      } catch (_) {
                        lastMovementStr = lastSale;
                      }
                    } else if (lastStock != null && lastStock.isNotEmpty) {
                      try {
                        final dt = DateTime.parse(lastStock);
                        lastMovementStr = 'นับ: ${DateFormat('dd/MM/yy').format(dt)}';
                        movementColor = Colors.teal.shade700;
                      } catch (_) {
                        lastMovementStr = lastStock;
                      }
                    } else {
                      lastMovementStr = 'ไม่เคยเคลื่อนไหว';
                      movementColor = Colors.red.shade700;
                    }

                    return DataRow(
                      color: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
                        if (index.isEven) return Colors.white;
                        return const Color(0xFFF9FAFB);
                      }),
                      cells: [
                        DataCell(Text('$globalIndex', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                        DataCell(
                          Text(
                            r['barcode']?.toString() ?? '',
                            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w500),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 260,
                            child: Text(
                              r['name']?.toString() ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blueGrey.shade200),
                            ),
                            child: Text(
                              r['categoryName']?.toString() ?? 'ทั่วไป',
                              style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade800),
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _numberFormat.format(qty),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: qty > 0 ? Colors.amber.shade900 : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                r['unitName']?.toString() ?? '',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        DataCell(Text('${_currencyFormat.format(cost)} ฿', style: const TextStyle(fontSize: 12))),
                        DataCell(Text('${_currencyFormat.format(price)} ฿', style: const TextStyle(fontSize: 12))),
                        DataCell(
                          Text(
                            '${_currencyFormat.format(capital)} ฿',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: capital > 0 ? Colors.red.shade700 : Colors.grey,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            lastMovementStr,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: movementColor),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                            tooltip: 'แก้ไขสินค้า',
                            onPressed: () => _editProduct(r),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),

          // Pagination Controls (Bottom Bar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'แสดง ${startIndex + 1} - $endIndex จากทั้งหมด ${_numberFormat.format(_records.length)} รายการ (หน้า $_currentPage จาก $totalPages)',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                Row(
                  children: [
                    const Text('แสดงหน้าละ: ', style: TextStyle(fontSize: 13)),
                    DropdownButton<int>(
                      value: _rowsPerPage,
                      isDense: true,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem<int>(value: 25, child: Text('25')),
                        DropdownMenuItem<int>(value: 50, child: Text('50')),
                        DropdownMenuItem<int>(value: 100, child: Text('100')),
                        DropdownMenuItem<int>(value: 200, child: Text('200')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _rowsPerPage = val;
                            _currentPage = 1;
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.first_page),
                      onPressed: _currentPage > 1
                          ? () => setState(() => _currentPage = 1)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _currentPage > 1
                          ? () => setState(() => _currentPage--)
                          : null,
                    ),
                    Text('$_currentPage / $totalPages', style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _currentPage < totalPages
                          ? () => setState(() => _currentPage++)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page),
                      onPressed: _currentPage < totalPages
                          ? () => setState(() => _currentPage = totalPages)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
