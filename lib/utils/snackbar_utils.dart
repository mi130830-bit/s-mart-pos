import 'package:flutter/material.dart';
import '../services/alert_service.dart';

class SnackbarUtils {
  static void showLeft(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    
    // เรียกใช้งาน AlertService ที่มีอยู่แล้ว ซึ่งใช้ OverlayEntry 
    // ทำให้ตัวกล่องมีขนาดพอดีกับข้อความ (wrap_content) สวยงามกว่า SnackBar ปกติ
    AlertService.show(
      context: context,
      message: message,
      type: isError ? 'error' : 'success',
    );
  }
}
