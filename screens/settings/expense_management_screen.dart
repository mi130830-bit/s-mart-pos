import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';
import '../../repositories/expense_repository.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/confirm_dialog.dart';
import 'dart:async'; // Added for TimeoutException

class ExpenseManagementScreen extends StatefulWidget {
  const ExpenseManagementScreen({super.key});

  @override
  State<ExpenseManagementScreen> createState() =>
      _ExpenseManagementScreenState();
}

class _ExpenseManagementScreenState extends State<ExpenseManagementScreen> {
  final ExpenseRepository _repo = ExpenseRepository();
  List<Expense> _expenses = [];
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('ExpenseScreen: Loading data...');
      final data = await _repo.getExpensesByDateRange(_startDate, _endDate);
      if (mounted) {
        setState(() {
          _expenses = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading expenses: $e');
      if (mounted) {
        setState(() {
          _expenses = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'ไม่สามารถโหลดข้อมูลได้ (อาจเป็นเพราะเครือข่ายหรือฐานข้อมูล): $e')),
        );
      }
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  Future<void> _showExpenseDialog([Expense? expense]) async {
    final titleCtrl = TextEditingController(text: expense?.title ?? '');
    final amountCtrl =
        TextEditingController(text: expense?.amount.toString() ?? '0');
    final catCtrl = TextEditingController(text: expense?.category ?? 'General');
    final noteCtrl = TextEditingController(text: expense?.note ?? '');
    DateTime selectedDate = expense?.date ?? DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDlg) => AlertDialog(
          title: Text(expense == null ? 'เพิ่มค่าใช้จ่าย' : 'แก้ไขค่าใช้จ่าย'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: titleCtrl,
                  label: 'หัวข้อ/รายการ',
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: amountCtrl,
                  label: 'จำนวนเงิน',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: catCtrl,
                  label: 'หมวดหมู่',
                ),
                ListTile(
                  title: const Text('วันที่จ่าย'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (d != null) {
                      setStateDlg(() => selectedDate = d);
                    }
                  },
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: noteCtrl,
                  label: 'หมายเหตุ',
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            CustomButton(
              onPressed: () => Navigator.pop(ctx),
              label: 'ยกเลิก',
              type: ButtonType.secondary,
            ),
            CustomButton(
              onPressed: () async {
                final e = Expense(
                  id: expense?.id ?? 0,
                  title: titleCtrl.text,
                  amount: double.tryParse(amountCtrl.text) ?? 0.0,
                  category: catCtrl.text,
                  date: selectedDate,
                  note: noteCtrl.text,
                );
                await _repo.saveExpense(e);
                if (!context.mounted) return;
                Navigator.pop(ctx);
                _loadData();
              },
              label: 'บันทึก',
              type: ButtonType.primary,
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double total = 0;
    for (var e in _expenses) {
      total += e.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการค่าใช้จ่าย (Expenses)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickDateRange,
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showExpenseDialog(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ช่วงเวลา: ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'รวมจ่าย: ${NumberFormat('#,##0.00').format(total)} ฿',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _expenses.length,
                    itemBuilder: (context, index) {
                      final e = _expenses[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.redAccent,
                          child: Icon(Icons.money_off, color: Colors.white),
                        ),
                        title: Text(e.title),
                        subtitle: Text(
                            '${DateFormat('dd/MM/yyyy').format(e.date)} | ${e.category}'),
                        trailing: Text(
                          '-${NumberFormat('#,##0.00').format(e.amount)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                        onTap: () => _showProductDialog(e),
                        onLongPress: () async {
                          final confirm = await ConfirmDialog.show(
                            context,
                            title: 'ยืนยัน',
                            content: 'ต้องการลบรายการนี้หรือไม่?',
                            confirmText: 'ลบ',
                            isDestructive: true,
                          );
                          if (confirm == true) {
                            await _repo.deleteExpense(e.id);
                            _loadData();
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showProductDialog(Expense e) {
    _showExpenseDialog(e);
  }
}
