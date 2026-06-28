import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/hr/attendance_log.dart';

class TempLeaveTimeline extends StatelessWidget {
  final AttendanceLog log;
  final bool isOnTempLeave;

  const TempLeaveTimeline({
    super.key,
    required this.log,
    required this.isOnTempLeave,
  });

  @override
  Widget build(BuildContext context) {
    if (isOnTempLeave) {
      return _buildInlineTempLeaveActive(log);
    } else {
      return _buildExpandedTimeline(log);
    }
  }

  Widget _buildInlineTempLeaveActive(AttendanceLog log) {
    final activeOut = log.latestTempOutTime!;
    final elapsed = DateTime.now().difference(activeOut);
    final roundNum = log.activeTempLeaveRound ?? 1;
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (log.clockIn != null)
          _buildTimeChip(
            Icons.login, DateFormat('HH:mm').format(log.clockIn!),
            Colors.green, 'เข้า',
          ),
        const Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
        _buildTimeChip(
          Icons.directions_run, DateFormat('HH:mm').format(activeOut),
          Colors.orange, 'ออก(รอบ $roundNum)',
        ),
        const Icon(Icons.more_horiz, size: 12, color: Colors.orange),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '⏱ ${_formatDuration(elapsed)}',
            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedTimeline(AttendanceLog log) {
    // สร้าง list ของ record แต่ละรอบที่มีข้อมูล
    final List<({DateTime out, DateTime? back, int round})> rounds = [];
    if (log.tempOut != null) rounds.add((out: log.tempOut!, back: log.backToWork, round: 1));
    if (log.tempOut2 != null) rounds.add((out: log.tempOut2!, back: log.backToWork2, round: 2));
    if (log.tempOut3 != null) rounds.add((out: log.tempOut3!, back: log.backToWork3, round: 3));

    if (rounds.isEmpty) return const SizedBox.shrink();

    final totalMins = log.totalTempLeaveMinutes;

    return Container(
      margin: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ประวัติออกชั่วคราว (${rounds.length} รอบ)',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 8),
          // วนแสดงทุกรอบ
          ...rounds.map((r) {
            final duration = r.back?.difference(r.out);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text('รอบ ${r.round}:', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(width: 6),
                  if (log.clockIn != null && r.round == 1) ...[
                    _buildTimelineStep(
                      icon: Icons.login,
                      label: 'เข้างาน',
                      time: DateFormat('HH:mm').format(log.clockIn!),
                      color: Colors.green,
                    ),
                    _buildTimelineConnector(null),
                  ],
                  _buildTimelineStep(
                    icon: Icons.directions_run,
                    label: 'ออก',
                    time: DateFormat('HH:mm').format(r.out),
                    color: Colors.orange,
                  ),
                  if (r.back != null) ...[
                    _buildTimelineConnector(duration),
                    _buildTimelineStep(
                      icon: Icons.keyboard_return,
                      label: 'กลับ',
                      time: DateFormat('HH:mm').format(r.back!),
                      color: Colors.blue,
                    ),
                  ] else ...[
                    _buildTimelineConnector(null),
                    const Icon(Icons.more_horiz, size: 14, color: Colors.orange),
                  ],
                ],
              ),
            );
          }),
          if (totalMins > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '⏱ ออกนอกรวมทั้งหมด ${_formatDuration(Duration(minutes: totalMins))}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(IconData icon, String time, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text('$label $time', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({required IconData icon, required String label, required String time, required Color color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        Text(time, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTimelineConnector(Duration? duration) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 2,
                  color: Colors.orange.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          if (duration != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _formatDuration(duration),
                style: const TextStyle(fontSize: 9, color: Colors.orange),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      return m > 0 ? '$h ชั่วม $m นาที' : '$h ชั่วม';
    }
    return '${d.inMinutes} นาที';
  }
}
