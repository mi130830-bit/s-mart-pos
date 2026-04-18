import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/customer.dart';
import '../../models/member_tier.dart';
import '../../models/debtor_transaction.dart'; // Added
import '../../models/order_item.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/sales_repository.dart';
import '../../repositories/debtor_repository.dart';
import 'create_billing_screen.dart'; // Added
import '../../services/alert_service.dart';

class CustomerDebtorScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDebtorScreen({super.key, required this.customer});

  @override
  State<CustomerDebtorScreen> createState() => _CustomerDebtorScreenState();
}

class _CustomerDebtorScreenState extends State<CustomerDebtorScreen> {
  final CustomerRepository _repo = CustomerRepository();
  final SalesRepository _salesRepo = SalesRepository();
  final DebtorRepository _debtRepo = DebtorRepository(); // Added
  List<DebtorTransaction> _ledger = []; // Changed to List<DebtorTransaction>
  List<Map<String, dynamic>> _historyOrders = []; // Added for History Tab
  Set<int> _outstandingOrderIds = {}; // ✅ Track Unpaid Orders
  bool _isLoading = true;
  late Customer _currentCustomer;
  List<MemberTier> _tiers = [];

  @override
  void initState() {
    super.initState();
    _currentCustomer = widget.customer;
    _refreshCustomer(); // Load fresh data + Ledger
    _loadTiers();
  }

  Future<void> _loadTiers() async {
    try {
      final t = await _repo.getAllTiers();
      if (mounted) {
        setState(() => _tiers = t);
      }
    } catch (_) {}
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
                              '${item.quantity} x ${moneyFormat.format(item.price.toDouble())}'),
                          trailing: Text(
                            moneyFormat.format(item.total.toDouble()),
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
                                '${item.quantity} x ${moneyFormat.format(item.price.toDouble())}',
                                style: const TextStyle(color: Colors.red)),
                            trailing: Text(
                              moneyFormat.format(item.total.toDouble()),
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
    // Load Ledger data from DebtorRepository (Source of Truth)
    final data = await _debtRepo.getDebtorHistory(_currentCustomer.id);

    if (mounted) {
      setState(() {
        _ledger = data;
        _isLoading = false;
      });
    }
  }

  // Added: Load Purchase History
  Future<void> _loadHistory() async {
    final data = await _salesRepo.getOrdersByCustomer(_currentCustomer.id);
    if (mounted) {
      setState(() {
        _historyOrders = data;
      });
    }
  }

  Future<void> _refreshCustomer() async {
    final updated = await _repo.getCustomerById(_currentCustomer.id);

    // ✅ Load Pending Bills to identify what is paid
    final pending = await _debtRepo.getPendingBills(_currentCustomer.id);

    if (updated != null && mounted) {
      setState(() {
        _currentCustomer = updated;
        _outstandingOrderIds = pending.map((e) => e.orderId).toSet();
      });
      _loadLedger();
      _loadHistory(); // Added call
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
      if (item.type == 'CREDIT_SALE' && _selectedIds.contains(item.id)) {
        total += item.amount.toDouble();
      }
    }
    return total;
  }

