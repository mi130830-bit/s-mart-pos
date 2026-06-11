import 'package:flutter/material.dart';

class SnackbarUtils {
  static void showLeft(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    
    final screenWidth = MediaQuery.of(context).size.width;
    // กำหนดความกว้าง SnackBar ประมาณ 350px และจัดให้อยู่มุมซ้ายล่าง
    final double snackbarWidth = 350.0;
    final double leftMargin = 24.0;
    final double rightMargin = screenWidth > (snackbarWidth + leftMargin * 2)
        ? screenWidth - snackbarWidth - leftMargin
        : leftMargin;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.teal.shade800,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          left: leftMargin,
          bottom: 24,
          right: rightMargin > 0 ? rightMargin : leftMargin,
        ),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
      ),
    );
  }
}
