import 'package:flutter/material.dart';

class AlertService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static OverlayEntry? _overlayEntry;

  static void show({
    required BuildContext context,
    required String message,
    required String type, // 'error', 'success', 'warning'
    Duration duration = const Duration(seconds: 3),
  }) {
    // Remove existing if any
    _overlayEntry?.remove();
    _overlayEntry = null;

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 20,
        left: 20,
        child: Material(
          color: Colors.transparent,
          child: _buildToast(message, type),
        ),
      ),
    );

    _overlayEntry = entry;
    Overlay.of(context).insert(entry);

    Future.delayed(duration, () {
      if (_overlayEntry == entry) {
        entry.remove();
        _overlayEntry = null;
      }
    });
  }

  static Widget _buildToast(String message, String type) {
    Color bg;
    IconData icon;
    Color textCol = Colors.white;

    switch (type) {
      case 'error':
        bg = Colors.red.shade600;
        icon = Icons.error_outline;
        break;
      case 'success':
        bg = Colors.green.shade600;
        icon = Icons.check_circle_outline;
        break;
      case 'warning':
        bg = Colors.amber.shade700;
        icon = Icons.warning_amber_rounded;
        break;
      default:
        bg = Colors.grey.shade800;
        icon = Icons.info_outline;
    }

    return Container(
      width: 300, // Fixed small width
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textCol, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textCol, fontSize: 14),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          // Close button? strictly auto-dismiss for now
        ],
      ),
    );
  }
}
