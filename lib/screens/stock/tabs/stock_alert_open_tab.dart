import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../state/shortage_provider.dart';
import '../../../models/shortage_log_model.dart';
import '../../../services/alert_service.dart';
import '../widgets/stock_pagination_control.dart';
import '../dialogs/stock_alert_confirm_dialog.dart';
import '../utils/stock_date_utils.dart';

class StockAlertOpenTab extends StatefulWidget {
  const StockAlertOpenTab({super.key});

  @override
  State<StockAlertOpenTab> createState() => _StockAlertOpenTabState();
}

class _StockAlertOpenTabState extends State<StockAlertOpenTab> {
  final _searchCtrl = TextEditingController();
  int _currentPage = 1;
  final int _itemsPerPage = 20;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _markAsOrdered(int id) async {
    await Provider.of<ShortageProvider>(context, listen: false)
        .markAsOrdered(id);
    if (mounted) {
      AlertService.show(
        context: context,
        message: 'บันทึกเป็น "สั่งแล้ว" เรียบร้อย',
        type: 'success',
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _copyToClipboard(ShortageLogModel alert) async {
    final cleanName = alert.itemName.replaceAll(RegExp(r'\s*\(คงเหลือ:.*?\)'), '').trim();
    await Clipboard.setData(ClipboardData(text: cleanName));
    if (mounted) {
      AlertService.show(
        context: context,
        message: 'คัดลอก "$cleanName" แล้ว',
        type: 'success',
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ShortageProvider>(context);
    final q = _searchCtrl.text.trim().toLowerCase();
    final lowStockNames = provider.lowStockProducts.map((p) => p.name.toLowerCase()).toSet();

    final allAlerts = provider.openShortages
        .where((a) => q.isEmpty || a.itemName.toLowerCase().contains(q))
        .toList();
    final totalItems = allAlerts.length;
    final totalPages = totalItems == 0 ? 1 : (totalItems / _itemsPerPage).ceil();
    if (_currentPage > totalPages) _currentPage = totalPages;

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);
    final currentDisplayAlerts = allAlerts.sublist(startIndex, endIndex);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'ค้นหาในรายการรอจัดการ...',
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
          color: Colors.grey.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('รายการรอจัดการ ($totalItems รายการ)',
                  style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.bold)),
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
          child: currentDisplayAlerts.isEmpty
              ? Center(
                  child: Text(q.isNotEmpty ? 'ไม่พบ "$q"' : 'ไม่มีรายการค้าง',
                      style: TextStyle(color: Colors.grey.shade500)))
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: currentDisplayAlerts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final alert = currentDisplayAlerts[i];
                    final realIndex = startIndex + i + 1;
                    final cleanName = alert.itemName.replaceAll(RegExp(r'\s*\(คงเหลือ:.*?\)'), '').trim();
                    final isLowStock = lowStockNames.contains(cleanName.toLowerCase());
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.shade50,
                        foregroundColor: Colors.teal,
                        radius: 16,
                        child: Text('$realIndex',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      title: Row(
                        children: [
                          Flexible(child: Text(cleanName, style: const TextStyle(fontWeight: FontWeight.w500))),
                          if (isLowStock) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade300),
                              ),
                              child: Text('⚠️ ถึงจุดสั่งของ',
                                  style: TextStyle(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                            ),
                          ],
                          if (provider.stockQuantities.containsKey(alert.id) &&
                              provider.stockQuantities[alert.id] != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Text(
                                '📦 ${(provider.stockQuantities[alert.id]!['stockQty'] as double).toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('แจ้งโดย: ${alert.reportedBy ?? '-'} | เวลา: ${StockDateUtils.formatDate(alert.createdAt)}'),
                          if (provider.priceSuggestions[alert.id] != null && provider.priceSuggestions[alert.id]!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8, runSpacing: 4,
                              children: provider.priceSuggestions[alert.id]!.asMap().entries.map((entry) {
                                final index = entry.key + 1;
                                final sug = entry.value;
                                final cost = double.tryParse(sug['costPrice'].toString()) ?? 0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: index == 1 ? Colors.green.shade50 : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: index == 1 ? Colors.green.shade200 : Colors.orange.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(index == 1 ? Icons.emoji_events : Icons.local_shipping,
                                          size: 14, color: index == 1 ? Colors.green.shade700 : Colors.orange.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'แนะนำ $index: ${sug['supplierName']} (${cost.toStringAsFixed(2)} ฿)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: index == 1 ? Colors.green.shade800 : Colors.orange.shade900,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            onPressed: () => _markAsOrdered(alert.id),
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('สั่งซื้อ'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.teal, size: 20),
                            tooltip: 'คัดลอก',
                            onPressed: () => _copyToClipboard(alert),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'ลบรายการ',
                            onPressed: () => StockAlertConfirmDialog.showDeleteConfirm(context, alert.id, alert.itemName),
                          ),
                        ],
                      ),
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
