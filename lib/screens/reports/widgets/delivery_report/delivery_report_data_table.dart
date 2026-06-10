import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../services/alert_service.dart';

class DeliveryReportDataTable extends StatelessWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> filteredRecords;
  final VoidCallback onEmptyAction;
  final Function(Map<String, dynamic>) onAssignVehicle;

  const DeliveryReportDataTable({
    super.key,
    required this.isLoading,
    required this.filteredRecords,
    required this.onEmptyAction,
    required this.onAssignVehicle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final moneyFormat = NumberFormat('#,##0.00');

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (filteredRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('ไม่พบข้อมูลการจัดส่งในช่วงที่เลือก',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onEmptyAction,
              child: const Text('เปลี่ยนช่วงวันที่'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
              colorScheme.primary.withValues(alpha: 0.1)),
          columns: const [
            DataColumn(label: Text('วันที่')),
            DataColumn(label: Text('ลูกค้า')),
            DataColumn(label: Text('คนขับ')),
            DataColumn(label: Text('รถ')),
            DataColumn(label: Text('ยอดเงิน')),
            DataColumn(label: Text('ระยะทาง')),
            DataColumn(label: Text('ค่าน้ำมัน')),
            DataColumn(label: Text('พิกัด GPS')),
          ],
          rows: filteredRecords.map((r) {
            final rawDate = r['completedAt']?.toString() ?? '';
            String dateStr = '-';
            try {
              if (rawDate.isNotEmpty) {
                final dt = DateTime.parse(rawDate);
                dateStr = dateFormat.format(dt); // วันที่เท่านั้น ไม่มีเวลา
              }
            } catch (_) {
              dateStr = rawDate;
            }
            final amount =
                double.tryParse(r['totalAmount']?.toString() ?? '0') ?? 0.0;
            return DataRow(cells: [
              DataCell(Text(dateStr)),
              DataCell(Text(r['customerName']?.toString() ?? '-')),
              DataCell(Text(r['driverName']?.toString() ?? '-')),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(r['vehiclePlate']?.toString().isNotEmpty == true
                        ? r['vehiclePlate'].toString()
                        : 'ไม่ระบุ'),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => onAssignVehicle(r),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.edit, size: 14, color: Colors.indigo),
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(Text(
                '฿${moneyFormat.format(amount)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green),
              )),
              DataCell(
                () {
                  final dist =
                      double.tryParse(r['distanceKm']?.toString() ?? '0') ??
                          0.0;
                  final src = r['_distanceSource']?.toString() ?? '';
                  if (dist <= 0) {
                    return const Tooltip(
                      message:
                          'ยังไม่มีระยะทาง — กรอก "ระยะทางจัดส่ง" ในข้อมูลลูกค้า',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 14, color: Colors.orange),
                          SizedBox(width: 4),
                          Text('ยังไม่กำหนด',
                              style: TextStyle(
                                  color: Colors.orange, fontSize: 12)),
                        ],
                      ),
                    );
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${dist.toStringAsFixed(2)} กม.'),
                      if (src == 'customer') ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'ระยะทางจากข้อมูลลูกค้า',
                          child: Icon(Icons.person_pin_circle_outlined,
                              size: 13, color: Colors.blue.shade400),
                        ),
                      ],
                    ],
                  );
                }(),
              ),
              DataCell(Text(
                () {
                  final fuel = double.tryParse(r['fuelCostEstimate']?.toString() ?? '0') ?? 0.0;
                  return fuel > 0 ? '฿${moneyFormat.format(fuel)}' : '-';
                }(),
                style: TextStyle(
                    color: (() {
                      final fuelCost = double.tryParse(
                              r['fuelCostEstimate']?.toString() ?? '0') ??
                          0.0;
                      return fuelCost > 0 ? Colors.red : Colors.grey;
                    })(),
                    fontWeight: FontWeight.bold),
              )),
              DataCell(
                r['locationUrl'] != null &&
                        r['locationUrl'].toString().isNotEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.map, color: Colors.blue),
                            tooltip: 'เปิด Google Maps',
                            onPressed: () async {
                              final url =
                                  Uri.parse(r['locationUrl'].toString());
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url,
                                    mode: LaunchMode.externalApplication);
                              } else {
                                if (context.mounted) {
                                  AlertService.show(
                                      context: context,
                                      message: 'ไม่สามารถเปิดลิงก์ได้',
                                      type: 'error');
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy,
                                size: 18, color: Colors.grey),
                            tooltip: 'คัดลอกลิงก์',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(
                                  text: r['locationUrl'].toString()));
                              AlertService.show(
                                  context: context,
                                  message: 'คัดลอกพิกัดลง Clipboard แล้ว',
                                  type: 'success');
                            },
                          ),
                        ],
                      )
                    : const Text('-'),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
