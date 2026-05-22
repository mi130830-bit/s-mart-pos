import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../models/shop_info.dart';
import '../../repositories/shift_repository.dart';
import 'pdf_helper.dart';

class ShiftReportPdf {
  /// Generate Shortened Report (for Thermal 80/58mm and A5)
  static Future<Uint8List> generateShort({
    required ShiftSummary shift,
    required ShopInfo shopInfo,
    required PdfPageFormat pageFormat,
  }) async {
    final ttf = await PdfHelper.getFontRegular();
    final ttfBold = await PdfHelper.getFontBold();

    final pdf = pw.Document();
    
    final currency = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(child: pw.Text(shopInfo.name.isNotEmpty ? shopInfo.name : 'Store', style: pw.TextStyle(font: ttfBold, fontSize: 16))),
              pw.Center(child: pw.Text('สรุปปิดกะ (แบบย่อ)', style: pw.TextStyle(font: ttfBold, fontSize: 14))),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),

               // Details
              pw.Text('เริ่ม: ${dateFmt.format(shift.openedAt)}', style: pw.TextStyle(font: ttf, fontSize: 12)),
              pw.Text('ปิด: ${dateFmt.format(shift.closedAt)}', style: pw.TextStyle(font: ttf, fontSize: 12)),
              pw.Text('ผู้ทำรายการ: ${shift.closedBy ?? 'แอดมิน'}', style: pw.TextStyle(font: ttf, fontSize: 12)),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              
              // Totals
              _buildRow('ยอดขายรวม:', currency.format(shift.totalSales), ttf, ttfBold),
              _buildRow('รับเงินสด:', currency.format(shift.totalCash), ttf, ttfBold),
              _buildRow('รับเงินโอน/QR:', currency.format(shift.totalTransfer), ttf, ttfBold),
              
