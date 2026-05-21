import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/shortage_provider.dart';
import '../widgets/stock_pagination_control.dart';

class StockAlertLowStockTab extends ConsumerStatefulWidget {
  const StockAlertLowStockTab({super.key});

  @override
  ConsumerState<StockAlertLowStockTab> createState() => _StockAlertLowStockTabState();
}

class _StockAlertLowStockTabState extends ConsumerState<StockAlertLowStockTab> {
  final _searchCtrl = TextEditingController();
  int _currentPage = 1;
  final int _itemsPerPage = 20;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(shortageProvider);
    final q = _searchCtrl.text.trim().toLowerCase();
    final allProducts = provider.lowStockProducts
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();
    final totalItems = allProducts.length;
    final totalPages = totalItems == 0 ? 1 : (totalItems / _itemsPerPage).ceil();
    if (_currentPage > totalPages) _currentPage = totalPages;

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);

    if (provider.lowStockProducts.isEmpty && !provider.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade300),
            const SizedBox(height: 8),
            const Text('ไม่มีสินค้าถึงจุดสั่งของ 🎉',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'ค้นหาสินค้าถึงจุดสั่งของ...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: q.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() { _searchCtrl.clear(); _currentPage = 1; }),
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (_) => setState(() => _currentPage = 1),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.red.shade50,
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'สินค้าถึงจุดสั่งของ ($totalItems รายการ)',
                  style: TextStyle(
                      color: Colors.red.shade800, fontWeight: FontWeight.bold),
                ),
              ),
              if (provider.isLoading)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
        StockPaginationControl(
          currentPage: _currentPage,
          totalPages: totalPages,
          onPrev: () => setState(() => _currentPage--),
          onNext: () => setState(() => _currentPage++),
        ),
        Expanded(
          child: allProducts.isEmpty
              ? Center(
                  child: Text(q.isNotEmpty ? 'ไม่พบ "$q"' : 'ไม่มีสินค้าถึงจุดสั่งของ',
                      style: TextStyle(color: Colors.grey.shade500)))
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: allProducts.sublist(startIndex, endIndex).length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final p = allProducts.sublist(startIndex, endIndex)[i];
                    final stock = p.stockQuantity;
                    final reorder = (p.reorderPoint ?? 0).toDouble();
                    final deficit = reorder - stock;
                    final pct = reorder > 0 ? (stock / reorder).clamp(0.0, 1.0) : 1.0;
                    final globalIndex = startIndex + i + 1;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        radius: 16,
                        child: Text('$globalIndex',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      title: Text(p.name,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'คงเหลือ: ${stock.toStringAsFixed(0)}  |  จุดสั่งซื้อ: ${reorder.toStringAsFixed(0)}  |  ขาด: ${deficit > 0 ? deficit.toStringAsFixed(0) : '0'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: pct,
                            backgroundColor: Colors.red.shade100,
                            color: pct < 0.5 ? Colors.red : Colors.orange,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
        StockPaginationControl(
          currentPage: _currentPage,
          totalPages: totalPages,
          onPrev: () => setState(() => _currentPage--),
          onNext: () => setState(() => _currentPage++),
        ),
      ],
    );
  }
}
