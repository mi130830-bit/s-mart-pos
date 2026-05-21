import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../repositories/product_repository.dart';
import '../../../repositories/sales_repository.dart';
import '../../../services/alert_service.dart';
import '../../../services/logger_service.dart';
import '../../../widgets/common/confirm_dialog.dart';

// Model สำหรับเก็บรายการในตะกร้าคืนของ
class ReturnEntry {
  final int orderId;
  final int productId;
  final String productName;
  final double price;
  double returnQty;
  final double maxReturnable; // จำนวนสูงสุดที่คืนได้ (ซื้อ - คืนไปแล้ว)
  final String customerName;

  ReturnEntry({
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.returnQty,
    required this.maxReturnable,
    required this.customerName,
  });

  double get totalRefund => returnQty * price;
}

class StockReturnState {
  final List<ReturnEntry> returnItems;
  final bool isLoading;

  StockReturnState({
    this.returnItems = const [],
    this.isLoading = false,
  });

  StockReturnState copyWith({
    List<ReturnEntry>? returnItems,
    bool? isLoading,
  }) {
    return StockReturnState(
      returnItems: returnItems ?? this.returnItems,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  double get totalRefundAmount =>
      returnItems.fold(0.0, (sum, item) => sum + item.totalRefund);
}

final stockReturnProvider = AutoDisposeNotifierProvider<StockReturnController, StockReturnState>(
  () => StockReturnController(),
);

class StockReturnController extends AutoDisposeNotifier<StockReturnState> {
  final ProductRepository _productRepo = ProductRepository();
  final SalesRepository _salesRepo = SalesRepository();
  bool _mounted = true;

  ProductRepository get productRepo => _productRepo;

  @override
  StockReturnState build() {
    _mounted = true;
    ref.onDispose(() => _mounted = false);
    return StockReturnState();
  }

  // --- API / DB Operations ---

  Future<Map<String, dynamic>?> searchOrder(int orderId) async {
    return await _salesRepo.getOrderWithItems(orderId);
  }

  Future<List<Map<String, dynamic>>> findOrdersByProduct(int productId) async {
    _setLoading(true);
    final orders = await _salesRepo.findOrdersByProduct(productId);
    _setLoading(false);
    return orders;
  }

  void addReturnEntry(ReturnEntry entry) {
    if (!_mounted) return;
    state = state.copyWith(
      returnItems: [...state.returnItems, entry],
    );
  }

  void removeReturnEntry(int index) {
    if (!_mounted) return;
    if (index >= 0 && index < state.returnItems.length) {
      final newItems = List<ReturnEntry>.from(state.returnItems);
      newItems.removeAt(index);
      state = state.copyWith(returnItems: newItems);
    }
  }

  void updateReturnQty(int index, double newQty) {
    if (!_mounted) return;
    if (index >= 0 && index < state.returnItems.length && newQty > 0) {
      final newItems = List<ReturnEntry>.from(state.returnItems);
      newItems[index].returnQty = newQty;
      state = state.copyWith(returnItems: newItems);
    }
  }

  Future<void> saveReturnBatch(BuildContext context) async {
    if (state.returnItems.isEmpty) return;

    bool confirm = await ConfirmDialog.show(
          context,
          title: 'ยืนยันการคืนสินค้า',
          content:
              'ต้องการคืนสินค้าจำนวน ${state.returnItems.length} รายการ\nรวมเป็นเงิน ${NumberFormat('#,##0.00').format(state.totalRefundAmount)} บาท หรือไม่?',
          confirmText: 'ยืนยัน',
          cancelText: 'ยกเลิก',
        ) ??
        false;

    if (!confirm) return;

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    int successCount = 0;
    int failCount = 0;
    
    // Create a local copy to iterate
    final itemsToReturn = List<ReturnEntry>.from(state.returnItems);
    
    for (var item in itemsToReturn) {
      try {
        bool res = await _salesRepo.processReturn(
          orderId: item.orderId,
          productId: item.productId,
          productName: item.productName,
          returnQty: item.returnQty,
          price: item.price,
        );
        if (res) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e, stackTrace) {
        failCount++;
        LoggerService.error('StockReturn', 'Failed to process return for ${item.productName}', e, stackTrace);
      }
    }

    if (!context.mounted) return;
    Navigator.pop(context); // ปิด Loading

    if (failCount > 0) {
      AlertService.show(
        context: context,
        message: 'มีข้อผิดพลาด $failCount รายการ, สำเร็จ $successCount รายการ',
        type: 'warning',
      );
    } else {
      AlertService.show(
        context: context,
        message: 'บันทึกคืนสำเร็จ $successCount รายการ',
        type: 'success',
      );
    }

    if (_mounted) {
      state = state.copyWith(returnItems: []);
    }
  }

  void _setLoading(bool value) {
    if (_mounted) {
      state = state.copyWith(isLoading: value);
    }
  }
}