              pw.SizedBox(height: 10),
              // Drawer Reconciliation
              _buildRow('เงินทอนตั้งต้น:', currency.format(shift.openingCash), ttf, ttf),
              _buildRow('เงินสดควรมี:', currency.format(shift.expectedCash), ttf, ttfBold),
              _buildRow('เงินสดนับจริง:', currency.format(shift.actualCash), ttf, ttfBold),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),

              // Difference
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ส่วนต่าง:', style: pw.TextStyle(font: ttfBold, fontSize: 14)),
                  pw.Text(
                    shift.difference < 0 ? '${currency.format(shift.difference)} (ขาด)' 
                     : shift.difference > 0 ? '+${currency.format(shift.difference)} (เกิน)' 
                     : '0.00 (พอดี)',
                    style: pw.TextStyle(font: ttfBold, fontSize: 14),
                  ),
                ],
              ),
              pw.Divider(borderStyle: pw.BorderStyle.solid),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('ตรวจสอบและเซ็นรับรอง', style: pw.TextStyle(font: ttf, fontSize: 10))),
              pw.SizedBox(height: 30),
              pw.Center(child: pw.Text('......................................................', style: pw.TextStyle(font: ttf, fontSize: 10))),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Full Report (For A4 / PDF Backup)
  static Future<Uint8List> generateFull({
    required ShiftSummary shift,
    required ShopInfo shopInfo,
  }) async {
    final ttf = await PdfHelper.getFontRegular();
    final ttfBold = await PdfHelper.getFontBold();

    final pdf = pw.Document();
    
    final currency = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm:ss');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
               // Header
              pw.Center(child: pw.Text(shopInfo.name.isNotEmpty ? shopInfo.name : 'Store', style: pw.TextStyle(font: ttfBold, fontSize: 24))),
              pw.SizedBox(height: 5),
              pw.Center(child: pw.Text('รายงานสรุปยอดขายประจำกะ (เอกสารฉบับเต็ม)', style: pw.TextStyle(font: ttfBold, fontSize: 18))),
               pw.Center(child: pw.Text('พิมพ์เมื่อ: ${dateFmt.format(DateTime.now())}', style: pw.TextStyle(font: ttf, fontSize: 12, color: PdfColors.grey600))),
              pw.SizedBox(height: 20),
              
              // Info Box
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildFullRow('เวลารอบบิล เริ่มต้น:', dateFmt.format(shift.openedAt), ttf, ttfBold),
                    _buildFullRow('เวลารอบบิล สิ้นสุด:', dateFmt.format(shift.closedAt), ttf, ttfBold),
                    _buildFullRow('ผู้ดำเนินการปิดกะ:', shift.closedBy ?? 'ผู้ดูแลระบบ (Admin)', ttf, ttfBold),
                  ]
                )
              ),
              
              pw.SizedBox(height: 20),

              // Revenue Section
              pw.Text('1. สรุปรายรับ (Revenue Summary)', style: pw.TextStyle(font: ttfBold, fontSize: 16)),
              pw.Divider(),
              _buildFullRow('รายรับรวมทั้งสิ้น (Total Sales)', currency.format(shift.totalSales), ttf, ttfBold, isHighlight: true),
              pw.SizedBox(height: 5),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 20),
                child: pw.Column(
                  children: [
                     _buildFullRow('- ชำระผ่าน เงินสด (Cash/Pay Debt)', currency.format(shift.totalCash), ttf, ttf),
                     _buildFullRow('- ชำระผ่าน โอน/สแกน (Transfer/QR)', currency.format(shift.totalTransfer), ttf, ttf),
                     _buildFullRow('- ค้างชำระ (Credit Sales)', currency.format(shift.totalCredit), ttf, ttf),
                  ]
                )
              ),
              
              pw.SizedBox(height: 30),

               // Drawer Section
              pw.Text('2. สรุปตัวเงินลิ้นชัก (Drawer Reconciliation)', style: pw.TextStyle(font: ttfBold, fontSize: 16)),
              pw.Divider(),
              _buildFullRow('เงินทอนตั้งต้น (Opening Cash)', currency.format(shift.openingCash), ttf, ttf),
              _buildFullRow('รับเงินสดสุทธิ (Total Cash In)', currency.format(shift.totalCash), ttf, ttf),
              _buildFullRow('หักเงินนำออก/ค่าใช้จ่าย (Cash Out)', currency.format(shift.expenseAmount), ttf, ttf),
              pw.SizedBox(height: 10),
              pw.Container(
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.all(8),
                child: _buildFullRow('จำนวนเงินที่ควรมีในลิ้นชัก (Expected)', currency.format(shift.expectedCash), ttfBold, ttfBold, size: 16)
              ),
              pw.SizedBox(height: 10),
              _buildFullRow('จำนวนเงินสดที่นับได้จริง (Actual Count)', currency.format(shift.actualCash), ttfBold, ttfBold, size: 16),
              
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: shift.difference == 0 ? PdfColors.green : PdfColors.red, width: 2),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('ส่วนต่าง (Difference)', style: pw.TextStyle(font: ttfBold, fontSize: 16)),
                    pw.Text(
                      shift.difference == 0 ? 'พอดี (0.00)' 
                       : shift.difference < 0 ? 'เงินขาด ( ${currency.format(shift.difference)} )'
                       : 'เงินเกิน ( +${currency.format(shift.difference)} )',
                      style: pw.TextStyle(
                        font: ttfBold, 
                        fontSize: 16, 
                        color: shift.difference == 0 ? PdfColors.green700 : PdfColors.red700
                      )
                    )
                  ]
                )
              ),

              pw.SizedBox(height: 20),
               pw.Text('หมายเหตุ: ${shift.note.isNotEmpty ? shift.note : '-'}', style: pw.TextStyle(font: ttf, fontSize: 12, color: PdfColors.grey700)),
              
              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('..................................................................', style: pw.TextStyle(font: ttf)),
                      pw.Text('(                                                  )', style: pw.TextStyle(font: ttf)),
                      pw.Text('พนักงานแคชเชียร์ผู้ส่งกะ', style: pw.TextStyle(font: ttf)),
                    ]
                  ),
                  pw.Column(
                    children: [
                      pw.Text('..................................................................', style: pw.TextStyle(font: ttf)),
                      pw.Text('(                                                  )', style: pw.TextStyle(font: ttf)),
                      pw.Text('ผู้รับเงิน / ผู้ตรวจสอบ', style: pw.TextStyle(font: ttf)),
                    ]
                  )
                ]
              )
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildRow(String label, String value, pw.Font fontLabel, pw.Font fontValue) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: fontLabel, fontSize: 12)),
          pw.Text(value, style: pw.TextStyle(font: fontValue, fontSize: 12)),
        ],
      ),
    );
  }

  static pw.Widget _buildFullRow(String label, String value, pw.Font fontLabel, pw.Font fontValue, {bool isHighlight = false, double size = 14}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: fontLabel, fontSize: size, color: isHighlight ? PdfColors.blue800 : PdfColors.black)),
          pw.Text(value, style: pw.TextStyle(font: fontValue, fontSize: size, color: isHighlight ? PdfColors.blue800 : PdfColors.black)),
        ],
      ),
    );
  }
}
