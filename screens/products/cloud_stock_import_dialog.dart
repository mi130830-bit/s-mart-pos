import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../services/mysql_service.dart'; // To look up products
import 'package:intl/intl.dart';
import '../../services/alert_service.dart';

class CloudStockImportDialog extends StatefulWidget {
  const CloudStockImportDialog({super.key});

  @override
  State<CloudStockImportDialog> createState() => _CloudStockImportDialogState();
}

class _CloudStockImportDialogState extends State<CloudStockImportDialog> {
  final FirebaseService _firebase = FirebaseService();
  final MySQLService _db = MySQLService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _jobs = [];
  final Map<String, bool> _processing = {};

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  Future<void> _fetchJobs() async {
    setState(() => _isLoading = true);
    // ✅ Use the new method to fetch only Shop Work Logs
    try {
      final jobs = await _firebase.fetchShopWorkLogs();
      if (mounted) {
        setState(() {
          _jobs = jobs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AlertService.show(
          context: context,
          message: 'Error loading jobs: $e',
          type: 'error',
        );
      }
    }
  }

  Future<void> _importJob(Map<String, dynamic> job) async {
    final jobId = job['id'];
    setState(() => _processing[jobId] = true);

    try {
      // 1. Get Items from Job
      final items = job['items'] as List<dynamic>? ?? [];
      if (items.isEmpty) throw Exception('ไม่พบรายการสินค้าใน Job');

      List<Map<String, dynamic>> mappedItems = [];
      int missingCount = 0;

      if (!_db.isConnected()) await _db.connect();

      for (var item in items) {
        // ✅ MAPPING UPDATE: S-Link 'shop_work_logs' uses 'description' and 'quantity'
        final name = item['description'];
        final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;

        // Find Product ID by Name
        final res = await _db.query(
            'SELECT id, stockQuantity, name FROM product WHERE name LIKE :name LIMIT 1',
            {'name': name});

        if (res.isNotEmpty) {
          final product = res.first;

          // No 'System Qty' snapshot in work logs usually, but check just in case
          String note = 'S_MartPOS Work Log';

          mappedItems.add({
            'product': product, // Full product map
            'actualQty': qty,
            'systemQty':
                double.tryParse(product['stockQuantity'].toString()) ?? 0.0,
            'note': note,
          });
        } else {
          missingCount++;
        }
      }

      if (!mounted) return;

      if (missingCount > 0) {
        AlertService.show(
          context: context,
          message: '⚠️ ไม่พบสินค้า $missingCount รายการ (ชื่อไม่ตรง)',
          type: 'warning',
        );
      }

      Navigator.pop(context, mappedItems); // Return the list to parent
    } catch (e) {
      if (mounted) {
        AlertService.show(
          context: context,
          message: 'Error: $e',
          type: 'error',
        );
        setState(() => _processing[jobId] = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ดึงประวัติงานหลังบ้าน (Work Log)'),
      content: SizedBox(
        width: 500,
        height: 600,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _jobs.isEmpty
                ? const Center(child: Text('ไม่พบรายการในช่วง 7 วัน'))
                : ListView.separated(
                    itemCount: _jobs.length,
                    separatorBuilder: (ctx, i) => const Divider(),
                    itemBuilder: (ctx, i) {
                      final job = _jobs[i];
                      final date =
                          job['created_at'] as DateTime? ?? DateTime.now();
                      final isProcessing = _processing[job['id']] == true;

                      final items = job['items'] as List? ?? [];
                      // Use deliverer_id for now as we don't have name mapping here easily
                      final deliverer = job['deliverer_id'] != null
                          ? 'ID: ${(job['deliverer_id'] as String).substring(0, 5)}...'
                          : 'Unknown';

                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.build)),
                        title: Text(
                            'วันที่: ${DateFormat('dd/MM HH:mm').format(date)}'),
                        subtitle: Row(
                          children: [
                            Expanded(
                                child: Text(
                                    '${items.length} รายการ | ผู้บันทึก: $deliverer')),
                          ],
                        ),
                        trailing: isProcessing
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                                onPressed: () => _importJob(job),
                                child: const Text('นำเข้า'),
                              ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ปิด'),
        )
      ],
    );
  }
}
