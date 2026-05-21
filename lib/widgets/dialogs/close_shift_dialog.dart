import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../repositories/shift_repository.dart';
import '../../services/printing/receipt_service.dart';
import '../../services/alert_service.dart';
import '../../state/auth_provider.dart';

class CloseShiftDialog extends ConsumerStatefulWidget {
  const CloseShiftDialog({super.key});

  @override
  ConsumerState<CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends ConsumerState<CloseShiftDialog> {
  final ShiftRepository _shiftRepo = ShiftRepository();
  final _currencyFormat = NumberFormat('#,##0.00');
  
  bool _isLoading = true;
  DateTime _openedAt = DateTime.now();
  
  double _totalSales = 0;
  double _totalCash = 0;
  double _totalTransfer = 0;
  double _totalCredit = 0;

  double _openingCash = 0;
  double _actualCash = 0;
  final double _expenseAmount = 0; // ในอนาคตสามารถดึงจากตารางค่าใช้จ่ายที่จ่ายจากลิ้นชัก
  
  final TextEditingController _openingCashController = TextEditingController();
  final TextEditingController _actualCashController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _selectedPrintFormat = '80mm';

  @override
  void initState() {
    super.initState();
    _loadShiftData();
    
    _openingCashController.addListener(_onInputChanged);
    _actualCashController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _openingCashController.dispose();
    _actualCashController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    setState(() {
      _openingCash = double.tryParse(_openingCashController.text.replaceAll(',', '')) ?? 0;
      _actualCash = double.tryParse(_actualCashController.text.replaceAll(',', '')) ?? 0;
    });
  }

  Future<void> _loadShiftData() async {
    setState(() => _isLoading = true);
    try {
      final lastClosed = await _shiftRepo.getLastShiftClosingTime();
      if (lastClosed != null) {
        _openedAt = lastClosed;
      }

      final totals = await _shiftRepo.getShiftTotals(_openedAt);
      
      setState(() {
        _totalSales = totals['totalSales'] ?? 0;
        _totalCash = totals['totalCash'] ?? 0;
        _totalTransfer = totals['totalTransfer'] ?? 0;
        _totalCredit = totals['totalCredit'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading shift data: $e');
      if (mounted) {
        AlertService.show(context: context, message: 'เกิดข้อผิดพลาดในการโหลดข้อมูลหน้าปิดกะ', type: 'error');
        Navigator.pop(context);
      }
    }
  }

  double get _expectedCash {
    return _openingCash + _totalCash - _expenseAmount;
  }

  double get _difference {
    return _actualCash - _expectedCash;
  }

  Future<void> _submitCloseShift() async {
    final auth = ref.read(authProvider);
    final user = auth.currentUser;
    
    // ยืนยันก่อนบันทึก
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันระบบปิดกะ'),
        content: const Text('เมื่อยืนยันแล้ว ยอดขายและลิ้นชักจะถูกเริ่มนับใหม่รอบถัดไป\nและสลิปจะถูกพิมพ์ออกอัตโนมัติ แน่ใจหรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('ยืนยันปิดกะเลย', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final summary = ShiftSummary(
        openedAt: _openedAt,
        closedAt: now,
        closedBy: user?.displayName ?? 'Admin',
        openingCash: _openingCash,
        expectedCash: _expectedCash,
        actualCash: _actualCash,
        difference: _difference,
        totalSales: _totalSales,
        totalCash: _totalCash,
        totalTransfer: _totalTransfer,
        totalCredit: _totalCredit,
        expenseAmount: _expenseAmount,
        note: _noteController.text,
      );

      final success = await _shiftRepo.closeShift(summary);

      if (success) {
        // พิมพ์สลิป
        await ReceiptService().printShiftClosingSlip(
          shift: summary,
          paperSize: _selectedPrintFormat, 
          isPreview: _selectedPrintFormat == 'SAVE_PDF',
        );

        if (mounted) {
          AlertService.show(context: context, message: 'สิ้นสุดการปิดกะเรียบร้อย เครื่องพิมพ์กำลังทำงาน', type: 'success');
          Navigator.pop(context, true); // ส่ง true กลับไปบอกหน้าหลักว่าทำสำเร็จทำ reload data ได้
        }
      } else {
        if (mounted) {
          AlertService.show(context: context, message: 'บันทึกไม่สำเร็จ กรุณาลองใหม่', type: 'error');
        }
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(context: context, message: 'เกิดข้อผิดพลาดในการบันทึก: $e', type: 'error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSummaryRow(String label, double value, {bool isHighlight = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isHighlight ? 16 : 14, fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal)),
          Text(
            _currencyFormat.format(value), 
            style: TextStyle(
              fontSize: isHighlight ? 16 : 14, 
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              color: color ?? (isHighlight ? Colors.indigo : Colors.black87),
            )
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(
          width: 100, height: 100,
          child: Center(child: CircularProgressIndicator())
        ),
      );
    }

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.point_of_sale, color: Colors.teal),
          SizedBox(width: 8),
          Text('สรุปยอดเพื่อปิดกะ (Drawer)'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('เริ่มนับบิลตั้งแต่: ${DateFormat('dd/MM/yyyy HH:mm').format(_openedAt)}', style: const TextStyle(color: Colors.grey)),
              const Divider(),
              
              // --- 1. System Sales ---
              const Text('1. สรุปรายรับในระบบ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              _buildSummaryRow('ยอดขายรวม (Total Sales):', _totalSales, isHighlight: true),
              _buildSummaryRow('- รับเงินสด / ชำระหนี้ด้วยเงินสด:', _totalCash, color: Colors.green[700]),
              _buildSummaryRow('- โอนผ่านธนาคาร / สแกนคิวอาร์:', _totalTransfer, color: Colors.blue[700]),
              _buildSummaryRow('- ยอดลูกหนี้ (ค้างชำระ):', _totalCredit, color: Colors.orange[800]),
              const Divider(),

              // --- 2. Drawer Calculator ---
              const Text('2. คำนวณเงินลิ้นชัก', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('เงินทอนตั้งต้น (ถ้ามี):'),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _openingCashController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        isDense: true, contentPadding: EdgeInsets.all(8), border: OutlineInputBorder()
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.grey[200],
                child: _buildSummaryRow('เงินสดรวมที่ "ควรมี" ในลิ้นชัก:', _expectedCash, isHighlight: true, color: Colors.black),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('เงินสดที่ "นับได้จริง":', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _actualCashController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                      decoration: const InputDecoration(
                        isDense: true, contentPadding: EdgeInsets.all(8), border: OutlineInputBorder()
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Difference Display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _difference == 0 ? Colors.green : Colors.red, width: 2
                  ),
                  borderRadius: BorderRadius.circular(4)
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ส่วนต่างเงินสด:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      _difference == 0 ? 'พอดี (0.00)' 
                       : _difference < 0 ? 'เงินขาด ( ${_currencyFormat.format(_difference)} )'
                       : 'เงินเกิน ( +${_currencyFormat.format(_difference)} )',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16, 
                        color: _difference == 0 ? Colors.green[700] : Colors.red[700]
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text('หมายเหตุ / รายการค่าใช้จ่ายเพิ่มเติม:'),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(), hintText: 'เช่น ค่าข้าว, จ่ายค่าน้ำแข็ง, ...',
                  isDense: true,
                ),
              ),

              const SizedBox(height: 16),
              // Print Options
              const Text('ตัวเลือกสลิปสรุป:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                initialValue: _selectedPrintFormat,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: '80mm', child: Text('ใบย่อ - เครื่องพิมพ์ความร้อน 80mm/58mm')),
                  DropdownMenuItem(value: 'A5', child: Text('ใบย่อ - กระดาษ A5 (ครึ่งแผ่น)')),
                  DropdownMenuItem(value: 'A4', child: Text('ใบเต็ม - กระดาษ A4 (เต็มแผ่นแจกแจง)')),
                  DropdownMenuItem(value: 'SAVE_PDF', child: Text('บันทึกเอกสารเต็มเป็นไฟล์ PDF')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPrintFormat = val);
                },
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        ElevatedButton.icon(
          onPressed: _submitCloseShift, 
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          icon: const Icon(Icons.print),
          label: const Text('บันทึกปิดกะ & พิมพ์'),
        )
      ],
    );
  }
}
