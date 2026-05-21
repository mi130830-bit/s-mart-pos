import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/customer.dart';
import '../../models/member_tier.dart';
import '../../models/debtor_transaction.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/sales_repository.dart';
import '../../repositories/debtor_repository.dart';
import 'billing/create_billing_screen.dart';
import '../../services/alert_service.dart';
import 'dialogs/customer_debtor/customer_debtor_order_detail_dialog.dart';
import 'dialogs/customer_debtor/customer_debtor_payment_dialog.dart';
import 'widgets/customer_debtor/customer_debtor_profile_tab.dart';
import 'widgets/customer_debtor/customer_debtor_ledger_tab.dart';
import 'widgets/customer_debtor/customer_debtor_history_tab.dart';

class CustomerDebtorScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDebtorScreen({super.key, required this.customer});

  @override
  State<CustomerDebtorScreen> createState() => _CustomerDebtorScreenState();
}

class _CustomerDebtorScreenState extends State<CustomerDebtorScreen> {
  final CustomerRepository _repo = CustomerRepository();
  final SalesRepository _salesRepo = SalesRepository();
  final DebtorRepository _debtRepo = DebtorRepository();

  List<DebtorTransaction> _ledger = [];
  List<Map<String, dynamic>> _historyOrders = [];
  Set<int> _outstandingOrderIds = {};
  final Set<int> _selectedIds = {};

  bool _isLoading = true;
  late Customer _currentCustomer;
  List<MemberTier> _tiers = [];

  final _moneyFormat = NumberFormat('#,##0.00');
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _currentCustomer = widget.customer;
    _refreshCustomer();
    _loadTiers();
  }

  // ─── Data Loading ────────────────────────────────────────────────────────────

  Future<void> _loadTiers() async {
    try {
      final t = await _repo.getAllTiers();
      if (mounted) setState(() => _tiers = t);
    } catch (_) {}
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    final data = await _debtRepo.getDebtorHistory(_currentCustomer.id);
    if (mounted) {
      setState(() {
        _ledger = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    final data = await _salesRepo.getOrdersByCustomer(_currentCustomer.id);
    if (mounted) setState(() => _historyOrders = data);
  }

  Future<void> _refreshCustomer() async {
    final updated = await _repo.getCustomerById(_currentCustomer.id);
    final pending = await _debtRepo.getPendingBills(_currentCustomer.id);

    if (updated != null && mounted) {
      setState(() {
        _currentCustomer = updated;
        _outstandingOrderIds = pending.map((e) => e.orderId).toSet();
      });
      _loadLedger();
      _loadHistory();
    }
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
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
    await showDebtPaymentDialog(
      context: context,
      currentCustomer: _currentCustomer,
      ledger: _ledger,
      selectedIds: _selectedIds,
      debtRepo: _debtRepo,
      onSuccess: () {
        setState(() => _selectedIds.clear());
        _refreshCustomer();
      },
    );
  }

  Future<void> _showOrderDetail(int orderId) async {
    await showOrderDetailDialog(
      context: context,
      orderId: orderId,
      salesRepo: _salesRepo,
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

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
              Tab(icon: Icon(Icons.history), text: 'ประวัติการซื้อ'),
            ],
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
          ),
          actions: [
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
                            color: Colors.blue,
                            fontWeight: FontWeight.bold))),
              ),
          ],
        ),
        body: TabBarView(
          children: [
            CustomerDebtorProfileTab(
              currentCustomer: _currentCustomer,
              tiers: _tiers,
              ledger: _ledger,
            ),
            CustomerDebtorLedgerTab(
              currentCustomer: _currentCustomer,
              ledger: _ledger,
              selectedIds: _selectedIds,
              outstandingOrderIds: _outstandingOrderIds,
              isLoading: _isLoading,
              moneyFormat: _moneyFormat,
              dateFormat: _dateFormat,
              onOpenPaymentDialog: _openPaymentDialog,
              onToggleSelection: _toggleSelection,
              onDeleteTransaction: _handleDeleteTransaction,
              onShowOrderDetail: _showOrderDetail,
              onRecalculateDebt: _recalculateDebt,
            ),
            CustomerDebtorHistoryTab(
              historyOrders: _historyOrders,
              moneyFormat: _moneyFormat,
              dateFormat: _dateFormat,
              onShowOrderDetail: _showOrderDetail,
            ),
          ],
        ),
      ),
    );
  }
}
