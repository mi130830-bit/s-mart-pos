import 'package:flutter/material.dart';
import '../../services/mysql_service.dart';
import 'package:intl/intl.dart';
import '../../services/alert_service.dart';

class CloudStockImportDialog extends StatefulWidget {
  const CloudStockImportDialog({
    super.key,
    this.pendingWorkLogIds = const <String>{},
    this.pendingProductIds = const <int>{},
  });

  final Set<String> pendingWorkLogIds;
  final Set<int> pendingProductIds;

  @override
  State<CloudStockImportDialog> createState() => _CloudStockImportDialogState();
}

class _CloudStockImportDialogState extends State<CloudStockImportDialog> {
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
    try {
      if (!_db.isConnected()) await _db.connect();
      if (!_db.isConnected()) {
        throw StateError('ไม่สามารถเชื่อมต่อฐานข้อมูล POS ได้');
      }

      final rows = await _db.query('''
        SELECT l.sync_id, l.deliverer_id,
               COALESCE(
                 CONVERT(e.display_name USING utf8mb4) COLLATE utf8mb4_unicode_ci,
                 CONVERT(u.displayName USING utf8mb4) COLLATE utf8mb4_unicode_ci,
                 CONVERT(l.deliverer_id USING utf8mb4) COLLATE utf8mb4_unicode_ci
               ) AS deliverer_name,
               l.logged_at, i.description, i.quantity, i.unit
        FROM shop_work_logs l
        LEFT JOIN shop_work_log_items i
          ON CONVERT(l.sync_id USING utf8mb4) COLLATE utf8mb4_unicode_ci =
             CONVERT(i.log_sync_id USING utf8mb4) COLLATE utf8mb4_unicode_ci
        LEFT JOIN employee_profile e
          ON e.id = (
            SELECT ep.id
            FROM employee_profile ep
            WHERE CONVERT(ep.firebase_uid USING utf8mb4) COLLATE utf8mb4_bin =
                  CONVERT(l.deliverer_id USING utf8mb4) COLLATE utf8mb4_bin
               OR CONVERT(CAST(ep.user_id AS CHAR) USING utf8mb4) COLLATE utf8mb4_unicode_ci =
                  CONVERT(l.deliverer_id USING utf8mb4) COLLATE utf8mb4_unicode_ci
               OR CONVERT(CAST(ep.id AS CHAR) USING utf8mb4) COLLATE utf8mb4_unicode_ci =
                  CONVERT(l.deliverer_id USING utf8mb4) COLLATE utf8mb4_unicode_ci
            ORDER BY CASE
              WHEN CONVERT(ep.firebase_uid USING utf8mb4) COLLATE utf8mb4_bin =
                   CONVERT(l.deliverer_id USING utf8mb4) COLLATE utf8mb4_bin THEN 0
              WHEN CONVERT(CAST(ep.user_id AS CHAR) USING utf8mb4) COLLATE utf8mb4_unicode_ci =
                   CONVERT(l.deliverer_id USING utf8mb4) COLLATE utf8mb4_unicode_ci THEN 1
              WHEN CONVERT(CAST(ep.id AS CHAR) USING utf8mb4) COLLATE utf8mb4_unicode_ci =
                   CONVERT(l.deliverer_id USING utf8mb4) COLLATE utf8mb4_unicode_ci THEN 2
              ELSE 3
            END, ep.id ASC
            LIMIT 1
          )
        LEFT JOIN user u ON u.id = e.user_id
        WHERE l.stock_checked_at IS NULL
        ORDER BY l.logged_at ASC, i.id ASC
      ''');

      final jobsById = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final syncId = row['sync_id']?.toString();
        if (syncId == null || syncId.isEmpty) continue;

        final job = jobsById.putIfAbsent(
          syncId,
          () => {
            'id': syncId,
            'deliverer_name': row['deliverer_name']?.toString() ?? '',
            'logged_at': row['logged_at'],
            'items': <Map<String, dynamic>>[],
          },
        );
        if (row['description'] != null) {
          (job['items'] as List<Map<String, dynamic>>).add({
            'description': row['description']?.toString() ?? '',
            'quantity': row['quantity'],
            'unit': row['unit']?.toString() ?? 'หน่วย',
          });
        }
      }

