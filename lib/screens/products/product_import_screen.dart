import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/alert_service.dart';
import '../../widgets/common/custom_buttons.dart';
import 'controllers/product_import_controller.dart';
import 'widgets/import_preview_table.dart';

class ProductImportScreen extends ConsumerStatefulWidget {
  const ProductImportScreen({super.key});

  @override
  ConsumerState<ProductImportScreen> createState() =>
      _ProductImportScreenState();
}

class _ProductImportScreenState
    extends ConsumerState<ProductImportScreen> {
  // Colors
  final Color _primaryColor = Colors.indigo;
  final Color _successColor = Colors.teal;

  void _showResultDialog(ProductImportState state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('ผลการนำเข้า'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildResultTile('สำเร็จ', '${state.successCount}', Colors.green),
            const Divider(),
            _buildResultTile('ล้มเหลว', '${state.failCount}', Colors.red),
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
    final state = ref.watch(productImportProvider);
    final controller = ref.read(productImportProvider.notifier);

    // Listen for errors
    ref.listen<ProductImportState>(productImportProvider, (prev, next) {
      if (next.errorMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            AlertService.show(
                context: context,
                message: next.errorMessage!,
                type: 'error');
            controller.clearError();
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('นำเข้าสินค้า (Import Products)'),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'ดาวน์โหลด Template',
            onPressed: () async {
              final result = await controller.exportTemplate();
              if (result != null && context.mounted) {
                AlertService.show(
                  context: context,
                  message:
                      'บันทึก Template (.csv) สำเร็จ! แนะนำให้เปิดและแก้ไขแล้วบันทึกกลับมาเป็น CSV เหมือนเดิม',
                  type: 'success',
                );
              }
            },
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
                        onPressed: state.isLoading
                            ? null
                            : () => controller.pickFile(),
                        icon: Icons.file_upload_outlined,
                        label: 'เลือกไฟล์ Excel/CSV',
                        type: ButtonType.secondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomButton(
                        onPressed: (state.isLoading ||
                                state.dataRows.isEmpty)
                            ? null
                            : () async {
                                final done = await controller.saveProducts();
                                if (done && mounted) {
                                  _showResultDialog(ref.read(productImportProvider));
                                }
                              },
                        icon: Icons.save_as_outlined,
                        label: 'ยืนยันนำเข้าข้อมูล',
                        backgroundColor: _successColor,
                        type: ButtonType.primary,
                      ),
                    ),
                  ],
                ),
                if (state.isLoading || state.dataRows.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(state.statusMessage,
                          style: TextStyle(
                              color: _primaryColor,
                              fontWeight: FontWeight.w600)),
                      if (state.isLoading)
                        Text(
                            '${(state.progressValue * 100).toInt()}%',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: state.progressValue,
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
            child: state.dataRows.isEmpty && !state.isLoading
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
                : state.isLoading && state.dataRows.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : const ImportPreviewTable(),
          ),
        ],
      ),
    );
  }
}
