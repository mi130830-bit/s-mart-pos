import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/customer.dart';
import '../../models/billing_note.dart';
import '../../models/billing_note_item.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/billing_repository.dart';
import '../../repositories/debtor_repository.dart';
import '../../models/outstanding_bill.dart';

class CreateBillingScreen extends StatefulWidget {
  final Customer? preSelectedCustomer;

  const CreateBillingScreen({super.key, this.preSelectedCustomer});

  @override
  State<CreateBillingScreen> createState() => _CreateBillingScreenState();
}

class _CreateBillingScreenState extends State<CreateBillingScreen> {
  final CustomerRepository _customerRepo = CustomerRepository();
  final BillingRepository _billingRepo = BillingRepository();
  final DebtorRepository _debtorRepo = DebtorRepository();

  // Data
  List<Customer> _allCustomers = [];
  Customer? _selectedCustomer;
  List<OutstandingBill> _activeBills =
      []; // List of bills currently in the table
  bool _isLoading = false;

  // Controllers
  final TextEditingController _searchBillCtrl =
      TextEditingController(); // "Search Bill"
  final TextEditingController _customerDisplayCtrl =
      TextEditingController(); // "Debtor Name"
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _dueDateCtrl = TextEditingController();

  final DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    _dueDateCtrl.text = DateFormat('dd/MM/yyyy').format(_dueDate);
    if (widget.preSelectedCustomer != null) {
      _selectCustomer(widget.preSelectedCustomer!);
    } else {
      _loadCustomers();
    }
  }

  Future<void> _loadCustomers() async {
    final list = await _customerRepo.getAllCustomers();
    if (mounted) {
      setState(() {
        _allCustomers = list;
      });
    }
  }

  void _selectCustomer(Customer c) {
    setState(() {
      _selectedCustomer = c;
      _customerDisplayCtrl.text = '${c.firstName} ${c.lastName ?? ""}';
    });
    _loadPendingBills(c.id);
  }

  Future<void> _loadPendingBills(int customerId) async {
    setState(() => _isLoading = true);
    try {
      final bills = await _debtorRepo.getPendingBills(customerId);
      if (mounted) {
        setState(() {
          _activeBills = List.from(bills); // Copy all to active
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _removeBill(int index) {
    setState(() {
      _activeBills.removeAt(index);
    });
  }

  double get _totalAmount {
    return _activeBills.fold(0.0, (sum, item) {
      return sum + item.remaining;
    });
  }

  // Pick Date
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
        _dueDateCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  // Search Dialog
  Future<void> _showCustomerSearchDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        List<Customer> filtered = List.from(_allCustomers);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('ค้นหาจากสมาชิก'),
              content: SizedBox(
                width: 500,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'ชื่อ, เบอร์โทร...',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (query) {
                        setDialogState(() {
                          final q = query.toLowerCase();
                          filtered = _allCustomers.where((c) {
                            return c.firstName.toLowerCase().contains(q) ||
                                (c.lastName ?? '').toLowerCase().contains(q) ||
                                (c.phone ?? '').contains(q);
                          }).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final c = filtered[index];
                          return ListTile(
                            title: Text('${c.firstName} ${c.lastName ?? ""}'),
                            subtitle: Text(c.phone ?? '-'),
                            trailing: c.currentDebt > 0
                                ? Text(
                                    '฿${NumberFormat("#,##0").format(c.currentDebt)}',
                                    style: const TextStyle(color: Colors.red))
                                : null,
                            onTap: () {
                              Navigator.pop(context);
                              _selectCustomer(c);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ปิด'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณาเลือกลูกหนี้')));
      return;
    }
    if (_activeBills.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ไม่มีรายการในใบวางบิล')));
      return;
    }

    setState(() => _isLoading = true);

    final note = BillingNote(
      customerId: _selectedCustomer!.id,
      documentNo: 'INV-${DateTime.now().millisecondsSinceEpoch}', // Logic เดิม
      issueDate: _issueDate,
      dueDate: _dueDate,
      totalAmount: _totalAmount,
      note: _noteCtrl.text,
      status: 'PENDING',
    );

    List<BillingNoteItem> items = [];
    for (var b in _activeBills) {
      final orderId = b.orderId;
      final amount = b.remaining;
      items.add(BillingNoteItem(orderId: orderId, amount: amount));
    }

    final success = await _billingRepo.createBillingNote(note, items);

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
            const Text('สร้างใบวางบิล',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Search Row
            Row(
              children: [
                const Text('ค้นหาบิล: '),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _searchBillCtrl,
                    decoration: const InputDecoration(
                      hintText: 'ค้นหาบิล',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    // Local filter logic implemented below in ListView
                    setState(() {});
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('ค้นหา'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showCustomerSearchDialog,
                  icon: const Icon(Icons.person_search),
                  label: const Text('ค้นหาจากสมาชิก'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white),
                ),
                const SizedBox(width: 20),
                const Text('ลูกหนี้: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 2),
                    decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey))),
                    child: Text(_customerDisplayCtrl.text,
                        style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Table Header
            Container(
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
                      child: Text('ลงวันที่',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white))),
                  Expanded(
                      flex: 2,
                      child: Text('วันที่ครบกำหนด',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white))),
                  Expanded(
                      flex: 2,
                      child: Text('จำนวนเงิน',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white))),
                  Expanded(
                      flex: 3,
                      child: Text('หมายเหตุ',
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

            // Table Body
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _activeBills.isEmpty
                      ? Container(
                          color: Colors.grey.shade100,
                          width: double.infinity,
                          height: double.infinity) // Empty space
                      : ListView.builder(
                          itemCount: _activeBills.length,
                          itemBuilder: (context, index) {
                            // Search Filter logic (Local)
                            final item = _activeBills[index];
                            final orderId = item.orderId.toString();
                            if (_searchBillCtrl.text.isNotEmpty &&
                                !orderId.contains(_searchBillCtrl.text)) {
                              return const SizedBox
                                  .shrink(); // Hide if not match local search
                            }

                            final dt = item.createdAt;
                            final remaining = item.remaining;
                            // Note?

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
                                      child: Text(orderId,
                                          textAlign: TextAlign.center)),
                                  Expanded(
                                      flex: 2,
                                      child: Text(
                                          DateFormat('dd/MM/yyyy').format(dt),
                                          textAlign: TextAlign.center)),
                                  Expanded(
                                      flex: 2,
                                      child: Text(
                                          DateFormat('dd/MM/yyyy').format(
                                              dt.add(const Duration(days: 30))),
                                          textAlign: TextAlign
                                              .center)), // Est due date
                                  Expanded(
                                      flex: 2,
                                      child: Text(
                                          NumberFormat('#,##0.00')
                                              .format(remaining),
                                          textAlign: TextAlign.end,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  Expanded(
                                      flex: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        child: Text(
                                            item.status == 'HELD'
                                                ? 'พักบิล'
                                                : '',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                color: Colors.grey)),
                                      )),
                                  Expanded(
                                      flex: 1,
                                      child: IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red, size: 20),
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
                  flex: 2,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                              width: 100,
                              child: Text('วันที่นัดชำระ:',
                                  textAlign: TextAlign.right)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _dueDateCtrl,
                              readOnly: true,
                              onTap: _pickDate,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                suffixIcon:
                                    Icon(Icons.calendar_today, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(
                              width: 100,
                              child: Text('หมายเหตุ:',
                                  textAlign: TextAlign.right)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _noteCtrl,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'หมายเหตุ',
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                // Summary Box
                Container(
                  width: 300,
                  color: Colors.grey.shade200,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('${_activeBills.length}',
                          style: const TextStyle(
                              fontSize: 32,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold)),
                      const Text('จำนวนบิล',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(NumberFormat('#,##0.00').format(_totalAmount),
                          style: const TextStyle(
                              fontSize: 32,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold)),
                      const Text('ราคา',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 45)),
                  onPressed: _isLoading ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('บันทึก'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 45)),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('ยกเลิก'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
