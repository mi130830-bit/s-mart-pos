import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_desktop/utils/snackbar_utils.dart';
import '../../../state/hr/payroll_provider.dart';
import '../widgets/payroll_current_view.dart';
import '../widgets/payroll_history_view.dart';
import '../../../repositories/expense_repository.dart';
import '../../../models/expense.dart';

class HrPayrollTab extends ConsumerStatefulWidget {
  const HrPayrollTab({super.key});

  @override
  ConsumerState<HrPayrollTab> createState() => _HrPayrollTabState();
}

class _HrPayrollTabState extends ConsumerState<HrPayrollTab> {
  String _selectedView = 'CURRENT'; // 'CURRENT' or 'HISTORY'
  DateTime _startDate = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)); // Start of week (Monday)
  DateTime _endDate = DateTime.now().add(Duration(days: 6 - DateTime.now().weekday)); // End of week (Saturday)
  String _payCycleFilter = 'ALL'; // 'ALL', 'DAILY', 'WEEKLY', 'MONTHLY'

  // History filter state
  DateTime _historyStart = DateTime.now().subtract(const Duration(days: 90));
  DateTime _historyEnd = DateTime.now();
  int? _historyEmployeeFilter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadData();
      _loadHistory();
    });
  }

  void _loadData() {
    ref.read(payrollProvider.notifier).loadByPeriod(_startDate, _endDate);
  }

  void _loadHistory() {
    ref.read(payrollProvider.notifier).loadPeriodSummaries(
      startDate: _historyStart,
      endDate: _historyEnd,
    );
    ref.read(payrollProvider.notifier).loadHistory(
      startDate: _historyStart,
      endDate: _historyEnd,
      employeeId: _historyEmployeeFilter,
    );
  }

  Future<void> _selectHistoryRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _historyStart, end: _historyEnd),
    );
    if (picked != null) {
      setState(() {
        _historyStart = picked.start;
        _historyEnd = picked.end;
      });
      _loadHistory();
    }
  }

  // Using SnackbarUtils instead of custom _showToast

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  Future<void> _calculatePayroll() async {
    final hasHistory = await ref.read(payrollProvider.notifier).hasHistoryInPeriod(_startDate, _endDate);
    if (!mounted) return;

    if (hasHistory) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('ทำรายการซ้ำ'),
            ],
          ),
          content: Text(
            'รอบวันที่ ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}\n'
            'มีการคำนวณและยืนยันการจ่ายไปแล้วบางส่วน หรือทั้งหมด\n\n'
            'ระบบไม่อนุญาตให้คำนวณซ้ำ กรุณาไปตรวจสอบที่ "ประวัติจ่ายเงิน"'
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _selectedView = 'HISTORY';
                  _historyStart = _startDate;
                  _historyEnd = _endDate;
                });
                _loadHistory();
              },
              child: const Text('ไปที่ประวัติจ่ายเงิน')
            ),
          ],
        ),
      );
      return;
    }

    bool skipAdvanceDeduction = false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('⚙️ คำนวณเงินเดือน'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ระบบจะคำนวณเงินเดือนของพนักงานทุกคนในช่วงวันที่\n${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}\n\nต้องการดำเนินการต่อหรือไม่?'),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('งดหักเงินเบิกล่วงหน้ารอบนี้ (ยกเว้นชั่วคราว)'),
                  value: skipAdvanceDeduction,
                  onChanged: (val) {
                    setState(() {
                      skipAdvanceDeduction = val ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true), 
                child: const Text('คำนวณเลย')
              ),
            ],
          );
        }
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(payrollProvider.notifier).calculateForPeriod(_startDate, _endDate, payCycleFilter: _payCycleFilter, skipAdvanceDeduction: skipAdvanceDeduction);
        if (mounted) {
          SnackbarUtils.showLeft(context, 'คำนวณเงินเดือนสำเร็จ');
        }
      } catch (e) {
        if (mounted) {
          SnackbarUtils.showLeft(context, 'เกิดข้อผิดพลาด: $e');
        }
      }
    }
  }

  Future<void> _clearAllDrafts() async {
    final state = ref.read(payrollProvider);
    final draftCount = state.records.where((r) => r.status == 'DRAFT').length;

    if (draftCount == 0) {
      SnackbarUtils.showLeft(context, 'ไม่มีรายการฉบับร่างในรอบนี้');
      return;
    }

    final dateFormat = DateFormat('dd/MM/yyyy');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('ล้างรายการทั้งหมด'),
          ],
        ),
        content: Text(
          'ระบบจะลบรายการเงินเดือน "ฉบับร่าง" ทั้งหมด $draftCount รายการ\n'
          'ในรอบ ${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}\n\n'
          '⚠️ รายการที่ "ยืนยันแล้ว" หรือ "จ่ายแล้ว" จะไม่ถูกลบ\n'
          'ดำเนินการต่อหรือไม่?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_sweep),
            label: const Text('ล้างรายการ'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final deleted = await ref.read(payrollProvider.notifier).deleteAllDraftsForPeriod(_startDate, _endDate);
        if (mounted) {
          SnackbarUtils.showLeft(context, 'ล้างรายการสำเร็จ $deleted รายการ');
        }
      } catch (e) {
        if (mounted) {
          SnackbarUtils.showLeft(context, 'เกิดข้อผิดพลาด: $e');
        }
      }
    }
  }

  Future<void> _saveTotalToExpense() async {
    final state = ref.read(payrollProvider);
    if (state.records.isEmpty) {
      SnackbarUtils.showLeft(context, 'ไม่มีข้อมูลเงินเดือนในรอบนี้');
      return;
    }
    
    double totalNetPay = state.records.fold(0.0, (sum, req) => sum + req.netPay);
    if (totalNetPay <= 0) {
        
        
      return;
    }

    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat('#,##0.00');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('💰 บันทึกลงรายจ่าย'),
        content: Text('คุณต้องการบันทึกยอดเงินเดือนรวม ฿${currencyFormat.format(totalNetPay)}\nรอบวันที่ ${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}\nลงในบัญชีรายจ่ายของร้านหรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('บันทึกเลย')
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final repo = ExpenseRepository();
        final expense = Expense(
          id: 0,
          title: 'จ่ายเงินเดือนรอบ ${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
          amount: totalNetPay,
          category: 'เงินเดือน',
          date: DateTime.now(),
          type: 'EXPENSE',
          note: 'บันทึกอัตโนมัติจากระบบเงินเดือน (${state.records.length} คน)',
        );
        await repo.saveExpense(expense);

        // ✅ อัพเดทสถานะเป็น PAID แทนการลบ — เก็บไว้ดูประวัติภายหลัง
        await ref.read(payrollProvider.notifier).markAllPaidForPeriod(_startDate, _endDate);

        // รีโหลดประวัติ
        _loadHistory();

        if (mounted) {
          // แสดง Dialog แจ้งเตือนให้ตรวจสอบ
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 8),
                  Expanded(child: Text('บันทึกรายจ่ายสำเร็จ')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ระบบบันทึกยอดเงินเดือนรวม ฿${currencyFormat.format(totalNetPay)}\n'
                    'ลงในบัญชีรายจ่ายเรียบร้อยแล้ว\n',
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.history, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ดูประวัติการจ่ายเงินได้ที่แท็บ "ประวัติจ่ายเงิน"\nหรือตรวจสอบรายจ่ายที่เมนู ตั้งค่า > จัดการบัญชีร้าน',
                            style: TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('รับทราบ'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          SnackbarUtils.showLeft(context, 'เกิดข้อผิดพลาด: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(payrollProvider);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat('#,##0.00');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header & Actions ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedView == 'CURRENT' ? 'จัดการเงินเดือน / ค่าแรง' : 'ประวัติจ่ายเงิน',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Row(
                children: _selectedView == 'CURRENT' ? [
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _payCycleFilter,
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('รวมทุกรอบจ่าย', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'DAILY', child: Text('รายวัน', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'WEEKLY', child: Text('รายสัปดาห์', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'MONTHLY', child: Text('รายเดือน', style: TextStyle(fontSize: 14))),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _payCycleFilter = v;
                              if (v == 'DAILY') {
                                _startDate = DateTime.now();
                                _endDate = DateTime.now();
                              } else {
                                _startDate = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
                                _endDate = DateTime.now().add(Duration(days: 6 - DateTime.now().weekday));
                              }
                            });
                            _loadData();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _selectDateRange(context),
                    icon: const Icon(Icons.calendar_month),
                    label: Text('${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _calculatePayroll,
                    icon: const Icon(Icons.calculate),
                    label: const Text('คำนวณรอบนี้'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _saveTotalToExpense,
                    icon: const Icon(Icons.account_balance_wallet),
                    label: const Text('ลงรายจ่าย'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  ),
                  if (state.records.any((r) => r.status == 'DRAFT')) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _clearAllDrafts,
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('ล้างรายการ'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    ),
                  ],
                ] : [
                  ElevatedButton.icon(
                    onPressed: _loadHistory,
                    icon: const Icon(Icons.refresh),
                    label: const Text('รีเฟรช'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black87),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          
          // ── SegmentedButton ──────────────────────────────
          Center(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'CURRENT',
                  icon: Icon(Icons.receipt_long),
                  label: Text('ทำรายการ'),
                ),
                ButtonSegment(
                  value: 'HISTORY',
                  icon: Icon(Icons.history),
                  label: Text('ประวัติจ่ายเงิน'),
                ),
              ],
              selected: {_selectedView},
              onSelectionChanged: (value) {
                setState(() {
                  _selectedView = value.first;
                });
                if (value.first == 'HISTORY') {
                  _loadHistory();
                }
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Content ──────────────────────────────────────────────
          if (_selectedView == 'CURRENT')
            PayrollCurrentView(
              state: state,
              dateFormat: dateFormat,
              currencyFormat: currencyFormat,
              startDate: _startDate,
              endDate: _endDate,
            )
          else
            PayrollHistoryView(
              state: state,
              dateFormat: dateFormat,
              currencyFormat: currencyFormat,
              historyStart: _historyStart,
              historyEnd: _historyEnd,
              historyEmployeeFilter: _historyEmployeeFilter,
              onSelectHistoryRange: () => _selectHistoryRange(context),
              onSelectQuickRange: (days) {
                setState(() {
                  _historyEnd = DateTime.now();
                  _historyStart = DateTime.now().subtract(Duration(days: days));
                });
                _loadHistory();
              },
              onEmployeeFilterChanged: (val) {
                setState(() => _historyEmployeeFilter = val);
                _loadHistory();
              },
              onLoadHistory: _loadHistory,
            ),
        ],
      ),
    );
  }
}

