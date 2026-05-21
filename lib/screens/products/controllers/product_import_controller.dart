import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/product.dart';
import '../../../repositories/category_repository.dart';
import '../../../repositories/product_repository.dart';
import '../../../repositories/supplier_repository.dart';
import '../../../repositories/unit_repository.dart';
import '../../../services/logger_service.dart';

final productImportProductRepoProvider = Provider((ref) => ProductRepository());
final productImportCategoryRepoProvider = Provider((ref) => CategoryRepository());
final productImportUnitRepoProvider = Provider((ref) => UnitRepository());
final productImportSupplierRepoProvider = Provider((ref) => SupplierRepository());

class ProductImportState {
  final List<List<dynamic>> dataRows;
  final bool isLoading;
  final double progressValue;
  final String statusMessage;
  final int successCount;
  final int failCount;
  final String? errorMessage;

  ProductImportState({
    this.dataRows = const [],
    this.isLoading = false,
    this.progressValue = 0.0,
    this.statusMessage = 'พร้อมสำหรับการนำเข้า',
    this.successCount = 0,
    this.failCount = 0,
    this.errorMessage,
  });

  ProductImportState copyWith({
    List<List<dynamic>>? dataRows,
    bool? isLoading,
    double? progressValue,
    String? statusMessage,
    int? successCount,
    int? failCount,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProductImportState(
      dataRows: dataRows ?? this.dataRows,
      isLoading: isLoading ?? this.isLoading,
      progressValue: progressValue ?? this.progressValue,
      statusMessage: statusMessage ?? this.statusMessage,
      successCount: successCount ?? this.successCount,
      failCount: failCount ?? this.failCount,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final productImportProvider = AutoDisposeNotifierProvider<ProductImportController, ProductImportState>(
  () => ProductImportController(),
);

class ProductImportController extends AutoDisposeNotifier<ProductImportState> {
  late final ProductRepository _productRepo;
  late final CategoryRepository _categoryRepo;
  late final UnitRepository _unitRepo;
  late final SupplierRepository _supplierRepo;
  bool _mounted = true;

  @override
  ProductImportState build() {
    _productRepo = ref.read(productImportProductRepoProvider);
    _categoryRepo = ref.read(productImportCategoryRepoProvider);
    _unitRepo = ref.read(productImportUnitRepoProvider);
    _supplierRepo = ref.read(productImportSupplierRepoProvider);
    
    _mounted = true;
    ref.onDispose(() => _mounted = false);
    
    return ProductImportState();
  }

  void clearError() {
    if (_mounted) state = state.copyWith(clearError: true);
  }

  Future<void> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv', 'txt'],
        allowMultiple: false,
      );

      if (result != null) {
        if (!_mounted) return;
        state = state.copyWith(
          isLoading: true,
          statusMessage: 'กำลังอ่านไฟล์...',
          dataRows: [],
          progressValue: 0.0,
          clearError: true,
        );

        final file = result.files.first;
        final extension = file.extension?.toLowerCase() ?? '';
        List<List<dynamic>> tempRows = [];

        if (extension == 'xlsx' || extension == 'xls') {
          var bytes = file.bytes;
          if (bytes == null && !kIsWeb) {
            bytes = await File(file.path!).readAsBytes();
          }

          if (bytes != null) {
            var excel = Excel.decodeBytes(bytes);
            final table = excel.tables[excel.tables.keys.first];
            if (table != null) {
              for (var row in table.rows) {
                tempRows.add(row.map((e) => e?.value ?? '').toList());
              }
            }
          }
        } else {
          String content = '';
          List<int> bytes;
          if (kIsWeb) {
            bytes = file.bytes!;
          } else {
            bytes = await File(file.path!).readAsBytes();
          }

          try {
            content = utf8.decode(bytes);
          } catch (e) {
            content = latin1.decode(bytes);
          }

          tempRows = const CsvDecoder().convert(content);
        }

        if (!_mounted) return;

        if (tempRows.isNotEmpty) {
          // Remove Header
          tempRows.removeAt(0);
          // Filter Empty
          final rows = tempRows
              .where((r) => r.isNotEmpty && r[0].toString().isNotEmpty)
              .toList();
          state = state.copyWith(
            dataRows: rows,
            statusMessage: 'อ่านไฟล์สำเร็จ พบข้อมูล ${rows.length} รายการ',
            isLoading: false,
          );
        } else {
          state = state.copyWith(
            statusMessage: 'ไม่พบข้อมูลในไฟล์',
            isLoading: false,
          );
        }
      }
    } catch (e, stackTrace) {
      LoggerService.error('ProductImport', 'Failed to pick or parse file', e, stackTrace);
      if (!_mounted) return;

      String errorMsg = 'อ่านไฟล์ไม่สำเร็จ: $e';
      if (e.toString().contains('numFmtId')) {
        errorMsg =
            'ไม่รองรับรูปแบบ Excel นี้ (numFmtId Error)\nคำแนะนำ: โปรดบันทึกไฟล์เป็น .CSV (UTF-8) แล้วลองใหม่อีกครั้ง';
      }
      state = state.copyWith(
        isLoading: false,
        statusMessage: 'เกิดข้อผิดพลาดในการอ่านไฟล์',
        errorMessage: errorMsg,
      );
    }
  }

  Future<bool> saveProducts() async {
    if (state.dataRows.isEmpty) return false;

    if (!_mounted) return false;
    state = state.copyWith(
      isLoading: true,
      successCount: 0,
      failCount: 0,
      progressValue: 0.0,
      statusMessage: 'กำลังบันทึกข้อมูล...',
    );

    int total = state.dataRows.length;
    int successCount = 0;
    int failCount = 0;

    for (int i = 0; i < total; i++) {
      if (!_mounted) return false;
      var row = state.dataRows[i];
      try {
        if (row.length < 7) {
          failCount++;
          continue;
        }

        // Mapping Data
        String code = row[0].toString().trim();
        String name = row[1].toString().trim();
        String category = row[2].toString().trim();
        String qtyStr = row[3].toString().replaceAll(',', '');
        int stock = double.tryParse(qtyStr)?.toInt() ?? 0;
        String unit = row[4].toString().trim();
        double cost =
            double.tryParse(row[5].toString().replaceAll(',', '')) ?? 0.0;
        double price =
            double.tryParse(row[6].toString().replaceAll(',', '')) ?? 0.0;

        double wholesalePrice = 0.0;
        if (row.length > 7) {
          wholesalePrice =
              double.tryParse(row[7].toString().replaceAll(',', '')) ?? 0.0;
        }
        double memberPrice = 0.0;
        if (row.length > 8) {
          memberPrice =
              double.tryParse(row[8].toString().replaceAll(',', '')) ?? 0.0;
        }

        double reorderPoint = 0.0;
        if (row.length > 9) {
          reorderPoint =
              double.tryParse(row[9].toString().replaceAll(',', '')) ?? 0.0;
        }

        String alias = '';
        if (row.length > 10) {
          alias = row[10].toString().trim();
        }

        String supplierName = '';
        if (row.length > 11) {
          supplierName = row[11].toString().trim();
        }

        if (name.isEmpty) {
          failCount++;
          continue;
        }

        // 2. Lookup IDs
        int categoryId = 0;
        if (category.isNotEmpty) {
          categoryId = await _categoryRepo.getOrCreateCategoryId(category);
        }

        int unitId = 0;
        if (unit.isNotEmpty) {
          unitId = await _unitRepo.getOrCreateUnitId(unit);
        }

        int supplierId = 0;
        if (supplierName.isNotEmpty) {
          supplierId = await _supplierRepo.getOrCreateSupplierId(supplierName);
        }

        // 3. Create Product
        if (code.isEmpty || code.toLowerCase() == 'null') {
          code = 'AUTO${DateTime.now().microsecondsSinceEpoch}';
        }

        final newProduct = Product(
          id: 0,
          barcode: code,
          name: name,
          alias: alias,
          productType: 0, // General (Default)
          categoryId: categoryId,
          unitId: unitId,
          supplierId: supplierId,
          stockQuantity: stock.toDouble(),
          costPrice: cost,
          retailPrice: price,
          wholesalePrice: wholesalePrice,
          memberRetailPrice: memberPrice,
          reorderPoint: reorderPoint,
          points: 0,
          vatType: 0,
          trackStock: true,
        );

        final result = await _productRepo.addProduct(newProduct);
        if (result > 0) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e, stackTrace) {
        LoggerService.error('ProductImport', 'Failed to save row $i', e, stackTrace);
        failCount++;
      }

      // Update Progress every 5 items or last item
      if (i % 5 == 0 || i == total - 1) {
        if (_mounted) {
          state = state.copyWith(
            progressValue: (i + 1) / total,
            statusMessage: 'กำลังบันทึก... ${((i + 1) / total * 100).toStringAsFixed(0)}%',
            successCount: successCount,
            failCount: failCount,
          );
        }
        await Future.delayed(const Duration(milliseconds: 1)); // UI Yield
      }
    }

    if (_mounted) {
      state = state.copyWith(
        isLoading: false,
        progressValue: 1.0,
        statusMessage: 'บันทึกเสร็จสิ้น',
        dataRows: [],
        successCount: successCount,
        failCount: failCount,
      );
    }
    
    return true; // Finished processing
  }

  Future<String?> exportTemplate() async {
    try {
      // Create Header Row
      List<String> headers = [
        'บาร์โค้ด (Barcode)',
        'ชื่อสินค้า (Name)',
        'หมวดหมู่/ประเภท (Category/Type)', // Renamed for clarity
        'จำนวนสต็อก (Stock)',
        'หน่วยนับ (Unit)',
        'ต้นทุน (Cost)',
        'ราคาขาย (Retail)',
        'ราคาส่ง (Wholesale)',
        'ราคาสมาชิก (Member)',
        'จุดสั่งซื้อ (Restock Point)',
        'ตัวย่อ (Alias)',
        'ผู้ขาย (Supplier)'
      ];

      // Convert to CSV
      List<List<dynamic>> rows = [headers];
      String csvContent = const CsvEncoder().convert(rows);

      // Add UTF-8 BOM for Excel compatibility with Thai text
      final bytes = utf8.encode('\uFEFF$csvContent');

      // Save file
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'บันทึกไฟล์ Template (CSV)',
        fileName: 'product_import_template.csv',
        allowedExtensions: ['csv'],
        type: FileType.custom,
      );

      if (outputFile != null) {
        File(outputFile)
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);
        return outputFile; // Success
      }
      return null; // Cancelled
    } catch (e, stackTrace) {
      LoggerService.error('ProductImport', 'Error export template: $e', e, stackTrace);
      if (_mounted) {
        state = state.copyWith(
          errorMessage: 'เกิดข้อผิดพลาดในการสร้าง Template: $e'
        );
      }
      return null;
    }
  }
}
