import 'dart:async';
import 'package:flutter/material.dart';

/// Floating Action Card แสดงเมื่อพนักงานสแกนนิ้วในสถานะที่ต้องเลือกสถานะเพิ่มเติม
/// (เช่น อยู่ในงาน → ออกชั่วคราว / เลิกงาน)
///
/// แสดงเป็น Overlay ที่มุมล่างขวาของจอ โดยไม่ขวางหน้าจอ POS หลัก
/// มี Countdown Timer auto-dismiss หากไม่มีการโต้ตอบภายใน [autoTimeoutSeconds]
class FingerprintActionCard extends StatefulWidget {
  final String employeeName;

  /// 'CLOCK_IN' = กำลังเข้างานอยู่ ยังไม่ได้ออก
  /// 'TEMP_LEAVE' = ออกชั่วคราวอยู่
  final String currentStatus;

  /// เรียกเมื่อผู้ใช้กดปุ่มเลือกสถานะ หรือ Timeout
  final void Function(String action) onActionSelected;

  /// จำนวนวินาที Auto-dismiss (default 30 วินาที)
  final int autoTimeoutSeconds;

  const FingerprintActionCard({
    super.key,
    required this.employeeName,
    required this.currentStatus,
    required this.onActionSelected,
    this.autoTimeoutSeconds = 30,
  });

  @override
  State<FingerprintActionCard> createState() => _FingerprintActionCardState();
}

class _FingerprintActionCardState extends State<FingerprintActionCard>
    with SingleTickerProviderStateMixin {
  late Timer _countdownTimer;
  late int _remaining;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _remaining = widget.autoTimeoutSeconds;

    // Slide-in animation จากด้านล่าง
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();

    // Countdown timer ลด 1 ทุกวินาที
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _countdownTimer.cancel();
        // Auto-dismiss โดยไม่เรียก callback (ไม่บันทึกอะไร)
        widget.onActionSelected('DISMISS');
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    _slideController.dispose();
    super.dispose();
  }

  void _handleAction(String action) {
    _countdownTimer.cancel();
    widget.onActionSelected(action);
  }

  @override
  Widget build(BuildContext context) {
    final isClockIn = widget.currentStatus == 'CLOCK_IN';

    return SlideTransition(
      position: _slideAnimation,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2235),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.blueAccent.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(),
              const Divider(height: 1, color: Color(0xFF2E3450)),
              // Body: Action Buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (isClockIn) ...[
                      _buildActionButton(
                        icon: Icons.directions_run,
                        label: 'ออกชั่วคราว',
                        sublabel: 'ออกไปทำธุระ แล้วจะกลับมา',
                        color: Colors.orange,
                        action: 'TEMP_LEAVE',
                      ),
                      const SizedBox(height: 10),
                      _buildActionButton(
                        icon: Icons.logout,
                        label: 'เลิกงาน',
                        sublabel: 'บันทึกเวลาเลิกงานของวันนี้',
                        color: Colors.redAccent,
                        action: 'CLOCK_OUT',
                      ),
                    ] else ...[
                      _buildActionButton(
                        icon: Icons.keyboard_return,
                        label: 'กลับเข้าทำงาน',
                        sublabel: 'เข้ามาทำงานต่อแล้ว',
                        color: Colors.green,
                        action: 'TEMP_RETURN',
                      ),
                      const SizedBox(height: 10),
                      _buildActionButton(
                        icon: Icons.logout,
                        label: 'เลิกงาน',
                        sublabel: 'บันทึกเวลาเลิกงานของวันนี้',
                        color: Colors.redAccent,
                        action: 'CLOCK_OUT',
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Countdown + ยกเลิก
                    _buildFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isClockIn = widget.currentStatus == 'CLOCK_IN';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fingerprint, color: Colors.blueAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.employeeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isClockIn ? '🟢 กำลังทำงานอยู่' : '🟠 ออกชั่วคราวอยู่',
                  style: TextStyle(
                    color: isClockIn ? Colors.green.shade400 : Colors.orange.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required String action,
  }) {
    return InkWell(
      onTap: () => _handleAction(action),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    // Progress: countdown จาก 1.0 → 0.0
    final progress = _remaining / widget.autoTimeoutSeconds;
    final progressColor = _remaining > 15
        ? Colors.blueAccent
        : _remaining > 8
            ? Colors.orange
            : Colors.red;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ปิดอัตโนมัติใน $_remaining วินาที',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: () => _handleAction('DISMISS'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            foregroundColor: Colors.white54,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('ยกเลิก', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
