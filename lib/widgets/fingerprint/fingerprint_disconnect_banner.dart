import 'package:flutter/material.dart';

/// Overlay widget แจ้งเตือนเมื่อเครื่องสแกนลายนิ้วมือหลุดการเชื่อมต่อ
/// แสดงที่มุมบนขวาของหน้าจอพร้อมปุ่มค้นหาเชื่อมต่อซ้ำ
class FingerprintDisconnectBanner extends StatefulWidget {
  final Future<bool> Function() onReconnect;
  final VoidCallback onDismiss;

  const FingerprintDisconnectBanner({
    super.key,
    required this.onReconnect,
    required this.onDismiss,
  });

  @override
  State<FingerprintDisconnectBanner> createState() =>
      FingerprintDisconnectBannerState();
}

class FingerprintDisconnectBannerState
    extends State<FingerprintDisconnectBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fadeSlide;
  bool _isReconnecting = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeSlide = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeSlide,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.3, 0),
          end: Offset.zero,
        ).animate(_fadeSlide),
        child: Container(
          width: 340,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade700, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.25),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---- Header ----
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.fingerprint,
                          color: Colors.redAccent, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'เครื่องสแกนหลุดการเชื่อมต่อ',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'ลายนิ้วมือไม่ถูกบันทึกในขณะนี้',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ปุ่มปิด
                    IconButton(
                      onPressed: widget.onDismiss,
                      icon: const Icon(Icons.close,
                          color: Colors.white38, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // ---- ปุ่มค้นหาใหม่ ----
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isReconnecting
                        ? null
                        : () async {
                            setState(() => _isReconnecting = true);
                            final connected = await widget.onReconnect();
                            if (mounted && !connected) {
                              setState(() => _isReconnecting = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.blue.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isReconnecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white54,
                            ),
                          )
                        : const Icon(Icons.wifi_find_rounded, size: 18),
                    label: Text(
                      _isReconnecting
                          ? 'กำลังค้นหา...'
                          : 'ค้นหาและเชื่อมต่อซ้ำ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
