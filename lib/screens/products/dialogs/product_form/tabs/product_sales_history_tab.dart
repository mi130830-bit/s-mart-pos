// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api, use_build_context_synchronously
part of '../product_form_dialog.dart';

extension ProductSalesHistoryTabExtension on _ProductFormDialogState {
  Future<void> _loadSalesHistory() async {
    if (widget.product == null) return;
    setState(() => _loadingHistory = true);
    try {
      final repo = SalesRepository();
      final rows = await repo.findOrdersByProduct(widget.product!.id);
      if (mounted) setState(() => _salesHistory = rows);
    } catch (e) {
      if (mounted) setState(() => _salesHistory = []);
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Widget _buildSalesHistoryTab() {
    if (_loadingHistory && _salesHistory == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = _salesHistory ?? [];
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.orange.shade50,
          child: Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'ประวัติการขาย (${items.length} บิลล่าสุด)',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'รีเฟรช',
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: () {
                  setState(() => _salesHistory = null);
                  _loadSalesHistory();
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
              SizedBox(width: 60,  child: Text('บิล #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              SizedBox(width: 120, child: Text('วันที่', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              SizedBox(width: 60,  child: Text('จำนวน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
              SizedBox(width: 80,  child: Text('ราคา/หน่วย', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
              Expanded(child: Text('ลูกค้า', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
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
                      Icon(Icons.receipt_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('ยังไม่มีประวัติการขาย',
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
                    final orderId = r['orderId']?.toString() ?? '-';
                    final qty =
                        double.tryParse(r['quantity'].toString()) ?? 0;
                    final price =
                        double.tryParse(r['price'].toString()) ?? 0;
                    final firstName = r['firstName']?.toString() ?? '';
                    final lastName = r['lastName']?.toString() ?? '';
                    final customerName = (firstName.isEmpty && lastName.isEmpty)
                        ? 'ลูกค้าทั่วไป'
                        : '$firstName $lastName'.trim();
                    final createdAt = r['createdAt']?.toString() ?? '';
                    String dateStr = createdAt;
                    try {
                      final dt = DateTime.parse(createdAt);
                      dateStr = DateFormat('dd/MM/yy HH:mm').format(dt);
                    } catch (_) {}

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(
                              '#$orderId',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text(dateStr,
                                style: const TextStyle(fontSize: 12)),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(
                              qty.toStringAsFixed(0),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              '฿${price.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              customerName,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
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
