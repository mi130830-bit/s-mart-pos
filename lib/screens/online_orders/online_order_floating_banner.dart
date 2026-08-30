import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/online_orders_provider.dart';
import 'online_orders_screen.dart';

class OnlineOrderFloatingBanner extends ConsumerStatefulWidget {
  const OnlineOrderFloatingBanner({super.key});

  @override
  ConsumerState<OnlineOrderFloatingBanner> createState() =>
      _OnlineOrderFloatingBannerState();
}

class _OnlineOrderFloatingBannerState
    extends ConsumerState<OnlineOrderFloatingBanner>
    with SingleTickerProviderStateMixin {
  int _dismissedCount = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(onlineOrdersPendingCountProvider);

    // If no pending orders, reset dismissal and hide
    if (pendingCount <= 0) {
      _dismissedCount = 0;
      return const SizedBox.shrink();
    }

    // If dismissed for this count, hide until a new order arrives
    if (pendingCount <= _dismissedCount) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF059669), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing Notification Icon with Badge
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: Badge(
                  label: Text(
                    pendingCount.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  backgroundColor: Colors.red.shade600,
                  child: const Icon(
                    Icons.notifications_active,
                    color: Color(0xFF059669),
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Content Text
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'มีคำสั่งซื้อออนไลน์ใหม่!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ค้างอยู่ $pendingCount รายการรอตรวจสอบ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Action Button: Open Orders
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OnlineOrdersScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                'ดูออเดอร์',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),

            const SizedBox(width: 4),

            // Dismiss Button
            IconButton(
              onPressed: () {
                setState(() {
                  _dismissedCount = pendingCount;
                });
              },
              icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
              tooltip: 'ซ่อนชั่วคราว',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }
}
