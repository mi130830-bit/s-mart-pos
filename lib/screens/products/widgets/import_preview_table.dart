import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/product_import_controller.dart';

class ImportPreviewTable extends ConsumerWidget {
  const ImportPreviewTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productImportProvider);
    final dataRows = state.dataRows;

    return Container(
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
                'ตัวอย่างข้อมูล (${dataRows.length} รายการ)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(Colors.grey.shade50),
                    columns: const [
                      DataColumn(label: Text('บาร์โค้ด')),
                      DataColumn(label: Text('ชื่อสินค้า')),
                      DataColumn(label: Text('หมวดหมู่/ประเภท')),
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
                    rows: dataRows.take(100).map((row) {
                      String val(int i) =>
                          row.length > i ? row[i].toString() : '';
                      return DataRow(
                        cells: [
                          DataCell(Text(val(0))),
                          DataCell(Text(
                            val(1),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )),
                          DataCell(Text(val(2))),
                          DataCell(Text(val(3))),
                          DataCell(Text(val(4))),
                          DataCell(Text(val(5))),
                          DataCell(Text(val(6))),
                          DataCell(Text(val(7))),
                          DataCell(Text(val(8))),
                          DataCell(Text(val(9))),
                          DataCell(Text(val(10))),
                          DataCell(Text(val(11))),
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
