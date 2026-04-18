import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/customer.dart';
import '../../repositories/debtor_repository.dart';
import 'customer_debtor_screen.dart';
import '../../repositories/sales_repository.dart'; // For fetching/printing
import '../../repositories/customer_repository.dart'; // For customer data if needed

import '../../services/printing/receipt_service.dart';
import '../../models/order_item.dart';
import '../pos/pos_state_manager.dart'; // For delivery
import 'package:provider/provider.dart';
import '../../models/outstanding_bill.dart';
import '../../services/alert_service.dart';
//import '../../services/settings_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DebtorListScreen extends StatefulWidget {
  const DebtorListScreen({super.key});

  @override
  State<DebtorListScreen> createState() => _DebtorListScreenState();
}

class _DebtorListScreenState extends State<DebtorListScreen> {
  final DebtorRepository _debtorRepo = DebtorRepository();
  final SalesRepository _salesRepo = SalesRepository(); // Added
  final ReceiptService _receiptService = ReceiptService(); // Added
  final CustomerRepository _customerRepo = CustomerRepository(); // Added

  // Data for Summary
  double _summaryTotalDebt = 0.0;
  int _summaryDebtorCount = 0;

  // Data for List
  List<OutstandingBill> _allTransactions = [];
  List<OutstandingBill> _filteredTransactions = [];

  bool _isLoading = true;
  bool _isSendingAlerts = false; // Add loading state for alerts
  final TextEditingController _searchCtrl = TextEditingController();

  // Sorting
  String _sortOption =
      'OUTSTANDING_NEW'; // OUTSTANDING_NEW, OUTSTANDING_OLD, DATE_NEW, DATE_OLD

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch Transaction List (Source of Truth) includes Credit & Held
      final transactions = await _debtorRepo.getOutstandingCreditSales();
      debugPrint('Loaded Debtor List: ${transactions.length} items');

      // Calculate Summary in Dart
      final double total = transactions.fold(0.0, (sum, t) {
        return sum + t.remaining;
      });

      final uniqueCustomers =
          transactions.map((t) => t.customerId).toSet().length;

