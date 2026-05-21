import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/outstanding_bill.dart';
import '../../../../repositories/debtor_repository.dart';
import '../../../../repositories/sales_repository.dart';
import '../../../../repositories/customer_repository.dart';
import '../../../../services/printing/receipt_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../models/customer.dart';
import '../../../../models/order_item.dart';
import '../../../../services/alert_service.dart';

class DebtorListState {
  final List<OutstandingBill> allTransactions;
  final List<OutstandingBill> filteredTransactions;
  final double summaryTotalDebt;
  final int summaryDebtorCount;
  final bool isLoading;
  final bool isSendingAlerts;
  final String sortOption;
  final String searchQuery;

  DebtorListState({
    this.allTransactions = const [],
    this.filteredTransactions = const [],
    this.summaryTotalDebt = 0.0,
    this.summaryDebtorCount = 0,
    this.isLoading = true,
    this.isSendingAlerts = false,
    this.sortOption = 'OUTSTANDING_NEW',
    this.searchQuery = '',
  });

  DebtorListState copyWith({
    List<OutstandingBill>? allTransactions,
    List<OutstandingBill>? filteredTransactions,
    double? summaryTotalDebt,
    int? summaryDebtorCount,
    bool? isLoading,
    bool? isSendingAlerts,
    String? sortOption,
    String? searchQuery,
  }) {
    return DebtorListState(
      allTransactions: allTransactions ?? this.allTransactions,
      filteredTransactions: filteredTransactions ?? this.filteredTransactions,
      summaryTotalDebt: summaryTotalDebt ?? this.summaryTotalDebt,
      summaryDebtorCount: summaryDebtorCount ?? this.summaryDebtorCount,
      isLoading: isLoading ?? this.isLoading,
      isSendingAlerts: isSendingAlerts ?? this.isSendingAlerts,
      sortOption: sortOption ?? this.sortOption,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final debtorListProvider = AutoDisposeNotifierProvider<DebtorListController, DebtorListState>(
  () => DebtorListController(),
);

class DebtorListController extends AutoDisposeNotifier<DebtorListState> {
  final DebtorRepository debtorRepo = DebtorRepository();
  final SalesRepository salesRepo = SalesRepository();
  final CustomerRepository customerRepo = CustomerRepository();
  final ReceiptService receiptService = ReceiptService();

  bool _mounted = true;

  @override
  DebtorListState build() {
    _mounted = true;
    ref.onDispose(() => _mounted = false);
    
    // Trigger loadData safely
    Future.microtask(() {
      if (_mounted) loadData();
    });
    
    return DebtorListState();
  }

  Future<void> loadData() async {
    if (!_mounted) return;
    state = state.copyWith(isLoading: true);
    
    try {
      final transactions = await debtorRepo.getOutstandingCreditSales();

      final double total = transactions.fold(0.0, (sum, t) => sum + t.remaining);
      final uniqueCustomers = transactions.map((t) => t.customerId).toSet().length;

      if (!_mounted) return;
      state = state.copyWith(
        allTransactions: transactions,
        filteredTransactions: transactions,
        summaryTotalDebt: total,
        summaryDebtorCount: uniqueCustomers,
        isLoading: false,
      );

      if (state.searchQuery.isNotEmpty) {
        onSearch(state.searchQuery);
      } else {
        sortTransactions();
      }
    } catch (e) {
      if (!_mounted) return;
      state = state.copyWith(isLoading: false);
      debugPrint('Error loading debtor data: $e');
    }
  }

  void onSearch(String val) {
    if (!_mounted) return;
    final query = val.toLowerCase();
    
    List<OutstandingBill> newFiltered;
    if (query.isEmpty) {
      newFiltered = state.allTransactions;
    } else {
      newFiltered = state.allTransactions.where((t) {
        final name = t.customerName.toLowerCase();
        final phone = (t.phone ?? '').toLowerCase();
        final bill = t.orderId.toString();
        return name.contains(query) || phone.contains(query) || bill.contains(query);
      }).toList();
    }
    
    state = state.copyWith(
      searchQuery: query,
      filteredTransactions: newFiltered,
    );
    sortTransactions();
  }

  void setSortOption(String val) {
    if (!_mounted) return;
    state = state.copyWith(sortOption: val);
    sortTransactions();
  }

  void sortTransactions() {
    if (!_mounted) return;
    
    final sortedList = List<OutstandingBill>.from(state.filteredTransactions);
    sortedList.sort((a, b) {
      if (state.sortOption.startsWith('OUTSTANDING')) {
        final aUnpaid = a.remaining > 0.01;
        final bUnpaid = b.remaining > 0.01;
        if (aUnpaid && !bUnpaid) return -1;
        if (!aUnpaid && bUnpaid) return 1;
      }

      final dateA = a.createdAt;
      final dateB = b.createdAt;

      if (state.sortOption.contains('NEW')) {
        return dateB.compareTo(dateA);
      } else {
        return dateA.compareTo(dateB);
      }
    });
    
    state = state.copyWith(filteredTransactions: sortedList);
  }

  Future<void> sendBulkDebtAlerts(BuildContext context) async {
    if (!_mounted) return;
    state = state.copyWith(isSendingAlerts: true);

    final Map<int, OutstandingBill> uniqueDebtors = {};
    for (var t in state.allTransactions) {
      if (t.lineUserId != null && t.lineUserId!.isNotEmpty) {
        if (!uniqueDebtors.containsKey(t.customerId)) {
          uniqueDebtors[t.customerId] = t;
        }
      }
    }

    if (uniqueDebtors.isEmpty) {
      if (_mounted) state = state.copyWith(isSendingAlerts: false);
      if (!context.mounted) return;
      AlertService.show(
          context: context,
          message: 'ไม่พบลูกหนี้ที่ผูก LINE Account เลย',
          type: 'warning');
      return;
    }

    int successCount = 0;
    try {
      final notificationService = NotificationService();
      for (var debtor in uniqueDebtors.values) {
        final message = '📢 แจ้งเตือนยอดค้างชำระ\n\n'
            'เรียนคุณ ${debtor.customerName}\n'
            'ขณะนี้มียอดค้างชำระคงเหลือ: ฿${NumberFormat('#,##0.00').format(debtor.currentDebt)}\n\n'
            'สามารถตรวจสอบรายละเอียดบิลทั้งหมดหรือติดต่อชำระเงินได้ที่ร้าน ส.บริการ ท่าข้าม นะครับ 🙏';

        try {
          final isSuccess = await notificationService.sendLinePushMessage(
            lineUserId: debtor.lineUserId!,
            message: message,
          );
          if (isSuccess) successCount++;
        } catch (e) {
          debugPrint('Failed to send to ${debtor.customerName}: $e');
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      debugPrint('Bulk Alert Error: $e');
    }

    if (_mounted) state = state.copyWith(isSendingAlerts: false);
    if (!context.mounted) return;
    AlertService.show(
        context: context,
        message: 'ส่งสำเร็จ $successCount จาก ${uniqueDebtors.length} ราย',
        type: successCount > 0 ? 'success' : 'warning');
  }

  Future<void> executePrint(BuildContext context, int orderId, String type) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final fullOrderData = await salesRepo.getOrderWithItems(orderId);
      if (fullOrderData == null) {
        if (context.mounted) Navigator.pop(context);
        return;
      }

      final orderData = fullOrderData['order'];
      final items = fullOrderData['items'] as List<OrderItem>;

      int customerId = int.tryParse(orderData['customerId'].toString()) ?? 0;
      Customer? customer;
      if (customerId > 0) {
        customer = await customerRepo.getCustomerById(customerId);
      }
      customer ??= Customer(
        id: 0,
        memberCode: '',
        currentPoints: 0,
        firstName: orderData['firstName'] ?? 'ลูกค้าทั่วไป',
        lastName: orderData['lastName'],
        phone: orderData['phone'],
        address: orderData['address'] ?? '',
      );

      final grandTotal = double.tryParse(orderData['grandTotal'].toString()) ?? 0.0;
      final discount = double.tryParse(orderData['discount'].toString()) ?? 0.0;
      final total = double.tryParse(orderData['total'].toString()) ?? grandTotal;
      final received = double.tryParse(orderData['received'].toString()) ?? 0.0;
      final change = double.tryParse(orderData['changeAmount'].toString()) ?? 0.0;

      if (!context.mounted) return;
      Navigator.pop(context); // Pop loading dialog

      if (type == 'RECEIPT') {
        await receiptService.printReceipt(
          orderId: orderId,
          items: items,
          total: total,
          discount: discount,
          grandTotal: grandTotal,
          received: received,
          change: change,
          customer: customer,
          isPreview: false,
        );
      } else if (type == 'DELIVERY') {
        await receiptService.printDeliveryNote(
          orderId: orderId,
          items: items,
          customer: customer,
          discount: discount,
          isPreview: false,
        );
      } else if (type == 'SAVE_RECEIPT_PDF') {
        await receiptService.printReceipt(
          orderId: orderId,
          items: items,
          total: total,
          discount: discount,
          grandTotal: grandTotal,
          received: received,
          change: change,
          customer: customer,
          isPreview: true,
          useCashBillSettings: true,
        );
      } else if (type == 'SAVE_DELIVERY_PDF') {
        await receiptService.printDeliveryNote(
          orderId: orderId,
          items: items,
          customer: customer,
          discount: discount,
          isPreview: true,
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      debugPrint("Print Error: $e");
      if (context.mounted) {
        AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
      }
    }
  }
}
