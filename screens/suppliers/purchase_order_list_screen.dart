import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart'; // [NEW]
import '../../repositories/purchase_repository.dart';
import 'create_purchase_order_screen.dart';
import '../../services/alert_service.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../services/printing/pdf_document_service.dart';

class PurchaseOrderListScreen extends StatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  State<PurchaseOrderListScreen> createState() =>
      _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState extends State<PurchaseOrderListScreen> {
  final PurchaseRepository _purchaseRepo = PurchaseRepository();
  List<Map<String, dynamic>> _pos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await _purchaseRepo.getPOs();
    setState(() {
      _pos = results;
      _isLoading = false;
    });
  }

  Future<void> _printPO(int poId) async {
    try {
      final details = await _purchaseRepo.getPODetails(poId);
      if (details == null) return;

      final header = details['header'];
      final items = details['items'] as List<Map<String, dynamic>>;

      final pdfService = PdfDocumentService();
      final pdfData =
          await pdfService.generatePurchaseOrder(header: header, items: items);

      await Printing.layoutPdf(
        onLayout: (format) async => pdfData,
        name: 'PO_${header['id']}',
      );
    } catch (e) {
      debugPrint('Print PO Error: $e');
      if (mounted) {
        AlertService.show(
            context: context, message: 'Print Error: $e', type: 'error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการใบสั่งซื้อ (Purchase Orders)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pos.isEmpty
              ? _buildEmptyState()
              : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const CreatePurchaseOrderScreen()),
          );
          if (result == true) _loadData();
        },
        label: const Text('สร้างใบสั่งซื้อใหม่'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('ยังไม่มีใบสั่งซื้อ',
              style: TextStyle(color: Colors.grey, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildList() {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final nf = NumberFormat('#,##0.00');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pos.length,
      itemBuilder: (context, index) {
        final po = _pos[index];
        final status = po['status'].toString();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text('PO #${po['id']} - ${po['supplierName'] ?? "N/A"}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'วันที่: ${df.format(DateTime.parse(po['createdAt'].toString()))}'),
                Text('พนักงาน: ${po['userName'] ?? "Admin"}'),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                    '${nf.format(double.tryParse(po['totalAmount'].toString()) ?? 0.0)} ฿',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.indigo)),
                _buildStatusChip(status),
              ],
            ),
            onTap: () => _showPODetails(po['id']),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    switch (status) {
      case 'DRAFT':
        color = Colors.grey;
        text = 'ร่าง';
        break;
      case 'ORDERED':
        color = Colors.blue;
        text = 'สั่งซื้อแล้ว';
        break;
      case 'RECEIVED':
        color = Colors.green;
        text = 'รับของแล้ว';
        break;
      case 'CANCELLED':
        color = Colors.red;
        text = 'ยกเลิก';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _showPODetails(int poId) async {
    final details = await _purchaseRepo.getPODetails(poId);
    if (details == null) return;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final header = details['header'];
        final items = details['items'] as List<Map<String, dynamic>>;
        final nf = NumberFormat('#,##0.00');

        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(sheetCtx).size.height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('รายละเอียดใบสั่งซื้อ #${header['id']}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  Row(children: [
                    IconButton(
                        icon: const Icon(Icons.print, color: Colors.indigo),
                        onPressed: () => _printPO(poId),
                        tooltip: 'พิมพ์ใบสั่งซื้อ'),
                    IconButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: const Icon(Icons.close)),
                  ])
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final it = items[i];
                    return ListTile(
                      title: Text(it['productName']),
                      subtitle: Text(
                          '${it['quantity']} x ${nf.format(double.tryParse(it['costPrice'].toString()) ?? 0.0)}'),
                      trailing: Text(
                          '${nf.format(double.tryParse(it['total'].toString()) ?? 0.0)} ฿'),
                    );
                  },
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ยอดรวมสุทธิ:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                      '${nf.format(double.tryParse(header['totalAmount'].toString()) ?? 0.0)} ฿',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo)),
                ],
              ),
              const SizedBox(height: 24),
              if (header['status'] == 'ORDERED' || header['status'] == 'DRAFT')
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: CustomButton(
                    onPressed: () async {
                      final navigator = Navigator.of(sheetCtx);
                      final ok = await _purchaseRepo.receivePO(poId);
                      if (ok && mounted) {
                        navigator.pop();
                        _loadData();
                        AlertService.show(
                          context: context, // Use State context
                          message: 'รับสินค้าเข้าสต็อกเรียบร้อย',
                          type: 'success',
                        );
                      }
                    },
                    icon: Icons.download_for_offline,
                    label: 'กดรับสินค้าเข้าคลัง (Receive Stock)',
                    type: ButtonType.primary,
                    backgroundColor: Colors.green,
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
