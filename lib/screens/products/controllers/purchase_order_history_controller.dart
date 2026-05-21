import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/supplier.dart';
import '../../../../repositories/stock_repository.dart';
import '../../../../services/logger_service.dart';

final poHistoryStockRepoProvider = Provider((ref) => StockRepository());

class PurchaseOrderHistoryState {
  final List<Map<String, dynamic>> orders;
  final bool isLoading;
  final DateTime? selectedDate;
  final int? selectedSupplierId;
  final String? selectedSupplierName;
  final String paymentFilter;
  final int currentPage;
  final bool hasNextPage;
  final String? errorMessage;

  PurchaseOrderHistoryState({
    this.orders = const [],
    this.isLoading = false,
    this.selectedDate,
    this.selectedSupplierId,
    this.selectedSupplierName,
    this.paymentFilter = 'ALL',
    this.currentPage = 1,
    this.hasNextPage = false,
    this.errorMessage,
  });

  PurchaseOrderHistoryState copyWith({
    List<Map<String, dynamic>>? orders,
    bool? isLoading,
    DateTime? selectedDate,
    bool clearDate = false,
    int? selectedSupplierId,
    String? selectedSupplierName,
    bool clearSupplier = false,
    String? paymentFilter,
    int? currentPage,
    bool? hasNextPage,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PurchaseOrderHistoryState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      selectedDate: clearDate ? null : (selectedDate ?? this.selectedDate),
      selectedSupplierId: clearSupplier ? null : (selectedSupplierId ?? this.selectedSupplierId),
      selectedSupplierName: clearSupplier ? null : (selectedSupplierName ?? this.selectedSupplierName),
      paymentFilter: paymentFilter ?? this.paymentFilter,
      currentPage: currentPage ?? this.currentPage,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final purchaseOrderHistoryProvider = AutoDisposeNotifierProvider<PurchaseOrderHistoryController, PurchaseOrderHistoryState>(
  () => PurchaseOrderHistoryController(),
);

class PurchaseOrderHistoryController extends AutoDisposeNotifier<PurchaseOrderHistoryState> {
  late final StockRepository _stockRepo;
  final int _limit = 25;
  bool _mounted = true;

  @override
  PurchaseOrderHistoryState build() {
    _stockRepo = ref.read(poHistoryStockRepoProvider);
    _mounted = true;
    ref.onDispose(() => _mounted = false);
    
    Future.microtask(() {
      if (_mounted) loadData();
    });
    
    return PurchaseOrderHistoryState();
  }

  void clearError() {
    if (_mounted) state = state.copyWith(clearError: true);
  }

  void setDate(DateTime? date) {
    if (!_mounted) return;
    state = state.copyWith(
      selectedDate: date,
      clearDate: date == null,
      currentPage: 1,
    );
    loadData();
  }

  void setSupplier(Supplier? supplier) {
    if (supplier != null) {
      if (supplier.id == state.selectedSupplierId) return;
      if (!_mounted) return;
      state = state.copyWith(
        selectedSupplierId: supplier.id,
        selectedSupplierName: supplier.name,
        currentPage: 1,
      );
      loadData();
    }
  }

  void clearSupplier() {
    if (!_mounted) return;
    state = state.copyWith(
      clearSupplier: true,
      currentPage: 1,
    );
    loadData();
  }

  void setPaymentFilter(String filter) {
    if (filter != state.paymentFilter) {
      if (!_mounted) return;
      state = state.copyWith(
        paymentFilter: filter,
        currentPage: 1,
      );
      loadData();
    }
  }
  
  void nextPage() {
    if (state.hasNextPage) {
      if (!_mounted) return;
      state = state.copyWith(currentPage: state.currentPage + 1);
      loadData();
    }
  }
  
  void prevPage() {
    if (state.currentPage > 1) {
      if (!_mounted) return;
      state = state.copyWith(currentPage: state.currentPage - 1);
      loadData();
    }
  }

  Future<void> loadData() async {
    if (!_mounted) return;
    state = state.copyWith(isLoading: true);

    try {
      DateTime? startDate;
      DateTime? endDate;
      if (state.selectedDate != null) {
        startDate = DateTime(state.selectedDate!.year, state.selectedDate!.month,
            state.selectedDate!.day, 0, 0, 0);
        endDate = DateTime(state.selectedDate!.year, state.selectedDate!.month,
            state.selectedDate!.day, 23, 59, 59);
      }
      
      bool? isPaidFilter;
      if (state.paymentFilter == 'UNPAID') isPaidFilter = false;
      if (state.paymentFilter == 'PAID') isPaidFilter = true;

      final received = await _stockRepo.getPurchaseOrders(
        status: 'RECEIVED',
        startDate: startDate,
        endDate: endDate,
        supplierId: state.selectedSupplierId,
        isPaid: isPaidFilter,
        limit: _limit + 1,
        offset: (state.currentPage - 1) * _limit,
      );

      bool hasNext = false;
      if (received.length > _limit) {
        hasNext = true;
        received.removeLast();
      }

      received.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
      
      if (_mounted) {
        state = state.copyWith(
          orders: received,
          hasNextPage: hasNext,
          isLoading: false,
        );
      }
    } catch (e, stackTrace) {
      LoggerService.error('POHistory', 'Failed to load data', e, stackTrace);
      if (_mounted) {
        state = state.copyWith(
          errorMessage: 'ไม่สามารถโหลดข้อมูลได้: $e',
          isLoading: false,
        );
      }
    }
  }

  Future<bool> deleteOrder(int poId) async {
    try {
      await _stockRepo.deletePurchaseOrder(poId);
      await loadData();
      return true;
    } catch (e, stackTrace) {
      LoggerService.error('POHistory', 'Failed to delete PO $poId', e, stackTrace);
      if (_mounted) {
        state = state.copyWith(errorMessage: 'เกิดข้อผิดพลาดในการลบ: $e');
      }
      return false;
    }
  }

  Future<bool> togglePaymentStatus(Map<String, dynamic> order) async {
    final poId = int.tryParse(order['id'].toString()) ?? 0;
    if (poId == 0) return false;
    
    final currentStatus =
        (int.tryParse(order['isPaid']?.toString() ?? '0') ?? 0) == 1;
    final newStatus = !currentStatus;

    try {
      await _stockRepo.updatePaymentStatus(poId, newStatus);
      // Update local state by rebuilding the list
      if (_mounted) {
        final newOrders = List<Map<String, dynamic>>.from(state.orders);
        final index = newOrders.indexWhere((o) => o['id'] == order['id']);
        if (index != -1) {
          final updatedOrder = Map<String, dynamic>.from(newOrders[index]);
          updatedOrder['isPaid'] = newStatus ? 1 : 0;
          newOrders[index] = updatedOrder;
          state = state.copyWith(orders: newOrders);
        }
      }
      return newStatus;
    } catch (e, stackTrace) {
      LoggerService.error('POHistory', 'Failed to toggle payment $poId', e, stackTrace);
      if (_mounted) {
        state = state.copyWith(errorMessage: 'ไม่สามารถอัปเดตสถานะได้: $e');
      }
      return currentStatus;
    }
  }
  
  Future<List<Map<String, dynamic>>> getOrderItems(int poId) async {
    try {
      return await _stockRepo.getPurchaseOrderItems(poId);
    } catch (e, stackTrace) {
      LoggerService.error('POHistory', 'Failed to get order items', e, stackTrace);
      if (_mounted) {
        state = state.copyWith(errorMessage: 'ไม่สามารถโหลดรายการสินค้าได้: $e');
      }
      return [];
    }
  }
  
  Future<bool> updateReceivedOrder(Map<String, dynamic> order, List<Map<String, dynamic>> items) async {
    try {
      final poId = int.tryParse(order['id'].toString()) ?? 0;
      if (poId == 0) return false;

      final vatType = int.tryParse(order['vatType']?.toString() ?? '0') ?? 0;
      final isPaid = (int.tryParse(order['isPaid']?.toString() ?? '0') ?? 0) == 1;
      final documentNo = order['documentNo']?.toString();

      double subtotal = items.fold(0.0, (s, item) {
        final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        final cost = double.tryParse(item['costPrice'].toString()) ?? 0.0;
        return s + (qty * cost);
      });
      
      double totalWithVat = subtotal;
      if (vatType == 1) totalWithVat = subtotal * 1.07;

      await _stockRepo.updateReceivedPurchaseOrderQty(
        poId: poId,
        newItems: items,
        totalAmount: totalWithVat,
        documentNo: documentNo,
        vatType: vatType,
        isPaid: isPaid,
      );
      await loadData();
      return true;
    } catch (e, stackTrace) {
      LoggerService.error('POHistory', 'Failed to update received PO', e, stackTrace);
      if (_mounted) {
        state = state.copyWith(errorMessage: 'เกิดข้อผิดพลาดในการแก้ไข: $e');
      }
      return false;
    }
  }
}