  Future<void> _recalculateDebt() async {
    setState(() => _isLoading = true);
    final newDebt = await _debtRepo.recalculateDebt(_currentCustomer.id);
    if (mounted) {
      AlertService.show(
        context: context,
        message: 'คำนวณยอดหนี้ใหม่เรียบร้อย: ${newDebt.toString()} บาท',
        type: 'success',
      );
      await _refreshCustomer();
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openPaymentDialog() async {
    final TextEditingController amountController = TextEditingController();

    // ยอดเงินเริ่มต้น: เลือกจากยอดรวมที่เลือก หรือ ยอดหนี้ทั้งหมด
    double defaultAmount =
        _selectedIds.isNotEmpty ? _selectedTotal : _currentCustomer.currentDebt;
    // จัดรูปแบบยอดเงินเริ่มต้นทันที
    amountController.text =
        defaultAmount > 0 ? NumberFormat('#,###.##').format(defaultAmount) : '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isProcessing = false; // สถานะสำหรับ Dialog
        return StatefulBuilder(builder: (builderContext, setStateDialog) {
          // ... (existing helper functions) ...
          double getRawAmount() {
            String clean = amountController.text.replaceAll(',', '');
            return double.tryParse(clean) ?? 0.0;
          }

          double inputAmount = getRawAmount();
          double debtToPay = defaultAmount;
          double change = inputAmount - debtToPay;

          void updateAmount(String val) {
            if (isProcessing) return; // ป้องกันการแก้ไขขณะกำลังประมวลผล
            setStateDialog(() {
              // ... (existing calc logic) ...
              String currentRaw = amountController.text.replaceAll(',', '');
              if (val == 'C') {
                amountController.clear();
                return;
              } else if (val == '⌫') {
                if (currentRaw.isNotEmpty) {
                  currentRaw = currentRaw.substring(0, currentRaw.length - 1);
                }
              } else {
                currentRaw += val;
              }

              // จัดรูปแบบใหม่
              if (currentRaw.isEmpty) {
                amountController.clear();
              } else {
                double d = double.tryParse(currentRaw) ?? 0.0;
                final fmt = NumberFormat('#,###.##');
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
                  // ... (ส่วน UI 1, 2, 3 เหมือนเดิม) ...
                  // 1. ข้อมูลหนี้
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

                  // 2. ช่องกรอกจำนวนเงิน
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

                  // 4. Calculator Pad (Disabled if processing)
                  Opacity(
                    opacity: isProcessing ? 0.5 : 1.0,
                    child: IgnorePointer(
                      ignoring: isProcessing,
                      child: GridView.count(
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
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Suggestion Chips (Banknotes)
                  Opacity(
                    opacity: isProcessing ? 0.5 : 1.0,
                    child: IgnorePointer(
                      ignoring: isProcessing,
                      child: Wrap(
                        spacing: 8,
                        children: [100, 500, 1000].map((note) {
                          return ActionChip(
                            label: Text('+$note'),
                            onPressed: () {
                              double current = getRawAmount();
                              setStateDialog(() {
                                double newVal = current + note;
                                final fmt = NumberFormat('#,###.##');
                                amountController.text = fmt.format(newVal);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (!isProcessing)
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
                onPressed: (inputAmount >= debtToPay && !isProcessing)
                    ? () async {
                        // Prevent Double Click
                        setStateDialog(() => isProcessing = true);

                        // Define vars before try to use in catch if needed/mounted
                        // Define vars before try to use in catch if needed/mounted
                        final nav = Navigator.of(context);

                        try {
                          // Logic assumes user pays exactly what's needed for selected,
                          // OR generic amount.
                          // If multiple selected, we call processBatchPayment

                          if (_selectedIds.isNotEmpty) {
                            // Batch Payment
                            await _debtRepo.processBatchPayment(
                                customerId: _currentCustomer.id,
                                payAmount: inputAmount -
                                    change, // Corrected: Use Net Amount
                                orderIds: _selectedIds.toList());
                          } else {
                            // Lump Sum / Generic Payment

                            // Use payDebt wrapper if available or raw transactDebt (ensure negative)
                            // Using transactDebt with enforced negative as per previous findings
                            await _debtRepo.payDebt(
                                customerId: _currentCustomer.id,
                                amount: inputAmount - change // Net Pay
                                );
                          }

                          if (mounted) {
                            setState(() => _selectedIds.clear());
                            _refreshCustomer();
                            nav.pop();
                            AlertService.show(
                              context: context,
                              message: 'บันทึกการชำระเงินสำเร็จ',
                              type: 'success',
                            );
                          }
                        } catch (e) {
                          // Handle Error
                          setStateDialog(() => isProcessing = false);
                          if (mounted) {
                            AlertService.show(
                              context: context,
                              message: 'Error: $e',
                              type: 'error',
                            );
                          }
                        }
                      }
                    : null,
                child: isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('ยืนยันการรับเงิน',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
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
      length: 3, // Changed to 3
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
              Tab(
                  icon: Icon(Icons.history),
                  text: 'ประวัติการซื้อ'), // Added Tab
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

            // Tab 3: Purchase History (New)
            _buildHistoryTab(moneyFormat, dateFormat),
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
                            Row(
                              children: [
                                Text(
                                  '${_currentCustomer.firstName} ${_currentCustomer.lastName ?? ""}',
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold),
                                ),
                                if (_currentCustomer.lineUserId != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.green.shade200),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.check_circle,
                                            color: Colors.green, size: 16),
                                        SizedBox(width: 4),
                                        Text('LINE OA',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green)),
                                      ],
                                    ),
                                  )
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'รหัสสมาชิก: ${_currentCustomer.memberCode.isEmpty ? "-" : _currentCustomer.memberCode}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 2),
                            Builder(
                              builder: (context) {
                                String tierName = 'ทั่วไป (General)';
                                if (_currentCustomer.tierId != null) {
                                  final t = _tiers.where((t) => t.id == _currentCustomer.tierId).firstOrNull;
                                  if (t != null) {
                                    tierName = '${t.name} (ลด ${t.discountPercentage}%)';
                                  }
                                }
                                return Text(
                                  'ระดับสมาชิก: $tierName',
                                  style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 13),
                                );
                              }
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildProfileRow(Icons.phone, 'เบอร์โทรศัพท์',
                      _currentCustomer.phone?.isNotEmpty == true ? _currentCustomer.phone! : '-'),
                  _buildProfileRow(Icons.cake, 'วันเกิด',
                      _currentCustomer.dateOfBirth != null ? DateFormat('dd/MM/yyyy').format(_currentCustomer.dateOfBirth!) : '-'),
                  _buildProfileRow(Icons.event_busy, 'หมดอายุสมาชิก',
                      _currentCustomer.membershipExpiryDate != null ? DateFormat('dd/MM/yyyy').format(_currentCustomer.membershipExpiryDate!) : '-'),
                  _buildProfileRow(Icons.badge_outlined, 'เลขบัตรประชาชน',
                      _currentCustomer.nationalId?.isNotEmpty == true ? _currentCustomer.nationalId! : '-'),
                  _buildProfileRow(Icons.receipt_long_outlined, 'เลขผู้เสียภาษี',
                      _currentCustomer.taxId?.isNotEmpty == true ? _currentCustomer.taxId! : '-'),
                  _buildProfileRow(Icons.location_on, 'ที่อยู่ตามบัตรประชาชน',
                      _currentCustomer.address?.isNotEmpty == true ? _currentCustomer.address! : '-'),
                  _buildProfileRow(Icons.local_shipping, 'ที่อยู่จัดส่งสินค้า',
                      _currentCustomer.shippingAddress?.isNotEmpty == true ? _currentCustomer.shippingAddress! : '-'),
                  _buildProfileRow(Icons.note, 'หมายเหตุ',
                      _currentCustomer.remarks?.isNotEmpty == true ? _currentCustomer.remarks! : '-'),
                  const Divider(height: 32),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('สถิติ (Statistics)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
                  ),
                  const SizedBox(height: 12),
                  _buildProfileRow(Icons.star, 'คะแนนสะสม',
                      '${NumberFormat('#,##0').format(_currentCustomer.currentPoints)} แต้ม',
                      valueColor: Colors.orange, isBold: true),
                  _buildProfileRow(Icons.shopping_bag, 'ยอดซื้อรวม',
                      '${NumberFormat('#,##0.00').format(_currentCustomer.totalSpending)} บาท',
                      valueColor: Colors.green, isBold: true),
                  _buildProfileRow(
                      Icons.money_off,
                      'ยอดหนี้ค้างชำระ',
                      '${NumberFormat('#,##0.00').format(_currentCustomer.currentDebt)} บาท',
                      valueColor: Colors.red,
                      isBold: true),
                  if (_currentCustomer.lineUserId != null) ...[
                    const Divider(height: 32),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Line Official CRM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: _currentCustomer.linePictureUrl != null
                              ? NetworkImage(_currentCustomer.linePictureUrl!)
                              : null,
                          backgroundColor: Colors.grey.shade200,
                          child: _currentCustomer.linePictureUrl == null
                              ? const Icon(Icons.person, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_currentCustomer.lineDisplayName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Line ID: ...${_currentCustomer.lineUserId!.substring(_currentCustomer.lineUserId!.length > 4 ? _currentCustomer.lineUserId!.length - 4 : 0)}', style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ],
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
            'ลูกค้าเริ่มเปิดบัญชีเมื่อ: ${_ledger.isNotEmpty ? DateFormat('dd/MM/yyyy').format(_ledger.last.createdAt) : "-"}',
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('ยอดหนี้คงเหลือ',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('คำนวณยอดหนี้ใหม่?'),
                            content: const Text(
                                'ระบบจะรวมยอดจากรายการเดินบัญชีทั้งหมดเพื่อให้ได้ยอดปัจจุบันที่ถูกต้องที่สุด'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c),
                                  child: const Text('ยกเลิก')),
                              TextButton(
                                  onPressed: () {
                                    Navigator.pop(c);
                                    _recalculateDebt();
                                  },
                                  child: const Text('ยืนยัน')),
                            ],
                          ),
                        ),
                        child: const Icon(Icons.sync,
                            size: 16, color: Colors.blueGrey),
                      )
                    ],
                  ),
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
                        final id = item.id;
                        final type = item.type;
                        final amount = item.amount.toDouble();
                        final dt = item.createdAt;

                        final isPayment = type == 'DEBT_PAYMENT';
                        final isCreditSale = type == 'CREDIT_SALE';
                        final isSelected = _selectedIds.contains(id);

                        // Check if this Credit Sale is fully paid?
                        // We check if item.orderId is present in _outstandingOrderIds
                        final bool isFullyPaid = isCreditSale &&
                            item.orderId != null &&
                            !_outstandingOrderIds.contains(item.orderId);

                        return ListTile(
                          leading: isCreditSale
                              ? (isFullyPaid
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green) // Paid Icon
                                  : Checkbox(
                                      value: isSelected,
                                      onChanged: (v) => _toggleSelection(id)))
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
                              : 'ซื้อเชื่อ (บิล #${item.orderId ?? "-"})'),
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
                          onTap: (isCreditSale && item.orderId != null)
                              ? () => _showOrderDetail(item.orderId!)
                              : null,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab(NumberFormat moneyFormat, DateFormat dateFormat) {
    if (_historyOrders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('ยังไม่มีประวัติการซื้อ',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _historyOrders.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final order = _historyOrders[i];
        final dt = DateTime.parse(order['createdAt'].toString());
        final status = order['status'];

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: const Icon(Icons.receipt_long, color: Colors.blue),
          ),
          title: Text('บิล #${order['id']}'),
          subtitle:
              Text('${dateFormat.format(dt)} | ${order['paymentMethod']}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '฿${moneyFormat.format(double.tryParse(order['grandTotal'].toString()) ?? 0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16),
              ),
              Text(
                status,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          onTap: () =>
              _showOrderDetail(int.tryParse(order['id'].toString()) ?? 0),
        );
      },
    );
  }

  Future<void> _handleDeleteTransaction(DebtorTransaction item) async {
    final type = item.type;
    final id = item.id;
    final orderId = item.orderId ?? 0;

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
            AlertService.show(
              context: context,
              message: 'เพิ่มหนี้ยกมาสำเร็จ',
              type: 'success',
            );
            _refreshCustomer();
          }
        } catch (e) {
          if (mounted) {
            AlertService.show(
              context: context,
              message: 'เกิดข้อผิดพลาด: $e',
              type: 'error',
            );
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
            AlertService.show(
              context: context,
              message: 'ลบรายการสำเร็จ',
              type: 'success',
            );
            _refreshCustomer();
          }
        } catch (e) {
          if (mounted) {
            AlertService.show(
              context: context,
              message: 'เกิดข้อผิดพลาด: $e',
              type: 'error',
            );
          }
        }
      }
    }
  }
}
