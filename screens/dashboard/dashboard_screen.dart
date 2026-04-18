import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Repositories & Models
import '../../repositories/sales_repository.dart';

import '../../repositories/debtor_repository.dart';
import '../../services/ai_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart'; // New import
import 'package:provider/provider.dart';

// ✅ Added for Actions
import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../services/printing/receipt_service.dart';
import '../../services/alert_service.dart';
import '../pos/pos_state_manager.dart';
import '../../state/auth_provider.dart';
import '../reports/best_selling_screen.dart';
import '../../widgets/dialogs/admin_auth_dialog.dart';
import '../../widgets/sync_status_widget.dart';
import '../reports/financial_report_screen.dart'; // ✅ Import Financial Report
import '../reports/fuel_summary_screen.dart'; // ✅ Added for Fuel Summary Report
import '../customers/customer_search_dialog.dart';
import '../../services/excel_export_service.dart'; // ✅ Added Excel Export
import '../../widgets/dialogs/close_shift_dialog.dart'; // ✅ Added Close Shift Dialog

import '../../repositories/customer_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final SalesRepository _salesRepo = SalesRepository();

  final DebtorRepository _debtRepo = DebtorRepository();
  final AiService _aiService = AiService();

  // State Variables
  // Note: TabController is removed in favor of DefaultTabController
  bool _isLoading = true;
  double _todaySales = 0.0;
  double _todayProfit = 0.0;

  int _todayOrders = 0;

  // ✅ Net Profit Vars (Removed for cleanliness)
  // double _todayPurchases = 0.0;
  // double _todayExpenses = 0.0;
  // double _todayNetProfit = 0.0;
  List<Map<String, dynamic>> _recentOrders = [];

  // ✅ Added: Date Selection State
  DateTime _selectedDate = DateTime.now();

  // ✅ Added: Advanced Analytics State
  final Map<int, double> _hourlySales = {};
  Map<String, double> _timeOfDaySales = {
    'Morning': 0.0,
    'Afternoon': 0.0,
  };

  // ✅ Added: Credit Sales Stats State
  Map<String, dynamic> _creditStatsToday = {'amount': 0.0, 'count': 0};
  Map<String, dynamic> _creditStatsWeek = {'amount': 0.0, 'count': 0};
  Map<String, dynamic> _creditStatsMonth = {'amount': 0.0, 'count': 0};
  Map<String, dynamic> _creditStatsYear = {'amount': 0.0, 'count': 0};

  // ✅ Tab Controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Initialize TabController with 5 tabs (Daily, Summary, Trend, AI, BestSelling)
    // Note: The number of tabs is dynamic based on permissions, so we need to calc it.
    // However, for simplicity and to avoid complex permission logic inside initState,
    // we will initialize it after checking permissions or use a safe upper bound and mapped views.
    // Better approach: Calculate length based on permissions synchronously if possible, or build list first.
    // Since permission check might be specific, let's assume all 5 for now or handle dynamic length carefully.
    // Actually, Provider is accessible in initState but better in didChangeDependencies.
    // But to be safe and simple: We will use a fixed length if permissions don't change often,
    // OR we can reconstruct controller if needed.
    // Let's use a standard 5 tabs for now, or count them.
    // Wait, 'build' builds the list.
    // Let's lazy init in 'build' or use a post-frame callback?
    // No, standard way is:
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _prevDate() async {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    await _loadData();
  }

  Future<void> _nextDate() async {
    final now = DateTime.now();
    if (_isSameDay(_selectedDate, now)) return; // Prevent going into future
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
    await _loadData();
    // Do not reset tab index
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null && !_isSameDay(picked, _selectedDate)) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadData();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _exportDeliveryHistory(BuildContext context) async {
    final now = DateTime.now();
    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      ),
    );

    if (dateRange != null) {
      final start = DateTime(dateRange.start.year, dateRange.start.month,
          dateRange.start.day, 0, 0, 0);
      final end = DateTime(dateRange.end.year, dateRange.end.month,
          dateRange.end.day, 23, 59, 59);

      final service = ExcelExportService();
      final success = await service.exportDeliveryHistory(start, end);

      if (context.mounted) {
        if (success) {
          AlertService.show(
              context: context,
              message: 'สร้างไฟล์ Excel สรุปการจัดส่งสำเร็จ',
              type: 'success');
        } else {
          AlertService.show(
              context: context,
              message: 'ไม่พบข้อมูลในช่วงที่เลือก หรือมีข้อผิดพลาด',
              type: 'error');
        }
      }
    }
  }

  // ✅ Restored Action Methods
  // ✅ Check Permission Helper
  Future<bool> _checkPermission(String action) async {
    final auth = context.read<AuthProvider>();

    // 1. Check if user has permission
    if (auth.hasPermission(action)) {
      return true;
    }

    // 2. If not, ask for Admin PIN
    final authorized = await AdminAuthDialog.show(context);
    return authorized;
  }

  Future<void> _viewDebtPaymentDetails(Map<String, dynamic> row) async {
    final int? refId = int.tryParse(row['refId'].toString());
    final String note = row['note']?.toString() ?? '';
    final String amount = NumberFormat('#,##0.00')
        .format(double.tryParse(row['amount'].toString()) ?? 0);
    final String dateStr = DateFormat('dd/MM/yyyy HH:mm')
        .format(DateTime.parse(row['createdAt'].toString()));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('รายละเอียดการชำระหนี้'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('วันที่: $dateStr'),
            Text('ลูกค้า: ${row['customerName']}'),
            const Divider(),
            Text('ยอดชำระ: ฿$amount',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple)),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('หมายเหตุ: $note'),
            ],
            if (refId != null && refId > 0) ...[
              const SizedBox(height: 16),
              const Text('ชำระสำหรับบิล (Linked Bill):',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx); // Close current dialog
                  _viewOrderDetails(refId); // Open linked order
                },
                icon: const Icon(Icons.receipt),
                label: Text('ดูบิล #$refId'),
              )
            ]
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ปิด')),
        ],
      ),
    );
  }

  Future<void> _viewOrderDetails(int orderId) async {
    if (!await _checkPermission('history_view_detail')) return;
    if (!mounted) return;

    final result = await _salesRepo.getOrderWithItems(orderId);
    if (result == null || !mounted) return;

    // ... (rest of the function)
    final order = result['order'] as Map<String, dynamic>;
    final items = (result['items'] as List<OrderItem>?) ?? [];
    final returns = (result['returns'] as List<OrderItem>?) ?? [];
    final moneyFormat = NumberFormat('#,##0.00');

    double grandTotal = double.tryParse(order['grandTotal'].toString()) ?? 0.0;
    double totalCost = 0.0;
    for (var item in items) {
      totalCost += item.costPrice.toDouble() * item.quantity.toDouble();
    }
    for (var item in returns) {
      totalCost += item.costPrice.toDouble() *
          item.quantity.toDouble(); // return qty is negative
    }
    double profit = grandTotal - totalCost;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final bool canViewCost = auth.hasPermission('view_cost');
    final bool canViewProfit = auth.hasPermission('view_profit');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('รายละเอียดบิล #$orderId'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Info
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('ลูกค้า: ${order['firstName'] ?? "ทั่วไป"}'),
                subtitle: Text('วันที่: ${order['createdAt']}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ยอดรวม: ฿${moneyFormat.format(grandTotal)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.blue),
                    ),
                    if (canViewCost || canViewProfit)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          [
                            if (canViewCost)
                              'ทุน: ฿${moneyFormat.format(totalCost)}',
                            if (canViewProfit)
                              'กำไร: ฿${moneyFormat.format(profit)}',
                          ].join(' | '),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(),
              // Items List
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...items.map((item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.productName),
                          subtitle: Text('${item.quantity} x ${item.price}'),
                          trailing: Text(
                              '฿${moneyFormat.format(item.total.toDouble())}'),
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
                            subtitle: Text('${item.quantity} x ${item.price}',
                                style: const TextStyle(color: Colors.red)),
                            trailing: Text(
                                '฿${moneyFormat.format(item.total.toDouble())}',
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold)),
                          )),
                    ],
                  ],
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

  Future<void> _reprintOrder(Map<String, dynamic> orderRow) async {
    // Only support Sales for re-printing
    if (orderRow['type'] == 'DEBT_PAYMENT') return;

    if (!await _checkPermission('history_reprint')) return;
    if (!mounted) return;

    final orderId = int.tryParse(orderRow['id'].toString()) ?? 0;

    // 1. Show Choice Dialog
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('เลือกประเภทเอกสาร'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'SLIP'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.receipt, color: Colors.green),
                  SizedBox(width: 12),
                  Text('1. สลิป 80mm/58mm (Thermal)',
                      style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'RECEIPT_A4'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.description, color: Colors.blue),
                  SizedBox(width: 12),
                  Text('2. บิลเงินสด A4 (เต็มแผ่น)',
                      style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'RECEIPT_A5'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.description, color: Colors.blue),
                  SizedBox(width: 12),
                  Text('3. บิลเงินสด A5 (ครึ่งแผ่น)',
                      style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'DELIVERY_A4'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.local_shipping, color: Colors.orange),
                  SizedBox(width: 12),
                  Text('4. ใบส่งของ A4', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'DELIVERY_A5'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.local_shipping, color: Colors.orange),
                  SizedBox(width: 12),
                  Text('5. ใบส่งของ A5', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'SAVE_RECEIPT_PDF'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf, color: Colors.red),
                  SizedBox(width: 12),
                  Text('6. ดาวน์โหลดบิลเงินสด (PDF)',
                      style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'SAVE_DELIVERY_PDF'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf, color: Colors.red),
                  SizedBox(width: 12),
                  Text('7. ดาวน์โหลดใบส่งของ (PDF)',
                      style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    // 2. Fetch Data
    final result = await _salesRepo.getOrderWithItems(orderId);
    if (result == null) return;

    final order = result['order'] as Map<String, dynamic>;
    final items = (result['items'] as List<OrderItem>?) ?? [];

    final customer = Customer.fromJson({
      'id': int.tryParse(order['customerId'].toString()) ??
          0, // ✅ Pass ID for refresh
      'firstName': order['firstName'] ?? '',
      'lastName': order['lastName'] ?? '',
      'phone': order['phone'] ?? '',
      'address':
          order['address'] ?? '', // Ensure address is passed if available
    });

    // 3. Print based on choice
    if (choice == 'SLIP') {
      await ReceiptService().printReceipt(
        orderId: orderId,
        items: items,
        total: double.tryParse(order['total'].toString()) ?? 0,
        grandTotal: double.tryParse(order['grandTotal'].toString()) ?? 0,
        received: double.tryParse(order['received'].toString()) ?? 0,
        change: double.tryParse(order['changeAmount'].toString()) ?? 0,
        customer: customer,
        isPreview: false,
        useCashBillSettings: false, // Standard Thermal
      );
    } else if (choice == 'RECEIPT_A4' || choice == 'RECEIPT_A5') {
      await ReceiptService().printReceipt(
        orderId: orderId,
        items: items,
        total: double.tryParse(order['total'].toString()) ?? 0,
        grandTotal: double.tryParse(order['grandTotal'].toString()) ?? 0,
        received: double.tryParse(order['received'].toString()) ?? 0,
        change: double.tryParse(order['changeAmount'].toString()) ?? 0,
        customer: customer,
        isPreview: false,
        useCashBillSettings: true, // Use Document Printer
        pageFormatOverride: choice == 'RECEIPT_A4'
            ? PdfPageFormat.a4
            : null, // ✅ Let it use default settings
      );
    } else if (choice == 'DELIVERY_A4' || choice == 'DELIVERY_A5') {
      await ReceiptService().printDeliveryNote(
        orderId: orderId,
        items: items,
        customer: customer,
        discount: double.tryParse(order['discount'].toString()) ?? 0.0,
        isPreview: false,
        pageFormatOverride: choice == 'DELIVERY_A4'
            ? PdfPageFormat.a4
            : null, // ✅ Let it use default settings
      );
    } else if (choice == 'SAVE_RECEIPT_PDF') {
      await ReceiptService().printReceipt(
        orderId: orderId,
        items: items,
        total: double.tryParse(order['total'].toString()) ?? 0,
        grandTotal: double.tryParse(order['grandTotal'].toString()) ?? 0,
        received: double.tryParse(order['received'].toString()) ?? 0,
        change: double.tryParse(order['changeAmount'].toString()) ?? 0,
        customer: customer,
        isPreview: true, // ✅ Trigger PDF Save Dialog
        useCashBillSettings:
            true, // Document format (A4/A5) is better for saving
      );
    } else if (choice == 'SAVE_DELIVERY_PDF') {
      await ReceiptService().printDeliveryNote(
        orderId: orderId,
        items: items,
        customer: customer,
        discount: double.tryParse(order['discount'].toString()) ?? 0.0,
        isPreview: true, // ✅ Trigger PDF Save Dialog
      );
    }
  }

  Future<void> _sendToDelivery(int orderId) async {
    if (!await _checkPermission('history_send_delivery')) return;
    if (!mounted) return;

    try {
      await context
          .read<PosStateManager>()
          .sendToDeliveryFromHistory(orderId, jobType: 'delivery');
      if (mounted) {
        AlertService.show(
            context: context,
            message: 'ส่งข้อมูลไปฝ่ายจัดส่งเรียบร้อย',
            type: 'success');
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(
            context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
      }
    }
  }

  Future<void> _sendToBackShop(int orderId) async {
    if (!await _checkPermission('history_send_pickup')) return;
    if (!mounted) return;

    try {
      await context
          .read<PosStateManager>()
          .sendToDeliveryFromHistory(orderId, jobType: 'pickup');
      if (mounted) {
        AlertService.show(
            context: context,
            message: 'ส่งงาน "รับของหลังร้าน" เรียบร้อย',
            type: 'success');
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(
            context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
      }
    }
  }

  // ✅ New Logic: Change Customer in History (Strict Permission)
  Future<void> _showChangeCustomerDialog(int orderId) async {
    final auth = context.read<AuthProvider>();
    if (!auth.hasPermission('history_edit_customer')) {
      AlertService.show(
        context: context,
        message: 'คุณไม่มีสิทธิ์แก้ไขข้อมูลลูกค้าในประวัติการขาย',
        type: 'error',
      );
      return;
    }

    if (!mounted) return;

    final customer = await showDialog<Customer>(
      context: context,
      builder: (context) => const CustomerSearchDialog(),
    );

    if (customer != null && mounted) {
      try {
        await _salesRepo.updateOrderCustomer(orderId, customer.id);
        if (mounted) {
          AlertService.show(
            context: context,
            message:
                'อัปเดตข้อมูลลูกค้าเรียบร้อยแล้ว (คะแนนและยอดซื้อถูกย้ายแล้ว)',
            type: 'success',
          );
          _loadData(); // Reload history
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

  Future<void> _confirmDeleteOrder(Map<String, dynamic> orderRow) async {
    // ต้องมีสิทธิ์ history_delete_bill
    if (!await _checkPermission('history_delete_bill')) return;
    if (!mounted) return;

    final int orderId = int.tryParse(orderRow['id'].toString()) ?? 0;
    final String type = orderRow['type'] ?? 'ORDER';

    String? selectedReason = 'คีย์ผิด';
    final formKey = GlobalKey<FormState>();
    bool returnStock = true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(type == 'DEBT_PAYMENT'
              ? 'ยกเลิกการชำระหนี้?'
              : 'ยืนยันการยกเลิกบิล (Void)'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type == 'DEBT_PAYMENT'
                    ? 'คุณต้องการลบรายการชำระหนี้ #$orderId ใช่หรือไม่?\n(ยอดหนี้จะถูกคืนกลับไปที่ลูกค้า)'
                    : 'คุณต้องการยกเลิกบิล #$orderId ใช่หรือไม่?'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  decoration: const InputDecoration(
                    labelText: 'ระบุสาเหตุการยกเลิก (บังคับ)',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'คีย์ผิด', child: Text('คีย์ผิด')),
                    DropdownMenuItem(
                        value: 'ลูกค้ายกเลิก', child: Text('ลูกค้ายกเลิก')),
                    DropdownMenuItem(
                        value: 'เปลี่ยนสินค้า', child: Text('เปลี่ยนสินค้า')),
                    DropdownMenuItem(
                        value: 'ชำระเงินผิดพลาด',
                        child: Text('ชำระเงินผิดพลาด')),
                    DropdownMenuItem(value: 'อื่นๆ', child: Text('อื่นๆ')),
                  ],
                  onChanged: (val) {
                    setState(() => selectedReason = val);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณาเลือกสาเหตุ';
                    }
                    return null;
                  },
                ),
                if (type != 'DEBT_PAYMENT') ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('คืนยอดสต็อกสินค้า'),
                    value: returnStock,
                    onChanged: (v) => setState(() => returnStock = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const Text(
                    'บิลจะถูกปรับสถานะเป็น VOID และไม่นำไปคำนวณยอดขาย',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('ไม่ยกเลิก')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('ยืนยัน Void / ลบ',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      if (!mounted) return;

      if (type == 'DEBT_PAYMENT') {
        // ✅ ลบรายการชำระหนี้ (Reverse Debt Logic)
        try {
          final success = await _debtRepo.deleteTransaction(orderId);
          if (success) {
            _loadData(); // โหลดข้อมูลใหม่
            if (mounted) {
              AlertService.show(
                  context: context,
                  message: 'ลบรายการชำระหนี้เรียบร้อย',
                  type: 'success');
            }
          }
        } catch (e) {
          if (mounted) {
            AlertService.show(
                context: context,
                message: e.toString().replaceAll('Exception: ', ''),
                type: 'error');
          }
        }
      } else {
        // ✅ กรณีบิลขายปกติ (Void Order)
        await _salesRepo.voidOrder(orderId,
            reason: selectedReason ?? 'คีย์ผิด', returnToStock: returnStock);
        _loadData();
        if (mounted) {
          AlertService.show(
              context: context, message: 'ยกเลิกบิลเรียบร้อย', type: 'success');
        }
      }
    }
  }

  // ✅ AI Analysis State
  String _aiAnalysis = '';
  bool _isAnalyzing = false;

  // ✅ ข้อมูลกราฟ & ช่วงเวลา
  final CustomerRepository _customerRepo = CustomerRepository(); // เพิ่ม
  String _selectedPeriod = 'MONTH'; // 'MONTH', 'YEAR'
  List<Map<String, dynamic>> _filteredStats = [];
  double _rangeSales = 0.0;
  double _rangeProfit = 0.0;
  int _rangeOrders = 0;

  // Removed duplicate initState

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // ✅ Use _selectedDate instead of DateTime.now()
      final targetDate = _selectedDate;
      final startOfDay =
          DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0);
      final endOfDay = DateTime(
          targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

      // 1. ดึงข้อมูลตามวันที่เลือก
      final orders =
          await _salesRepo.getOrdersByDateRange(startOfDay, endOfDay);

      double todaySales = 0.0;
      int todayOrderCount = 0;

      for (var o in orders) {
        final double amt = double.tryParse(o['amount'].toString()) ?? 0.0;

        final String type = o['type']?.toString() ?? 'ORDER';

        // Sales Performance: Count only 'ORDER' (Exclude Debt Payments from Sales Revenue)
        if (type == 'ORDER') {
          todaySales += amt;
          todayOrderCount++;
        }
      }

      // Process Hourly Stats
      _processTimeStats(orders);

      // 2. ดึงข้อมูลวันนี้จาก Stats เพื่อหากำไร
      final todayStats = await _salesRepo.getSalesStatsByDateRange(
          startOfDay, endOfDay, 'DAILY');
      double todayProfit = 0.0;
      if (todayStats.isNotEmpty) {
        double daySales =
            double.tryParse(todayStats.first['totalSales'].toString()) ?? 0.0;
        double dayCost =
            double.tryParse(todayStats.first['totalCost'].toString()) ?? 0.0;
        todayProfit = daySales - dayCost;
      }

      // Net Profit calculation removed from here as requested
      // final netProfit = todaySales - (tPurchases + tExpenses);

      await _loadPeriodStats(resetLoading: false);

      // 4. ✅ ดึงข้อมูลสรุปยอดขายเชื่อ (Multi-Period) แบบขนาน (Concurrent)
      final now = DateTime.now();

      // Today
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Week (Start Monday)
      final weekStart = now.subtract(Duration(days: now.weekday - 1)); // Monday
      final weekStartDay =
          DateTime(weekStart.year, weekStart.month, weekStart.day, 0, 0, 0);

      // Month
      final monthStart = DateTime(now.year, now.month, 1, 0, 0, 0);

      // Year
      final yearStart = DateTime(now.year, 1, 1, 0, 0, 0);

      final creditFutures = await Future.wait([
        _salesRepo.getCreditStats(todayStart, todayEnd),
        _salesRepo.getCreditStats(weekStartDay, todayEnd),
        _salesRepo.getCreditStats(monthStart, todayEnd),
        _salesRepo.getCreditStats(yearStart, todayEnd),
      ]);

      final cToday = creditFutures[0];
      final cWeek = creditFutures[1];
      final cMonth = creditFutures[2];
      final cYear = creditFutures[3];

      if (mounted) {
        setState(() {
          _recentOrders = orders;

          _todaySales = todaySales;
          _todayProfit = todayProfit; // Gross Profit (Sales - Cost)
          _todayOrders = todayOrderCount;

          // ❌ Removed Net Profit, Expenses, Purchases from this view
          // _todayExpenses = tExpenses;
          // _todayPurchases = tPurchases;
          // _todayNetProfit = netProfit;

          _creditStatsToday = cToday;
          _creditStatsWeek = cWeek;
          _creditStatsMonth = cMonth;
          _creditStatsYear = cYear;

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPeriodStats({bool resetLoading = true}) async {
    if (resetLoading) setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      DateTime start;
      String type = 'DAILY';

      if (_selectedPeriod == 'YEAR') {
        start = DateTime(now.year, 1, 1);
        type = 'MONTHLY'; // Show Monthly bars
      } else {
        // MONTH (Default)
        start = DateTime(now.year, now.month, 1); // Start of this month
        type = 'DAILY'; // Show Daily bars
      }

      final stats = await _salesRepo.getSalesStatsByDateRange(
          start, DateTime(now.year, now.month, now.day, 23, 59, 59), type);

      double rangeSales = 0.0;
      double rangeCost = 0.0;
      int rangeOrders = 0;
      for (var s in stats) {
        rangeSales += double.tryParse(s['totalSales'].toString()) ?? 0.0;
        rangeCost += double.tryParse(s['totalCost'].toString()) ?? 0.0;
        rangeOrders += int.tryParse(s['orderCount'].toString()) ?? 0;
      }

      if (mounted) {
        setState(() {
          _filteredStats = stats;
          _rangeSales = rangeSales;
          _rangeProfit = rangeSales - rangeCost;
          _rangeOrders = rangeOrders;
          if (resetLoading) _isLoading = false;
        });
      }
    } catch (e) {
      if (resetLoading) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAiAnalysis() async {
    if (_isAnalyzing) return;
    setState(() {
      _isAnalyzing = true;
      _aiAnalysis = 'กำลังวิเคราะห์ข้อมูลด้วย AI...';
    });

    try {
      // 1. Calculate Date Range (Same logic as _loadPeriodStats)
      final now = DateTime.now();
      DateTime start;
      if (_selectedPeriod == 'YEAR') {
        start = DateTime(now.year, 1, 1);
      } else {
        start = DateTime(now.year, now.month, 1);
      }
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // 2. Fetch Top Products
      final topProducts =
          await _salesRepo.getTopProductsByDateRange(start, end, limit: 5);
      String topProductsStr = topProducts
          .map((e) =>
              "- ${e['name']} (ขายได้ ${e['qty']} หน่วย, ยอด ${e['totalSales']} บาท)")
          .join('\n');

      // 3. Prepare Data String
      String csv = 'ข้อมูลสรุปยอดขาย:\nวันที่,ยอดขาย,ต้นทุน,กำไร\n';
      for (var s in _filteredStats) {
        double sales = double.tryParse(s['totalSales'].toString()) ?? 0.0;
        double cost = double.tryParse(s['totalCost'].toString()) ?? 0.0;
        csv += '${s['label']},$sales,$cost,${sales - cost}\n';
      }

      csv += '\nสินค้าขายดี 5 อันดับแรกในช่วงนี้:\n$topProductsStr';

      // 4. Add Time Analysis
      csv += '\n\nข้อมูลพฤติกรรมลูกค้า (จากรายการวันนี้/ล่าสุด):';
      csv += '\nช่วงเช้า (เปิดร้าน-12:00): ฿${_timeOfDaySales['Morning']}';
      csv += '\nช่วงบ่าย (12:00-ปิดร้าน): ฿${_timeOfDaySales['Afternoon']}';

      // Find peak hour
      if (_hourlySales.isNotEmpty) {
        final peakHour =
            _hourlySales.entries.reduce((a, b) => a.value > b.value ? a : b);
        csv +=
            '\nช่วงเวลาที่ขายดีที่สุด: ${peakHour.key}:00 น. (ยอด ฿${peakHour.value})';
      }

      final result = await _aiService.predictSales(csv);
      if (mounted) {
        setState(() {
          _aiAnalysis = result;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiAnalysis = 'ไม่สามารถวิเคราะห์ได้ในขณะนี้: $e';
          _isAnalyzing = false;
        });
      }
    }
  }

  void _processTimeStats(List<Map<String, dynamic>> orders) {
    _hourlySales.clear();
    _timeOfDaySales = {'Morning': 0.0, 'Afternoon': 0.0};

    for (var o in orders) {
      // นับเฉพาะยอดขายจริง (ไม่รวมการชำระหนี้ในสถิติยอดขายทั่วไป)
      // หรือควรนับ Cash Inflow?
      // ลูกค้าต้องการ "แยกยอดขาย" ซึ่งมักหมายถึงรายรับจากการขาย
      // ดังนั้นเราจะใช้ type 'ORDER' เท่านั้น
      if (o['type'] != 'ORDER') continue;

      final date = DateTime.tryParse(o['createdAt'].toString());
      if (date == null) continue;

      final amount = double.tryParse(o['amount'].toString()) ?? 0.0;
      final hour = date.hour;

      // รายชั่วโมง
      _hourlySales[hour] = (_hourlySales[hour] ?? 0.0) + amount;

      // ช่วงเวลาของวัน
      // ช่วงเวลาของวัน
      // ลูกค้าขอ 2 ช่วง: เช้า และ บ่าย (ร้านปิด 17:00)
      if (hour < 12) {
        _timeOfDaySales['Morning'] = (_timeOfDaySales['Morning']!) + amount;
      } else {
        _timeOfDaySales['Afternoon'] = (_timeOfDaySales['Afternoon']!) + amount;
      }
      // กลางคืน (0-6) ปกติว่างเปล่าสำหรับร้านค้าปลีก แต่เพิ่มได้ถ้าต้องการ
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final auth = Provider.of<AuthProvider>(context);

    // ✅ 1. เตรียมแท็บแบบไดนามิก
    final List<Widget> tabs = [];
    final List<Widget> tabViews = [];

    // Tab 1: รายการวันนี้ (แสดงเสมอ)
    tabs.add(const Tab(text: 'รายการวันนี้'));
    tabViews.add(
      SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('รายการขาย',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                        'วันที่: ${DateFormat('dd MMMM yyyy', 'th').format(_selectedDate)}',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600))
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _prevDate,
                      tooltip: 'วันก่อนหน้า',
                    ),
                    TextButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label:
                          Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _isSameDay(_selectedDate, DateTime.now())
                          ? null
                          : _nextDate,
                      tooltip: 'วันถัดไป',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadData,
                      tooltip: 'โหลดข้อมูลใหม่',
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onPressed: () => _exportDeliveryHistory(context),
                      icon: const Icon(Icons.local_shipping),
                      label: const Text('Export ส่งของ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onPressed: () async {
                        final reloaded = await showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const CloseShiftDialog(),
                        );
                        if (reloaded == true) {
                          _loadData();
                        }
                      },
                      icon: const Icon(Icons.lock_clock),
                      label: const Text('ปิดกะ (Close Shift)',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildRecentOrdersTable(auth, true),
          ],
        ),
      ),
    );

    // Tab 2: สรุปยอดขาย
    if (auth.hasPermission('dashboard_view_summary')) {
      tabs.add(const Tab(text: 'สรุปยอดขาย'));
      // tabs.add(const Tab(text: 'กราฟแนวโน้ม')); // Hidden for compact view if needed
      tabViews.add(
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      'สรุปยอดขายวันที่ ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _prevDate,
                        tooltip: 'วันก่อนหน้า',
                      ),
                      TextButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                            DateFormat('dd/MM/yyyy').format(_selectedDate)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _isSameDay(_selectedDate, DateTime.now())
                            ? null
                            : _nextDate,
                        tooltip: 'วันถัดไป',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Row 2: Today Stats (Sales, Orders, Profit)
              Row(
                children: [
                  Expanded(
                    child: _buildCard(
                      'ยอดขายวันนี้',
                      '฿${NumberFormat('#,##0.00').format(_todaySales)}',
                      Colors.blue,
                      Icons.monetization_on,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCard(
                      'บิลวันนี้',
                      '$_todayOrders ใบ',
                      Colors.orange,
                      Icons.receipt,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCard(
                      'กำไร (Gross)',
                      '฿${NumberFormat('#,##0.00').format(_todayProfit)}',
                      Colors.green,
                      Icons.trending_up,
                      subtitle: 'ยอดขาย - ต้นทุนสินค้า',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ✅ Financial Report Button
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const FinancialReportScreen()));
                      },
                      icon: const Icon(Icons.analytics),
                      label: const Text('สรุปบัญชี (Financial)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const FuelSummaryScreen()));
                      },
                      icon: const Icon(Icons.local_gas_station),
                      label: const Text('สรุปน้ำมัน (Fuel Summary)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildTimeStatsSection(),
              const SizedBox(height: 32),
              const Text('สรุปยอดขายเชื่อ (ค้างรับ)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildCreditSummaryTable(),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('สรุปตามช่วงเวลา',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  _buildPeriodSelector(),
                ],
              ),
              const SizedBox(height: 16),
              _buildRangeSummaryCards(),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text(
                  'ส่วนนี้สรุปยอดขายและกำไรเปรียบเทียบระหว่าง วันนี้ และ ช่วงเวลาที่คุณเลือก',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Tab 3: กราฟแนวโน้ม
    if (auth.hasPermission('dashboard_view_trend')) {
      tabs.add(const Tab(text: 'กราฟแนวโน้ม'));
      tabViews.add(
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('กราฟวิเคราะห์แนวโน้ม',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  _buildPeriodSelector(),
                ],
              ),
              const SizedBox(height: 24),
              _buildChartSection(),
            ],
          ),
        ),
      );
    }

    // Tab 4: วิเคราะห์ AI
    if (auth.hasPermission('dashboard_view_ai')) {
      tabs.add(const Tab(text: 'วิเคราะห์ AI'));
      tabViews.add(
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildAiSection(),
              const SizedBox(height: 20),
              const Text(
                'AI จะวิเคราะห์จากข้อมูลเมื่อกราฟแสดงผล (เดือนนี้ หรือ ปีนี้)',
                style: TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Tab 5: สินค้าขายดี
    if (auth.hasPermission('dashboard_view_best_selling')) {
      tabs.add(const Tab(text: 'สินค้าขายดี'));
      tabViews.add(const BestSellingScreen(isEmbedded: true));
    }

    // ✅ 2. Use DefaultTabController
    // ✅ 2. Use Explicit TabController
    // We need to ensure controller length matches tabs.length.
    // If permissions change, we might have an issue.
    // For this specific app, let's re-create controller if length mismatch (rarely happens).
    if (_tabController.length != tabs.length) {
      _tabController.dispose();
      _tabController =
          TabController(length: tabs.length, vsync: this, initialIndex: 0);
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('ภาพรวมธุรกิจและประวัติการขาย',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController, // ✅ Use explicit controller
          isScrollable: true,
          tabs: tabs,
          labelColor: Colors.indigo,
          indicatorColor: Colors.indigo,
          unselectedLabelColor: Colors.grey,
        ),
        actions: [
          const SyncStatusWidget(),
          IconButton(
            icon:
                const Icon(Icons.local_shipping_outlined, color: Colors.orange),
            tooltip: 'ดาวน์โหลดรายงานการจัดส่ง (Excel)',
            onPressed: () => _exportDeliveryHistory(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: TabBarView(
        controller: _tabController, // ✅ Use explicit controller
        children: tabViews,
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'MONTH', label: Text('เดือนนี้')),
        ButtonSegment(value: 'YEAR', label: Text('ปีนี้')),
      ],
      selected: {_selectedPeriod},
      onSelectionChanged: (Set<String> newSelection) {
        setState(() {
          _selectedPeriod = newSelection.first;
        });
        _loadPeriodStats();
      },
    );
  }

  Widget _buildRangeSummaryCards() {
    final format = NumberFormat("#,##0");
    return Row(
      children: [
        _buildRangeSmallCard(
            'ยอดขายช่วงนี้', '฿${format.format(_rangeSales)}', Colors.indigo),
        const SizedBox(width: 12),
        _buildRangeSmallCard(
            'กำไรช่วงนี้', '฿${format.format(_rangeProfit)}', Colors.teal),
        const SizedBox(width: 12),
        _buildRangeSmallCard(
            'จำนวนบิล', '${format.format(_rangeOrders)} บิล', Colors.orange),
      ],
    );
  }

  Widget _buildRangeSmallCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 12)),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, String value, Color color, IconData icon,
      {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 24)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAiSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Text('วิเคราะห์ด้วย AI (Gemini)',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple)),
              const Spacer(),
              if (_aiAnalysis.isEmpty)
                ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : _fetchAiAnalysis,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('เริ่มวิเคราะห์'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.deepPurple),
                  onPressed: _fetchAiAnalysis,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isAnalyzing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_aiAnalysis.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                _aiAnalysis,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('กดปุ่มด้านบนเพื่อเริ่มการวิเคราะห์ยอดขายและกำไร',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    if (_filteredStats.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('ไม่มีข้อมูลในช่วงเวลานี้')),
      );
    }

    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'แนวโน้มยอดขายและกำไร (${_selectedPeriod == "YEAR" ? "ปี ${DateTime.now().year + 543}" : "เดือน${DateFormat('MMMM', 'th').format(DateTime.now())} ${DateTime.now().year + 543}"})',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) =>
                        Colors.blueGrey.withValues(alpha: 0.9),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String label = "";
                      if (rodIndex == 0) label = "ยอดขาย";
                      if (rodIndex == 1) label = "กำไร";
                      return BarTooltipItem(
                        '$label: ฿${NumberFormat("#,##0").format(rod.toY)}',
                        const TextStyle(color: Colors.white),
                      );
                    },
                  ),
                ),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      // ✅ Fix: Adjust interval to prevent overlapping labels
                      interval: _filteredStats.length > 7
                          ? (_filteredStats.length / 5).toDouble()
                          : 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= _filteredStats.length) {
                          return const SizedBox();
                        }
                        final label = _filteredStats[index]['label'];

                        if (_selectedPeriod == 'YEAR') {
                          // label is yyyy-MM
                          final parts = label.split('-');
                          if (parts.length < 2) return Text(label);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(parts[1],
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                          );
                        } else {
                          // label is yyyy-MM-dd
                          final date = DateTime.parse(label);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(DateFormat('dd/MM').format(date),
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                          );
                        }
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _filteredStats.asMap().entries.map((e) {
                  double sales =
                      double.tryParse(e.value['totalSales'].toString()) ?? 0;
                  double cost =
                      double.tryParse(e.value['totalCost'].toString()) ?? 0;
                  double profit = sales - cost;

                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      // Sales Rod
                      BarChartRodData(
                        toY: sales,
                        color: Colors.blue,
                        width: 10, // Adjust width as needed
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4)),
                      ),
                      // Profit Rod
                      BarChartRodData(
                        toY: profit,
                        color: Colors.green,
                        width: 10,
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(Colors.blue, 'ยอดขาย'),
              const SizedBox(width: 24),
              _buildLegend(Colors.green, 'กำไร'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildTimeStatsSection() {
    final formatMoney = NumberFormat("#,##0");

    // Find Peak Hour
    int peakHour = -1;
    double peakAmount = 0;
    if (_hourlySales.isNotEmpty) {
      final peak =
          _hourlySales.entries.reduce((a, b) => a.value > b.value ? a : b);
      peakHour = peak.key;
      peakAmount = peak.value;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('เจาะลึกพฤติกรรมการซื้อ (Advanced Analytics)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // 1. Time of Day Cards
        Row(
          children: [
            _buildSmallStatCard('ช่วงเช้า (06-12)', _timeOfDaySales['Morning']!,
                Icons.wb_sunny, Colors.orange),
            const SizedBox(width: 12),
            _buildSmallStatCard('ช่วงบ่าย (12-17)',
                _timeOfDaySales['Afternoon']!, Icons.wb_cloudy, Colors.blue),
            // User requested to remove Evening slot
          ],
        ),
        const SizedBox(height: 16),

        // 2. Hourly Graph (Simple Bar)
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ยอดขายรายชั่วโมง',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  if (peakHour != -1)
                    Text(
                        '🔥 ช่วงพีค: $peakHour:00 น. (฿${formatMoney.format(peakAmount)})',
                        style:
                            TextStyle(color: Colors.red.shade700, fontSize: 12))
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: BarChart(BarChartData(
                  barGroups: List.generate(24, (index) {
                    // Only show bars from 6:00 to 22:00 to save space, or all if needed
                    // Let's show 8:00 to 20:00 primarily, but map all
                    if (index < 6) return null; // Skip night
                    final amt = _hourlySales[index] ?? 0.0;
                    return BarChartGroupData(x: index, barRods: [
                      BarChartRodData(
                        toY: amt,
                        color: index == peakHour
                            ? Colors.red
                            : Colors.indigo.shade300,
                        width: 8,
                        borderRadius: BorderRadius.circular(2),
                      )
                    ]);
                  }).whereType<BarChartGroupData>().toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final h = val.toInt();
                        if (h % 3 == 0) {
                          return Text('$h:00',
                              style: const TextStyle(fontSize: 10));
                        }
                        return const SizedBox();
                      },
                      interval: 1,
                    )),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => Colors.black87,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                                '${group.x}:00 น.\n฿${formatMoney.format(rod.toY)}',
                                const TextStyle(color: Colors.white));
                          })),
                )),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallStatCard(
      String title, double value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(title,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
            Text('฿${NumberFormat("#,##0").format(value)}',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditSummaryTable() {
    final formatMoney = NumberFormat('#,##0.00');
    final formatCount = NumberFormat('#,##0');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4)],
      ),
      child: DataTable(
        headingRowColor:
            WidgetStateColor.resolveWith((states) => Colors.red.shade50),
        dataRowMinHeight: 60,
        dataRowMaxHeight: 60,
        columns: const [
          DataColumn(
              label: Text('ช่วงเวลา',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('ยอดคงค้าง (บาท)',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('จำนวนบิล',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: [
          _buildCreditRow(
              'วันนี้', _creditStatsToday, formatMoney, formatCount),
          _buildCreditRow(
              'สัปดาห์นี้', _creditStatsWeek, formatMoney, formatCount),
          _buildCreditRow(
              'เดือนนี้', _creditStatsMonth, formatMoney, formatCount),
          _buildCreditRow('ปีนี้', _creditStatsYear, formatMoney, formatCount),
        ],
      ),
    );
  }

  DataRow _buildCreditRow(String label, Map<String, dynamic> stats,
      NumberFormat fmtMoney, NumberFormat fmtCount) {
    final amount = double.tryParse(stats['amount'].toString()) ?? 0.0;
    final count = int.tryParse(stats['count'].toString()) ?? 0;

    return DataRow(cells: [
      DataCell(
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
      DataCell(Text(fmtMoney.format(amount),
          style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 16))),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(fmtCount.format(count),
            style: TextStyle(
                color: Colors.red.shade700, fontWeight: FontWeight.bold)),
      )),
    ]);
  }

  // ✅ ตารางรายการที่แก้ไขแล้ว
  Widget _buildRecentOrdersTable(AuthProvider auth, bool showMoney) {
    final moneyFormat = NumberFormat('#,##0.00');
    final bool canViewCost = auth.hasPermission('view_cost');
    final bool canViewProfit = auth.hasPermission('view_profit');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('รายการล่าสุดวันนี้',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            width: double.infinity,
            child: DataTable(
              columnSpacing: 20,
              horizontalMargin: 20,
              dataRowMinHeight: 50,
              dataRowMaxHeight: 65,
              columns: const [
                DataColumn(label: Text('เลขที่บิล')), // ✅ Added Bill No.
                DataColumn(label: Text('เวลา')),
                DataColumn(label: Text('ลูกค้า')),
                DataColumn(label: Text('ยอดรวม')),
                DataColumn(label: Text('รับเงิน')),
                DataColumn(label: Text('สถานะ')),
                DataColumn(label: Text('จัดการ')),
              ],
              rows: _recentOrders.map((o) {
                final date = DateTime.tryParse(o['createdAt'].toString()) ??
                    DateTime.now();
                final timeStr = DateFormat('HH:mm').format(date);
                final amount = double.tryParse(o['amount'].toString()) ?? 0.0;
                final totalCost =
                    double.tryParse(o['totalCost']?.toString() ?? '0.0') ?? 0.0;
                final profit = amount - totalCost;
                final received =
                    double.tryParse(o['received'].toString()) ?? 0.0;
                final type = o['type'];
                final rawStatus = o['status']?.toString().toUpperCase() ?? '';

                // ✅ Logic การแสดงสถานะและสี
                String statusText = '';
                Color statusColor = Colors.grey;
                bool isVoid = false;

                if (type == 'DEBT_PAYMENT') {
                  statusText = 'ชำระหนี้';
                  statusColor = Colors.purple;
                } else if (rawStatus == 'UNPAID') {
                  statusText = 'ค้างจ่าย';
                  statusColor = Colors.orange.shade800;
                } else if (rawStatus == 'COMPLETED') {
                  statusText = 'สำเร็จ';
                  statusColor = Colors.green;
                } else if (rawStatus == 'HELD') {
                  statusText = 'พักบิล';
                  statusColor = Colors.blue;
                } else if (rawStatus == 'VOID' || rawStatus == 'CANCELLED') {
                  statusText = 'ยกเลิก';
                  statusColor = Colors.grey;
                  isVoid = true;
                } else {
                  statusText = rawStatus;
                }

                final textStyle = TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isVoid ? Colors.grey : Colors.black87,
                  decoration: isVoid ? TextDecoration.lineThrough : null,
                );

                return DataRow(cells: [
                  DataCell(Text('#${o["id"]}',
                      style: textStyle.copyWith(
                          fontWeight: FontWeight.bold))), // ✅ Added Bill ID
                  DataCell(Text(timeStr, style: textStyle)),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(o['customerName'] ?? 'ลูกค้าทั่วไป',
                          style: textStyle),
                      if (!isVoid &&
                          type != 'DEBT_PAYMENT' &&
                          auth.hasPermission('history_edit_customer'))
                        IconButton(
                          icon: const Icon(Icons.person_add_alt_1_outlined,
                              size: 16, color: Colors.blueGrey),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showChangeCustomerDialog(
                              int.tryParse(o['id'].toString()) ?? 0),
                        ),
                    ],
                  )),
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(moneyFormat.format(amount),
                            style: textStyle.copyWith(
                                fontWeight: FontWeight.bold)),
                        if ((canViewCost || canViewProfit) && type == 'ORDER')
                          Text(
                            [
                              if (canViewCost)
                                'ทุน: ${moneyFormat.format(totalCost)}',
                              if (canViewProfit)
                                'กำไร: ${moneyFormat.format(profit)}',
                            ].join(' | '),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              decoration:
                                  isVoid ? TextDecoration.lineThrough : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                  DataCell(Text(
                    moneyFormat.format(received),
                    style: textStyle.copyWith(
                        // ถ้าเป็นบิลขายแล้วรับเงินไม่ครบ ให้ขึ้นสีแดง (ถ้าไม่ Void)
                        color: (!isVoid &&
                                received < amount &&
                                type != 'DEBT_PAYMENT')
                            ? Colors.red
                            : (isVoid ? Colors.grey : Colors.black87)),
                  )),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isVoid) // ซ่อนปุ่มจัดการสำหรับ Void (ยกเว้นลบ/ดูรายละเอียด?)
                          IconButton(
                            icon: const Icon(Icons.info_outline,
                                color: Colors.blue, size: 20),
                            tooltip: 'ดูรายละเอียด',
                            onPressed: () {
                              if (o['type'] == 'DEBT_PAYMENT') {
                                _viewDebtPaymentDetails(o);
                              } else {
                                _viewOrderDetails(
                                    int.tryParse(o['id'].toString()) ?? 0);
                              }
                            },
                          ),
                        if (!isVoid) ...[
                          // แก้ไข: อนุญาตให้ปริ้นสำหรับ DEBT_PAYMENT ด้วย
                          // ตรรกะ: แสดงปุ่มปริ้นสำหรับ (ORDER + DEBT_PAYMENT)
                          // แต่ปุ่ม ส่งของ/หลังร้าน แสดงเฉพาะ ORDER เท่านั้น
                          IconButton(
                            icon: const Icon(Icons.print,
                                color: Colors.grey, size: 20),
                            tooltip: 'ปริ้นซ้ำ',
                            onPressed: () => type == 'DEBT_PAYMENT'
                                ? _printDebtPaymentReceipt(o)
                                : _reprintOrder(o),
                          ),
                          if (type != 'DEBT_PAYMENT') ...[
                            IconButton(
                              icon: const Icon(Icons.local_shipping,
                                  color: Colors.orange, size: 20),
                              tooltip: 'ส่งของ',
                              onPressed: () => _sendToDelivery(
                                  int.tryParse(o['id'].toString()) ?? 0),
                            ),
                            IconButton(
                              icon: const Icon(Icons.store_mall_directory,
                                  color: Colors.deepPurple, size: 20),
                              tooltip: 'แจ้งรับของหลังร้าน',
                              onPressed: () => _sendToBackShop(
                                  int.tryParse(o['id'].toString()) ?? 0),
                            ),
                          ],
                        ],
                        // ปุ่มลบ (ใช้ได้สำหรับทุกสถานะรวมถึง Void หากต้องการ Hard Delete)
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          tooltip: 'ลบบิล',
                          onPressed: () =>
                              _confirmDeleteOrder(o), // ✅ ส่ง Object
                        ),
                      ],
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ เมนูใหม่สำหรับปริ้นใบเสร็จชำระหนี้
  Future<void> _printDebtPaymentReceipt(Map<String, dynamic> o) async {
    final int id = int.tryParse(o['id'].toString()) ?? 0;
    final double amount = double.tryParse(o['amount'].toString()) ?? 0.0;
    final String customerName = o['customerName'] ?? 'ลูกค้าทั่วไป';
    final DateTime date =
        DateTime.tryParse(o['createdAt'].toString()) ?? DateTime.now();

    // ดึงข้อมูลลูกค้าเพื่อนำไปแสดงที่อยู่ (ถ้ามี)
    Customer customer = Customer(
      id: 0,
      firstName: customerName,
      lastName: '',
      currentPoints: 0,
      phone: '',
      address: '',
      memberCode: '', // ใส่ค่าว่างเพราะต้องมี
    );

    // พยายามดึง ID ลูกค้าจริงถ้ามีข้อมูล
    int cid = 0;
    if (o.containsKey('customerId')) {
      cid = int.tryParse(o['customerId'].toString()) ?? 0;
    }

    if (cid > 0) {
      final realCustomer = await _customerRepo.getCustomerById(cid);
      if (realCustomer != null) {
        customer = realCustomer;
      }
    }

    // แสดง Dialog เลือกรูปแบบการพิมพ์
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('เลือกรูปแบบใบเสร็จ (Select Format)'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(context);
              await ReceiptService().printDebtPayment(
                transactionId: id,
                customer: customer,
                amount: amount,
                date: date,
                paperSizeOverride: '80mm',
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, color: Colors.blue),
                  SizedBox(width: 10),
                  Text('สลิปความร้อน (80mm)'),
                ],
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(context);
              await ReceiptService().printDebtPayment(
                transactionId: id,
                customer: customer,
                amount: amount,
                date: date,
                paperSizeOverride: 'A5',
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.description, color: Colors.green),
                  SizedBox(width: 10),
                  Text('ใบเสร็จ A5'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
