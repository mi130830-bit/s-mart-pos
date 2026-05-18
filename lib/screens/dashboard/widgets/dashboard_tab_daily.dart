import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../state/auth_provider.dart';
import '../../../widgets/common/thai_aware_search_field.dart';
import '../../../widgets/dialogs/close_shift_dialog.dart';
import '../../../services/excel_export_service.dart';
import '../../../services/alert_service.dart';
import 'dashboard_orders_table.dart';

/// แท็บ "รายการวันนี้" ในหน้า Dashboard
class DashboardTabDaily extends StatelessWidget {
  final DateTime selectedDate;
  final List<Map<String, dynamic>> orders;
  final String searchQuery;
  final bool isSearchLoading;
  final TextEditingController searchCtrl;
  final FocusNode searchFocus;

  // Date navigation callbacks
  final VoidCallback onPrevDate;
  final VoidCallback onNextDate;
  final VoidCallback onPickDate;
  final VoidCallback onRefresh;
  final bool isToday;

  // Table action callbacks
  final void Function(Map<String, dynamic> row) onViewDetails;
  final void Function(Map<String, dynamic> row) onReprint;
  final void Function(int orderId) onSendToDelivery;
  final void Function(int orderId) onSendToBackShop;
  final void Function(int orderId) onChangeCustomer;
  final void Function(Map<String, dynamic> row) onDelete;

  // Search callbacks
  final void Function(String val) onSearch;
  final void Function() onClearSearch;

  const DashboardTabDaily({
    super.key,
    required this.selectedDate,
    required this.orders,
    required this.searchQuery,
    required this.isSearchLoading,
    required this.searchCtrl,
    required this.searchFocus,
    required this.onPrevDate,
    required this.onNextDate,
    required this.onPickDate,
    required this.onRefresh,
    required this.isToday,
    required this.onViewDetails,
    required this.onReprint,
    required this.onSendToDelivery,
    required this.onSendToBackShop,
    required this.onChangeCustomer,
    required this.onDelete,
    required this.onSearch,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('รายการขาย',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                      'วันที่: ${DateFormat('dd MMMM yyyy', 'th').format(selectedDate)}',
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey.shade600))
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: onPrevDate,
                    tooltip: 'วันก่อนหน้า',
                  ),
                  TextButton.icon(
                    onPressed: onPickDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: isToday ? null : onNextDate,
                    tooltip: 'วันถัดไป',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: onRefresh,
                    tooltip: 'โหลดข้อมูลใหม่',
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => _exportDeliveryHistory(context),
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Export ส่งของ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onPressed: () async {
                      final reloaded = await showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const CloseShiftDialog(),
                      );
                      if (reloaded == true) onRefresh();
                    },
                    icon: const Icon(Icons.lock_clock),
                    label: const Text('ปิดกะ (Close Shift)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Search Bar ────────────────────────────────────────────────────────
          Container(
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
                    controller: searchCtrl,
                    focusNode: searchFocus,
                    label:
                        'ค้นหาเลขที่บิล, ชื่อลูกค้า หรือเบอร์โทรศัพท์ (พิมพ์แล้วกด Enter หรือคลิกปุ่มค้นหา)',
                    onSubmitted: onSearch,
                    onChanged: (val) {
                      if (val.isEmpty) onClearSearch();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 1,
                  ),
                  onPressed: () => onSearch(searchCtrl.text),
                  icon: const Icon(Icons.search, size: 20),
                  label: const Text('ค้นหาบิล',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                if (searchCtrl.text.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.clear, size: 20),
                    label: const Text('ล้างคำค้น',
                        style: TextStyle(fontSize: 15)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Orders Table ──────────────────────────────────────────────────────
          DashboardOrdersTable(
            orders: orders,
            searchQuery: searchQuery,
            isSearchLoading: isSearchLoading,
            auth: auth,
            onViewDetails: onViewDetails,
            onReprint: onReprint,
            onSendToDelivery: onSendToDelivery,
            onSendToBackShop: onSendToBackShop,
            onChangeCustomer: onChangeCustomer,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }

  Future<void> _exportDeliveryHistory(BuildContext context) async {
    final now = DateTime.now();
    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      ),
    );

    if (dateRange != null && context.mounted) {
      final start = DateTime(dateRange.start.year, dateRange.start.month,
          dateRange.start.day, 0, 0, 0);
      final end = DateTime(dateRange.end.year, dateRange.end.month,
          dateRange.end.day, 23, 59, 59);

      final service = ExcelExportService();
      final success = await service.exportDeliveryHistory(start, end);

      if (context.mounted) {
        AlertService.show(
          context: context,
          message: success
              ? 'สร้างไฟล์ Excel สรุปการจัดส่งสำเร็จ'
              : 'ไม่พบข้อมูลในช่วงที่เลือก หรือมีข้อผิดพลาด',
          type: success ? 'success' : 'error',
        );
      }
    }
  }
}
