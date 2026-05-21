import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/customer.dart';
import '../../../models/billing_note.dart';
import '../../../models/billing_note_item.dart';
import '../../../models/outstanding_bill.dart';
import '../../../repositories/customer_repository.dart';
import '../../../repositories/billing_repository.dart';
import '../../../repositories/debtor_repository.dart';
import '../../../services/alert_service.dart';
import '../../../services/logger_service.dart';

class CreateBillingState {
  final List<Customer> allCustomers;
  final Customer? selectedCustomer;
  final List<OutstandingBill> activeBills;
  final bool isLoading;

  CreateBillingState({
    this.allCustomers = const [],
    this.selectedCustomer,
    this.activeBills = const [],
    this.isLoading = false,
  });

  double get totalAmount => activeBills.fold(0.0, (sum, item) => sum + item.remaining);

  CreateBillingState copyWith({
    List<Customer>? allCustomers,
    Customer? selectedCustomer,
    List<OutstandingBill>? activeBills,
    bool? isLoading,
  }) {
    return CreateBillingState(
      allCustomers: allCustomers ?? this.allCustomers,
      selectedCustomer: selectedCustomer ?? this.selectedCustomer,
      activeBills: activeBills ?? this.activeBills,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final createBillingProvider = AutoDisposeNotifierProvider<CreateBillingController, CreateBillingState>(
  () => CreateBillingController(),
);

class CreateBillingController extends AutoDisposeNotifier<CreateBillingState> {
  final CustomerRepository _customerRepo = CustomerRepository();
  final BillingRepository _billingRepo = BillingRepository();
  final DebtorRepository _debtorRepo = DebtorRepository();

  bool _mounted = true;

  @override
  CreateBillingState build() {
    _mounted = true;
    ref.onDispose(() => _mounted = false);
    return CreateBillingState();
  }

  Future<void> loadCustomers(BuildContext context) async {
    if (!_mounted) return;
    state = state.copyWith(isLoading: true);
    
    try {
      final allCustomers = await _customerRepo.getAllCustomers();
      if (_mounted) {
        state = state.copyWith(allCustomers: allCustomers, isLoading: false);
      }
    } catch (e, stackTrace) {
      LoggerService.error('CreateBillingController', 'Failed to load customers', e, stackTrace);
      if (_mounted) state = state.copyWith(isLoading: false);
      if (context.mounted) {
        AlertService.show(
          context: context,
          message: 'โหลดข้อมูลลูกค้าล้มเหลว',
          type: 'error',
        );
      }
    }
  }

  void selectCustomer(BuildContext context, Customer c) {
    if (!_mounted) return;
    state = state.copyWith(selectedCustomer: c);
    loadPendingBills(context, c.id);
  }

  Future<void> loadPendingBills(BuildContext context, int customerId) async {
    if (!_mounted) return;
    state = state.copyWith(isLoading: true);
    
    try {
      final bills = await _debtorRepo.getPendingBills(customerId);
      if (_mounted) {
        state = state.copyWith(activeBills: List.from(bills), isLoading: false);
      }
    } catch (e, stackTrace) {
      LoggerService.error('CreateBillingController', 'Failed to load pending bills for $customerId', e, stackTrace);
      if (_mounted) state = state.copyWith(isLoading: false);
      if (context.mounted) {
        AlertService.show(
          context: context,
          message: 'โหลดบิลค้างชำระล้มเหลว',
          type: 'error',
        );
      }
    }
  }

  void removeBill(int index) {
    if (!_mounted) return;
    final newList = List<OutstandingBill>.from(state.activeBills);
    newList.removeAt(index);
    state = state.copyWith(activeBills: newList);
  }

  Future<bool> saveBillingNote(
    BuildContext context, {
    required DateTime issueDate,
    required DateTime dueDate,
    required String note,
  }) async {
    if (state.selectedCustomer == null) {
      AlertService.show(
        context: context,
        message: 'กรุณาเลือกลูกหนี้',
        type: 'warning',
      );
      return false;
    }
    if (state.activeBills.isEmpty) {
      AlertService.show(
        context: context,
        message: 'ไม่มีรายการในใบวางบิล',
        type: 'warning',
      );
      return false;
    }

    if (!_mounted) return false;
    state = state.copyWith(isLoading: true);

    try {
      final billingNote = BillingNote(
        customerId: state.selectedCustomer!.id,
        documentNo: 'INV-${DateTime.now().millisecondsSinceEpoch}',
        issueDate: issueDate,
        dueDate: dueDate,
        totalAmount: state.totalAmount,
        note: note,
        status: 'PENDING',
      );

      List<BillingNoteItem> items = state.activeBills.map((b) {
        return BillingNoteItem(orderId: b.orderId, amount: b.remaining);
      }).toList();

      final success = await _billingRepo.createBillingNote(billingNote, items);

      if (_mounted) state = state.copyWith(isLoading: false);

      if (success) {
        return true;
      } else {
        if (context.mounted) {
          AlertService.show(
            context: context,
            message: 'บันทึกไม่สำเร็จ',
            type: 'error',
          );
        }
        return false;
      }
    } catch (e, stackTrace) {
      LoggerService.error('CreateBillingController', 'Failed to save billing note', e, stackTrace);
      if (_mounted) state = state.copyWith(isLoading: false);
      if (context.mounted) {
        AlertService.show(
          context: context,
          message: 'เกิดข้อผิดพลาดในการบันทึกบิล',
          type: 'error',
        );
      }
      return false;
    }
  }
}
