import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:screen_retriever/screen_retriever.dart';
import '../models/order_item.dart';

class CustomerDisplayService {
  static final CustomerDisplayService _instance =
      CustomerDisplayService._internal();

  factory CustomerDisplayService() {
    return _instance;
  }

  CustomerDisplayService._internal();

  dynamic _windowId; // ใช้ dynamic เพราะอาจเป็น int หรือ String (UUID)
  bool get isOpen => _windowId != null;



  Map<String, dynamic> _lastKnownState = {}; // ✅ Cache last state
  
  /// ✅ ส่งคำสั่งสั่งโหลดการตั้งค่าใหม่ (ใช้เมื่อมีการซิงก์จาก SyncService)
  Future<void> reloadSettings() async {
    if (_windowId == null) return;
    try {
      await WindowController.fromWindowId(_windowId!.toString())
          .invokeMethod('reload_settings', '');
    } catch (e) {
      debugPrint('⚠️ Error sending reload to customer display: $e');
    }
  }

  /// เขียนข้อมูลผ่าน IPC (Method Channel)
  Future<void> _sendToWindow(Map<String, dynamic> data) async {
    // ✅ Cache state
    _lastKnownState = data;
    
    if (_windowId == null) {
      // ถ้าหน้าต่างยังไม่เปิด ให้บันทึกไว้รอเปิด
      return;
    }

    try {
      await WindowController.fromWindowId(_windowId!.toString())
          .invokeMethod('update_state', jsonEncode(data));
    } catch (e) {
      debugPrint('⚠️ Error sending data to customer display: $e');
    }
  }

  /// ✅ Update Font Size in Real-time
  Future<void> updateFontSize(double fontSize) async {
    final newState = Map<String, dynamic>.from(_lastKnownState);

    // Create or update settings object
    final settings = Map<String, dynamic>.from(newState['settings'] ?? {});
    settings['fontSize'] = fontSize;
    newState['settings'] = settings;

    // Update timestamp to trigger reload
    newState['timestamp'] = DateTime.now().millisecondsSinceEpoch;

    await _sendToWindow(newState);
  }

  /// เปิดหน้าต่างลูกค้า
  Future<void> openDisplay() async {
    if (_windowId != null) return;

    try {
      double x = 0;
      double y = 0;
      double width = 1280;
      double height = 720;

      try {
        List<Display> displays =
            await ScreenRetriever.instance.getAllDisplays();
        if (displays.length > 1) {
          Display? targetDisplay;

          // สูตรใหม่: หาจอที่ตำแหน่งไม่ใช่ (0,0) ซึ่งมักจะเป็นจอที่ 2
          try {
            targetDisplay = displays.firstWhere(
              (d) {
                final dx = d.visiblePosition?.dx ?? 0;
                final dy = d.visiblePosition?.dy ?? 0;
                // เลือกจอที่ไม่อยู่ที่จุด 0,0
                return dx != 0 || dy != 0;
              },
              orElse: () => displays.last, // ถ้าไม่เจอ ให้ใช้จอล่างสุดในลิสต์
            );
          } catch (e) {
            targetDisplay = displays.last;
          }

          // targetDisplay is non-null due to try/catch logic above
          final pos = targetDisplay.visiblePosition;
          x = pos?.dx ?? 0;
          y = pos?.dy ?? 0;

          width = targetDisplay.size.width;
          height = targetDisplay.size.height;

          // Fallback: ถ้ายังได้ 0,0 แต่มีมากกว่า 1 จอ ให้เดาว่าจอ 2 อยู่ขวาของจอหลัก
          if (x == 0 && y == 0) {
            // Check if we have a primary display size to offset from
            if (displays.isNotEmpty) {
              x = displays.first.size.width;
            } else {
              x = 1920; // Default fallback
            }
          }

          debugPrint('🖥️ Target Display: $x,$y ($width x $height)');
        }
      } catch (e) {
        debugPrint('Screen Retriever Error: $e');
      }

      final args = {
        'args1': 'customer_display',
        'width': width,
        'height': height,
        'x': x,
        'y': y,
        'fullscreen': true,
      };

      final window = await WindowController.create(
          WindowConfiguration(arguments: jsonEncode(args)));

      _windowId = window.windowId;
      debugPrint('🚀 Customer Display Created: ID=$_windowId');

      await Future.delayed(const Duration(milliseconds: 200));
      await window.show();

      // เริ่มต้นด้วยหน้าว่าง
      await showIdle();
    } catch (e) {
      debugPrint('Error opening customer display: $e');
      _windowId = null;
    }
  }

  /// ปิดหน้าต่าง
  Future<void> closeDisplay() async {
    if (_windowId == null) return;
    try {
      // Loop close implementation if needed
    } catch (e) {
      debugPrint('Error closing display: $e');
    }
    _windowId = null;
  }

  Future<void> updateCart({
    required double total,
    required List<OrderItem> items,
    double received = 0.0,
    double change = 0.0,
  }) async {
    final mappedItems = items.map((item) {
      return {
        'name': item.productName,
        'qty': item.quantity.toDouble(),
        'price': item.price.toDouble(),
        'total': item.total.toDouble(),
      };
    }).toList();

    await _sendToWindow({
      'state': 'active',
      'total': total,
      'received': received,
      'change': change,
      'items': mappedItems,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> showIdle() async {
    await _sendToWindow({
      'state': 'idle',
      'total': 0.0,
      'items': [],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> showQrCode({
    required String qrData,
    required double amount,
    required double total,
    required List<OrderItem> items,
    double received = 0.0,
    double change = 0.0,
  }) async {
    final mappedItems = items.map((item) {
      return {
        'name': item.productName,
        'qty': item.quantity.toDouble(),
        'price': item.price.toDouble(),
        'total': item.total.toDouble(),
      };
    }).toList();

    await _sendToWindow({
      'state': 'payment',
      'qrData': qrData,
      'amount': amount,
      'total': total,
      'received': received,
      'change': change,
      'items': mappedItems,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> showSuccess({
    double received = 0.0,
    double change = 0.0,
    double total = 0.0,
    List<OrderItem> items = const [],
  }) async {
    final mappedItems = items.map((item) {
      return {
        'name': item.productName,
        'qty': item.quantity.toDouble(),
        'price': item.price.toDouble(),
        'total': item.total.toDouble(),
      };
    }).toList();

    await _sendToWindow({
      'state': 'success',
      'total': total,
      'received': received,
      'change': change,
      'items': mappedItems,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    // Removed auto-reset to idle
  }
}