      if (mounted) {
        setState(() {
          _allTransactions = transactions;
          _filteredTransactions = transactions;
          _summaryTotalDebt = total;
          _summaryDebtorCount = uniqueCustomers;
          _isLoading = false;
        });

        // Re-apply search if exists
        if (_searchCtrl.text.isNotEmpty) {
          _onSearch(_searchCtrl.text);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearch(String val) {
    setState(() {
      final query = val.toLowerCase();
      if (query.isEmpty) {
        _filteredTransactions = _allTransactions;
      } else {
        _filteredTransactions = _allTransactions.where((t) {
          final name = t.customerName.toLowerCase();
          final phone = (t.phone ?? '').toLowerCase();
          final bill = t.orderId.toString();
          return name.contains(query) ||
              phone.contains(query) ||
              bill.contains(query);
        }).toList();
      }
    });
    _sortTransactions();
  }

  void _sortTransactions() {
    setState(() {
      _filteredTransactions.sort((a, b) {
        // Logic for Outstanding First
        if (_sortOption.startsWith('OUTSTANDING')) {
          final aUnpaid = a.remaining > 0.01;
          final bUnpaid = b.remaining > 0.01;
          if (aUnpaid && !bUnpaid) return -1; // a comes first
          if (!aUnpaid && bUnpaid) return 1; // b comes first
        }

        // Logic for Date
        final dateA = a.createdAt;
        final dateB = b.createdAt;

        if (_sortOption.contains('NEW')) {
          return dateB.compareTo(dateA); // Newest first
        } else {
          return dateA.compareTo(dateB); // Oldest first
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Total Summary Card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.orange.shade700, Colors.orange.shade400]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ยอดลูกหนี้คงค้างรวม (Total Receivables)',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      '฿${NumberFormat('#,##0.00').format(_summaryTotalDebt)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        '$_summaryDebtorCount รายลูกหนี้ (${_allTransactions.length} บิลคงค้าง)',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isSendingAlerts ? null : _sendBulkDebtAlerts,
                icon: _isSendingAlerts
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.orange, strokeWidth: 2))
                    : const Icon(Icons.notifications_active,
                        color: Colors.orange),
                label:
                    Text(_isSendingAlerts ? 'กำลังส่ง...' : 'ทวงหนี้ทั้งหมด'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange.shade700,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        // Search Bar

        // Options Row (Search + Sort)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'ค้นหาลูกหนี้... (ชื่อ, เบอร์โทร, เลขบิล)',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                  onChanged: _onSearch,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortOption,
                    items: const [
                      DropdownMenuItem(
                          value: 'OUTSTANDING_NEW',
                          child: Text('ค้างชำระก่อน (ใหม่-เก่า)')),
                      DropdownMenuItem(
                          value: 'OUTSTANDING_OLD',
                          child: Text('ค้างชำระก่อน (เก่า-ใหม่)')),
                      DropdownMenuItem(
                          value: 'DATE_NEW', child: Text('เวลา (ใหม่-เก่า)')),
                      DropdownMenuItem(
                          value: 'DATE_OLD', child: Text('เวลา (เก่า-ใหม่)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _sortOption = val);
                        _sortTransactions();
                      }
                    },
                  ),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Table Header
        Container(
          color: const Color(0xFF2d9cdb),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: const [
              Expanded(
                  flex: 1,
                  child: Text('ที่',
                      style: _headerStyle, textAlign: TextAlign.center)),
              Expanded(
                  flex: 2,
                  child: Text('วันที่',
                      style: _headerStyle, textAlign: TextAlign.center)), // New
              Expanded(
                  flex: 3,
                  child: Text('ลูกค้า', style: _headerStyle)), // Renamed
              Expanded(
                  flex: 2,
                  child: Text('บิลที่',
                      style: _headerStyle, textAlign: TextAlign.center)), // New
              Expanded(
                  flex: 2,
                  child: Text('ยอดเต็ม', // Renamed
                      style: _headerStyle,
                      textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text('ชำระแล้ว', // New Column (Paid)
                      style: _headerStyle,
                      textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text('ค้างชำระ', // New Column
                      style: _headerStyle,
                      textAlign: TextAlign.right)),
              Expanded(
                  flex: 3, // Increased from 2
                  child: Text('จัดการ',
                      style: _headerStyle, textAlign: TextAlign.center)),
            ],
          ),
        ),

        // Table Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredTransactions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check_circle_outline,
                              size: 64, color: Colors.green),
                          SizedBox(height: 10),
                          Text('ไม่พบรายการค้างชำระ',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _filteredTransactions.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (ctx, index) {
                        final t = _filteredTransactions[index];
                        final dt = t.createdAt;
                        final amount = t.amount;
                        final remaining = t.remaining;

                        return Container(
                          color: index % 2 == 0
                              ? Colors.white
                              : Colors.blue.shade50.withValues(alpha: 0.3),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          child: Row(
                            children: [
                              // No.
                              Expanded(
                                  flex: 1,
                                  child: Text('${index + 1}',
                                      textAlign: TextAlign.center)),
                              // Date
                              Expanded(
                                  flex: 2,
                                  child: Text(
                                      DateFormat('dd/MM/yyyy').format(dt),
                                      textAlign: TextAlign.center)),
                              // Customer
                              Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(t.customerName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      if (t.phone != null &&
                                          t.phone!.isNotEmpty)
                                        Text(t.phone!,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600])),
                                    ],
                                  )),
                              // Bill #
                              Expanded(
                                  flex: 2,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('#${t.orderId}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.blueGrey,
                                              fontWeight: FontWeight.bold)),
                                      if (t.status == 'HELD')
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text('พักบิล',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.orange,
                                                  fontWeight: FontWeight.bold)),
                                        )
                                    ],
                                  )),
                              // Amount
                              Expanded(
                                  flex: 2,
                                  child: Text(
                                    NumberFormat('#,##0.00').format(amount),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        color: Colors
                                            .grey.shade700), // Grey for total
                                  )),
                              // Paid
                              Expanded(
                                  flex: 2,
                                  child: Text(
                                    NumberFormat('#,##0.00')
                                        .format(amount - remaining),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(color: Colors.green),
                                  )),
                              // Remaining
                              Expanded(
                                  flex: 2,
                                  child: Text(
                                    NumberFormat('#,##0.00').format(remaining),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red), // Red for remaining
                                  )),
                              // Actions
                              Expanded(
                                flex: 3, // Increased flex space for buttons
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Pay Button (New)
                                    IconButton(
                                      icon: const Icon(Icons.monetization_on,
                                          color: Colors.green),
                                      tooltip: 'ชำระเงิน',
                                      onPressed: remaining > 0
                                          ? () => _showPaymentDialog(
                                              t.orderId, remaining)
                                          : null, // Disable if fully paid (though list filters them out mostly)
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.list_alt,
                                          color: Colors.purple),
                                      tooltip: 'ดูบัญชีรายคน',
                                      onPressed: () async {
                                        // We need to create a Customer object to pass
                                        // Assuming currentDebt in transaction row might be stale, fetching fresh one or using what we have
                                        final customer = Customer(
                                          id: t.customerId,
                                          firstName: t
                                              .customerName, // Use combined name as first name for now or split if needed, but display purposes mostly
                                          lastName: '',
                                          phone: t.phone,
                                          currentDebt: t.currentDebt,
                                          memberCode: 'TEMP',
                                          currentPoints: 0,
                                        );

                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  CustomerDebtorScreen(
                                                      customer: customer)),
                                        );
                                        _loadData(); // Refresh on return
                                      },
                                    ),
                                    // View Details
                                    IconButton(
                                      icon: const Icon(Icons.visibility,
                                          color: Colors.teal),
                                      tooltip: 'ดูรายการสินค้า',
                                      onPressed: () =>
                                          _showBillDetails(t.orderId),
                                    ),
                                    // Print
                                    IconButton(
                                      icon: const Icon(Icons.print,
                                          color: Colors.blueGrey),
                                      tooltip: 'พิมพ์บิล',
                                      onPressed: () =>
                                          _showPrintOptions(t.orderId),
                                    ),
                                    // Delivery
                                    IconButton(
                                      icon: const Icon(Icons.local_shipping,
                                          color: Colors.orange),
                                      tooltip: 'ส่งงานจัดส่ง',
                                      onPressed: () async {
                                        try {
                                          final posState =
                                              context.read<PosStateManager>();
                                          await posState
                                              .sendToDeliveryFromHistory(
                                                  t.orderId);
                                          if (!context.mounted) return;
                                          AlertService.show(
                                              context: context,
                                              message: 'ส่งข้อมูลจัดส่งสำเร็จ!',
                                              type: 'success');
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          AlertService.show(
                                              context: context,
                                              message: 'Error: $e',
                                              type: 'error');
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // --- Helpers for Print & Delivery ---

  Future<void> _sendBulkDebtAlerts() async {
    // 1. ถามยืนยัน
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันส่งทวงหนี้'),
        content: const Text(
            'ระบบจะส่งข้อความแจ้งเตือนยอดหนี้ทาง LINE ให้กับลูกหนี้ทุกคนที่มี Line ID (ไม่มีค่าใช้จ่ายเพิ่ม)\nคุณต้องการดำเนินการต่อหรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('ส่งทันที (Send)')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSendingAlerts = true);

    // Group by customer to prevent sending multiple messages to the same person
    final Map<int, OutstandingBill> uniqueDebtors = {};
    for (var t in _allTransactions) {
      if (t.lineUserId != null && t.lineUserId!.isNotEmpty) {
        if (!uniqueDebtors.containsKey(t.customerId)) {
          uniqueDebtors[t.customerId] = t;
        }
      }
    }

    if (uniqueDebtors.isEmpty) {
      setState(() => _isSendingAlerts = false);
      if (!mounted) return;
      AlertService.show(
          context: context,
          message: 'ไม่พบลูกหนี้ที่ผูก LINE Account เลย',
          type: 'warning');
      return;
    }

    int successCount = 0;
    try {
      final String apiUrl = 'http://localhost:8080';

      for (var debtor in uniqueDebtors.values) {
        final message = '📢 แจ้งเตือนยอดค้างชำระ\n\n'
            'เรียนคุณ ${debtor.customerName}\n'
            'ขณะนี้มียอดค้างชำระคงเหลือ: ฿${NumberFormat('#,##0.00').format(debtor.currentDebt)}\n\n'
            'สามารถตรวจสอบรายละเอียดบิลทั้งหมดหรือติดต่อชำระเงินได้ที่ร้าน ส.บริการ ท่าข้าม นะครับ 🙏';

        try {
          final res = await http.post(
            Uri.parse('$apiUrl/api/v1/line/push-message'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(
                {"lineUserId": debtor.lineUserId, "message": message}),
          );
          if (res.statusCode == 200) successCount++;
        } catch (e) {
          debugPrint('Failed to send to ${debtor.customerName}: $e');
        }
        await Future.delayed(
            const Duration(milliseconds: 500)); // Rate limit safety
      }
    } catch (e) {
      debugPrint('Bulk Alert Error: $e');
    }

    setState(() => _isSendingAlerts = false);
    if (!mounted) return;
    AlertService.show(
        context: context,
        message: 'ส่งสำเร็จ $successCount จาก ${uniqueDebtors.length} ราย',
        type: successCount > 0 ? 'success' : 'warning');
  }

  Future<void> _showPrintOptions(int orderId) async {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('เลือกประเภทเอกสาร'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _executePrint(orderId, 'RECEIPT');
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.blue),
                    SizedBox(width: 12),
                    Text('ใบเสร็จรับเงิน (Receipt)',
                        style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            const Divider(),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _executePrint(orderId, 'DELIVERY');
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('ใบส่งของ (Delivery Note)',
                        style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            const Divider(),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _executePrint(orderId, 'SAVE_RECEIPT_PDF');
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red),
                    SizedBox(width: 12),
                    Text('ดาวน์โหลดใบเสร็จ (PDF)',
                        style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _executePrint(orderId, 'SAVE_DELIVERY_PDF');
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red),
                    SizedBox(width: 12),
                    Text('ดาวน์โหลดใบส่งของ (PDF)',
                        style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executePrint(int orderId, String type) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final fullOrderData = await _salesRepo.getOrderWithItems(orderId);
      if (fullOrderData == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final orderData = fullOrderData['order'];
      final items = fullOrderData['items'] as List<OrderItem>;

      // Re-construct customer object or fetch it
      int customerId = int.tryParse(orderData['customerId'].toString()) ?? 0;
      Customer? customer;
      if (customerId > 0) {
        customer = await _customerRepo.getCustomerById(customerId);
      }
      // Fallback
      customer ??= Customer(
        id: 0,
        memberCode: '',
        currentPoints: 0,
        firstName: orderData['firstName'] ?? 'ลูกค้าทั่วไป',
        lastName: orderData['lastName'],
        phone: orderData['phone'],
        address: orderData['address'] ?? '',
      );

      final grandTotal =
          double.tryParse(orderData['grandTotal'].toString()) ?? 0.0;
      final discount = double.tryParse(orderData['discount'].toString()) ?? 0.0;
      final total =
          double.tryParse(orderData['total'].toString()) ?? grandTotal;
      final received = double.tryParse(orderData['received'].toString()) ?? 0.0;
      final change =
          double.tryParse(orderData['changeAmount'].toString()) ?? 0.0;

      if (!mounted) return;
      Navigator.pop(context); // Pop loading dialog

      if (type == 'RECEIPT') {
        await _receiptService.printReceipt(
          orderId: orderId,
          items: items,
          total: total,
          discount: discount,
          grandTotal: grandTotal,
          received: received,
          change: change,
          customer: customer,
          isPreview: false,
        );
      } else if (type == 'DELIVERY') {
        await _receiptService.printDeliveryNote(
          orderId: orderId,
          items: items,
          customer: customer,
          discount: discount,
          isPreview: false,
        );
      } else if (type == 'SAVE_RECEIPT_PDF') {
        await _receiptService.printReceipt(
          orderId: orderId,
          items: items,
          total: total,
          discount: discount,
          grandTotal: grandTotal,
          received: received,
          change: change,
          customer: customer,
          isPreview: true, // Trigger PDF save dialog
          useCashBillSettings: true, // Standardize A4/A5 for PDF
        );
      } else if (type == 'SAVE_DELIVERY_PDF') {
        await _receiptService.printDeliveryNote(
          orderId: orderId,
          items: items,
          customer: customer,
          discount: discount,
          isPreview: true, // Trigger PDF save dialog
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Print Error: $e");
      if (mounted) {
        AlertService.show(
            context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
      }
    }
  }

  Future<void> _showBillDetails(int orderId) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final fullOrderData = await _salesRepo.getOrderWithItems(orderId);
      if (!mounted) return;
      Navigator.pop(context); // Pop loading

      if (fullOrderData == null) return;

      final items = fullOrderData['items'] as List<OrderItem>;
      final order = fullOrderData['order'];

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('รายละเอียดบิล #$orderId'),
            content: SizedBox(
              width: 500,
              height: 400,
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                        'ลูกค้า: ${order['firstName']} ${order['lastName'] ?? ''}'),
                    subtitle: Text(
                        'ยอดรวม: ${NumberFormat('#,##0.00').format(double.tryParse(order['grandTotal']?.toString() ?? '0') ?? 0)} บาท'),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final item = items[i];
                        return ListTile(
                          dense: true,
                          leading: Text('${i + 1}.'),
                          title: Text(item.productName),
                          subtitle: item.comment.isNotEmpty
                              ? Text(item.comment,
                                  style: const TextStyle(color: Colors.grey))
                              : null,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                  '${NumberFormat('#,##0.##').format(item.quantity.toDouble())} x ${NumberFormat('#,##0.00').format(item.price.toDouble())}'),
                              Text(
                                  NumberFormat('#,##0.00')
                                      .format(item.total.toDouble()),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
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
                  child: const Text('ปิด')),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("View Details Error: $e");
      if (mounted) {
        AlertService.show(
            context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
      }
    }
  }

  Future<void> _showPaymentDialog(int orderId, double remainingAmount) async {
    final TextEditingController amountController = TextEditingController();
    amountController.text = NumberFormat('#,###.##').format(remainingAmount);

    // Simple Numeric Keypad Dialog logic can be reused or simplified here
    // For brevity, using standard dialog with validated text field logic

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          // Helper for raw value
          double getRawAmount() =>
              double.tryParse(amountController.text.replaceAll(',', '')) ?? 0.0;
          double inputAmount = getRawAmount();

          return AlertDialog(
            title: Text('ชำระเงิน (บิล #$orderId)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'ยอดคงค้าง: ${NumberFormat('#,##0.00').format(remainingAmount)}',
                    style: const TextStyle(fontSize: 16, color: Colors.red)),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'ระบุยอดชำระ',
                      border: OutlineInputBorder(),
                      suffixText: 'บาท'),
                  onChanged: (val) {
                    // Real-time update state to validate button
                    setStateDialog(() {});
                  },
                ),
                const SizedBox(height: 8),
                if (inputAmount > remainingAmount)
                  const Text('ยอดชำระเกินยอดคงค้าง!',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white),
                onPressed: (inputAmount > 0 &&
                        inputAmount <=
                            remainingAmount + 0.01) // Allow slight float diff
                    ? () async {
                        Navigator.pop(context);
                        // Process
                        showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(
                                child: CircularProgressIndicator()));

                        final success = await _debtorRepo.paySpecificBill(
                            orderId: orderId, amount: inputAmount);

                        if (!context.mounted) return;
                        Navigator.pop(context); // Close loading

                        if (success) {
                          AlertService.show(
                              context: context,
                              message: 'บันทึกการชำระเงินสำเร็จ',
                              type: 'success');
                          _loadData(); // Refresh list
                        } else {
                          AlertService.show(
                              context: context,
                              message: 'เกิดข้อผิดพลาดในการบันทึก',
                              type: 'error');
                        }
                      }
                    : null,
                child: const Text('ยืนยัน'),
              )
            ],
          );
        });
      },
    );
  }
}

const _headerStyle =
    TextStyle(color: Colors.white, fontWeight: FontWeight.bold);
