import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/unit_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../widgets/common/custom_buttons.dart';

class ProductImportScreen extends StatefulWidget {
  const ProductImportScreen({super.key});

  @override
  State<ProductImportScreen> createState() => _ProductImportScreenState();
}

class _ProductImportScreenState extends State<ProductImportScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final UnitRepository _unitRepo = UnitRepository();
  final SupplierRepository _supplierRepo = SupplierRepository();

  List<List<dynamic>> _dataRows = [];
  bool _isLoading = false;
  double _progressValue = 0.0;
  String _statusMessage = 'พร้อมสำหรับการนำเข้า';
  int _successCount = 0;
  int _failCount = 0;

  // Colors
  final Color _primaryColor = Colors.indigo;
  final Color _successColor = Colors.teal;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv', 'txt'],
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _isLoading = true;
          _statusMessage = 'กำลังอ่านไฟล์...';
          _dataRows = [];
          _progressValue = 0.0;
        });

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

          tempRows = const CsvToListConverter().convert(
            content,
            eol: '\n',
            shouldParseNumbers: false,
          );
        }

        setState(() {
          if (tempRows.isNotEmpty) {
            // Remove Header
            tempRows.removeAt(0);
            // Filter Empty
            _dataRows = tempRows
                .where((r) => r.isNotEmpty && r[0].toString().isNotEmpty)
                .toList();
            _statusMessage =
                'อ่านไฟล์สำเร็จ พบข้อมูล ${_dataRows.length} รายการ';
          } else {
            _statusMessage = 'ไม่พบข้อมูลในไฟล์';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'เกิดข้อผิดพลาดในการอ่านไฟล์';
        });
      }

      String errorMsg = 'อ่านไฟล์ไม่สำเร็จ: $e';
      if (e.toString().contains('numFmtId')) {
        errorMsg =
            'ไม่รองรับรูปแบบ Excel นี้ (numFmtId Error)\nคำแนะนำ: โปรดบันทึกไฟล์เป็น .CSV (UTF-8) แล้วลองใหม่อีกครั้ง';
      }
      _showError(errorMsg);
    }
  }

  Future<void> _saveProducts() async {
    if (_dataRows.isEmpty) return;

    setState(() {
      _isLoading = true;
      _successCount = 0;
      _failCount = 0;
      _progressValue = 0.0;
      _statusMessage = 'กำลังบันทึกข้อมูล...';
    });

    int total = _dataRows.length;

    for (int i = 0; i < total; i++) {
      var row = _dataRows[i];
      try {
        if (row.length < 7) {
          _failCount++;
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

        // --- ส่วนเสริม: ราคาส่งและราคาสมาชิก ---
        double wholesalePrice =
            double.tryParse(row[7].toString().replaceAll(',', '')) ?? 0.0;
        double memberPrice =
            double.tryParse(row[8].toString().replaceAll(',', '')) ?? 0.0;

        // --- ส่วนเสริม: จุดสั่งซื้อ (Restock Point) Column 9 ---
        double reorderPoint = 0.0;
        if (row.length > 9) {
          reorderPoint =
              double.tryParse(row[9].toString().replaceAll(',', '')) ?? 0.0;
        }

        // --- Alias (ตัวย่อ) Column 10 ---
        String alias = '';
        if (row.length > 10) {
          alias = row[10].toString().trim();
        }

        // --- Supplier (ผู้ขาย) Column 11 ---
        String supplierName = '';
        if (row.length > 11) {
          supplierName = row[11].toString().trim();
        }

        if (name.isEmpty) {
          _failCount++;
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
          _successCount++;
        } else {
          _failCount++;
        }
      } catch (e) {
        debugPrint('Error row $i: $e');
        _failCount++;
      }

      // Update Progress every 5 items or last item
      if (i % 5 == 0 || i == total - 1) {
        if (mounted) {
          setState(() {
            _progressValue = (i + 1) / total;
            _statusMessage =
                'กำลังบันทึก... ${((i + 1) / total * 100).toStringAsFixed(0)}%';
          });
        }
        await Future.delayed(const Duration(milliseconds: 1)); // UI Yield
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _progressValue = 1.0;
        _statusMessage = 'บันทึกเสร็จสิ้น';
        _dataRows = []; // Clear data after import
      });
      _showResultDialog();
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('ผลการนำเข้า'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildResultTile('สำเร็จ', '$_successCount', Colors.green),
            const Divider(),
            _buildResultTile('ล้มเหลว', '$_failCount', Colors.red),
            const SizedBox(height: 16),
            const Text(
              'หมายเหตุ: ข้อมูลที่ไม่สมบูรณ์ถูกข้ามไป',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          CustomButton(
            onPressed: () => Navigator.pop(ctx),
            label: 'ตกลง',
            type: ButtonType.primary,
          )
        ],
      ),
    );
  }

  Future<void> _exportTemplate() async {
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
      String csvContent = const ListToCsvConverter().convert(rows);

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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'บันทึก Template (.csv) สำเร็จ! แนะนำให้เปิดและแก้ไขแล้วบันทึกกลับมาเป็น CSV เหมือนเดิม'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error export template: $e');
      if (mounted) _showError('เกิดข้อผิดพลาดในการสร้าง Template: $e');
    }
  }

  Widget _buildResultTile(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('นำเข้าสินค้า (Import Products)'),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'ดาวน์โหลด Template',
            onPressed: () => _exportTemplate(),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- 1. Control Panel ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        onPressed: _isLoading ? null : _pickFile,
                        icon: Icons.file_upload_outlined,
                        label: 'เลือกไฟล์ Excel/CSV',
                        type: ButtonType.secondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomButton(
                        onPressed: (_isLoading || _dataRows.isEmpty)
                            ? null
                            : _saveProducts,
                        icon: Icons.save_as_outlined,
                        label: 'ยืนยันนำเข้าข้อมูล',
                        backgroundColor: _successColor,
                        type: ButtonType.primary,
                      ),
                    ),
                  ],
                ),
                if (_isLoading || _dataRows.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_statusMessage,
                          style: TextStyle(
                              color: _primaryColor,
                              fontWeight: FontWeight.w600)),
                      if (_isLoading)
                        Text('${(_progressValue * 100).toInt()}%',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _progressValue,
                    backgroundColor: Colors.grey.shade200,
                    color: _primaryColor,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ],
            ),
          ),

          // --- 2. Data Preview ---
          Expanded(
            child: _dataRows.isEmpty && !_isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.table_chart_outlined,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 20),
                        Text(
                          'ยังไม่ได้เลือกไฟล์',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'รองรับ .xlsx, .csv (Format 12 Columns)',
                            style:
                                TextStyle(color: _primaryColor, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )
                : _isLoading && _dataRows.isEmpty // Loading while parsing file
                    ? const Center(child: CircularProgressIndicator())
                    : Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                color: Colors.grey.shade100,
                                child: Text(
                                  'ตัวอย่างข้อมูล (${_dataRows.length} รายการ)',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(
                                          Colors.grey.shade50),
                                      columns: const [
                                        DataColumn(label: Text('บาร์โค้ด')),
                                        DataColumn(label: Text('ชื่อสินค้า')),
                                        DataColumn(
                                            label: Text('หมวดหมู่/ประเภท')),
                                        DataColumn(label: Text('สต็อก')),
                                        DataColumn(label: Text('หน่วย')),
                                        DataColumn(label: Text('ทุน')),
                                        DataColumn(label: Text('ราคาขาย')),
                                        DataColumn(label: Text('ราคาขายส่ง')),
                                        DataColumn(label: Text('ราคาสมาชิก')),
                                        DataColumn(label: Text('จุดสั่งซื้อ')),
                                        DataColumn(label: Text('ตัวย่อ')),
                                        DataColumn(label: Text('ผู้ขาย')),
                                        DataColumn(label: Text('ตรวจสอบ')),
                                      ],
                                      rows: _dataRows.take(100).map((row) {
                                        // Helper
                                        String val(int i) => row.length > i
                                            ? row[i].toString()
                                            : '';
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(val(0))),
                                            DataCell(Text(
                                              val(1),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            )),
                                            DataCell(Text(val(2))),
                                            DataCell(Text(val(3))),
                                            DataCell(Text(val(4))),
                                            DataCell(Text(val(5))),
                                            DataCell(Text(val(6))),
                                            DataCell(Text(val(7))),
                                            DataCell(Text(val(8))),
                                            DataCell(
                                                Text(val(9))), // Restock Point
                                            DataCell(Text(val(10))), // Alias
                                            DataCell(Text(val(11))), // Supplier
                                            DataCell(_buildStatusChip(row)),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(List<dynamic> row) {
    bool isComplete =
        row.length >= 7 && row[1].toString().isNotEmpty; // Check Name
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isComplete ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isComplete ? 'พร้อม' : 'ไม่ครบ',
        style: TextStyle(
            fontSize: 10,
            color: isComplete ? Colors.green.shade800 : Colors.red.shade800,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}
