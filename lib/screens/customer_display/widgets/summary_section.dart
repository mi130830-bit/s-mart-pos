import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import '../customer_display_provider.dart';

/// Right-top panel: shows the total, received amount, change, and a digital clock.
class SummarySection extends StatelessWidget {
  final CustomerDisplayState state;

  const SummarySection({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: Colors.blue.shade900,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _DigitalClock(),
              const SizedBox(height: 15),
              const SizedBox(width: 300, child: Divider(color: Colors.white24)),
              const SizedBox(height: 15),
              const Text('ยอดชำระ',
                  style: TextStyle(color: Colors.white70, fontSize: 20)),
              Text(
                NumberFormat('#,##0.00').format(state.total),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 60,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (state.mode == CustomerDisplayMode.success || state.received > 0) ...[
                const SizedBox(width: 300, child: Divider(color: Colors.white24)),
                const SizedBox(height: 10),
                SizedBox(
                  width: 300,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('รับเงิน:',
                              style: TextStyle(color: Colors.white, fontSize: 18)),
                          Text(
                            NumberFormat('#,##0.00').format(state.received),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('เงินทอน:',
                              style: TextStyle(color: Colors.white, fontSize: 18)),
                          Text(
                            NumberFormat('#,##0.00').format(state.change),
                            style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (state.mode == CustomerDisplayMode.success) ...[
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.greenAccent),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.greenAccent, size: 24),
                              SizedBox(width: 8),
                              Text('ชำระเงินสำเร็จ',
                                  style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Digital Clock (file-private, used only by SummarySection) ──────────────
class _DigitalClock extends StatefulWidget {
  const _DigitalClock();

  @override
  State<_DigitalClock> createState() => _DigitalClockState();
}

class _DigitalClockState extends State<_DigitalClock> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th', null);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          DateFormat('EEEE d MMMM yyyy', 'th').format(_now),
          style: const TextStyle(
              color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        Text(
          DateFormat('HH:mm:ss', 'th').format(_now),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2),
        ),
      ],
    );
  }
}
