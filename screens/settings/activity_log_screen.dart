import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../repositories/activity_repository.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final ActivityRepository _activityRepo = ActivityRepository();
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final results = await _activityRepo.getLogs();
    setState(() {
      _logs = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติการทำงาน (Audit Logs)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              separatorBuilder: (context, i) => const Divider(),
              itemBuilder: (context, i) {
                final log = _logs[i];
                final df = DateFormat('dd/MM/yyyy HH:mm:ss');
                final date = DateTime.parse(log['createdAt'].toString());

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getActionColor(log['action'].toString())
                        .withValues(alpha: 0.1),
                    child: Icon(_getActionIcon(log['action'].toString()),
                        color: _getActionColor(log['action'].toString())),
                  ),
                  title: Text(log['action'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log['details'] ?? ''),
                      const SizedBox(height: 4),
                      Text(
                        'โดย: ${log['displayName'] ?? log['username'] ?? "System"} | ${df.format(date)}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Color _getActionColor(String action) {
    if (action.contains('DELETE')) return Colors.red;
    if (action.contains('UPDATE')) return Colors.orange;
    if (action.contains('RETURN')) return Colors.blue;
    return Colors.grey;
  }

  IconData _getActionIcon(String action) {
    if (action.contains('DELETE')) return Icons.delete_forever;
    if (action.contains('UPDATE')) return Icons.edit_note;
    if (action.contains('RETURN')) return Icons.assignment_return;
    return Icons.info_outline;
  }
}