      if (mounted) {
        setState(() {
          _jobs = jobsById.values.toList();
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
    final jobId = job['id'].toString();
    if (widget.pendingWorkLogIds.contains(jobId)) {
      AlertService.show(
        context: context,
        message: 'ใบตรวจนับนี้อยู่ในรายการรอบันทึกแล้ว',
        type: 'warning',
      );
      return;
    }
    setState(() => _processing[jobId] = true);

    try {
      // 1. Get Items from Job
      final items = job['items'] as List<dynamic>? ?? [];
      if (items.isEmpty) throw Exception('ไม่พบรายการสินค้าใน Job');

      List<Map<String, dynamic>> mappedItems = [];
      int missingCount = 0;
      final matchedProductIds = <int>{};

      if (!_db.isConnected()) await _db.connect();

      for (var item in items) {
        final name = item['description']?.toString().trim() ?? '';
        final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;

        if (name.isEmpty) {
          missingCount++;
          continue;
        }

        // Prefer the exact POS name. Only a unique space-normalized match may
        // recover a legacy S-Link description with ordinary ASCII whitespace.
        final exactMatches = await _db.query(
          'SELECT id, stockQuantity, name FROM product WHERE TRIM(name) = :name',
          {'name': name},
        );
        Map<String, dynamic>? product;
        if (exactMatches.length == 1) {
          product = exactMatches.first;
        } else if (exactMatches.isEmpty) {
          final fallbackMatches = await _db.query(
            '''
            SELECT id, stockQuantity, name
            FROM product
            WHERE CONVERT(
              REPLACE(REPLACE(REPLACE(REPLACE(name, ' ', ''), CHAR(9), ''), CHAR(13), ''), CHAR(10), '')
              USING utf8mb4
            ) COLLATE utf8mb4_unicode_ci = CONVERT(
              REPLACE(REPLACE(REPLACE(REPLACE(:description, ' ', ''), CHAR(9), ''), CHAR(13), ''), CHAR(10), '')
              USING utf8mb4
            ) COLLATE utf8mb4_unicode_ci
            ''',
            {'description': name},
          );
          if (fallbackMatches.length == 1) {
            product = fallbackMatches.first;
          }
        }

        if (product != null) {
          final productId = int.tryParse(product['id'].toString()) ?? 0;
          if (productId <= 0 ||
              widget.pendingProductIds.contains(productId) ||
              !matchedProductIds.add(productId)) {
            throw StateError(
              'พบสินค้าซ้ำในใบตรวจนับหรืออยู่ในรายการรอบันทึก: ${product['name']}',
            );
          }

          const note = 'ผลตรวจนับจาก S-Link';

          mappedItems.add({
            'product': product, // Full product map
            'actualQty': qty,
            'systemQty':
                double.tryParse(product['stockQuantity'].toString()) ?? 0.0,
            'note': note,
            'sourceWorkLogIds': <String>{jobId},
          });
        } else {
          missingCount++;
        }
      }

      if (!mounted) return;

      if (missingCount > 0) {
        AlertService.show(
          context: context,
          message:
              'ไม่สามารถนำเข้าได้: ไม่พบสินค้า $missingCount รายการ กรุณาแก้ชื่อสินค้าใน S-Link ให้ตรงกับ POS',
          type: 'error',
        );
        setState(() => _processing[jobId] = false);
        return;
      }

      // Every imported line keeps the original sheet size. If a POS user
      // removes one line before confirming, the sheet remains pending rather
      // than being falsely marked as fully reviewed.
      for (final mappedItem in mappedItems) {
        mappedItem['sourceWorkLogItemCount'] = mappedItems.length;
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
      title: const Text('ดึงใบตรวจนับจาก S-Link'),
      content: SizedBox(
        width: 500,
        height: 600,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _jobs.isEmpty
                ? const Center(child: Text('ไม่มีใบตรวจนับที่รอ POS ยืนยัน'))
                : ListView.separated(
                    itemCount: _jobs.length,
                    separatorBuilder: (ctx, i) => const Divider(),
                    itemBuilder: (ctx, i) {
                      final job = _jobs[i];
                      final rawDate = job['logged_at'];
                      final date = rawDate is DateTime
                          ? rawDate
                          : DateTime.tryParse(rawDate?.toString() ?? '') ??
                              DateTime.now();
                      final isProcessing = _processing[job['id']] == true;

                      final items = job['items'] as List? ?? [];
                      final deliverer =
                          job['deliverer_name']?.toString().isNotEmpty == true
                              ? job['deliverer_name'].toString()
                              : 'ไม่ระบุผู้ตรวจนับ';

                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.build)),
                        title: Text(
                            'วันที่: ${DateFormat('dd/MM HH:mm').format(date)}'),
                        subtitle: Row(
                          children: [
                            Expanded(
                                child: Text(
                                    '${items.length} รายการ | ผู้ตรวจนับ: $deliverer')),
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
