import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/stock_repository.dart';

// ✅ 1. Import Simplified Dialog
import 'product_selection_dialog.dart';
import '../../widgets/common/custom_buttons.dart';

class StockCardView extends StatefulWidget {
  const StockCardView({super.key});

  @override
  State<StockCardView> createState() => _StockCardViewState();
}

class _StockCardViewState extends State<StockCardView> {
  final StockRepository _stockRepo = StockRepository();
  final ProductRepository _productRepo = ProductRepository();

  Product? _selectedProduct;
  List<Map<String, dynamic>> _movements = [];
  bool _isLoading = false;
  bool _isRestockLoading = false;
  List<Map<String, dynamic>> _restockSuggestions = [];

  Future<void> _selectProduct() async {
    // Pass repo to the new unified dialog
    final Product? picked = await showDialog<Product>(
      context: context,
      builder: (context) => ProductSelectionDialog(repo: _productRepo),
    );

    if (picked != null) {
      if (mounted) {
        setState(() {
          _selectedProduct = picked;
          _loadMovements(picked.id);
          _loadRestockSuggestions(picked.id);
        });
      }
    }
  }

  Future<void> _loadMovements(int productId) async {
    setState(() => _isLoading = true);
    final data = await _stockRepo.getStockMovements(productId);

    // Calculate Running Balance
    double currentBalance = _selectedProduct?.stockQuantity ?? 0;
    List<Map<String, dynamic>> processed = [];

    for (var row in data) {
      final change = double.tryParse(row['quantityChange'].toString()) ?? 0;
      final rowBalance = currentBalance;

      final newRow = Map<String, dynamic>.from(row);
      newRow['balanceSnapshot'] = rowBalance;
      processed.add(newRow);

      currentBalance -= change;
    }

    if (mounted) {
      setState(() {
        _movements = processed;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRestockSuggestions(int productId) async {
    setState(() => _isRestockLoading = true);
    final data = await _stockRepo.getRestockSuggestions(productId);
    if (mounted) {
      setState(() {
        _restockSuggestions = data;
        _isRestockLoading = false;
      });
    }
  }

  Color _getTypeColor(String type) {
    if (type.contains('IN') || type.contains('ADD')) return Colors.green;
    if (type.contains('OUT') || type.contains('SUB')) return Colors.red;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // --- Header Section ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('สินค้าที่เลือก:',
                              style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            _selectedProduct?.name ?? 'กรุณาเลือกสินค้า',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          if (_selectedProduct != null)
                            Text(
                                'คงเหลือปัจจุบัน: ${_selectedProduct!.stockQuantity.toStringAsFixed(0)} ชิ้น',
                                style:
                                    TextStyle(color: Colors.indigo.shade700)),
                        ],
                      ),
                    ),
                    CustomButton(
                      onPressed: _selectProduct,
                      icon: Icons.search,
                      label: 'เลือกสินค้า',
                      type: ButtonType.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const TabBar(
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blue,
                  tabs: [
                    Tab(icon: Icon(Icons.history), text: 'ประวัติเคลื่อนไหว'),
                    Tab(
                        icon: Icon(Icons.shopping_cart_checkout),
                        text: 'ข้อมูลสั่งซื้อ (Restock)'),
                  ],
                )
              ],
            ),
          ),
          const Divider(height: 1),

          // --- Tab Views ---
          Expanded(
            child: TabBarView(
              children: [
                _buildMovementHistory(),
                _buildRestockInfo(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementHistory() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _movements.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 10),
                    Text(
                      _selectedProduct == null
                          ? 'เลือกสินค้าเพื่อดูความเคลื่อนไหว'
                          : 'ไม่พบประวัติการเคลื่อนไหว',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                itemCount: _movements.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final m = _movements[i];
                  final type = m['transactionType'] ?? '-';
                  final qty =
                      double.tryParse(m['quantityChange'].toString()) ?? 0;
                  final balance = m['balanceSnapshot'] as double?;

                  final dateStr = m['createdAt'].toString();
                  DateTime dt = DateTime.tryParse(dateStr) ?? DateTime.now();

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          _getTypeColor(type).withValues(alpha: 0.1),
                      child: Icon(
                        qty > 0 ? Icons.arrow_downward : Icons.arrow_upward,
                        color: _getTypeColor(type),
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(type,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        if (balance != null)
                          Text('(Bal: ${balance.toStringAsFixed(0)})',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(dt),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${qty > 0 ? "+" : ""}${qty.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: qty > 0 ? Colors.green : Colors.red,
                          ),
                        ),
                        if (m['note'] != null &&
                            m['note'].toString().isNotEmpty)
                          Tooltip(
                            message: m['note'],
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Icon(Icons.info_outline,
                                  size: 16, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
  }

  Widget _buildRestockInfo() {
    if (_isRestockLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selectedProduct == null) {
      return Center(
          child: Text("กรุณาเลือกสินค้าก่อน",
              style: TextStyle(color: Colors.grey)));
    }

    if (_restockSuggestions.isEmpty) {
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text('ไม่มีประวัติการสั่งซื้อ (PO)',
              style: TextStyle(color: Colors.grey)),
        ],
      ));
    }

    // Find Best Price
    double minPrice = double.infinity;
    for (var r in _restockSuggestions) {
      final p = double.tryParse(r['costPrice'].toString()) ?? double.infinity;
      if (p < minPrice) minPrice = p;
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _restockSuggestions.length,
      separatorBuilder: (ctx, i) => const Divider(),
      itemBuilder: (ctx, i) {
        final item = _restockSuggestions[i];
        final supplier = item['supplierName'] ?? 'ไม่ระบุร้านค้า';
        final price = double.tryParse(item['costPrice'].toString()) ?? 0.0;
        final dateStr = item['createdAt'].toString();
        final dt = DateTime.tryParse(dateStr) ?? DateTime.now();

        final isBestPrice = (price == minPrice && price > 0);

        return Card(
          elevation: isBestPrice ? 2 : 0,
          color: isBestPrice ? Colors.green.shade50 : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: isBestPrice
                  ? BorderSide(color: Colors.green.shade300)
                  : BorderSide.none),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  isBestPrice ? Colors.green : Colors.grey.shade300,
              child: Icon(Icons.store, color: Colors.white),
            ),
            title:
                Text(supplier, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle:
                Text('วันที่: ${DateFormat('dd/MM/yyyy HH:mm').format(dt)}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '฿${NumberFormat('#,##0.00').format(price)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isBestPrice ? Colors.green.shade800 : Colors.black,
                  ),
                ),
                if (isBestPrice)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('ราคาดีที่สุด',
                        style: TextStyle(color: Colors.white, fontSize: 10)),
                  )
              ],
            ),
          ),
        );
      },
    );
  }
}
