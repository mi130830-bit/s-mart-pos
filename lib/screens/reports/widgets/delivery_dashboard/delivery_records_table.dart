import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../services/alert_service.dart';

class DeliveryRecordsTable extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final bool isLoading;
  final VoidCallback onChangeDateRange;
  final void Function(Map<String, dynamic>) onAssignVehicle;
  final void Function(int) onViewOrderDetails;
  final double Function(Map<String, dynamic>) onCalculateFuelCost;

  const DeliveryRecordsTable({
    super.key,
    required this.records,
    required this.isLoading,
    required this.onChangeDateRange,
    required this.onAssignVehicle,
    required this.onViewOrderDetails,
    required this.onCalculateFuelCost,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (records.isEmpty) {
      return DeliveryEmptyState(onChangeDateRange: onChangeDateRange);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: records.length,
      itemBuilder: (context, index) {
        return _buildJobCard(context, records[index], cs);
      },
    );
  }

  Widget _buildJobCard(BuildContext context, Map<String, dynamic> r, ColorScheme cs) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');
    final moneyFormat = NumberFormat('#,##0.00');

    final rawDate = r['completedAt']?.toString() ?? '';
    String dateStr = '-';
    String timeStr = '';
    try {
      if (rawDate.isNotEmpty) {
        final dt = DateTime.parse(rawDate);
        dateStr = dateFormat.format(dt);
        timeStr = timeFormat.format(dt);
      }
    } catch (_) {}

    final amount = double.tryParse(r['totalAmount']?.toString() ?? '0') ?? 0.0;
    final distKm = double.tryParse(r['distanceKm']?.toString() ?? '0') ?? 0.0;
    final fuelCost = onCalculateFuelCost(r);
    final orderId = int.tryParse(r['orderId']?.toString() ?? '0') ?? 0;

    final driverName = r['driverName']?.toString() ?? '-';
    final vehiclePlate = r['vehiclePlate']?.toString().trim() ?? '';
    final customerName = r['customerName']?.toString() ?? '-';
    final customerPhone = r['customerPhone']?.toString() ?? '';
    final customerAddress = r['customerAddress']?.toString() ?? '';
    final locationUrl = r['locationUrl']?.toString() ?? '';
    final note = r['note']?.toString() ?? '';
    final jobType = r['jobType']?.toString() ?? 'delivery';
    final status = r['status']?.toString() ?? '';

    final bool missingDistance = distKm == 0.0;
    final bool isDelivery = jobType == 'delivery';
    final statusColor = status == 'completed' ? Colors.green : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: missingDistance
            ? BorderSide(color: Colors.orange.shade300, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Date + Status ─────────────────────────────
            Row(
              children: [
                Icon(
                  isDelivery
                      ? Icons.local_shipping_outlined
                      : Icons.store_mall_directory_outlined,
                  color: isDelivery ? Colors.indigo : Colors.teal,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const Spacer(),
                // Missing distance warning badge
                if (missingDistance)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 12,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ยังไม่มีระยะทาง',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    status == 'completed' ? '✅ เสร็จสิ้น' : status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 14),

            // ── Customer & Driver ─────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(
                        Icons.person_outline,
                        'ลูกค้า',
                        customerName,
                        bold: true,
                      ),
                      if (customerPhone.isNotEmpty)
                        _infoRow(
                          Icons.phone_outlined,
                          'เบอร์โทร',
                          customerPhone,
                        ),
                      if (customerAddress.isNotEmpty)
                        _infoRow(
                          Icons.location_on_outlined,
                          'ที่อยู่',
                          customerAddress,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(
                        Icons.person_search_outlined,
                        'คนขับ',
                        driverName.isEmpty ? '-' : driverName,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.directions_car_outlined,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'รถ: ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      vehiclePlate.isEmpty
                                          ? 'ไม่ระบุ'
                                          : vehiclePlate,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => onAssignVehicle(r),
                                    borderRadius: BorderRadius.circular(12),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.edit,
                                        size: 14,
                                        color: Colors.indigo,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Stats Row ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _statChip(
                    icon: Icons.payments_outlined,
                    label: 'ยอดเงิน',
                    value: '฿${moneyFormat.format(amount)}',
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statChip(
                    icon: Icons.route_outlined,
                    label: 'ระยะทาง (จากลูกค้า)',
                    value: distKm > 0
                        ? '${distKm.toStringAsFixed(2)} กม.'
                        : '— ยังไม่กำหนด',
                    color: distKm > 0
                        ? Colors.blue.shade700
                        : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statChip(
                    icon: Icons.local_gas_station_outlined,
                    label: 'ค่าน้ำมัน',
                    value: fuelCost > 0
                        ? '฿${moneyFormat.format(fuelCost)}'
                        : '-',
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),

            // ── GPS Link & Bill ──────────────────────────────────────
            if (locationUrl.isNotEmpty || orderId > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (locationUrl.isNotEmpty)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'พิกัด GPS:',
                              style:
                                  TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () async {
                                final url = Uri.parse(locationUrl);
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(
                                    url,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                              child: Text(
                                'เปิด Google Maps',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: locationUrl),
                                );
                                AlertService.show(
                                  context: context,
                                  message: 'คัดลอกลิงก์แล้ว',
                                  type: 'success',
                                );
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.copy_outlined,
                                    size: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'คัดลอก',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (locationUrl.isNotEmpty && orderId > 0)
                    const SizedBox(width: 8),
                  if (orderId > 0)
                    OutlinedButton.icon(
                      onPressed: () => onViewOrderDetails(orderId),
                      icon: const Icon(
                        Icons.receipt_long,
                        size: 16,
                        color: Colors.teal,
                      ),
                      label: const Text(
                        'ดูบิลขาย',
                        style: TextStyle(color: Colors.teal),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.teal.shade200),
                        backgroundColor: Colors.teal.shade50,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            ],

            // ── Note ──────────────────────────────────────────────
            if (note.isNotEmpty && note != '-') ...[
              const SizedBox(height: 6),
              _infoRow(Icons.notes_outlined, 'หมายเหตุ', note),
            ],

            // ── Hint for missing distance ─────────────────────────
            if (missingDistance) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ยังไม่มีระยะทาง — กรุณากรอก "ระยะทางจัดส่ง" ในหน้าแก้ไขข้อมูลลูกค้า "$customerName"',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DeliveryEmptyState extends StatelessWidget {
  final VoidCallback onChangeDateRange;

  const DeliveryEmptyState({
    super.key,
    required this.onChangeDateRange,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_shipping_outlined,
              size: 72,
              color: Colors.indigo.shade300,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ไม่พบข้อมูลการจัดส่ง',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ไม่พบรายการจัดส่งตามช่วงเวลาหรือรถที่เลือก',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onChangeDateRange,
            icon: const Icon(Icons.date_range, size: 16),
            label: const Text('เปลี่ยนช่วงวันที่'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.indigo,
              side: const BorderSide(color: Colors.indigo),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
