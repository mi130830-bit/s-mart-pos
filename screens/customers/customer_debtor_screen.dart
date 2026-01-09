import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/customer.dart';
import '../../models/order_item.dart'; // Added
import '../../repositories/customer_repository.dart';
import '../../repositories/sales_repository.dart'; // Added
import '../../repositories/debtor_repository.dart'; // Added
import 'create_billing_screen.dart'; // Added

class CustomerDebtorScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDebtorScreen({super.key, required this.customer});

  @override
  State<CustomerDebtorScreen> createState() => _CustomerDebtorScreenState();
}

class _CustomerDebtorScreenState extends State<CustomerDebtorScreen> {
  final CustomerRepository _repo = CustomerRepository();
  final SalesRepository _salesRepo = SalesRepository(); // Added
  List<Map<String, dynamic>> _ledger = [];
  bool _isLoading = true;
  late Customer _currentCustomer;

  @override
  void initState() {
    super.initState();
    _currentCustomer = widget.customer;
    _refreshCustomer(); // Load fresh data + Ledger
  }

  // Show Order Details Dialog
  Future<void> _showOrderDetail(int orderId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _salesRepo.getOrderWithItems(orderId);
    if (!mounted) return;
    Navigator.pop(context); // Close Loading

    if (result == null) return;

    final items = result['items'] as List<OrderItem>;
    final returns = (result['returns'] as List<OrderItem>?) ?? [];
    final order = result['order'];
    final dt = DateTime.parse(order['createdAt'].toString());
    final moneyFormat = NumberFormat('#,##0.00');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('รายละเอียดบิล #$orderId\n${dateFormat.format(dt)}',
            textAlign: TextAlign.center),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...items.map((item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.productName),
                          subtitle: Text(
                              '${item.quantity} x ${moneyFormat.format(item.price)}'),
                          trailing: Text(
                            moneyFormat.format(item.total),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        )),
                    if (returns.isNotEmpty) ...[
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('รายการคืนสินค้า / ส่วนลด',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                      ),
                      ...returns.map((item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.productName,
                                style: const TextStyle(color: Colors.red)),
                            subtitle: Text(
                                '${item.quantity} x ${moneyFormat.format(item.price)}',
                                style: const TextStyle(color: Colors.red)),
                            trailing: Text(
                              moneyFormat.format(item.total),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red),
                            ),
                          )),
                    ],
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('ยอดรวมสุทธิ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text(
                  '฿${moneyFormat.format(double.tryParse(order['grandTotal'].toString()) ?? 0)}',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ปิด')),
        ],
      ),
    );
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    // Load Ledger data from Repository
    final List<Map<String, dynamic>> data =
        await _repo.getLedger(_currentCustomer.id);

    if (mounted) {
      setState(() {
        _ledger = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshCustomer() async {
    final updated = await _repo.getCustomerById(_currentCustomer.id);
    if (updated != null && mounted) {
      setState(() {
        _currentCustomer = updated;
      });
      _loadLedger();
    }
  }

  // Selection Set
  final Set<int> _selectedIds = {};

  // Toggle Selection
  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  // Calculate Total Selected
  double get _selectedTotal {
    double total = 0.0;
    for (var item in _ledger) {
      if (item['transactionType'] == 'CREDIT_SALE' &&
          _selectedIds.contains(item['id'])) {
        total += double.parse(item['amount'].toString());
      }
    }
    return total;
  }

  Future<void> _openPaymentDialog() async {
    final TextEditingController amountController = TextEditingController();

    // Default amount: Either selected total or full debt
    double defaultAmount =
        _selectedIds.isNotEmpty ? _selectedTotal : _currentCustomer.currentDebt;
    // Format default amount immediately
    amountController.text =
        defaultAmount > 0 ? NumberFormat('#,###.##').format(defaultAmount) : '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          // Helper to parse value from controller (handling commas)
          double getRawAmount() {
            String clean = amountController.text.replaceAll(',', '');
            return double.tryParse(clean) ?? 0.0;
          }

          double inputAmount = getRawAmount();
          double debtToPay = defaultAmount;
          double change = inputAmount - debtToPay;

          void updateAmount(String val) {
            setStateDialog(() {
              String currentRaw = amountController.text.replaceAll(',', '');
              // Handle overwrite if needed, but simple append for now
              // If text has decimal point? The current keypad has no dot.
              // Assuming integer input for custom keypad OR preserving existing decimals if logic allows.
              // But we will re-format as Number, so effectively integer-like entering unless we handle dot.

              if (val == 'C') {
                amountController.clear();
                return;
              } else if (val == '⌫') {
                if (currentRaw.isNotEmpty) {
                  currentRaw = currentRaw.substring(0, currentRaw.length - 1);
                }
              } else {
                if (currentRaw.contains('.')) {
                  // Try to avoid appending to decimals for now or handle smart logic.
                  // Simple logic: If it has dot, we are appending to decimal part.
                  // But standard int format might strip it.
                  // Let's strip decimals if user starts typing new number?
                  // No, let's just append and format.
                  currentRaw += val;
                } else {
                  currentRaw += val;
                }
              }

              // Re-format
              if (currentRaw.isEmpty) {
                amountController.clear();
              } else {
                double d = double.tryParse(currentRaw) ?? 0.0;
                // Use NumberFormat with commas, no fixed decimals for input (Int behavior favored)
                // If previous had decimals (e.g. from default), typing might feel weird.
                // Let's stick to: "If user types, we format as #,###"
                // If it ends with .00 we might lose it, which is fine for "New Entry" feel.

                final fmt =
                    NumberFormat('#,###.##'); // allow decimals if present
                // Special handling: don't let NumberFormat kill pending decimal input if we had dot button (we don't yet).

                amountController.text = fmt.format(d);
              }
            });
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('รับชำระหนี้ (Payment)',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Debt Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ยอดที่ต้องชำระ:',
                            style: TextStyle(fontSize: 16)),
                        Text(NumberFormat('#,##0.00').format(debtToPay),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Input Amount
                  TextField(
                    controller: amountController,
                    readOnly: true, // Use calculator buttons
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'รับเงินมา',
                      prefixText: '฿ ',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  // 3. Change Display
                  if (change > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('เงินทอน:',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                          Text(NumberFormat('#,##0.00').format(change),
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                  const Divider(),

                  // 4. Calculator Pad
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      for (var key in [
                        '7',
                        '8',
                        '9',
                        '4',
                        '5',
                        '6',
                        '1',
                        '2',
                        '3',
                        'C',
                        '0',
                        '⌫'
                      ])
                        ElevatedButton(
                          onPressed: () => updateAmount(key),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (key == 'C' || key == '⌫')
                                ? Colors.red.shade50
                                : Colors.grey.shade100,
                            foregroundColor: (key == 'C' || key == '⌫')
                                ? Colors.red
                                : Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(key,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Suggestion Chips (Banknotes)
                  Wrap(
                    spacing: 8,
                    children: [100, 500, 1000].map((note) {
                      return ActionChip(
                        label: Text('+$note'),
                        onPressed: () {
                          double current = getRawAmount();
                          setStateDialog(() {
                            // Add note value and re-format
                            double newVal = current + note;
                            final fmt = NumberFormat('#,###.##');
                            amountController.text = fmt.format(newVal);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12)),
                child: const Text('ยกเลิก', style: TextStyle(fontSize: 16)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                onPressed: inputAmount >= debtToPay
                    ? () async {
                        // Confirm Payment Logic
                        // Actual payment is limited to debt amount (cannot overpay debt in system usually)
                        // Or we record full payment and system handles credit balance.
                        // For now, let's record only the Debt Amount as paid.

                        final payAmount =
                            debtToPay; // Only pay what is owed/selected

                        String note = 'ชำระหนี้';
                        if (_selectedIds.isNotEmpty) {
                          final oids = _ledger
                              .where((i) => _selectedIds.contains(i['id']))
                              .map((i) => '#${i['orderId']}')
                              .join(', ');
                          note += ' (รายการ: $oids)';
                        }
                        note +=
                            ' | รับเงิน: ${NumberFormat('#,##0.00').format(inputAmount)} | ทอน: ${NumberFormat('#,##0.00').format(change)}';

                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(context);

                        await _repo.addTransaction(
                          customerId: _currentCustomer.id,
                          type: 'DEBT_PAYMENT',
                          amount: -payAmount,
                          note: note,
                        );

                        if (mounted) {
                          setState(() => _selectedIds.clear());
                          _refreshCustomer();
                          nav.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                                content: Text('บันทึกการชำระเงินสำเร็จ'),
                                backgroundColor: Colors.green),
                          );
                        }
                      }
                    : null, // Disable if not enough money
                child: const Text('ยืนยันการรับเงิน',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final moneyFormat = NumberFormat('#,##0.00');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('จัดการข้อมูล: ${_currentCustomer.firstName}'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person), text: 'ข้อมูลลูกค้า'),
              Tab(
                  icon: Icon(Icons.account_balance_wallet),
                  text: 'รายการบัญชี/หนี้'),
            ],
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
          ),
          actions: [
            // New: Create Billing Note Shortcut
            IconButton(
              tooltip: 'สร้างใบวางบิล',
              icon: const Icon(Icons.receipt_long, color: Colors.purple),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateBillingScreen(
                      preSelectedCustomer: _currentCustomer,
                    ),
                  ),
                );
              },
            ),
            if (_selectedIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                    child: Text('เลือก ${_selectedIds.length} รายการ',
                        style: const TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold))),
              )
          ],
        ),
        body: TabBarView(
          children: [
            // Tab 1: Customer Profile
            _buildProfileTab(),

            // Tab 2: Ledger/Debt List (Existing Logic)
            _buildLedgerTab(moneyFormat, dateFormat),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Info Card
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.blue.shade50,
                        child: Text(
                          _currentCustomer.firstName.isNotEmpty
                              ? _currentCustomer.firstName[0]
                              : '?',
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_currentCustomer.firstName} ${_currentCustomer.lastName ?? ""}',
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'รหัสสมาชิก: ${_currentCustomer.memberCode.isEmpty ? "-" : _currentCustomer.memberCode}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildProfileRow(Icons.phone, 'เบอร์โทรศัพท์',
                      _currentCustomer.phone ?? '-'),
                  _buildProfileRow(Icons.location_on, 'ที่อยู่',
                      _currentCustomer.address ?? '-'),
                  _buildProfileRow(Icons.star, 'คะแนนสะสม',
                      '${_currentCustomer.currentPoints} แต้ม'),
                  _buildProfileRow(
                      Icons.money,
                      'ยอดหนี้ค้างชำระ',
                      NumberFormat('#,##0.00')
                          .format(_currentCustomer.currentDebt),
                      valueColor: Colors.red,
                      isBold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Actions or other info can go here
          const Text('ประวัติย่อ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            'ลูกค้าเริ่มเปิดบัญชีเมื่อ: ${_ledger.isNotEmpty ? DateFormat('dd/MM/yyyy').format(DateTime.parse(_ledger.last['createdAt'].toString())) : "-"}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerTab(NumberFormat moneyFormat, DateFormat dateFormat) {
    return Column(
      children: [
        // Header Summary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: Colors.grey.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ยอดหนี้คงเหลือ',
                      style: TextStyle(color: Colors.grey)),
                  Text(
                    '฿${moneyFormat.format(_currentCustomer.currentDebt)}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _openPaymentDialog,
                icon: const Icon(Icons.payment),
                label: Text(_selectedIds.isNotEmpty
                    ? 'ชำระ ${_selectedIds.length} รายการ'
                    : 'รับชำระหนี้'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Ledger List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _ledger.isEmpty
                  ? const Center(
                      child: Text('ยังไม่มีรายการเคลื่อนไหว',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      itemCount: _ledger.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final item = _ledger[i];
                        final id = int.tryParse(item['id'].toString()) ?? 0;
                        final type = item['transactionType'];
                        final amount = double.parse(item['amount'].toString());
                        final dt = DateTime.parse(item['createdAt'].toString());

                        final isPayment = type == 'DEBT_PAYMENT';
                        final isCreditSale = type == 'CREDIT_SALE';
                        final isSelected = _selectedIds.contains(id);

                        return ListTile(
                          leading: isCreditSale
                              ? Checkbox(
                                  value: isSelected,
                                  onChanged: (v) => _toggleSelection(id))
                              : CircleAvatar(
                                  backgroundColor: isPayment
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                                  child: Icon(
                                    isPayment
                                        ? Icons.check_circle
                                        : Icons.shopping_cart,
                                    color:
                                        isPayment ? Colors.green : Colors.red,
                                  ),
                                ),
                          title: Text(isPayment
                              ? 'ชำระหนี้'
                              : 'ซื้อเชื่อ (บิล #${item['orderId'] ?? "-"})'),
                          subtitle: Text(dateFormat.format(dt)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                (amount > 0 ? '+' : '') +
                                    moneyFormat.format(amount),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: amount > 0 ? Colors.red : Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.grey),
                                onPressed: () => _handleDeleteTransaction(item),
                                tooltip: 'ลบรายการ',
                              ),
                            ],
                          ),
                          onTap: (isCreditSale && item['orderId'] != null)
                              ? () => _showOrderDetail(
                                  int.parse(item['orderId'].toString()))
                              : null,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _handleDeleteTransaction(Map<String, dynamic> item) async {
    final type = item['transactionType'];
    final id = int.tryParse(item['id'].toString()) ?? 0;
    final orderId = int.tryParse(item['orderId']?.toString() ?? '0') ?? 0;

    if (type == 'DEBT_PAYMENT') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ลบรายการชำระเงิน'),
          content:
              const Text('ต้องการลบรายการชำระเงินนี้และคืนยอดหนี้ใช่หรือไม่?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('ยกเลิก')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('ยืนยันลบ',
                    style: TextStyle(color: Colors.white))),
          ],
        ),
      );

      if (confirm == true) {
        try {
          // Use DebtorRepository logic
          await DebtorRepository().deleteTransaction(id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('ลบรายการชำระเงินเรียบร้อย'),
                backgroundColor: Colors.green));
            _refreshCustomer();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('เกิดข้อผิดพลาด: $e'),
                backgroundColor: Colors.red));
          }
        }
      }
    } else if (type == 'CREDIT_SALE' && orderId > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('ลบรายการขายเชื่อ #$orderId'),
          content: const Text(
              'ต้องการลบรายการนี้ใช่หรือไม่?\n(กรุณาเลือกการจัดการสต็อก)'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child:
                    const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('ลบ (ไม่คืนสต็อก)',
                  style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('ลบ (และคืนสต็อก)',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != null) {
        try {
          await _salesRepo.deleteOrder(orderId, returnToStock: confirm);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('ลบรายการสำเร็จ'),
                backgroundColor: Colors.green));
            _refreshCustomer();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('เกิดข้อผิดพลาด: $e'),
                backgroundColor: Colors.red));
          }
        }
      }
    }
  }
}
