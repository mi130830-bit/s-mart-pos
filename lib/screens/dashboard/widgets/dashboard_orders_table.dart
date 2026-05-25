import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../state/auth_provider.dart';

/// ตารางแสดงรายการสั่งซื้อ/บิล ในหน้า Dashboard
///
/// รับ callback แทนการเรียก method โดยตรง เพื่อให้ parent screen จัดการ logic เอง
class DashboardOrdersTable extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final String searchQuery;
  final bool isSearchLoading;
  final AuthState auth;

  // Callbacks
  final void Function(Map<String, dynamic> row) onViewDetails;
  final void Function(Map<String, dynamic> row) onReprint;
  final void Function(int orderId) onSendToDelivery;
  final void Function(int orderId) onSendToBackShop;
  final void Function(int orderId) onChangeCustomer;
  final void Function(Map<String, dynamic> row) onDelete;

  const DashboardOrdersTable({
    super.key,
    required this.orders,
    required this.searchQuery,
    required this.isSearchLoading,
    required this.auth,
    required this.onViewDetails,
    required this.onReprint,
    required this.onSendToDelivery,
    required this.onSendToBackShop,
    required this.onChangeCustomer,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (isSearchLoading) return _buildLoadingCard();
    if (orders.isEmpty) return _buildEmptyCard();
    return _buildTable();
  }

  // ── Loading & Empty States ───────────────────────────────────────────────────

  Widget _buildLoadingCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(48.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('กำลังค้นหาข้อมูลบิล...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                searchQuery.isNotEmpty
                    ? 'ไม่พบข้อมูลบิลสำหรับคำค้น "$searchQuery"'
                    : 'ไม่มีรายการขายในวันที่เลือก',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Table ────────────────────────────────────────────────────────────────────

  Widget _buildTable() {
    final moneyFormat = NumberFormat('#,##0.00');
    final bool canViewCost = auth.hasPermission('view_cost');
    final bool canViewProfit = auth.hasPermission('view_profit');
    final titleText = searchQuery.isNotEmpty
        ? 'ผลการค้นหาบิลสำหรับ: "$searchQuery"'
        : 'รายการล่าสุดวันนี้';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(titleText,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                if (searchQuery.isNotEmpty)
                  Text(
                    'พบทั้งหมด ${orders.length} รายการ',
                    style: TextStyle(
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: DataTable(
              columnSpacing: 20,
              horizontalMargin: 20,
              dataRowMinHeight: 50,
              dataRowMaxHeight: 65,
              columns: const [
                DataColumn(label: Text('เลขที่บิล')),
                DataColumn(label: Text('เวลา')),
                DataColumn(label: Text('ลูกค้า')),
                DataColumn(label: Text('ยอดรวม')),
                DataColumn(label: Text('รับเงิน')),
                DataColumn(label: Text('สถานะ')),
                DataColumn(label: Text('จัดการ')),
              ],
              rows: orders.map((o) => _buildRow(o, moneyFormat,
                  canViewCost: canViewCost,
                  canViewProfit: canViewProfit)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(
    Map<String, dynamic> o,
    NumberFormat moneyFormat, {
    required bool canViewCost,
    required bool canViewProfit,
  }) {
    final date =
        DateTime.tryParse(o['createdAt'].toString()) ?? DateTime.now();
    final timeStr = DateFormat('HH:mm').format(date);
    final amount = double.tryParse(o['amount'].toString()) ?? 0.0;
    final totalCost =
        double.tryParse(o['totalCost']?.toString() ?? '0.0') ?? 0.0;
    final profit = amount - totalCost;
    final received = double.tryParse(o['received'].toString()) ?? 0.0;
    final type = o['type'];
    final rawStatus = o['status']?.toString().toUpperCase() ?? '';
    final paymentMethod = o['paymentMethod']?.toString().toLowerCase() ?? '';
    final int orderId = int.tryParse(o['id'].toString()) ?? 0;

    // ── สถานะ ──────────────────────────────────────────────────────────────────
    String statusText = '';
    Color statusColor = Colors.grey;
    bool isVoid = false;

    if (type == 'DEBT_PAYMENT') {
      statusText = 'ชำระหนี้';
      statusColor = Colors.purple;
    } else if (rawStatus == 'UNPAID') {
      statusText = 'ค้างจ่าย';
      statusColor = Colors.orange.shade800;
    } else if (rawStatus == 'COMPLETED') {
      statusText = paymentMethod == 'credit' ? 'สำเร็จ (ลงบัญชี)' : 'สำเร็จ';
      statusColor = Colors.green;
    } else if (rawStatus == 'HELD') {
      statusText = 'พักบิล';
      statusColor = Colors.blue;
    } else if (rawStatus == 'VOID' || rawStatus == 'CANCELLED') {
      statusText = 'ยกเลิก';
      statusColor = Colors.grey;
      isVoid = true;
    } else {
      statusText = rawStatus;
    }

    final textStyle = TextStyle(
      fontWeight: FontWeight.w500,
      color: isVoid ? Colors.grey : Colors.black87,
      decoration: isVoid ? TextDecoration.lineThrough : null,
    );

    return DataRow(cells: [
      // เลขที่บิล
      DataCell(Text('#${o["id"]}',
          style: textStyle.copyWith(fontWeight: FontWeight.bold))),
      // เวลา
      DataCell(Text(timeStr, style: textStyle)),
      // ลูกค้า
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(o['customerName'] ?? 'ลูกค้าทั่วไป', style: textStyle),
          if (!isVoid &&
              type != 'DEBT_PAYMENT' &&
              auth.hasPermission('history_edit_customer'))
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_outlined,
                  size: 16, color: Colors.blueGrey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => onChangeCustomer(orderId),
            ),
        ],
      )),
      // ยอดรวม
      DataCell(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(moneyFormat.format(amount),
              style: textStyle.copyWith(fontWeight: FontWeight.bold)),
          if ((canViewCost || canViewProfit) && type == 'ORDER')
            Text(
              [
                if (canViewCost) 'ทุน: ${moneyFormat.format(totalCost)}',
                if (canViewProfit) 'กำไร: ${moneyFormat.format(profit)}',
              ].join(' | '),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                decoration: isVoid ? TextDecoration.lineThrough : null,
              ),
            ),
        ],
      )),
      // รับเงิน
      DataCell(Text(
        moneyFormat.format(received),
        style: textStyle.copyWith(
          color: (!isVoid && received < amount && type != 'DEBT_PAYMENT')
              ? Colors.red
              : (isVoid ? Colors.grey : Colors.black87),
        ),
      )),
      // สถานะ
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor.withValues(alpha: 0.5)),
        ),
        child: Text(
          statusText,
          style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12),
        ),
      )),
      // จัดการ
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isVoid)
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.blue, size: 20),
              tooltip: 'ดูรายละเอียด',
              onPressed: () => onViewDetails(o),
            ),
          if (!isVoid) ...[
            IconButton(
              icon: const Icon(Icons.print, color: Colors.grey, size: 20),
              tooltip: 'ปริ้นซ้ำ',
              onPressed: () => onReprint(o),
            ),
            if (type != 'DEBT_PAYMENT') ...[
              IconButton(
                icon: const Icon(Icons.local_shipping,
                    color: Colors.orange, size: 20),
                tooltip: 'ส่งของ',
                onPressed: () => onSendToDelivery(orderId),
              ),
              IconButton(
                icon: const Icon(Icons.store_mall_directory,
                    color: Colors.deepPurple, size: 20),
                tooltip: 'แจ้งรับของหลังร้าน',
                onPressed: () => onSendToBackShop(orderId),
              ),
            ],
          ],
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            tooltip: 'ลบบิล',
            onPressed: () => onDelete(o),
          ),
        ],
      )),
    ]);
  }
}
