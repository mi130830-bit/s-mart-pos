import 'dart:convert';
import 'dart:io';
import 'dart:math'; // Import for Random
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../repositories/customer_repository.dart';

class CustomerImportScreen extends StatefulWidget {
  const CustomerImportScreen({super.key});

  @override
  State<CustomerImportScreen> createState() => _CustomerImportScreenState();
}

class _CustomerImportScreenState extends State<CustomerImportScreen> {
  final CustomerRepository _customerRepo = CustomerRepository();
  List<List<dynamic>> _csvData = [];
  bool _isLoading = false;
  int _successCount = 0;
  int _failCount = 0;

  // เลือกไฟล์ CSV
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        allowMultiple: false,
      );

      if (result != null) {
        setState(() => _isLoading = true);

        final file = result.files.first;
        String content = '';

        // จัดการ encoding
        if (kIsWeb) {
          final bytes = file.bytes!;
          try {
            content = utf8.decode(bytes);
          } catch (e) {
            content = latin1.decode(bytes);
          }
        } else {
          final f = File(file.path!);
          final bytes = await f.readAsBytes();
          try {
            content = utf8.decode(bytes);
          } catch (e) {
            // Fallback to Latin1 if UTF-8 fails (common for non-utf8 files)
            // Note: Thai characters might require 'TIS-620' which needs 'charset_converter' package
            // preventing add extra dependencies, we suggest saving as CSV UTF-8.
            content = latin1.decode(bytes);
          }
        }

        // แปลง CSV เป็น List
        final List<List<dynamic>> rows = const CsvToListConverter().convert(
          content,
          eol: '\n',
          shouldParseNumbers: false,
        );

        setState(() {
          // ตัด Header แถวแรกออก
          if (rows.isNotEmpty) {
            _csvData = rows.skip(1).toList();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('เกิดข้อผิดพลาดในการอ่านไฟล์: $e');
    }
  }

  // บันทึกข้อมูลลงฐานข้อมูล
  Future<void> _saveData() async {
    if (_csvData.isEmpty) return;

    setState(() => _isLoading = true);
    _successCount = 0;
    _failCount = 0;

    for (var row in _csvData) {
      try {
        // Mapping (0-based index):
        // 0: Member Code, 1: Title, 2: FirstName, 3: LastName, 4: Phone
        // 5: CardID, 6: Email, 7: DOB, 8: Expiry, 9: TaxID
        // 10: Address, 11: Remarks, 12: Points, 13: Debt, 14: TotalSpending

        String getValue(int index) => (index < row.length && row[index] != null)
            ? row[index].toString().trim()
            : '';

        double getDouble(int index) {
          final val = getValue(index).replaceAll(',', '');
          return double.tryParse(val) ?? 0.0;
        }

        int getInt(int index) {
          final val = getValue(index).replaceAll(',', '');
          return double.tryParse(val)?.toInt() ?? 0;
        }

        DateTime? getDate(int index) {
          final str = getValue(index);
          if (str.isEmpty) return null;
          try {
            return DateTime.parse(str);
          } catch (_) {
            return null;
          }
        }

        String code = getValue(0);
        String title = getValue(1);
        String firstName = getValue(2);
        String lastName = getValue(3);
        String phone = getValue(4);
        String nationalId = getValue(5);
        String email = getValue(6);
        DateTime? dob = getDate(7);
        DateTime? expiry = getDate(8);
        String taxId = getValue(9);
        String address = getValue(10);
        String remarks = getValue(11);
        int points = getInt(12);
        double debt = getDouble(13);
        double spending = getDouble(14);

        // 1. Auto-Generate Member Code if empty
        if (code.isEmpty) {
          // Format: MB-TimestampRandom (e.g. MB-17012345)
          final rnd = Random().nextInt(9999);
          final stamp = DateTime.now().millisecondsSinceEpoch % 1000000;
          code = 'MB-$stamp$rnd';
        }

        // 2. Extract Phone from FirstName if Phone is empty
        // Scenario: Name contains "Uncle Jazz 0812345678"
        if (phone.isEmpty) {
          final phoneRegExp = RegExp(r'0[0-9]{8,9}');
          final match = phoneRegExp.firstMatch(firstName);
          if (match != null) {
            phone = match.group(0)!;
            // Remove phone from name
            firstName = firstName.replaceAll(phone, '').trim();
          }
        }

        // Also check LastName for phone just in case
        if (phone.isEmpty) {
          final phoneRegExp = RegExp(r'0[0-9]{8,9}');
          final match = phoneRegExp.firstMatch(lastName);
          if (match != null) {
            phone = match.group(0)!;
            lastName = lastName.replaceAll(phone, '').trim();
          }
        }

        // 3. Handle Single Name field (Split to Last Name if needed)
        if (lastName.isEmpty && firstName.contains(' ')) {
          final parts = firstName.split(' ');
          // Verify if the second part is not just a leftover single char
          if (parts.length > 1) {
            firstName = parts[0];
            lastName = parts.sublist(1).join(' ').trim();
          }
        }

        final newCustomer = Customer(
          id: 0,
          memberCode: code,
          title: title.isNotEmpty ? title : null,
          firstName: firstName,
          lastName: lastName.isNotEmpty ? lastName : null,
          phone: phone,
          nationalId: nationalId.isNotEmpty ? nationalId : null,
          email: email.isNotEmpty ? email : null,
          dateOfBirth: dob,
          membershipExpiryDate: expiry,
          taxId: taxId.isNotEmpty ? taxId : null,
          address: address, // Ensure address is passed
          remarks: remarks.isNotEmpty ? remarks : null,
          currentPoints: points,
          currentDebt: debt,
          totalSpending: spending,
        );

        final success = await _customerRepo.saveCustomer(newCustomer);
        if (success) {
          _successCount++;
        } else {
          _failCount++;
        }
      } catch (e) {
        debugPrint('Error importing row: $row -> $e');
        _failCount++;
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _csvData = [];
      });
    }

    if (!mounted) return; // Fix: Check mounted before dialog
    _showResultDialog();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('สรุปผลการนำเข้า'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('สำเร็จ: $_successCount รายการ',
                style: const TextStyle(
                    color: Colors.green,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text('ล้มเหลว: $_failCount รายการ',
                style: const TextStyle(color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('ตกลง'),
          )
        ],
      ),
    );
  }

  Future<void> _exportTemplate() async {
    try {
      // Create Header Row
      List<String> headers = [
        'รหัสสมาชิก (Code)',
        'คำนำหน้า (Title)',
        'ชื่อ (First Name)',
        'นามสกุล (Last Name)',
        'เบอร์โทร (Phone)',
        'เลขบัตรปชช (National ID)',
        'อีเมล (Email)',
        'วันเกิด (DOB yyyy-mm-dd)',
        'วันหมดอายุ (Expiry yyyy-mm-dd)',
        'เลขผู้เสียภาษี (Tax ID)',
        'ที่อยู่ (Address)',
        'หมายเหตุ (Remarks)',
        'คะแนนสะสม (Points)',
        'หนี้คงค้าง (Debt)',
        'ยอดซื้อรวม (Total Spending)'
      ];

      // Convert to CSV
      List<List<dynamic>> rows = [headers];
      String csvContent = const ListToCsvConverter().convert(rows);

      // Add UTF-8 BOM for Excel compatibility with Thai text
      final bytes = utf8.encode('\uFEFF$csvContent');

      // Save file
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'บันทึกไฟล์ Template (CSV)',
        fileName: 'customer_import_template.csv',
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
                  'บันทึก Template (.csv) สำเร็จ! แนะนำให้เปิดด้วย Excel แก้ไขแล้วบันทึกกลับเป็น CSV'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('นำเข้ารายชื่อลูกค้า (Import CSV)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'ดาวน์โหลด Template',
            onPressed: _exportTemplate,
          ),
        ],
      ),
      body: Column(
        children: [
          // ส่วนควบคุมด้านบน
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('เลือกไฟล์ CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                if (_csvData.isNotEmpty)
                  Expanded(
                    child: Text(
                      'พบข้อมูล ${_csvData.length} รายการ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                if (_csvData.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveData,
                    icon: const Icon(Icons.save_alt),
                    label: const Text('ยืนยันการนำเข้า'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),

          // ตารางแสดงผลตัวอย่าง (Preview Table)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _csvData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description_outlined,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text(
                                'กรุณาเลือกไฟล์ .csv (UTF-8) เพื่อนำเข้าข้อมูล',
                                style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 8),
                            const Text(
                                'Columns: Code, Title, Name, Surname, Phone, ..., Address, ...',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor:
                                WidgetStateProperty.all(Colors.grey.shade200),
                            columns: const [
                              DataColumn(label: Text('รหัสสมาชิก')),
                              DataColumn(label: Text('ชื่อ-นามสกุล')),
                              DataColumn(label: Text('เบอร์โทร')),
                              DataColumn(label: Text('ที่อยู่')),
                            ],
                            rows: _csvData.take(50).map((row) {
                              String getValue(int index) =>
                                  (index < row.length && row[index] != null)
                                      ? row[index].toString()
                                      : '';

                              // Corrected Indices for Preview
                              String code = getValue(0);
                              String name = getValue(2); // First Name
                              String surname = getValue(3); // Last Name
                              String phone = getValue(4); // Phone
                              String addr = getValue(10); // Address

                              // Mimic cleaning logic for preview
                              if (phone.isEmpty) {
                                final phoneRegExp = RegExp(r'0[0-9]{8,9}');
                                final match = phoneRegExp.firstMatch(name);
                                if (match != null) {
                                  phone = match.group(0)!;
                                  name = name.replaceAll(phone, '').trim();
                                }
                              }

                              if (code.isEmpty) code = '(Auto)';

                              return DataRow(cells: [
                                DataCell(Text(code,
                                    style:
                                        const TextStyle(color: Colors.blue))),
                                DataCell(Text('$name $surname'.trim())),
                                DataCell(Text(phone)),
                                DataCell(SizedBox(
                                    width: 250,
                                    child: Text(addr,
                                        overflow: TextOverflow.ellipsis))),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
