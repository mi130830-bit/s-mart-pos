import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';
import '../../repositories/expense_repository.dart';

class ExpenseManagementScreen extends StatefulWidget {
  const ExpenseManagementScreen({super.key});

  @override
  State<ExpenseManagementScreen> createState() =>
      _ExpenseManagementScreenState();
}

class _ExpenseManagementScreenState extends State<ExpenseManagementScreen> {
  final ExpenseRepository _repo = ExpenseRepository();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  List<Expense> _expenses = [];
  bool _isLoading = false;

  // Stats
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final start =
          DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0, 0);
      final end =
          DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

      debugPrint('📊 Loading expenses: $start → $end');
      final data = await _repo.getExpensesByDateRange(start, end);
      debugPrint('📊 Got ${data.length} expense records');

      // Calculate totals locally from fetched data
      double income = 0.0;
      double expense = 0.0;

      for (var item in data) {
        if (item.type == 'INCOME') {
          income += item.amount;
        } else {
          expense += item.amount;
        }
      }

      if (mounted) {
        setState(() {
          _expenses = data;
          _totalIncome = income;
          _totalExpense = expense;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('❌ _loadData error: $e\n$st');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

  Future<void> _showEditDialog({Expense? expense}) async {
    final isEditing = expense != null;
    final titleCtrl = TextEditingController(text: expense?.title ?? '');
    final amountCtrl =
        TextEditingController(text: expense?.amount.toString() ?? '');
    final noteCtrl = TextEditingController(text: expense?.note ?? '');

    String category = expense?.category ?? 'ทั่วไป';
    String type = expense?.type ?? 'EXPENSE'; // Default to Expense
    DateTime selectedDate = expense?.date ?? DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? 'แก้ไขรายการ' : 'เพิ่มรายการใหม่'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Type Selector (Segmented Control)
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('รายจ่าย')),
                        selected: type == 'EXPENSE',
                        selectedColor: Colors.red.shade100,
                        onSelected: (v) => setState(() => type = 'EXPENSE'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('รายรับ')),
                        selected: type == 'INCOME',
                        selectedColor: Colors.green.shade100,
                        onSelected: (v) => setState(() => type = 'INCOME'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                      labelText: 'รายการ (เช่น ค่าน้ำ, ค่าไฟ, ขายของเก่า)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'จำนวนเงิน (บาท)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                      'dropdown_$type'), // Force rebuild on type change
                  initialValue: category,
                  items: <String>{
                    'ทั่วไป',
                    'ค่าน้ำ/ไฟ',
                    'ค่าเช่า',
                    'เงินเดือน',
                    'อุปกรณ์',
                    'สินค้าสิ้นเปลือง',
                    'อื่นๆ',
                    if (type == 'INCOME') ...{
                      'ขายของเก่า',
                      'ดอกเบี้ย',
                      'เงินคืน',
                      'อื่นๆ(รายรับ)'
                    },
                  }
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => category = v!),
                  decoration: const InputDecoration(
                      labelText: 'หมวดหมู่', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('วันที่บันทึก'),
                  subtitle:
                      Text(DateFormat('dd/MM/yyyy HH:mm').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (!context.mounted) return;
                    if (d != null) {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (t != null) {
                        setState(() {
                          selectedDate = DateTime(
                              d.year, d.month, d.day, t.hour, t.minute);
                        });
                      }
                    }
                  },
                ),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                      labelText: 'หมายเหตุ (Optional)',
                      border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: type == 'INCOME' ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                if (title.isEmpty || amount <= 0) return;

                final newExpense = Expense(
                  id: expense?.id ?? 0,
                  title: title,
                  amount: amount,
                  category: category,
                  date: selectedDate,
                  note: noteCtrl.text.trim(),
                  type: type, // ✅ Save Type
                );

                await _repo.saveExpense(newExpense);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  await _loadData(); // ✅ await เพื่อรอ reload
                }
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExpense(int id) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('ยืนยันการลบ'),
              content: const Text('คุณต้องการลบรายการนี้ใช่หรือไม่?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('ไม่ลบ')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child:
                        const Text('ลบ', style: TextStyle(color: Colors.red))),
              ],
            ));

    if (confirm == true) {
      await _repo.deleteExpense(id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการบัญชีร้าน (รายรับ-รายจ่าย)'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _pickDateRange(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade50,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryItem(
                          'รายรับรวม',
                          _totalIncome,
                          Colors.green,
                        ),
                      ),
                      Container(
                          width: 1, height: 40, color: Colors.grey.shade300),
                      Expanded(
                        child: _buildSummaryItem(
                          'รายจ่ายรวม',
                          _totalExpense,
                          Colors.red,
                        ),
                      ),
                      Container(
                          width: 1, height: 40, color: Colors.grey.shade300),
                      Expanded(
                        child: _buildSummaryItem(
                          'คงเหลือ',
                          _totalIncome - _totalExpense,
                          (_totalIncome - _totalExpense) >= 0
                              ? Colors.teal
                              : Colors.red,
                          isBold: true,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _expenses.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final ex = _expenses[i];
                      final isIncome = ex.type == 'INCOME';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isIncome
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          child: Icon(
                            isIncome
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: isIncome ? Colors.green : Colors.red,
                            size: 20,
                          ),
                        ),
                        title: Text(ex.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${DateFormat('dd/MM HH:mm').format(ex.date)} | ${ex.category}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                '${isIncome ? '+' : '-'}${NumberFormat('#,##0.00').format(ex.amount)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color:
                                        isIncome ? Colors.green : Colors.red)),
                            const SizedBox(width: 8),
                            IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showEditDialog(expense: ex)),
                            IconButton(
                                icon: const Icon(Icons.delete,
                                    size: 20, color: Colors.grey),
                                onPressed: () => _deleteExpense(ex.id)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(),
        label: const Text('เพิ่มรายการใหม่'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color,
      {bool isBold = false}) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          '฿${NumberFormat('#,##0').format(amount)}',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
