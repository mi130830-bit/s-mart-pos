import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/customer.dart';
import '../controllers/create_billing_controller.dart';

class CreateBillingScreen extends ConsumerStatefulWidget {
  final Customer? preSelectedCustomer;

  const CreateBillingScreen({super.key, this.preSelectedCustomer});

  @override
  ConsumerState<CreateBillingScreen> createState() => _CreateBillingScreenState();
}

class _CreateBillingScreenState extends ConsumerState<CreateBillingScreen> {
  // Controllers
  final TextEditingController _searchBillCtrl = TextEditingController();
  final TextEditingController _customerDisplayCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _dueDateCtrl = TextEditingController();

  final DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    _dueDateCtrl.text = DateFormat('dd/MM/yyyy').format(_dueDate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(createBillingProvider.notifier);
      if (widget.preSelectedCustomer != null) {
        _selectCustomer(widget.preSelectedCustomer!, controller);
      } else {
        controller.loadCustomers(context);
      }
    });
  }

  @override
  void dispose() {
    _searchBillCtrl.dispose();
    _customerDisplayCtrl.dispose();
    _noteCtrl.dispose();
    _dueDateCtrl.dispose();
    super.dispose();
  }

  void _selectCustomer(Customer c, CreateBillingController controller) {
    _customerDisplayCtrl.text = '${c.firstName} ${c.lastName ?? ""}';
    controller.selectCustomer(context, c);
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
  Future<void> _showCustomerSearchDialog(CreateBillingState state, CreateBillingController controller) async {
    showDialog(
      context: context,
      builder: (context) {
        List<Customer> filtered = List.from(state.allCustomers);
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
                          filtered = state.allCustomers.where((c) {
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
                              _selectCustomer(c, controller);
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

  Future<void> _save(CreateBillingController controller) async {
    final success = await controller.saveBillingNote(
      context,
      issueDate: _issueDate,
      dueDate: _dueDate,
      note: _noteCtrl.text,
    );
    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createBillingProvider);
    final controller = ref.read(createBillingProvider.notifier);

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
                  onPressed: () => _showCustomerSearchDialog(state, controller),
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
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.activeBills.isEmpty
                      ? Container(
                          color: Colors.grey.shade100,
                          width: double.infinity,
                          height: double.infinity) // Empty space
                      : ListView.builder(
                          itemCount: state.activeBills.length,
                          itemBuilder: (context, index) {
                            // Search Filter logic (Local)
                            final item = state.activeBills[index];
                            final orderId = item.orderId.toString();
                            if (_searchBillCtrl.text.isNotEmpty &&
                                !orderId.contains(_searchBillCtrl.text)) {
                              return const SizedBox.shrink();
                            }

                            final dt = item.createdAt;
                            final remaining = item.remaining;

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
                                          textAlign: TextAlign.center)),
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
                                        onPressed: () => controller.removeBill(index),
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
                      Text('${state.activeBills.length}',
                          style: const TextStyle(
                              fontSize: 32,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold)),
                      const Text('จำนวนบิล',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(NumberFormat('#,##0.00').format(state.totalAmount),
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
                  onPressed: state.isLoading ? null : () => _save(controller),
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
