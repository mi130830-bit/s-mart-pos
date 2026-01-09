import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/customer.dart';
import '../../models/billing_note.dart';
import '../../models/billing_note_item.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/billing_repository.dart';
import '../../repositories/debtor_repository.dart';
import '../../models/outstanding_bill.dart';

class EditBillingScreen extends StatefulWidget {
  final BillingNote billingNote;

  const EditBillingScreen({super.key, required this.billingNote});

  @override
  State<EditBillingScreen> createState() => _EditBillingScreenState();
}

class _EditBillingScreenState extends State<EditBillingScreen> {
  final CustomerRepository _customerRepo = CustomerRepository();
  final BillingRepository _billingRepo = BillingRepository();
  final DebtorRepository _debtorRepo = DebtorRepository();

  // Data
  Customer? _customer;
  List<OutstandingBill> _activeBills = [];
  bool _isLoading = false;

  // Controllers
  final TextEditingController _customerDisplayCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _dueDateCtrl = TextEditingController();
  final TextEditingController _docNoCtrl = TextEditingController();

  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Load Customer
      final allCustomers = await _customerRepo.getAllCustomers();
      _customer = allCustomers.firstWhere(
          (c) => c.id == widget.billingNote.customerId,
          orElse: () => Customer(
              id: 0,
              firstName: 'Unknown',
              memberCode: '',
              currentPoints: 0,
              currentDebt: 0));
      _customerDisplayCtrl.text =
          '${_customer!.firstName} ${_customer!.lastName ?? ""}';

      // 2. Load Existing Items in Note
      final existingItems =
          await _billingRepo.getBillingNoteItems(widget.billingNote.id!);

      // 3. Load Pending Bills (Candidate Order)
      await _debtorRepo.getPendingBills(widget.billingNote.customerId);
      // 'pendingBills' removed as it was unused. We fetch fresh in dialog.

      // 4. Merge Logic
      List<OutstandingBill> noteBills = existingItems.map((map) {
        final dt =
            DateTime.tryParse(map['orderDate'].toString()) ?? DateTime.now();
        final amount = double.tryParse(map['orderTotal'].toString()) ?? 0.0;
        final remaining = double.tryParse(map['amount'].toString()) ??
            0.0; // This is the billed amount
        final received = amount - remaining;

        return OutstandingBill(
          orderId: int.tryParse(map['orderId'].toString()) ?? 0,
          customerId: widget.billingNote.customerId,
          amount: amount,
          received: received, // estimate
          remaining: remaining,
          createdAt: dt,
          status: 'COMPLETED',
          customerName: _customer?.firstName ?? '',
          phone: _customer?.phone,
          currentDebt: _customer?.currentDebt ?? 0.0,
        );
      }).toList();

      _activeBills = noteBills;

      // Setup Fields
      _docNoCtrl.text = widget.billingNote.documentNo;
      _noteCtrl.text = widget.billingNote.note ?? '';
      _issueDate = widget.billingNote.issueDate;
      _dueDate = widget.billingNote.dueDate;
      _dueDateCtrl.text = DateFormat('dd/MM/yyyy').format(_dueDate);

      _isLoading = false;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading edit data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _removeBill(int index) {
    setState(() {
      _activeBills.removeAt(index);
    });
  }

