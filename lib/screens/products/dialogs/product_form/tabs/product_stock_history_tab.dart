// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api, use_build_context_synchronously
part of '../product_form_dialog.dart';

extension ProductStockHistoryTabExtension on _ProductFormDialogState {
  Future<void> _loadStockInHistory() async {
    if (widget.product == null) return;
    setState(() => _loadingHistory = true);
    try {
      final repo = StockRepository();
      // ดึงจาก stockledger เฉพาะ PURCHASE_IN / STOCK_IN / ADJUST_ADD
      final raw = await repo.getStockMovements(widget.product!.id);
      final filtered = raw
          .where((r) => ['PURCHASE_IN', 'STOCK_IN', 'ADJUST_ADD', 'RETURN_IN', 'ADJUST_CORRECT', 'ADJUST_SUB', 'ADJUST_FIX']
              .contains(r['transactionType']?.toString()))
          .toList();
      if (mounted) setState(() => _stockInHistory = filtered);
    } catch (e) {
      if (mounted) setState(() => _stockInHistory = []);
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Widget _buildStockInHistoryTab() {
    if (_loadingHistory && _stockInHistory == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = _stockInHistory ?? [];
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.teal.shade50,
          child: Row(
            children: [
              Icon(Icons.move_to_inbox, color: Colors.teal.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'ประวัติรับเข้า / ปรับสต็อก (${items.length} รายการ)',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.teal.shade800),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'รีเฟรช',
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: () {
                  setState(() => _stockInHistory = null);
                  _loadStockInHistory();
                },
              ),
            ],
          ),
        ),
        // Column Headers
        Container(
          color: Colors.grey.shade200,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: const Row(
            children: [
              SizedBox(width: 130, child: Text('วันที่/เวลา', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              SizedBox(width: 90, child: Text('ประเภท', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              SizedBox(width: 70, child: Text('จำนวน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
              SizedBox(width: 8),
              Expanded(child: Text('หมายเหตุ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        ),
        // List
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('ยังไม่มีประวัติรับสินค้าเข้า',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Colors.black12),
                  itemBuilder: (_, i) {
                    final r = items[i];
                    final qty =
                        double.tryParse(r['quantityChange'].toString()) ?? 0;
                    final type = r['transactionType']?.toString() ?? '';
                    final note = r['note']?.toString() ?? '-';
                    final createdAt = r['createdAt']?.toString() ?? '';
                    String dateStr = createdAt;
                    try {
                      final dt = DateTime.parse(createdAt);
                      dateStr = DateFormat('dd/MM/yy HH:mm').format(dt);
                    } catch (_) {}

                    final isPositive = qty >= 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 130,
                            child: Text(dateStr,
                                style: const TextStyle(fontSize: 12)),
                          ),
                          SizedBox(
                            width: 90,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.teal.shade900),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: Text(
                              '${isPositive ? '+' : ''}${qty.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isPositive
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  fontSize: 13),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(note,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
