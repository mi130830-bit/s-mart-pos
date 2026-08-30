import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import '../repositories/dead_stock_repository.dart';
import 'logger_service.dart';

class DeadStockExcelService {
  Future<String?> exportDeadStockReport({
    required List<Map<String, dynamic>> records,
    required DeadStockFilter filter,
    String? categoryName,
  }) async {
    try {
      if (records.isEmpty) {
        debugPrint('⚠️ [DeadStockExcel] No records to export.');
        return null;
      }

      final excel = Excel.createExcel();
      final Sheet sheet = excel['สินค้าไม่เคลื่อนไหว'];
      excel.delete('Sheet1'); // Remove default sheet

      // ── Title & Meta ──────────────────────────────────────
      final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      titleCell.value = TextCellValue('รายงานสินค้าไม่มีการเคลื่อนไหว (Dead Stock Report)');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        fontColorHex: ExcelColor.fromHexString('#1E3A5F'),
      );

      String filterText = 'เงื่อนไข: ';
      if (filter.daysInactive == null) {
        filterText += 'ไม่เคยมีการเคลื่อนไหวเลย (Never Moved)';
      } else {
        filterText += 'ไม่มีการเคลื่อนไหวเกิน ${filter.daysInactive} วัน';
      }

      if (categoryName != null && categoryName.isNotEmpty) {
        filterText += ' | หมวดหมู่: $categoryName';
      }

      if (filter.stockFilter == 'has_stock') {
        filterText += ' | เฉพาะสินค้าที่มีสต็อก (> 0)';
      } else if (filter.stockFilter == 'zero_stock') {
        filterText += ' | สต็อกเป็น 0';
      }

      final filterCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
      filterCell.value = TextCellValue(filterText);
      filterCell.cellStyle = CellStyle(fontColorHex: ExcelColor.fromHexString('#555555'));

      final dateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2));
      dateCell.value = TextCellValue('วันที่พิมพ์รายงาน: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
      dateCell.cellStyle = CellStyle(fontColorHex: ExcelColor.fromHexString('#777777'));

      // ── Headers ──────────────────────────────────────────
      final headers = [
        'ลำดับ',
        'รหัสบาร์โค้ด',
        'ชื่อสินค้า',
        'หมวดหมู่',
        'สต็อกคงเหลือ',
        'หน่วยนับ',
        'ราคาทุน (฿)',
        'ราคาขาย (฿)',
        'มูลค่าเงินทุนจม (฿)',
        'เคลื่อนไหวล่าสุด',
        'สถานะการเคลื่อนไหว',
      ];

      const int headerRowIndex = 4;
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRowIndex));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        );
      }

      // ── Data Rows ────────────────────────────────────────
      int rowIndex = headerRowIndex + 1;
      double totalQuantity = 0.0;
      double totalCapital = 0.0;

      for (int i = 0; i < records.length; i++) {
        final r = records[i];
        final qty = double.tryParse(r['stockQuantity']?.toString() ?? '0') ?? 0.0;
        final cost = double.tryParse(r['costPrice']?.toString() ?? '0') ?? 0.0;
        final price = double.tryParse(r['retailPrice']?.toString() ?? '0') ?? 0.0;
        final capital = double.tryParse(r['totalCapital']?.toString() ?? '0') ?? 0.0;

        totalQuantity += qty;
        totalCapital += capital;

        // Last movement formatting
        final lastStock = r['lastStockAdjustmentDate']?.toString();
        final lastSale = r['lastSaleDate']?.toString();
        String lastMovementStr = '-';
        String statusStr = 'ไม่เคยเคลื่อนไหว';

        if (lastSale != null && lastSale.isNotEmpty) {
          try {
            final dt = DateTime.parse(lastSale);
            lastMovementStr = 'ขาย: ${DateFormat('dd/MM/yyyy').format(dt)}';
            statusStr = 'เคยขาย';
          } catch (_) {
            lastMovementStr = lastSale;
          }
        } else if (lastStock != null && lastStock.isNotEmpty) {
          try {
            final dt = DateTime.parse(lastStock);
            lastMovementStr = 'ปรับสต็อก: ${DateFormat('dd/MM/yyyy').format(dt)}';
            statusStr = 'เคยปรับสต็อก';
          } catch (_) {
            lastMovementStr = lastStock;
          }
        }

        final rowValues = [
          (i + 1),
          r['barcode']?.toString() ?? '',
          r['name']?.toString() ?? '',
          r['categoryName']?.toString() ?? 'ทั่วไป',
          qty,
          r['unitName']?.toString() ?? 'ชิ้น',
          cost,
          price,
          capital,
          lastMovementStr,
          statusStr,
        ];

        for (int col = 0; col < rowValues.length; col++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
          final val = rowValues[col];

          if (val is double) {
            cell.value = DoubleCellValue(val);
          } else if (val is int) {
            cell.value = IntCellValue(val);
          } else {
            cell.value = TextCellValue(val.toString());
          }
        }
        rowIndex++;
      }

      // ── Summary Row ──────────────────────────────────────
      rowIndex++;
      final totalLabelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex));
      totalLabelCell.value = TextCellValue('รวมทั้งหมด ${records.length} รายการ');
      totalLabelCell.cellStyle = CellStyle(bold: true);

      final totalQtyCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
      totalQtyCell.value = DoubleCellValue(totalQuantity);
      totalQtyCell.cellStyle = CellStyle(bold: true);

      final totalCapitalCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex));
      totalCapitalCell.value = DoubleCellValue(totalCapital);
      totalCapitalCell.cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#D32F2F'),
      );

      // ── Column Widths ────────────────────────────────────
      final widths = [
        8.0,  // ลำดับ
        18.0, // บาร์โค้ด
        35.0, // ชื่อสินค้า
        18.0, // หมวดหมู่
        14.0, // สต็อก
        10.0, // หน่วยนับ
        14.0, // ราคาทุน
        14.0, // ราคาขาย
        18.0, // มูลค่าทุนจม
        20.0, // เคลื่อนไหวล่าสุด
        18.0, // สถานะ
      ];
      for (int i = 0; i < widths.length; i++) {
        sheet.setColumnWidth(i, widths[i]);
      }

      // ── Save & Open ──────────────────────────────────────
      final dir = await getApplicationDocumentsDirectory();
      final dateFmt = DateFormat('yyyyMMdd_HHmmss');
      final outputPath = '${dir.path}\\Dead_Stock_Report_${dateFmt.format(DateTime.now())}.xlsx';

      final fileBytes = excel.encode();
      if (fileBytes != null) {
        try {
          File(outputPath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(fileBytes);
        } on FileSystemException catch (fse) {
          if (fse.osError?.errorCode == 32) {
            throw Exception('ไม่สามารถบันทึกไฟล์ได้ เนื่องจากไฟล์เปิดค้างไว้อยู่ กรุณาปิดไฟล์ก่อนทำการ Export ใหม่ครับ');
          }
          rethrow;
        }

        debugPrint('✅ [DeadStockExcel] Saved: $outputPath');
        OpenFile.open(outputPath);
        return outputPath;
      }
      return null;
    } catch (e, stack) {
      LoggerService.error('DeadStockExcel', 'Failed to export dead stock to Excel', e, stack);
      rethrow;
    }
  }
}