  // Show "Add Pending Bill" Dialog
  Future<void> _showAddPendingDialog() async {
    if (_customer == null) return;
    // Fetch fresh pending bills
    final pending = await _debtorRepo.getPendingBills(_customer!.id);

    // Filter out those already in _activeBills
    final currentIds = _activeBills.map((b) => b.orderId).toSet();
    final available =
        pending.where((b) => !currentIds.contains(b.orderId)).toList();

    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่มีรายการค้างชำระเพิ่มเติม')));
      }
      return;
    }

    if (!mounted) return;

    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('เพิ่มรายการค้างชำระ'),
              content: SizedBox(
                width: 600,
                height: 400,
                child: ListView.builder(
                  itemCount: available.length,
                  itemBuilder: (context, index) {
                    final item = available[index];
                    return ListTile(
                      title: Text('Bill #${item.orderId}'),
                      subtitle: Text(
                          '${DateFormat('dd/MM/yyyy').format(item.createdAt)} - ฿${item.remaining}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        onPressed: () {
                          setState(() {
                            _activeBills.add(item);
                          });
                          Navigator.pop(ctx);
                          _showAddPendingDialog(); // Re-open to pick more
                        },
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('ปิด'))
              ],
            ));
  }

  double get _totalAmount {
    return _activeBills.fold(0.0, (sum, item) {
      return sum + item.remaining;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate:
          DateTime.now().subtract(const Duration(days: 365)), // Allow past?
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
        _dueDateCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (_activeBills.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ไม่มีรายการในใบวางบิล')));
      return;
    }

    setState(() => _isLoading = true);

    // Update Note Object
    final updatedNote = BillingNote(
      id: widget.billingNote.id,
      customerId: widget.billingNote.customerId,
      documentNo: _docNoCtrl.text,
      issueDate: _issueDate,
      dueDate: _dueDate,
      totalAmount: _totalAmount,
      note: _noteCtrl.text,
      status: widget.billingNote.status, // Keep status
      createdAt: widget.billingNote.createdAt,
    );

    List<BillingNoteItem> items = [];
    for (var b in _activeBills) {
      items.add(BillingNoteItem(orderId: b.orderId, amount: b.remaining));
    }

    final success = await _billingRepo.updateBillingNote(updatedNote, items);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('บันทึกไม่สำเร็จ')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 1000,
        height: 700,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('แก้ไขใบวางบิล ${_docNoCtrl.text}',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context))
              ],
            ),
            const SizedBox(height: 20),

            // Info Row
            Row(
              children: [
                const Text('ลูกหนี้: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_customerDisplayCtrl.text,
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: _showAddPendingDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มรายการค้างชำระ'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Table Header
            Container(
              // Reuse header style from Create
              color: Colors.blueGrey.shade800,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: const [
                  Expanded(
                      flex: 1,
                      child: Text('ที่',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white))),
                  Expanded(
                      flex: 2,
                      child: Text('เลขที่',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white))),
                  Expanded(
                      flex: 2,
                      child: Text('วันที่',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white))),
                  Expanded(
                      flex: 2,
                      child: Text('ยอดเงิน',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white))),
                  Expanded(
                      flex: 1,
                      child: Text('ลบ',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white))),
                ],
              ),
            ),

            // List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _activeBills.isEmpty
                      ? const Center(child: Text('ไม่มีรายการ'))
                      : ListView.builder(
                          itemCount: _activeBills.length,
                          itemBuilder: (context, index) {
                            final item = _activeBills[index];
                            return Container(
                              decoration: BoxDecoration(
                                border: const Border(
                                    bottom: BorderSide(
                                        color: Colors.grey, width: 0.5)),
                                color: index % 2 == 0
                                    ? Colors.white
                                    : Colors.grey.shade50,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                      flex: 1,
                                      child: Text('${index + 1}',
                                          textAlign: TextAlign.center)),
                                  Expanded(
                                      flex: 2,
                                      child: Text('${item.orderId}',
                                          textAlign: TextAlign.center)),
                                  Expanded(
                                      flex: 2,
                                      child: Text(
                                          DateFormat('dd/MM/yyyy')
                                              .format(item.createdAt),
                                          textAlign: TextAlign.center)),
                                  Expanded(
                                      flex: 2,
                                      child: Text(
                                          NumberFormat('#,##0.00')
                                              .format(item.remaining),
                                          textAlign: TextAlign.center)),
                                  Expanded(
                                      flex: 1,
                                      child: IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => _removeBill(index),
                                      )),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            const SizedBox(height: 16),
            // Footer
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _dueDateCtrl,
                        readOnly: true,
                        onTap: _pickDate,
                        decoration: const InputDecoration(
                            labelText: 'วันที่ครบกำหนด',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today)),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _noteCtrl,
                        decoration: const InputDecoration(
                            labelText: 'หมายเหตุ',
                            border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Container(
                  width: 300,
                  color: Colors.grey.shade200,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('${_activeBills.length}',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue)),
                      const Text('รายการ'),
                      const SizedBox(height: 5),
                      Text(NumberFormat('#,##0.00').format(_totalAmount),
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue)),
                      const Text('รวมเป็นเงิน'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('บันทึกการแก้ไข'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 50)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('ยกเลิก'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(100, 50)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
