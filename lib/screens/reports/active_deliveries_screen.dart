import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../../services/integration/delivery_integration_service.dart';
import '../../services/alert_service.dart';

class ActiveDeliveriesScreen extends StatefulWidget {
  final DeliveryIntegrationService? deliveryService;
  const ActiveDeliveriesScreen({super.key, this.deliveryService});

  @override
  State<ActiveDeliveriesScreen> createState() => _ActiveDeliveriesScreenState();
}

class _ActiveDeliveriesScreenState extends State<ActiveDeliveriesScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _jobs = [];
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  final _moneyFormat = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.deliveryService == null) return;
    
    setState(() => _isLoading = true);
    try {
      final jobs = await widget.deliveryService!.fetchActiveDeliveryJobs();
      if (mounted) {
        setState(() {
          _jobs = jobs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AlertService.show(context: context, message: 'โหลดข้อมูลไม่สำเร็จ: $e', type: 'error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการที่รอส่งของ (Active Deliveries)'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 72, color: Colors.green.shade300),
                      const SizedBox(height: 16),
                      const Text('ไม่มีรายการที่รอส่งของ', style: TextStyle(color: Colors.grey, fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _jobs.length,
                  itemBuilder: (context, index) => _buildJobCard(_jobs[index]),
                ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final status = job['status']?.toString() ?? 'pending';

    // ✅ Safe parse created_at (may be DateTime or String from REST)
    DateTime? createdAt;
    final rawDate = job['created_at'];
    if (rawDate is DateTime) {
      createdAt = rawDate.isUtc ? rawDate.toLocal() : rawDate;
    } else if (rawDate is String && rawDate.isNotEmpty) {
      createdAt = DateTime.tryParse(rawDate)?.toLocal();
    }
    final dateStr = createdAt != null ? _dateFormat.format(createdAt) : '-';
    
    // ✅ Safe parse customer (may be Map or JSON-encoded String)
    Map<String, dynamic> customer = {};
    final rawCustomer = job['customer'];
    if (rawCustomer is Map<String, dynamic>) {
      customer = rawCustomer;
    } else if (rawCustomer is String && rawCustomer.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawCustomer);
        if (decoded is Map<String, dynamic>) customer = decoded;
      } catch (_) {}
    }
    final customerName = customer['name']?.toString() ?? '-';
    final customerPhone = customer['phoneNumber']?.toString() ?? '';
    final customerAddress = customer['address']?.toString() ?? '';
    
    final amount = double.tryParse(job['price']?.toString() ?? '0') ?? 0.0;
    final orderId = job['localOrderId']?.toString() ?? '-';
    final details = job['details']?.toString() ?? '';
    final jobType = job['job_type']?.toString() ?? 'delivery';
    
    // GPS parsing
    String locationUrl = '';
    final gp = job['destination_location'];
    if (gp != null) {
      if (gp is String) {
        locationUrl = gp;
      } else if (gp is Map) {
        final lat = gp['_latitude'] ?? gp['latitude'] ?? gp['lat'];
        final lng = gp['_longitude'] ?? gp['longitude'] ?? gp['lng'];
        if (lat != null && lng != null) {
          locationUrl = 'https://maps.google.com/?q=$lat,$lng';
        }
      } else {
        try {
          final lat = (gp as dynamic).latitude;
          final lng = (gp as dynamic).longitude;
          if (lat != null && lng != null) {
            locationUrl = 'https://maps.google.com/?q=$lat,$lng';
          }
        } catch (_) {}
      }
    }

    final isPickup = jobType == 'pickup' || jobType == 'customer_pickup';
    
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (status == 'pending') {
      statusColor = Colors.orange;
      statusText = '⏳ รอการจัดส่ง';
      statusIcon = Icons.hourglass_empty;
    } else if (status == 'shipping' || status == 'enroute' || status == 'en_route') {
      statusColor = Colors.blue;
      statusText = '🚚 กำลังจัดส่ง';
      statusIcon = Icons.local_shipping;
    } else if (status == 'accepted') {
      statusColor = Colors.purple;
      statusText = 'รับงานแล้ว (กำลังเตรียมตัว)';
      statusIcon = Icons.check_circle_outline;
    } else {
      statusColor = Colors.grey;
      statusText = status;
      statusIcon = Icons.info_outline;
    }

    if (isPickup) {
      statusIcon = Icons.storefront;
      if (status == 'pending') statusText = '🛍️ รอรับสินค้าหน้าร้าน';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Order #$orderId',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  dateStr,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            const Divider(),

            // Status Badge & Amount
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(
                  '฿${_moneyFormat.format(amount)}',
                  style: const TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Customer Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(Icons.person, 'ลูกค้า:', customerName, bold: true),
                      if (customerPhone.isNotEmpty)
                        _infoRow(Icons.phone, 'เบอร์โทร:', customerPhone),
                      if (customerAddress.isNotEmpty)
                        _infoRow(Icons.location_on, 'ที่อยู่:', customerAddress),
                    ],
                  ),
                ),
              ],
            ),

            if (details.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey.shade700),
                        const SizedBox(width: 6),
                        Text('รายการสินค้า', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      details,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],

            // GPS Link
            if (locationUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.map_outlined, size: 18, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Text('พิกัด GPS:', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () async {
                        final url = Uri.parse(locationUrl);
                        if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                      },
                      child: Text(
                        'เปิด Google Maps',
                        style: TextStyle(color: Colors.blue.shade700, fontSize: 14, decoration: TextDecoration.underline),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: locationUrl));
                        AlertService.show(context: context, message: 'คัดลอกลิงก์แล้ว', type: 'success');
                      },
                      child: Row(
                        children: [
                          Icon(Icons.copy_outlined, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('คัดลอก', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        ],
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }
}
