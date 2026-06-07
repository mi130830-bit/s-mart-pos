import '../../models/hr/payroll_record.dart';
import '../../repositories/hr/employee_repository.dart';
import '../../repositories/hr/attendance_repository.dart';
import '../../repositories/hr/leave_repository.dart';
import '../../repositories/hr/advance_repository.dart';
import '../../repositories/hr/payroll_repository.dart';

class PayrollCalculationService {
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  final AttendanceRepository _attendanceRepo = AttendanceRepository();
  final LeaveRepository _leaveRepo = LeaveRepository();
  final AdvanceRepository _advanceRepo = AdvanceRepository();
  final PayrollRepository _payrollRepo = PayrollRepository();

  Future<List<PayrollRecord>> calculateAllForPeriod(DateTime start, DateTime end) async {
    final employees = await _employeeRepo.getAll(activeOnly: true);
    List<PayrollRecord> records = [];

    for (var emp in employees) {
      final record = await calculatePayroll(emp.id, start, end);
      if (record != null) {
        records.add(record);
      }
    }
    return records;
  }

  Future<PayrollRecord?> calculatePayroll(int employeeId, DateTime periodStart, DateTime periodEnd) async {
    // 1. Get Employee Profile
    final emp = await _employeeRepo.getById(employeeId);
    if (emp == null) return null;

    // 2. Count Work Days from Attendance
    final workDays = await _attendanceRepo.countWorkDays(employeeId, periodStart, periodEnd);
    
    // We'll skip absent/late calc for now to keep it simple unless needed.
    final int absentDays = 0; 
    final int lateCount = 0;

    // 3. Get Leave Days (Paid)
    final leaves = await _leaveRepo.getApprovedInRange(employeeId, periodStart, periodEnd);
    double leaveDays = 0;
    for (var l in leaves) {
      // In a real system, we'd calculate intersection of leave date range and period date range
      // For simplicity, we just add total_days.
      leaveDays += l.totalDays;
    }

    // 4. Get Trip Count (If Driver)
    int tripCount = 0;
    double tripTotalFee = 0.0;
    if (emp.roleType == 'DRIVER' && emp.displayName != null && emp.displayName!.isNotEmpty) {
      tripCount = await _payrollRepo.getDriverTrips(emp.displayName!, periodStart, periodEnd);
      tripTotalFee = tripCount * emp.tripRate;
    }

    // 5. Calculate Gross Pay
    double dailyWageTotal = 0.0;
    double baseSalary = 0.0;
    
    if (emp.wageType == 'DAILY') {
      // Paid for work days only
      dailyWageTotal = workDays * emp.dailyWage;
    } else {
      // MONTHLY
      baseSalary = emp.baseSalary;
    }

    double overtimeHours = 0.0;
    double overtimePay = 0.0;
    double bonus = 0.0;

    double grossPay = dailyWageTotal + baseSalary + tripTotalFee + overtimePay + bonus;

    // 6. Get Outstanding Advances
    final outstandingAdvances = await _advanceRepo.getOutstanding(employeeId);
    // double remainingAdvancesToDeduct = grossPay * 0.8; // Allow max 80% deduction? Or total. Let's say we try to deduct as much as possible but leave some minimum, or just deduct all.
    double actualDeducted = 0.0;

    // For simplicity, let's try to deduct up to grossPay
    for (var adv in outstandingAdvances) {
      if (actualDeducted >= grossPay) break;
      
      // If installmentAmount is set, we only deduct up to installmentAmount per period
      // Otherwise we try to deduct the full remainingAmount
      double targetDeduction = adv.installmentAmount ?? adv.remainingAmount;
      if (targetDeduction > adv.remainingAmount) {
        targetDeduction = adv.remainingAmount;
      }
      
      double canDeduct = targetDeduction;
      if (actualDeducted + canDeduct > grossPay) {
        canDeduct = grossPay - actualDeducted; // Only deduct what's left of salary
      }
      
      actualDeducted += canDeduct;
    }

    double socialSecurity = 0.0; // Implement SS logic if needed (e.g. 5% max 750)
    double otherDeductions = 0.0;

    double totalDeductions = actualDeducted + socialSecurity + otherDeductions;
    double netPay = grossPay - totalDeductions;

    // Create Draft Record
    return PayrollRecord(
      id: 0,
      employeeId: employeeId,
      payCycle: emp.payCycle,
      periodStart: periodStart,
      periodEnd: periodEnd,
      workDays: workDays,
      absentDays: absentDays,
      lateCount: lateCount,
      leaveDays: leaveDays,
      dailyWageTotal: dailyWageTotal,
      baseSalary: baseSalary,
      tripCount: tripCount,
      tripTotalFee: tripTotalFee,
      overtimeHours: overtimeHours,
      overtimePay: overtimePay,
      bonus: bonus,
      grossPay: grossPay,
      advanceDeductions: actualDeducted, // We will actually apply these deductions to DB when Payroll is 'CONFIRMED' or 'PAID'
      socialSecurity: socialSecurity,
      otherDeductions: otherDeductions,
      totalDeductions: totalDeductions,
      netPay: netPay,
      status: 'DRAFT',
      employeeName: emp.displayName,
    );
  }
}
