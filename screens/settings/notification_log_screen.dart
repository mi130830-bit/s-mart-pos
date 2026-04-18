import 'package:flutter/material.dart';
import '../../repositories/notification_repository.dart';
import '../../services/mysql_service.dart';
import '../../services/notification_scheduler.dart';
import 'package:intl/intl.dart';
import '../../services/alert_service.dart';

class NotificationLogScreen extends StatefulWidget {
  const NotificationLogScreen({super.key});

  @override
  State<NotificationLogScreen> createState() => _NotificationLogScreenState();
}

class _NotificationLogScreenState extends State<NotificationLogScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _logs = [];
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLogs();
    });
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final repo = NotificationRepository(MySQLService());
      final logs = await repo.getLogs(limit: 100);
      setState(() {
        _logs = logs;
      });
    } catch (e) {
      debugPrint('Error loading logs: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _retryOne(int id) async {
    setState(() => _isLoading = true);
    try {
      final repo = NotificationRepository(MySQLService());
      // Reset status to PENDING and attempt_count to 0 to let Scheduler pick it up
      await repo.resetLog(id);

      if (mounted) {
        AlertService.show(
          context: context,
          message: 'รีเซ็ตรายการแล้ว รอระบบส่งใหม่สักครู่...',
          type: 'success',
        );
      }
      await _loadLogs();
      // Optional: Trigger scheduler immediately
      NotificationScheduler().triggerNow();
    } catch (e) {
      if (mounted) {
        AlertService.show(
          context: context,
          message: 'Error: $e',
          type: 'error',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _testNotification() async {
    setState(() => _isLoading = true);
    try {
      final repo = NotificationRepository(MySQLService());
      await repo.createLog(
        orderId: 99999, // Dummy Order ID
        lineUserId:
            'Udeadbeefdeadbeefdeadbeefdeadbeef', // Invalid ID to force error/retry
        messageType: 'TEST',
        content: 'ทดสอบระบบแจ้งเตือน (Simulation) ณ ${DateTime.now()}',
      );

      if (mounted) {
        AlertService.show(
          context: context,
          message: 'สร้างรายการทดสอบแล้ว (Pending)',
          type: 'success',
        );
      }
      await _loadLogs();

      // Optional: Trigger immediately
      // await NotificationScheduler().triggerNow();
    } catch (e) {
      if (mounted) {
        AlertService.show(
          context: context,
          message: 'Error: $e',
          type: 'error',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _manualRetry() async {
    setState(() => _isLoading = true);
    try {
      // Trigger the scheduler manually
      // Note: Scheduler uses a lock, so if it's already running, this might skip.
      // But it's fine for "Retry Now".
      // Actually method is private in scheduler, so we can't call _runTask directly.
      // But NotificationScheduler().start() won't force run if timer exists.
      // We should expose a force run or just call FirebaseService directly?
      // NotificationScheduler uses FirebaseService().processPendingNotifications internally.
      // Let's call FirebaseService directly for immediate feedback,
      // but NotificationScheduler manages concurrency.
      // Let's rely on NotificationScheduler logic if we expose a "trigger" method,
      // OR better: just call FirebaseService().processPendingNotifications(MySQLService()) directly
      // but we need to respect the lock if possible.
      // Since we can't access lock, let's just call it. It's safe idempotent.

      // WAIT! NotificationScheduler has a lock _isProcessing.
      // If we call FirebaseService directly, we might race.
      // But FirebaseService transaction logic (if any) should be safe.
      // Actually NotificationRepository updates rows.
      // Let's just assume it's safe.

      await NotificationScheduler().triggerNow();
      // We need to add triggerNow to Scheduler first if strict.
      // For now, I'll update Scheduler to expose trigger.
    } catch (e) {
      if (mounted) {
        AlertService.show(
          context: context,
          message: 'Error: $e',
          type: 'error',
        );
      }
    } finally {
      await _loadLogs(); // Reload logs
      if (mounted) {
        setState(() => _isLoading = false);
        AlertService.show(
          context: context,
          message: 'ดำเนินการ Retry เสร็จสิ้น',
          type: 'success',
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
        return Colors.green;
      case 'FAILED':
        return Colors.red;
      case 'PENDING':
      case 'RETRYING':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
        return Icons.check_circle;
      case 'FAILED':
        return Icons.error;
      case 'PENDING':
      case 'RETRYING':
        return Icons.access_time_filled;
      default:
        return Icons.help;
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ล้างประวัติการแจ้งเตือน'),
        content: const Text('คุณต้องการลบประวัติที่ส่งสำเร็จและล้มเหลวใช่หรือไม่?\n\n(รายการที่กำลังรอส่งจะถูกเก็บไว้)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยันลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final repo = NotificationRepository(MySQLService());
        await repo.clearLogs(onlySuccess: true); // Don't wipe pending things!
        
        if (mounted) {
          AlertService.show(context: context, message: 'ล้างประวัติเรียบร้อยแล้ว', type: 'success');
        }
      } catch (e) {
        if (mounted) {
          AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
        }
      } finally {
        await _loadLogs();
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติการแจ้งเตือน Line OA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'ล้างประวัติ (Clear Logs)',
            onPressed: _isLoading ? null : _clearLogs,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'แสดง 100 รายการล่าสุด',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _manualRetry,
                  icon: const Icon(Icons.sync),
                  label: const Text('ลองส่งใหม่ (Retry Now)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _testNotification,
                  icon: const Icon(Icons.bug_report),
                  label: const Text('จำลอง (Test)'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _isLoading && _logs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? const Center(child: Text('ไม่พบรายการ'))
                    : ListView.separated(
                        itemCount: _logs.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final status = log['status']?.toString() ?? 'UNKNOWN';
                          final date = log['created_at'] is DateTime
                              ? log['created_at'] as DateTime
                              : DateTime.tryParse(
                                      log['created_at'].toString()) ??
                                  DateTime.now();

                          return ExpansionTile(
                            leading: Icon(
                              _getStatusIcon(status),
                              color: _getStatusColor(status),
                            ),
                            title: Text(
                                '${log['message_type']} -> Order #${log['order_id']}'),
                            subtitle: Text(_dateFormat.format(date)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                // ignore: deprecated_member_use
                                color: _getStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: _getStatusColor(status)),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _rowDetail(
                                        'Line User ID', log['line_user_id']),
                                    const SizedBox(height: 4),
                                    _rowDetail('Content', log['content']),
                                    const SizedBox(height: 4),
                                    _rowDetail(
                                        'Attempts', '${log['attempt_count']}'),
                                    if (log['error_message'] != null) ...[
                                      const SizedBox(height: 8),
                                      const Text('Error Message:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red)),
                                      SelectableText(
                                          log['error_message'].toString(),
                                          style: const TextStyle(
                                              color: Colors.red)),
                                    ],
                                    if (status == 'FAILED') ...[
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _retryOne(
                                              int.tryParse(
                                                      log['id'].toString()) ??
                                                  0),
                                          icon: const Icon(Icons.refresh),
                                          label: const Text(
                                              'ส่งใหม่รายการนี้ (Retry This Item)'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _rowDetail(String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value ?? '-')),
      ],
    );
  }
}
