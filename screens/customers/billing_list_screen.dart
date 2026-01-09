import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../models/billing_note.dart';
import '../../repositories/billing_repository.dart';
import '../../services/printing/pdf_document_service.dart';
import 'create_billing_screen.dart';
import 'edit_billing_screen.dart';

class BillingListScreen extends StatefulWidget {
  const BillingListScreen({super.key});

  @override
  State<BillingListScreen> createState() => _BillingListScreenState();
}

class _BillingListScreenState extends State<BillingListScreen> {
  final BillingRepository _repo = BillingRepository();
  List<BillingNote> _allNotes = [];
  List<BillingNote> _filteredNotes = [];
  bool _isLoading = true;

  // Search & Filter
  final TextEditingController _searchCtrl = TextEditingController();
  String _statusFilter = 'ALL'; // ALL, PENDING, PAID

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    final list = await _repo.getBillingNotes();
    if (mounted) {
      setState(() {
        _allNotes = list;
        _filterNotes();
        _isLoading = false;
      });
    }
  }

  void _filterNotes() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredNotes = _allNotes.where((n) {
        final matchesSearch = n.documentNo.toLowerCase().contains(query) ||
            (n.customerName?.toLowerCase().contains(query) ?? false);

        final matchesStatus = _statusFilter == 'ALL' ||
            (_statusFilter == 'PAID' && n.status == 'PAID') ||
            (_statusFilter == 'PENDING' &&
                n.status != 'PAID'); // Treat others as pending

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Future<void> _deleteBillingNote(BillingNote note) async {
    if (note.status == 'PAID') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'ไม่สามารถลบใบวางบิลที่ "ชำระแล้ว" ได้ กรุณายกเลิกการชำระเงินก่อน'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text(
            'ต้องการลบใบวางบิล ${note.documentNo} หรือไม่?\n(ข้อมูลจะถูกลบถาวร และรายการขายจะกลับไปสถานะค้างบิล)'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ลบ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      // Real Delete
      final success = await _repo.deleteBillingNote(note.id!);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('ลบใบวางบิลเรียบร้อยแล้ว'),
          ));
        }
        _loadNotes();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('เกิดข้อผิดพลาดในการลบ'),
            backgroundColor: Colors.red,
          ));
        }
      }
    }
  }

  Future<void> _confirmPay(BillingNote note) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการชำระเงิน'),
        content: Text(
            'ต้องการเปลี่ยนสถานะเอกสาร ${note.documentNo} เป็น "ชำระแล้ว" หรือไม่?\nยอดเงิน: ฿${NumberFormat('#,##0.00').format(note.totalAmount)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ยืนยันชำระเงิน')),
        ],
      ),
    );

    if (result == true) {
      await _repo.updateStatus(
          note.id!, 'PAID', note.totalAmount, note.customerId);
      _loadNotes();
    }
  }

  Future<void> _printBillingNote(BillingNote note) async {
    try {
      final items = await _repo.getBillingNoteItems(note.id!);

      final mappedItems = items.map((i) {
        final orderId = i['orderId'];
        final amount = i['amount'];
        // Use default description if not joined
        return {
          'description': 'บิล/Invoice #$orderId',
          'amount': amount,
        };
      }).toList();

      final pdfService = PdfDocumentService();
      final pdfData =
          await pdfService.generateBillingNote(note: note, items: mappedItems);

      await Printing.layoutPdf(
        onLayout: (format) async => pdfData,
        name: 'Billing_${note.documentNo}',
      );
    } catch (e) {
      debugPrint('Print Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error printing: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 1. Header & Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'ค้นหารายการใบวางบิล',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'ค้นหารายการใบวางบิล',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          isDense: true,
                        ),
                        onChanged: (v) => _filterNotes(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onPressed: _filterNotes,
                      icon: const Icon(Icons.search),
                      label: const Text('ค้นหา'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onPressed: () async {
                        final res = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CreateBillingScreen()));
                        if (res == true) _loadNotes();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('ใบวางบิล'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildRadioFilter('ทั้งหมด', 'ALL'),
                    _buildRadioFilter('ค้างชำระ', 'PENDING'),
                    _buildRadioFilter('ชำระแล้ว', 'PAID'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 2. Table Header
          Container(
            color: Colors.blue,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                _buildHeaderCell('ที่', flex: 1),
                _buildHeaderCell('เลขที่', flex: 2),
                _buildHeaderCell('ชื่อลูกหนี้', flex: 4),
                _buildHeaderCell('จำนวนบิล', flex: 2),
                _buildHeaderCell('จำนวนเงิน', flex: 3),
                _buildHeaderCell('วันที่', flex: 3),
                _buildHeaderCell('วันที่ชำระ', flex: 3),
                _buildHeaderCell('สถานะ', flex: 2),
                _buildHeaderCell('พิมพ์', flex: 1),
                _buildHeaderCell('แก้ไข', flex: 1),
                _buildHeaderCell('ลบ', flex: 1),
              ],
            ),
          ),

          // 3. List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredNotes.isEmpty
                    ? const Center(child: Text('ไม่พบรายการ'))
                    : ListView.builder(
                        itemCount: _filteredNotes.length,
                        itemBuilder: (ctx, i) {
                          final note = _filteredNotes[i];
                          final isPaid = note.status == 'PAID';
                          return Container(
                            decoration: BoxDecoration(
                              color: i % 2 == 0
                                  ? Colors.white
                                  : Colors.grey.shade50,
                              border: const Border(
                                  bottom: BorderSide(
                                      color: Colors.grey, width: 0.5)),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 8),
                            child: Row(
                              children: [
                                _buildTextCell('${i + 1}',
                                    flex: 1, align: TextAlign.center),
                                _buildTextCell(note.documentNo, flex: 2),
                                _buildTextCell(note.customerName ?? '-',
                                    flex: 4),
                                _buildTextCell('${note.itemCount}',
                                    flex: 2, align: TextAlign.center),
                                _buildTextCell(
                                    '฿${NumberFormat("#,##0.00").format(note.totalAmount)}',
                                    flex: 3,
                                    fontWeight: FontWeight.bold),
                                _buildTextCell(
                                    DateFormat('dd-MM-yyyy HH:mm')
                                        .format(note.issueDate),
                                    flex: 3,
                                    fontSize: 12),
                                _buildTextCell(
                                    note.paymentDate != null
                                        ? DateFormat('dd-MM-yyyy HH:mm')
                                            .format(note.paymentDate!)
                                        : '-',
                                    flex: 3,
                                    fontSize: 12),

                                // Status
                                Expanded(
                                  flex: 2,
                                  child: isPaid
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4, horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text('จ่ายแล้ว',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12)),
                                        )
                                      : ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 30),
                                          ),
                                          onPressed: () => _confirmPay(note),
                                          child: const Text('จ่ายเงิน',
                                              style: TextStyle(fontSize: 12)),
                                        ),
                                ),

                                // Functions
                                Expanded(
                                  flex: 1,
                                  child: IconButton(
                                    icon: const Icon(Icons.print,
                                        color: Colors.blue),
                                    onPressed: () => _printBillingNote(note),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: IconButton(
                                    icon: const Icon(Icons.edit_note,
                                        color: Colors.blue),
                                    onPressed: () async {
                                      if (note.status == 'PAID') {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          content: Text(
                                              'ไม่สามารถแก้ไขใบวางบิลที่ "ชำระแล้ว" ได้'),
                                          backgroundColor: Colors.red,
                                        ));
                                        return;
                                      }

                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => EditBillingScreen(
                                                billingNote: note)),
                                      );
                                      if (result == true) {
                                        _loadNotes();
                                      }
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    onPressed: () => _deleteBillingNote(note),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Bottom Status
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade200,
            child: Row(
              children: [
                Text(
                    'พบ ${_filteredNotes.length} รายการ จากทั้งหมด ${_allNotes.length} รายการ',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRadioFilter(String label, String value) {
    final bool isSelected = _statusFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _statusFilter = value;
          _filterNotes();
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTextCell(String text,
      {required int flex,
      TextAlign align = TextAlign.left,
      FontWeight fontWeight = FontWeight.normal,
      double fontSize = 14}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(fontWeight: fontWeight, fontSize: fontSize),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
