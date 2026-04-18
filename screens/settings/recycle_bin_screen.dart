import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../state/auth_provider.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/debtor_repository.dart';
import '../../repositories/sales_repository.dart';
import '../../services/alert_service.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProductRepository _productRepo = ProductRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final DebtorRepository _debtorRepo = DebtorRepository();
  final SalesRepository _salesRepo = SalesRepository();

  List<Map<String, dynamic>> _deletedProducts = [];
  List<Map<String, dynamic>> _deletedCustomers = [];
  List<Map<String, dynamic>> _deletedDebts = [];
  List<Map<String, dynamic>> _voidedBills = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final products = await _productRepo.getDeletedProducts();
    final customers = await _customerRepo.getDeletedCustomers();
    final debts = await _debtorRepo.getDeletedTransactions();
    final voided = await _salesRepo.getVoidedOrders();

    if (mounted) {
      setState(() {
        _deletedProducts = products;
        _deletedCustomers = customers;
        _deletedDebts = debts;
        _voidedBills = voided;
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreProduct(int id, String name) async {
    final success = await _productRepo.restoreProduct(id);
    if (success && mounted) {
      AlertService.show(
        context: context,
        message: 'กู้คืนสินค้า "$name" สำเร็จ',
        type: 'success',
      );
      _loadData(); // Refresh
    }
  }

  Future<void> _restoreCustomer(int id, String name) async {
    final success = await _customerRepo.restoreCustomer(id);
    if (success && mounted) {
      AlertService.show(
        context: context,
        message: 'กู้คืนลูกค้า "$name" สำเร็จ',
        type: 'success',
      );
      _loadData(); // Refresh
    }
  }

  Future<void> _restoreDebt(int id) async {
    final success = await _debtorRepo.restoreTransaction(id);
    if (success && mounted) {
      AlertService.show(
        context: context,
        message: 'กู้คืนรายการหนี้สำเร็จ',
        type: 'success',
      );
      _loadData(); // Refresh
    }
  }

  Future<void> _restoreVoidedBill(int orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันกู้คืนบิล'),
        content: const Text(
            'การกู้คืนบิลจะทำให้สถานะกลับมาเป็น "สำเร็จ" และกู้คืนหนี้ (ถ้ามี)\n\n'
            '⚠️ ข้อควรระวัง: ระบบจะ **ไม่** ตัดสต็อกสินค้าใหม่อัตโนมัติ '
            'คุณต้องตรวจสอบและปรับสต็อกด้วยตัวเองหากจำเป็น\n\n'
            'ต้องการดำเนินการต่อหรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันกู้คืน',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _salesRepo.unvoidOrder(orderId, 'Unvoid by Admin');
      if (mounted) {
        AlertService.show(
          context: context,
          message: 'กู้คืนบิลสำเร็จ (สถานะและหนี้)',
          type: 'success',
        );
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = Provider.of<AuthProvider>(context).isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ถังขยะ (Recycle Bin)',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue, // Explicit color for contrast
        iconTheme:
            const IconThemeData(color: Colors.white), // Back button color
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white, // Selected tab text color
          unselectedLabelColor: Colors.white70, // Unselected tab text color
          indicatorColor: Colors.white, // Indicator line color
          tabs: const [
            Tab(text: 'สินค้าที่ลบ', icon: Icon(Icons.inventory_2_outlined)),
            Tab(text: 'ลูกค้าที่ลบ', icon: Icon(Icons.people_outline)),
            Tab(text: 'รายการหนี้', icon: Icon(Icons.money_off)),
            Tab(text: 'บิลที่ยกเลิก', icon: Icon(Icons.receipt_long)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProductList(isAdmin),
                _buildCustomerList(isAdmin),
                _buildDebtList(isAdmin),
                _buildVoidedBillList(isAdmin),
              ],
            ),
    );
  }

  Widget _buildProductList(bool isAdmin) {
    if (_deletedProducts.isEmpty) {
      return const Center(child: Text('ไม่มีสินค้าที่ถูกลบ'));
    }
    return ListView.separated(
      itemCount: _deletedProducts.length,
      separatorBuilder: (c, i) => const Divider(),
      itemBuilder: (context, index) {
        final item = _deletedProducts[index];
        final df = DateFormat('dd/MM/yyyy HH:mm');
        final deletedAt = item['deletedAt'] != null
            ? df.format(DateTime.parse(item['deletedAt'].toString()))
            : '-';

        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.red,
            child: Icon(Icons.inventory, color: Colors.white),
          ),
          title: Text(item['name'] ?? '-'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bar: ${item['barcode']} | Price: ${item['retailPrice']}'),
              Text('ลบเมื่อ: $deletedAt | โดย: ${item['deleteReason'] ?? "-"}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          trailing: isAdmin
              ? ElevatedButton.icon(
                  icon: const Icon(Icons.restore_from_trash),
                  label: const Text('กู้คืน'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white),
                  onPressed: () => _restoreProduct(
                      int.parse(item['id'].toString()), item['name']),
                )
              : null,
        );
      },
    );
  }

  Widget _buildCustomerList(bool isAdmin) {
    if (_deletedCustomers.isEmpty) {
      return const Center(child: Text('ไม่มีลูกค้าที่ถูกลบ'));
    }
    return ListView.separated(
      itemCount: _deletedCustomers.length,
      separatorBuilder: (c, i) => const Divider(),
      itemBuilder: (context, index) {
        final item = _deletedCustomers[index];
        final df = DateFormat('dd/MM/yyyy HH:mm');
        final deletedAt = item['deletedAt'] != null
            ? df.format(DateTime.parse(item['deletedAt'].toString()))
            : '-';

        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.orange,
            child: Icon(Icons.person, color: Colors.white),
          ),
          title: Text('${item['firstName']} ${item['lastName'] ?? ""}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phone: ${item['phone']}'),
              Text('ลบเมื่อ: $deletedAt | โดย: ${item['deleteReason'] ?? "-"}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          trailing: isAdmin
              ? ElevatedButton.icon(
                  icon: const Icon(Icons.restore_from_trash),
                  label: const Text('กู้คืน'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white),
                  onPressed: () => _restoreCustomer(
                      int.parse(item['id'].toString()), item['firstName']),
                )
              : null,
        );
      },
    );
  }

  Widget _buildDebtList(bool isAdmin) {
    if (_deletedDebts.isEmpty) {
      return const Center(child: Text('ไม่มีรายการหนี้ที่ถูกลบ'));
    }
    return ListView.builder(
      itemCount: _deletedDebts.length,
      itemBuilder: (context, index) {
        final item = _deletedDebts[index];
        final df = DateFormat('dd/MM/yyyy HH:mm');
        final deletedAt = item['deletedAt'] != null
            ? df.format(DateTime.parse(item['deletedAt'].toString()))
            : '-';
        final amount = double.tryParse(item['amount'].toString()) ?? 0.0;
        final type = item['transactionType'];
        final isPayment = type == 'DEBT_PAYMENT' || type == 'PAYMENT';
        // Note: Payments are negative in database, display absolute for readability
        // Debt creation (CREDIT_SALE) is positive.

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Icon(
              isPayment ? Icons.payment : Icons.credit_score,
              color: isPayment ? Colors.green : Colors.red,
            ),
            title: Text('${item['firstName'] ?? ""} ${item['lastName'] ?? ""}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${isPayment ? "ชำระหนี้" : "ก่อหนี้"} ${NumberFormat("#,##0.00").format(amount.abs())} บาท'),
                Text(
                    'ลบเมื่อ: $deletedAt | โดย: ${item['deleteReason'] ?? "-"}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            trailing: isAdmin
                ? ElevatedButton.icon(
                    icon: const Icon(Icons.restore_from_trash),
                    label: const Text('กู้คืน'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white),
                    onPressed: () =>
                        _restoreDebt(int.parse(item['id'].toString())),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildVoidedBillList(bool isAdmin) {
    if (_voidedBills.isEmpty) {
      return const Center(child: Text('ไม่มีบิลที่ถูกยกเลิก'));
    }
    return ListView.builder(
      itemCount: _voidedBills.length,
      itemBuilder: (context, index) {
        final item = _voidedBills[index];
        final df = DateFormat('dd/MM/yyyy HH:mm');
        final date = DateTime.parse(item['createdAt'].toString());
        final total = double.tryParse(item['grandTotal'].toString()) ?? 0.0;

        return Card(
          color: Colors.red.shade50,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title:
                Text('Bill #${item['id']} - ${item['firstName'] ?? "Guest"}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ยอดเงิน: ${NumberFormat("#,##0.00").format(total)} บาท'),
                Text(
                    'วันที่: ${df.format(date)} | สาเหตุ: ${item['voidReason'] ?? "-"}'),
              ],
            ),
            trailing: isAdmin
                ? ElevatedButton.icon(
                    icon: const Icon(Icons.restore_from_trash),
                    label: const Text('กู้คืน'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange, // Orange for caution
                        foregroundColor: Colors.white),
                    onPressed: () =>
                        _restoreVoidedBill(int.parse(item['id'].toString())),
                  )
                : const Chip(
                    label: Text('VOID',
                        style: TextStyle(color: Colors.white, fontSize: 10)),
                    backgroundColor: Colors.red,
                  ),
          ),
        );
      },
    );
  }
}
