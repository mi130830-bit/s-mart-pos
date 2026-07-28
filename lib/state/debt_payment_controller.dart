import '../models/customer.dart';
import '../models/debtor_transaction.dart';
import '../repositories/debtor_repository.dart';

class DebtPaymentController {
  final DebtorRepository debtRepo;

  DebtPaymentController({required this.debtRepo});

  /// คำนวณยอดหนี้เริ่มต้นจากรายการที่เลือก หรือยอดรวมลูกค้า
  double calculateDefaultAmount(
      Customer customer, List<DebtorTransaction> ledger, Set<int> selectedIds) {
    double selectedTotal = 0.0;
    for (var item in ledger) {
      if (item.type == 'CREDIT_SALE' && selectedIds.contains(item.id)) {
        selectedTotal += item.amount.toDouble();
      }
    }
    return selectedIds.isNotEmpty ? selectedTotal : customer.currentDebt;
  }

  /// ประมวลผลการรับชำระหนี้
  Future<void> processPayment({
    required Customer customer,
    required double payAmount,
    required List<DebtorTransaction> ledger,
    required Set<int> selectedIds,
  }) async {
    if (selectedIds.isNotEmpty) {
      final selectedOrderIds = ledger
          .where((item) =>
              selectedIds.contains(item.id) && item.orderId != null)
          .map((item) => item.orderId!)
          .toList();

      await debtRepo.processBatchPayment(
          customerId: customer.id,
          payAmount: payAmount,
          orderIds: selectedOrderIds);
    } else {
      final pendingBills = await debtRepo.getPendingBills(customer.id);
      final pendingOrderIds = pendingBills.map((b) => b.orderId).toList();

      if (pendingOrderIds.isNotEmpty) {
        await debtRepo.processBatchPayment(
            customerId: customer.id,
            payAmount: payAmount,
            orderIds: pendingOrderIds);
      } else {
        await debtRepo.payDebt(
            customerId: customer.id, amount: payAmount);
      }
    }
  }
}
