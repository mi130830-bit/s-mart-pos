import '../../models/hr/advance_payment.dart';
import '../../repositories/hr/advance_repository.dart';

class AdvanceService {
  final AdvanceRepository _advanceRepo = AdvanceRepository();

  Future<int> requestAdvance(int employeeId, double amount, String reason, {double? installmentAmount}) async {
    if (amount <= 0) {
      throw Exception('จำนวนเงินเบิกล่วงหน้าต้องมากกว่า 0');
    }

    final advance = AdvancePayment(
      id: 0,
      employeeId: employeeId,
      amount: amount,
      requestDate: DateTime.now(),
      reason: reason,
      status: 'PENDING',
      remainingAmount: 0.0, // Set to amount when approved
      installmentAmount: installmentAmount,
    );

    return await _advanceRepo.create(advance);
  }

  Future<void> approveAdvance(int advanceId, int approvedByUserId) async {
    await _advanceRepo.approve(advanceId, approvedByUserId);
  }

  Future<void> rejectAdvance(int advanceId) async {
    await _advanceRepo.reject(advanceId);
  }

  Future<double> getOutstandingTotal(int employeeId) async {
    return await _advanceRepo.getTotalOutstanding(employeeId);
  }

  Future<void> deductFromPayroll(int employeeId, int payrollId, double totalDeduction) async {
    if (totalDeduction <= 0) return;

    final outstanding = await _advanceRepo.getOutstanding(employeeId);
    double remainingToDeduct = totalDeduction;

    for (var adv in outstanding) {
      if (remainingToDeduct <= 0) break;

      double deductAmount = adv.remainingAmount;
      if (deductAmount > remainingToDeduct) {
        deductAmount = remainingToDeduct;
      }

      await _advanceRepo.recordDeduction(adv.id, payrollId, deductAmount);
      remainingToDeduct -= deductAmount;
    }
  }
  Future<void> revertDeductionsForPayroll(int payrollId) async {
    await _advanceRepo.revertDeductionsForPayroll(payrollId);
  }
}
