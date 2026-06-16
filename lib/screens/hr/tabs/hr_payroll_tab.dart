import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../state/hr/payroll_provider.dart';
import '../../../state/hr/employee_provider.dart';
import '../widgets/payroll_detail_dialog.dart';
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
  // Expanded period tracking for history detail
  String? _expandedPeriodKey;

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

  // ── Toast helper: แถบแจ้งเตือนเล็กๆ มุมซ้ายล่าง ──────────────────────────
  void _showToast(
    String message, {
    Color backgroundColor = const Color(0xFF323232),
    IconData icon = Icons.check_circle_outline,
    Color iconColor = Colors.white,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.only(left: 16, bottom: 20, right: 9999),
        padding: EdgeInsets.zero,
        duration: const Duration(seconds: 3),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // ──────────────────────────────────────────────────────────────────────────

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
          _showToast('คำนวณเงินเดือนสำเร็จ',
            backgroundColor: const Color(0xFF2E7D32),
            icon: Icons.check_circle_outline);
        }
      } catch (e) {
        if (mounted) {
          _showToast('เกิดข้อผิดพลาด: $e',
            backgroundColor: const Color(0xFFC62828),
            icon: Icons.error_outline);
        }
      }
    }
  }

  Future<void> _clearAllDrafts() async {
    final state = ref.read(payrollProvider);
    final draftCount = state.records.where((r) => r.status == 'DRAFT').length;

    if (draftCount == 0) {
      _showToast('ไม่มีรายการฉบับร่างในรอบนี้',
        backgroundColor: const Color(0xFF546E7A),
        icon: Icons.info_outline);
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
          _showToast('ล้างรายการสำเร็จ $deleted รายการ',
            backgroundColor: const Color(0xFFE65100),
            icon: Icons.delete_sweep);
        }
      } catch (e) {
        if (mounted) {
          _showToast('เกิดข้อผิดพลาด: $e',
            backgroundColor: const Color(0xFFC62828),
            icon: Icons.error_outline);
        }
      }
    }
  }

  Future<void> _saveTotalToExpense() async {
    final state = ref.read(payrollProvider);
    if (state.records.isEmpty) {
      _showToast('ไม่มีข้อมูลเงินเดือนในรอบนี้',
        backgroundColor: const Color(0xFF546E7A),
        icon: Icons.info_outline);
      return;
    }
    
    double totalNetPay = state.records.fold(0.0, (sum, req) => sum + req.netPay);
    if (totalNetPay <= 0) {
      _showToast('ยอดเงินเดือนรวมเป็น 0',
        backgroundColor: const Color(0xFF546E7A),
        icon: Icons.info_outline);
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
          _showToast('เกิดข้อผิดพลาด: $e',
            backgroundColor: const Color(0xFFC62828),
            icon: Icons.error_outline);
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DRAFT': return Colors.grey;
      case 'CONFIRMED': return Colors.orange;
      case 'PAID': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'DRAFT': return 'ฉบับร่าง';
      case 'CONFIRMED': return 'ยืนยันแล้ว (รอจ่าย)';
      case 'PAID': return 'จ่ายแล้ว';
      default: return status;
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
          if (_selectedView == 'CURRENT') ..._buildCurrentView(state, dateFormat, currencyFormat)
          else ..._buildHistoryView(state, dateFormat, currencyFormat),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ── CURRENT VIEW (ทำรายการ) ──────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════
  List<Widget> _buildCurrentView(PayrollState state, DateFormat dateFormat, NumberFormat currencyFormat) {
    return [

      // Records list
      Expanded(
        child: state.isLoading && state.records.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text('ยังไม่มีข้อมูลเงินเดือนในรอบ ${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                        const SizedBox(height: 8),
                        const Text('กดปุ่ม "คำนวณรอบนี้" เพื่อสร้างรายการใหม่', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListView.separated(
                      itemCount: state.records.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final req = state.records[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(req.status).withValues(alpha: 0.1),
                            child: Icon(Icons.person, color: _getStatusColor(req.status)),
                          ),
                          title: Row(
                            children: [
                              Text(
                                req.employeeName ?? 'พนักงาน (ID: ${req.employeeId})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(req.status).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatStatus(req.status),
                                  style: TextStyle(color: _getStatusColor(req.status), fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('รับ: ฿${currencyFormat.format(req.grossPay)}', style: const TextStyle(color: Colors.green)),
                                  const SizedBox(width: 16),
                                  Text('หัก: ฿${currencyFormat.format(req.totalDeductions)}', style: const TextStyle(color: Colors.red)),
                                  const SizedBox(width: 16),
                                  Text('สุทธิ: ฿${currencyFormat.format(req.netPay)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                ],
                              ),
                              Text('รอบจ่าย: ${req.payCycle} | ทำงาน: ${req.workDays} วัน | ลา: ${req.leaveDays} วัน'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('ยืนยันการลบและคืนค่ายอดเบิก'),
                                      content: const Text('ต้องการลบรายการเงินเดือนนี้ใช่หรือไม่?\n\n*หากมีการหักยอดเงินเบิกล่วงหน้าไปแล้ว ระบบจะทำการคืนยอดเงินเบิกกลับให้อัตโนมัติ เพื่อให้สามารถนำมาหักใหม่ได้ (สำหรับใช้ทดสอบ)'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                          onPressed: () => Navigator.pop(context, true), 
                                          child: const Text('ลบรายการ')
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    if (!context.mounted) return;
                                    try {
                                      await ref.read(payrollProvider.notifier).deleteRecord(req.id);
                                      if (mounted) {
                                        _showToast('ลบรายการสำเร็จ',
                                          backgroundColor: const Color(0xFF2E7D32),
                                          icon: Icons.check_circle_outline);
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        _showToast('เกิดข้อผิดพลาด: $e',
                                          backgroundColor: const Color(0xFFC62828),
                                          icon: Icons.error_outline);
                                      }
                                    }
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios, size: 16),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => PayrollDetailDialog(record: req),
                                  );
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => PayrollDetailDialog(record: req),
                            );
                          },
                        );
                      },
                    ),
                  ),
      ),
    ];
  }

  // ══════════════════════════════════════════════════════════════════
  // ── HISTORY VIEW (ประวัติจ่ายเงิน) ───────────────────────────────
  // ══════════════════════════════════════════════════════════════════
  List<Widget> _buildHistoryView(PayrollState state, DateFormat dateFormat, NumberFormat currencyFormat) {
    final employees = ref.watch(employeeProvider).employees;

    return [
      // ── Filter bar ──────────────────────────────────────────────
      Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => _selectHistoryRange(context),
            icon: const Icon(Icons.calendar_month),
            label: Text('${dateFormat.format(_historyStart)} - ${dateFormat.format(_historyEnd)}'),
          ),
          const SizedBox(width: 8),
          // Quick select buttons
          _buildQuickRangeChip('สัปดาห์นี้', 7),
          const SizedBox(width: 4),
          _buildQuickRangeChip('เดือนนี้', 30),
          const SizedBox(width: 4),
          _buildQuickRangeChip('3 เดือน', 90),
          const SizedBox(width: 12),
          // Employee filter dropdown
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<int?>(
              initialValue: _historyEmployeeFilter,
              decoration: const InputDecoration(
                labelText: 'พนักงาน',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('ทั้งหมด')),
                ...employees.map((e) => DropdownMenuItem<int?>(
                  value: e.id,
                  child: Text(e.displayName ?? 'ID: ${e.id}', overflow: TextOverflow.ellipsis),
                )),
              ],
              onChanged: (val) {
                setState(() { _historyEmployeeFilter = val; });
                _loadHistory();
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      // ── Period summaries list ───────────────────────────────────
      Expanded(
        child: state.isLoading && state.periodSummaries.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.periodSummaries.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('ยังไม่มีประวัติการจ่ายเงินในช่วงเวลาที่เลือก', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  )
                : Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListView.builder(
                      itemCount: state.periodSummaries.length,
                      itemBuilder: (context, index) {
                        final summary = state.periodSummaries[index];
                        final periodStart = DateTime.tryParse(summary['period_start']?.toString() ?? '') ?? DateTime.now();
                        final periodEnd = DateTime.tryParse(summary['period_end']?.toString() ?? '') ?? DateTime.now();
                        final employeeCount = int.tryParse(summary['employee_count']?.toString() ?? '0') ?? 0;
                        final totalNet = double.tryParse(summary['total_net']?.toString() ?? '0') ?? 0.0;
                        final totalGross = double.tryParse(summary['total_gross']?.toString() ?? '0') ?? 0.0;
                        final totalDed = double.tryParse(summary['total_deductions']?.toString() ?? '0') ?? 0.0;
                        final periodKey = '${periodStart.toIso8601String()}_${periodEnd.toIso8601String()}';
                        final isExpanded = _expandedPeriodKey == periodKey;

                        // Get matching detail records for this period
                        final periodRecords = state.historyRecords.where((r) =>
                          r.periodStart.year == periodStart.year &&
                          r.periodStart.month == periodStart.month &&
                          r.periodStart.day == periodStart.day &&
                          r.periodEnd.year == periodEnd.year &&
                          r.periodEnd.month == periodEnd.month &&
                          r.periodEnd.day == periodEnd.day
                        ).toList();

                        return Column(
                          children: [
                            if (index > 0) const Divider(height: 1),
                            // ── Period summary row ─────────────────────
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: Colors.green.withValues(alpha: 0.1),
                                child: const Icon(Icons.calendar_today, color: Colors.green),
                              ),
                              title: Text(
                                '📅 ${dateFormat.format(periodStart)} - ${dateFormat.format(periodEnd)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Text('👥 $employeeCount คน', style: const TextStyle(fontSize: 13)),
                                    const SizedBox(width: 12),
                                    Text('รับ: ฿${currencyFormat.format(totalGross)}', style: const TextStyle(color: Colors.green, fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Text('หัก: ฿${currencyFormat.format(totalDed)}', style: const TextStyle(color: Colors.red, fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Text('สุทธิ: ฿${currencyFormat.format(totalNet)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                                  ],
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_sweep, color: Colors.red),
                                    tooltip: 'ล้างประวัติรอบนี้ (สำหรับทดสอบ)',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('ยืนยันล้างประวัติทั้งรอบ'),
                                          content: Text('ต้องการลบประวัติเงินเดือนรอบ ${dateFormat.format(periodStart)} - ${dateFormat.format(periodEnd)} ทั้งหมดใช่หรือไม่?\n\n* ยอดเงินเบิกของทุกคนในรอบนี้จะถูกคืนกลับให้อัตโนมัติ (สำหรับใช้ทดสอบ)\n* ระบบจะลบประวัติรายการที่เคยลงบันทึกใน "บัญชีรายจ่าย" ให้อัตโนมัติด้วย'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                              onPressed: () => Navigator.pop(context, true), 
                                              child: const Text('ล้างประวัติ')
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        if (!context.mounted) return;
                                        try {
                                          // Delete all records in this period, which will also revert their advances
                                          for (var rec in periodRecords) {
                                            await ref.read(payrollProvider.notifier).deleteRecord(rec.id);
                                          }
                                          // Also delete linked expense
                                          try {
                                            final title = 'จ่ายเงินเดือนรอบ ${dateFormat.format(periodStart)} - ${dateFormat.format(periodEnd)}';
                                            await ExpenseRepository().deleteExpenseByTitle(title);
                                          } catch (e) {
                                            debugPrint('Failed to delete linked expense: $e');
                                          }
                                          _loadHistory();
                                          if (context.mounted) {
                                            _showToast('ล้างประวัติสำเร็จ',
                                              backgroundColor: const Color(0xFF2E7D32),
                                              icon: Icons.check_circle_outline);
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            _showToast('เกิดข้อผิดพลาด: $e',
                                              backgroundColor: const Color(0xFFC62828),
                                              icon: Icons.error_outline);
                                          }
                                        }
                                      }
                                    },
                                  ),
                                  Icon(
                                    isExpanded ? Icons.expand_less : Icons.expand_more,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                              onTap: () {
                                setState(() {
                                  _expandedPeriodKey = isExpanded ? null : periodKey;
                                });
                              },
                            ),
                            // ── Expanded detail (per employee) ────────
                            if (isExpanded)
                              Container(
                                color: Colors.grey.withValues(alpha: 0.04),
                                child: Column(
                                  children: [
                                    const Divider(height: 1),
                                    if (periodRecords.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Text('ไม่พบรายละเอียดรายคน', style: TextStyle(color: Colors.grey)),
                                      )
                                    else
                                      ...periodRecords.map((rec) => ListTile(
                                        dense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 2),
                                        leading: const CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Color(0xFFE3F2FD),
                                          child: Icon(Icons.person, size: 18, color: Colors.blue),
                                        ),
                                        title: Text(
                                          rec.employeeName ?? 'ID: ${rec.employeeId}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                        subtitle: Text(
                                          'ทำงาน: ${rec.workDays} วัน | ลา: ${rec.leaveDays} วัน',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '฿${currencyFormat.format(rec.netPay)}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 14),
                                                ),
                                                if (rec.totalDeductions > 0)
                                                  Text(
                                                    'หัก ฿${currencyFormat.format(rec.totalDeductions)}',
                                                    style: const TextStyle(color: Colors.red, fontSize: 11),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                              tooltip: 'ลบรายการนี้ (ใช้ทดสอบ)',
                                              onPressed: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: const Text('ยืนยันการลบและคืนค่ายอดเบิก'),
                                                    content: const Text('ต้องการลบรายการประวัติเงินเดือนนี้ใช่หรือไม่?\n\n*ระบบจะทำการคืนยอดเงินเบิกกลับให้อัตโนมัติ เพื่อให้สามารถนำมาหักใหม่ได้ (สำหรับใช้ทดสอบ)'),
                                                    actions: [
                                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                        onPressed: () => Navigator.pop(context, true), 
                                                        child: const Text('ลบรายการ')
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (confirm == true) {
                                                  if (!context.mounted) return;
                                                  try {
                                                    await ref.read(payrollProvider.notifier).deleteRecord(rec.id);
                                                    _loadHistory();
                                                    if (context.mounted) {
                                                      _showToast('ลบรายการสำเร็จ',
                                                        backgroundColor: const Color(0xFF2E7D32),
                                                        icon: Icons.check_circle_outline);
                                                    }
                                                  } catch (e) {
                                                    if (context.mounted) {
                                                      _showToast('เกิดข้อผิดพลาด: $e',
                                                        backgroundColor: const Color(0xFFC62828),
                                                        icon: Icons.error_outline);
                                                    }
                                                  }
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                                              tooltip: 'ดูรายละเอียด',
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => PayrollDetailDialog(record: rec),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => PayrollDetailDialog(record: rec),
                                          );
                                        },
                                      )),
                                    // ── Summary footer ────────────────────
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.05),
                                        border: Border(top: BorderSide(color: Colors.blue.withValues(alpha: 0.2))),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          const Text('💰 ยอดสุทธิรวม: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          Text(
                                            '฿${currencyFormat.format(totalNet)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
      ),
    ];
  }

  Widget _buildQuickRangeChip(String label, int days) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        setState(() {
          _historyEnd = DateTime.now();
          _historyStart = DateTime.now().subtract(Duration(days: days));
        });
        _loadHistory();
      },
    );
  }
}
