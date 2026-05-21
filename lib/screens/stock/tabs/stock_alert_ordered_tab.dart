import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/shortage_provider.dart';
import '../../../models/shortage_log_model.dart';
import '../../../services/alert_service.dart';
import '../dialogs/stock_alert_confirm_dialog.dart';
import '../utils/stock_date_utils.dart';

class StockAlertOrderedTab extends ConsumerStatefulWidget {
  const StockAlertOrderedTab({super.key});

  @override
  ConsumerState<StockAlertOrderedTab> createState() => _StockAlertOrderedTabState();
}

class _StockAlertOrderedTabState extends ConsumerState<StockAlertOrderedTab> {
  final Set<String> _collapsedMonths = {};
  final Map<String, int> _orderedMonthPages = {};
  final int _itemsPerPage = 20;

  Map<String, List<ShortageLogModel>> _groupByMonth(List<ShortageLogModel> items) {
    final Map<String, List<ShortageLogModel>> grouped = {};
    for (final item in items) {
      final date = item.orderedAt ?? item.createdAt;
      final key = '${StockDateUtils.thaiMonth(date.month)} ${date.year + 543}';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
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
    final provider = ref.watch(shortageProvider);
    final allAlerts = provider.orderedShortages;
    final grouped = _groupByMonth(allAlerts);
    final monthKeys = grouped.keys.toList();
    final totalItems = allAlerts.length;

    if (allAlerts.isEmpty) {
      return Center(
        child: Text('ยังไม่มีรายการที่สั่งแล้ว',
            style: TextStyle(color: Colors.grey.shade500)),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.blue.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('สินค้าที่สั่งแล้ว ($totalItems รายการ)',
                  style: TextStyle(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.bold)),
              if (provider.isLoading)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: monthKeys.length,
            itemBuilder: (ctx, mi) {
              final monthKey = monthKeys[mi];
              final items = grouped[monthKey]!;
              final isCollapsed = _collapsedMonths.contains(monthKey);

              final pageSize = _itemsPerPage;
              final currentPage = _orderedMonthPages[monthKey] ?? 1;
              final totalPages = (items.length / pageSize).ceil();
              final start = (currentPage - 1) * pageSize;
              final end = (start + pageSize).clamp(0, items.length);
              final pageItems = isCollapsed ? <ShortageLogModel>[] : items.sublist(start, end);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => setState(() {
                      if (isCollapsed) {
                        _collapsedMonths.remove(monthKey);
                      } else {
                        _collapsedMonths.add(monthKey);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: Colors.indigo.shade50,
                      child: Row(
                        children: [
                          Icon(
                            isCollapsed ? Icons.chevron_right : Icons.expand_more,
                            size: 20,
                            color: Colors.indigo,
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.calendar_month, size: 16, color: Colors.indigo),
                          const SizedBox(width: 6),
                          Text(monthKey,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.indigo)),
                          const SizedBox(width: 8),
                          Text('(${items.length} รายการ)',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.indigo.shade300)),
                          const Spacer(),
                          if (!isCollapsed && totalPages > 1)
                            Text('หน้า $currentPage/$totalPages',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.indigo.shade400)),
                        ],
                      ),
                    ),
                  ),

                  if (!isCollapsed) ...[
                    ...pageItems.asMap().entries.map((entry) {
                      final ii = entry.key;
                      final alert = entry.value;
                      final globalIndex = start + ii + 1;
                      return Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue,
                              radius: 16,
                              child: Text('$globalIndex',
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            title: Text(alert.itemName,
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text(
                                'แจ้งโดย: ${alert.reportedBy ?? '-'} | แจ้ง: ${StockDateUtils.formatDate(alert.createdAt)}'
                                '${alert.orderedAt != null ? ' | สั่ง: ${StockDateUtils.formatDate(alert.orderedAt!)}' : ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, size: 14, color: Colors.blue),
                                      SizedBox(width: 4),
                                      Text('สั่งแล้ว',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
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
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    }),

                    if (totalPages > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        color: Colors.indigo.shade50.withValues(alpha: 0.4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 20),
                              onPressed: currentPage > 1
                                  ? () => setState(() => _orderedMonthPages[monthKey] =
                                      currentPage - 1)
                                  : null,
                            ),
                            Text('$currentPage / $totalPages',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, size: 20),
                              onPressed: currentPage < totalPages
                                  ? () => setState(() => _orderedMonthPages[monthKey] =
                                      currentPage + 1)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
