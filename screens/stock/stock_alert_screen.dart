import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/auth_provider.dart';
import '../../state/shortage_provider.dart';
import '../../models/shortage_log_model.dart';
import '../../services/alert_service.dart';

class StockAlertScreen extends StatefulWidget {
  const StockAlertScreen({super.key});

  @override
  State<StockAlertScreen> createState() => _StockAlertScreenState();
}

class _StockAlertScreenState extends State<StockAlertScreen>
    with SingleTickerProviderStateMixin {
  final _itemController = TextEditingController();
  final _openSearchCtrl = TextEditingController();
  final _lowStockSearchCtrl = TextEditingController();
  final _orderedSearchCtrl = TextEditingController();
  final List<String> _pendingItems = [];
  bool _isSubmitting = false;
  late TabController _tabController;

  // Pagination - open tab
  int _openPage = 1;
  // Pagination - low stock tab
  int _lowStockPage = 1;
  final int _itemsPerPage = 20;
  // Ordered tab: collapsed month keys + per-month page tracking
  final Set<String> _collapsedMonths = {};
  final Map<String, int> _orderedMonthPages = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<ShortageProvider>(context, listen: false).loadShortages();
      }
    });
  }

  @override
  void dispose() {
    _itemController.dispose();
    _openSearchCtrl.dispose();
    _lowStockSearchCtrl.dispose();
    _orderedSearchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _addItemToPending() {
    final text = _itemController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _pendingItems.add(text);
        _itemController.clear();
      });
    }
  }

  void _removeItemFromPending(int index) {
    setState(() {
      _pendingItems.removeAt(index);
    });
  }

  Future<void> _submitAll() async {
    if (_pendingItems.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final provider = Provider.of<ShortageProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.currentUser;

      final futures =
          _pendingItems.map((item) => provider.createShortage(item, user));
      await Future.wait(futures);

      if (mounted) {
        AlertService.show(
          context: context,
          message: 'แจ้งเตือน ${_pendingItems.length} รายการเรียบร้อย!',
          type: 'success',
        );
        setState(() {
          _pendingItems.clear();
          _openPage = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(
          context: context,
          message: 'Error: $e',
          type: 'error',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _confirmDeleteAlert(int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบรายการ "$name" ใช่ไหม?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await Provider.of<ShortageProvider>(context, listen: false)
                  .markAsDone(id);
            },
            child: const Text('ลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // กด "สั่งซื้อ" ทำทันทีเลย ไม่มี confirm dialog
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
    await Clipboard.setData(ClipboardData(text: alert.itemName));
    if (mounted) {
      AlertService.show(
        context: context,
        message: 'คัดลอก "${alert.itemName}" แล้ว',
        type: 'success',
        duration: const Duration(seconds: 2),
      );
    }
  }

  Widget _buildPaginationControls(
      int currentPage, int totalPages, VoidCallback onPrev, VoidCallback onNext) {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: currentPage > 1 ? onPrev : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('หน้า $currentPage / $totalPages',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            onPressed: currentPage < totalPages ? onNext : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryForm(ShortageProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Autocomplete<ProductSearchResult>(
            optionsBuilder: (textEditingValue) async {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<ProductSearchResult>.empty();
              }
              return await provider.searchProducts(textEditingValue.text);
            },
            displayStringForOption: (option) => option.toString(),
            onSelected: (selection) {
              _itemController.text = selection.toString();
              _addItemToPending();
            },
            fieldViewBuilder:
                (context, textController, focusNode, onFieldSubmitted) {
              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        hintText: 'ค้นหาสินค้า / พิมพ์ชื่อสินค้าที่หมด...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onSubmitted: (val) {
                        _itemController.text = val;
                        _addItemToPending();
                        textController.clear();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () {
                      _itemController.text = textController.text;
                      _addItemToPending();
                      textController.clear();
                    },
                    icon: const Icon(Icons.add),
                    style:
                        IconButton.styleFrom(backgroundColor: Colors.teal),
                  ),
                ],
              );
            },
          ),
          if (_pendingItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _pendingItems.asMap().entries.map((entry) {
                return InputChip(
                  label: Text(entry.value),
                  onDeleted: () => _removeItemFromPending(entry.key),
                  backgroundColor: Colors.teal.shade50,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitAll,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(_isSubmitting
                    ? 'กำลังบันทึก...'
                    : 'บันทึกแจ้งเตือน (${_pendingItems.length})'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOpenTab(ShortageProvider provider) {
    final q = _openSearchCtrl.text.trim().toLowerCase();
    final lowStockNames = provider.lowStockProducts.map((p) => p.name.toLowerCase()).toSet();

    final allAlerts = provider.openShortages
        .where((a) => q.isEmpty || a.itemName.toLowerCase().contains(q))
        .toList();
    final totalItems = allAlerts.length;
    final totalPages = totalItems == 0 ? 1 : (totalItems / _itemsPerPage).ceil();
    if (_openPage > totalPages) _openPage = totalPages;

    final startIndex = (_openPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);
    final currentDisplayAlerts = allAlerts.sublist(startIndex, endIndex);

    return Column(
      children: [
        // ── Search bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _openSearchCtrl,
            decoration: InputDecoration(
              hintText: 'ค้นหาในรายการรอจัดการ...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: q.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() { _openSearchCtrl.clear(); _openPage = 1; }),
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (_) => setState(() => _openPage = 1),
          ),
        ),
        // Header
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
        _buildPaginationControls(
          _openPage, totalPages,
          () => setState(() => _openPage--),
          () => setState(() => _openPage++),
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
                          Text('แจ้งโดย: ${alert.reportedBy ?? '-'} | เวลา: ${_formatDate(alert.createdAt)}'),
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
                            onPressed: () => _confirmDeleteAlert(alert.id, alert.itemName),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        _buildPaginationControls(
          _openPage, totalPages,
          () => setState(() => _openPage--),
          () => setState(() => _openPage++),
        ),
      ],
    );
  }

  /// จัดกลุ่มรายการสั่งแล้วตาม เดือน/ปี
  Map<String, List<ShortageLogModel>> _groupByMonth(
      List<ShortageLogModel> items) {
    final Map<String, List<ShortageLogModel>> grouped = {};
    for (final item in items) {
      final date = item.orderedAt ?? item.createdAt;
      final key =
          '${_thaiMonth(date.month)} ${date.year + 543}'; // พ.ศ.
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }

  Widget _buildOrderedTab(ShortageProvider provider) {
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
        // Header bar
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

              // ── Pagination per month ──
              final pageSize = _itemsPerPage;
              final currentPage = _orderedMonthPages[monthKey] ?? 1;
              final totalPages = (items.length / pageSize).ceil();
              final start = (currentPage - 1) * pageSize;
              final end = (start + pageSize).clamp(0, items.length);
              final pageItems = isCollapsed ? <ShortageLogModel>[] : items.sublist(start, end);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Month header (tappable) ──
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

                  // ── Items ──
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
                                'แจ้งโดย: ${alert.reportedBy ?? '-'} | แจ้ง: ${_formatDate(alert.createdAt)}'
                                '${alert.orderedAt != null ? ' | สั่ง: ${_formatDate(alert.orderedAt!)}' : ''}'),
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
                                  onPressed: () => _confirmDeleteAlert(alert.id, alert.itemName),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    }),

                    // ── Pagination row for this month ──
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

  static const _thaiMonths = [
    '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน',
    'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม',
    'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];

  String _thaiMonth(int month) => _thaiMonths[month];

  Widget _buildLowStockTab(ShortageProvider provider) {
    final q = _lowStockSearchCtrl.text.trim().toLowerCase();
    final allProducts = provider.lowStockProducts
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();
    final totalItems = allProducts.length;
    final totalPages = totalItems == 0 ? 1 : (totalItems / _itemsPerPage).ceil();
    if (_lowStockPage > totalPages) _lowStockPage = totalPages;

    final startIndex = (_lowStockPage - 1) * _itemsPerPage;
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
        // ── Search bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _lowStockSearchCtrl,
            decoration: InputDecoration(
              hintText: 'ค้นหาสินค้าถึงจุดสั่งของ...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: q.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() { _lowStockSearchCtrl.clear(); _lowStockPage = 1; }),
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (_) => setState(() => _lowStockPage = 1),
          ),
        ),
        // Header
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
        _buildPaginationControls(
          _lowStockPage,
          totalPages,
          () => setState(() => _lowStockPage--),
          () => setState(() => _lowStockPage++),
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
        _buildPaginationControls(
          _lowStockPage,
          totalPages,
          () => setState(() => _lowStockPage--),
          () => setState(() => _lowStockPage++),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShortageProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('แจ้งของหมด / แจ้งซ่อม'),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.pending_actions, size: 18),
                      const SizedBox(width: 6),
                      Text('รอจัดการ (${provider.openShortages.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('ของหมด (${provider.lowStockProducts.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 18),
                      const SizedBox(width: 6),
                      Text('สั่งแล้ว (${provider.orderedShortages.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              _buildEntryForm(provider),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOpenTab(provider),
                    _buildLowStockTab(provider),
                    _buildOrderedTab(provider),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
