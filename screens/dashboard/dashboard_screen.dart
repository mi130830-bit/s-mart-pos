import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Repositories & Models
import '../../repositories/sales_repository.dart';
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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SalesRepository _salesRepo = SalesRepository();
  final AiService _aiService = AiService();

  // State Variables
  bool _isLoading = true;
  double _todaySales = 0.0;
  double _todayProfit = 0.0;
  int _todayOrders = 0;
  List<Map<String, dynamic>> _recentOrders = [];

  // ✅ Added: Date Selection State
  DateTime _selectedDate = DateTime.now();

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

  // ✅ Restored Action Methods
  Future<void> _viewOrderDetails(int orderId) async {
    final result = await _salesRepo.getOrderWithItems(orderId);
    if (result == null || !mounted) return;

    final order = result['order'] as Map<String, dynamic>;
    final items = (result['items'] as List<OrderItem>?) ?? [];
    final returns = (result['returns'] as List<OrderItem>?) ?? [];
    final moneyFormat = NumberFormat('#,##0.00');

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
                trailing: Text(
                    'ยอดรวม: ฿${moneyFormat.format(double.tryParse(order['grandTotal'].toString()) ?? 0.0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.blue)),
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
        pageFormatOverride:
            choice == 'RECEIPT_A4' ? PdfPageFormat.a4 : PdfPageFormat.a5,
      );
    } else if (choice == 'DELIVERY_A4' || choice == 'DELIVERY_A5') {
      await ReceiptService().printDeliveryNote(
        orderId: orderId,
        items: items,
        customer: customer,
        discount: double.tryParse(order['discount'].toString()) ?? 0.0,
        isPreview: false,
        pageFormatOverride:
            choice == 'DELIVERY_A4' ? PdfPageFormat.a4 : PdfPageFormat.a5,
      );
    }
  }

  Future<void> _sendToDelivery(int orderId) async {
    try {
      await context.read<PosStateManager>().sendToDeliveryFromHistory(orderId);
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

  Future<void> _confirmDeleteOrder(int orderId) async {
    bool returnStock = true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('ยืนยันการลบบิล'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('คุณต้องการลบบิล #$orderId ใช่หรือไม่?'),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('คืนเขาสต๊อกด้วย'),
                value: returnStock,
                onChanged: (v) => setState(() => returnStock = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('ยกเลิก')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ยืนยันการลบ',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await _salesRepo.deleteOrder(orderId, returnToStock: returnStock);
      _loadData(); // Refresh Dashboard
      if (mounted) {
        AlertService.show(
            context: context, message: 'ลบบิลเรียบร้อยแล้ว', type: 'success');
      }
    }
  }

  // ✅ AI Analysis State
  String _aiAnalysis = '';
  bool _isAnalyzing = false;

  // ✅ Chart & Range Data
  String _selectedPeriod = '7D'; // '7D', '30D', '1Y'
  List<Map<String, dynamic>> _filteredStats = [];
  double _rangeSales = 0.0;
  double _rangeProfit = 0.0;
  int _rangeOrders = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

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
      for (var o in orders) {
        todaySales += double.tryParse(o['amount'].toString()) ?? 0.0;
      }

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

      // 3. ดึงข้อมูลตามช่วงที่เลือก (สำหรับกราฟและสรุปช่วงเวลา)
      await _loadPeriodStats(resetLoading: false);

      if (mounted) {
        setState(() {
          _recentOrders = orders;
          _todaySales = todaySales;
          _todayProfit = todayProfit;
          _todayOrders = orders.length;
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

      if (_selectedPeriod == '1Y') {
        start = DateTime(now.year, 1, 1);
        type = 'MONTHLY';
      } else if (_selectedPeriod == '30D') {
        start = now.subtract(const Duration(days: 30));
      } else {
        start = now.subtract(const Duration(days: 7));
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
      // เตรียมข้อมูลตามช่วงที่เลือกเพื่อส่งให้ AI
      String csv = 'วันที่,ยอดขาย,ต้นทุน,กำไร\n';
      for (var s in _filteredStats) {
        double sales = double.tryParse(s['totalSales'].toString()) ?? 0.0;
        double cost = double.tryParse(s['totalCost'].toString()) ?? 0.0;
        csv += '${s['label']},$sales,$cost,${sales - cost}\n';
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('ภาพรวมธุรกิจและประวัติการขาย',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'รายการวันนี้'),
              Tab(text: 'สรุปยอดขาย'),
              Tab(text: 'กราฟแนวโน้ม'),
              Tab(text: 'วิเคราะห์ AI'),
            ],
            labelColor: Colors.indigo,
            indicatorColor: Colors.indigo,
            unselectedLabelColor: Colors.grey,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: TabBarView(
          children: [
            // Tab 1: รายการวันนี้ (Recent Sales Table only)
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
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadData,
                            tooltip: 'โหลดข้อมูลใหม่',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildRecentOrdersTable(true),
                ],
              ),
            ),

            // Tab 2: สรุปยอดขาย (Today's Card + Period-based Summaries)
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('สรุปยอดขายวันนี้',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildSummaryCards(),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('สรุปตามช่วงเวลา',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
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

            // Tab 3: กราฟแนวโน้ม (Trend Charts)
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('กราฟวิเคราะห์แนวโน้ม',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      _buildPeriodSelector(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildChartSection(),
                ],
              ),
            ),

            // Tab 4: วิเคราะห์ AI (AI Analysis)
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildAiSection(),
                  const SizedBox(height: 20),
                  const Text(
                    'AI จะวิเคราะห์จากข้อมูลในช่วงเวลาที่คุณเลือก (7 วัน, 30 วัน หรือ 1 ปี)',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: '7D', label: Text('7 วัน')),
        ButtonSegment(value: '30D', label: Text('30 วัน')),
        ButtonSegment(value: '1Y', label: Text('ปีนี้')),
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

  Widget _buildSummaryCards() {
    return Row(
      children: [
        _buildCard(
            'ยอดขายวันนี้',
            '฿${NumberFormat("#,##0").format(_todaySales)}',
            Colors.blue,
            Icons.attach_money),
        const SizedBox(width: 16),
        _buildCard(
            'กำไรวันนี้',
            '฿${NumberFormat("#,##0").format(_todayProfit)}',
            Colors.green,
            Icons.trending_up),
        const SizedBox(width: 16),
        _buildCard('จำนวนบิล', '$_todayOrders', Colors.orange, Icons.receipt),
      ],
    );
  }

  Widget _buildCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 24)),
              ],
            )
          ],
        ),
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
              child: Text(
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
              'แนวโน้มยอดขายและกำไร (${_selectedPeriod == "1Y" ? "รายเดือน" : "รายวัน"})',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) =>
                        Colors.indigo.withValues(alpha: 0.8),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.barIndex == 0 ? "ยอดขาย" : "กำไร"}: ฿${NumberFormat("#,##0").format(spot.y)}',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= _filteredStats.length) {
                          return const SizedBox();
                        }
                        final label = _filteredStats[index]['label'];

                        if (_selectedPeriod == '1Y') {
                          // label is yyyy-MM
                          final parts = label.split('-');
                          if (parts.length < 2) return Text(label);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(parts[1],
                                style: const TextStyle(fontSize: 10)),
                          );
                        } else {
                          // label is yyyy-MM-dd
                          final date = DateTime.parse(label);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(DateFormat('dd/MM').format(date),
                                style: const TextStyle(fontSize: 10)),
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
                lineBarsData: [
                  // Sales Line
                  LineChartBarData(
                    spots: _filteredStats.asMap().entries.map((e) {
                      return FlSpot(
                          e.key.toDouble(),
                          double.tryParse(e.value['totalSales'].toString()) ??
                              0);
                    }).toList(),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
                  // Profit Line
                  LineChartBarData(
                    spots: _filteredStats.asMap().entries.map((e) {
                      double sales =
                          double.tryParse(e.value['totalSales'].toString()) ??
                              0;
                      double cost =
                          double.tryParse(e.value['totalCost'].toString()) ?? 0;
                      return FlSpot(e.key.toDouble(), sales - cost);
                    }).toList(),
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
                ],
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
          )
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

  // ✅ ตารางรายการที่แก้ไขแล้ว
  Widget _buildRecentOrdersTable(bool showMoney) {
    final moneyFormat = NumberFormat('#,##0.00');

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
              columns: const [
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
                final received =
                    double.tryParse(o['received'].toString()) ?? 0.0;
                final type = o['type'];
                final rawStatus = o['status']?.toString().toUpperCase() ?? '';

                // ✅ Logic การแสดงสถานะและสี
                String statusText = '';
                Color statusColor = Colors.grey;

                if (type == 'DEBT_PAYMENT') {
                  statusText = 'ชำระหนี้';
                  statusColor = Colors.purple;
                } else if (rawStatus == 'UNPAID') {
                  // ✅ เช็คสถานะ UNPAID
                  statusText = 'ค้างจ่าย';
                  statusColor = Colors.orange.shade800;
                } else if (rawStatus == 'COMPLETED') {
                  statusText = 'สำเร็จ';
                  statusColor = Colors.green;
                } else if (rawStatus == 'HELD') {
                  statusText = 'พักบิล';
                  statusColor = Colors.blue;
                } else {
                  statusText = rawStatus;
                }

                return DataRow(cells: [
                  DataCell(Text(timeStr,
                      style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(Text(o['customerName'] ?? 'ลูกค้าทั่วไป')),
                  DataCell(Text(moneyFormat.format(amount),
                      style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(
                    moneyFormat.format(received),
                    style: TextStyle(
                        // ถ้าเป็นบิลขายแล้วรับเงินไม่ครบ ให้ขึ้นสีแดง
                        color: (received < amount && type != 'DEBT_PAYMENT')
                            ? Colors.red
                            : Colors.black87),
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
                        IconButton(
                          icon: const Icon(Icons.info_outline,
                              color: Colors.blue, size: 20),
                          tooltip: 'ดูรายละเอียด',
                          onPressed: () => _viewOrderDetails(
                              int.tryParse(o['id'].toString()) ?? 0),
                        ),
                        if (type != 'DEBT_PAYMENT') ...[
                          IconButton(
                            icon: const Icon(Icons.print,
                                color: Colors.grey, size: 20),
                            tooltip: 'ปริ้นซ้ำ',
                            onPressed: () => _reprintOrder(o),
                          ),
                          IconButton(
                            icon: const Icon(Icons.local_shipping,
                                color: Colors.orange, size: 20),
                            tooltip: 'ส่งของ',
                            onPressed: () => _sendToDelivery(
                                int.tryParse(o['id'].toString()) ?? 0),
                          ),
                        ],
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          tooltip: 'ลบบิล',
                          onPressed: () => _confirmDeleteOrder(
                              int.tryParse(o['id'].toString()) ?? 0),
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
}
