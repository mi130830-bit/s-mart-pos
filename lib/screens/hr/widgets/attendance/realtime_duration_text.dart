import 'dart:async';
import 'package:flutter/material.dart';

class RealtimeDurationText extends StatefulWidget {
  final DateTime startTime;
  final String prefix;
  final TextStyle style;

  const RealtimeDurationText({
    super.key,
    required this.startTime,
    required this.prefix,
    required this.style,
  });

  @override
  State<RealtimeDurationText> createState() => _RealtimeDurationTextState();
}

class _RealtimeDurationTextState extends State<RealtimeDurationText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) return '${duration.inMinutes} นาที';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '$hours ชม. $minutes นาที';
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startTime);
    return Text(
      '${widget.prefix} ${_formatDuration(elapsed)} แล้ว',
      style: widget.style,
    );
  }
}
