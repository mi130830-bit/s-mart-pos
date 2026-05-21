import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/auth_provider.dart';
import '../../../widgets/common/thai_aware_search_field.dart';
import '../../../widgets/dialogs/close_shift_dialog.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/dashboard_orders_table.dart';

/// แท็บ 1: "รายการวันนี้" — ตารางบิลพร้อมค้นหาและปุ่มจัดการ
class DashboardDailyTab extends ConsumerStatefulWidget {
  const DashboardDailyTab({super.key});

  @override
  ConsumerState<DashboardDailyTab> createState() => _DashboardDailyTabState();
}

class _DashboardDailyTabState extends ConsumerState<DashboardDailyTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);

    final orders = state.searchQuery.isNotEmpty 
        ? state.searchResults 
        : state.recentOrders;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, state, notifier),
          const SizedBox(height: 16),
          _buildSearchBar(context, state, notifier),
          const SizedBox(height: 16),
          DashboardOrdersTable(
            orders: orders,
            searchQuery: state.searchQuery,
            isSearchLoading: state.isSearchLoading,
            auth: auth,
            onViewDetails: (row) => notifier.viewDetails(context, row),
            onReprint: (row) => notifier.reprintOrder(context, row),
            onSendToDelivery: (id) => notifier.sendToDelivery(context, id),
            onSendToBackShop: (id) => notifier.sendToBackShop(context, id),
            onChangeCustomer: (id) => notifier.changeCustomer(context, id),
            onDelete: (row) => notifier.deleteOrder(context, row),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, DashboardState state, DashboardNotifier notifier) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('รายการขาย',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
                'วันที่: ${DateFormat('dd MMMM yyyy', 'th').format(state.selectedDate)}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => notifier.prevDate(),
              tooltip: 'วันก่อนหน้า',
            ),
            TextButton.icon(
              onPressed: () => notifier.pickDate(context),
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(DateFormat('dd/MM/yyyy').format(state.selectedDate)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: notifier.isSameDay(state.selectedDate, DateTime.now()) 
                  ? null 
                  : () => notifier.nextDate(),
              tooltip: 'วันถัดไป',
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => notifier.loadData(),
              tooltip: 'โหลดข้อมูลใหม่',
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () => notifier.exportDeliveryHistory(context),
              icon: const Icon(Icons.local_shipping),
              label: const Text('Export ส่งของ',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () async {
                final reloaded = await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const CloseShiftDialog(),
                );
                if (reloaded == true) notifier.loadData();
              },
              icon: const Icon(Icons.lock_clock),
              label: const Text('ปิดกะ (Close Shift)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  // ── Search Bar ───────────────────────────────────────────────────────────────

  Widget _buildSearchBar(BuildContext context, DashboardState state, DashboardNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ThaiAwareSearchField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              label:
                  'ค้นหาเลขที่บิล, ชื่อลูกค้า หรือเบอร์โทรศัพท์ (พิมพ์แล้วกด Enter หรือคลิกปุ่มค้นหา)',
              onSubmitted: (val) => notifier.performSearch(val, context),
              onChanged: (val) {
                if (val.isEmpty) {
                  _searchCtrl.clear();
                  notifier.clearSearch();
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 1,
            ),
            onPressed: () => notifier.performSearch(_searchCtrl.text, context),
            icon: const Icon(Icons.search, size: 20),
            label: const Text('ค้นหาบิล',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          if (_searchCtrl.text.isNotEmpty) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                _searchCtrl.clear();
                _searchFocus.unfocus();
                notifier.clearSearch();
              },
              icon: const Icon(Icons.clear, size: 20),
              label: const Text('ล้างคำค้น', style: TextStyle(fontSize: 15)),
            ),
          ],
        ],
      ),
    );
  }
}
