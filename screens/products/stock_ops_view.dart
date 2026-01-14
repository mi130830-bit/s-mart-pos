import 'package:flutter/material.dart';

// Import หน้าจอทั้งหมดในโฟลเดอร์เดียวกัน
import 'stock_in_section.dart';
import 'stock_return_section.dart';
import 'stock_adjustment_section.dart';
import 'stock_card_view.dart';

// Export เพื่อให้ไฟล์อื่นเรียกใช้ผ่านไฟล์นี้ได้เลย
export 'stock_adjustment_section.dart';
export 'stock_in_section.dart';
export 'stock_return_section.dart';
export 'stock_card_view.dart';
// Export Dialog เพื่อให้ไฟล์ข้างนอกใช้ได้
export 'product_selection_dialog.dart';

// --- Main Wrapper ---
class StockOperationTab extends StatelessWidget {
  final String operationType;
  // ค่าที่เป็นไปได้: 'ADD', 'RETURN', 'ADJUST', 'CARD'

  const StockOperationTab({super.key, required this.operationType});

  @override
  Widget build(BuildContext context) {
    switch (operationType) {
      case 'RETURN':
        return const StockReturnSection();
      case 'ADJUST':
        return const StockAdjustmentSection();
      case 'CARD':
        return const StockCardView();
      case 'ADD':
      default:
        return const StockInSection();
    }
  }
}
