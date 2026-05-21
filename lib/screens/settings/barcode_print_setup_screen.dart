import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../models/barcode_template.dart';
import '../../services/printing/barcode_print_service.dart';
import 'barcode_designer_screen.dart';
import '../../widgets/custom_radio_group.dart';
import 'controllers/barcode_print_setup_controller.dart';

class BarcodePrintSetupScreen extends ConsumerStatefulWidget {
  final BarcodeTemplate? template;

  const BarcodePrintSetupScreen({super.key, this.template});

  @override
  ConsumerState<BarcodePrintSetupScreen> createState() => _BarcodePrintSetupScreenState();
}

class _BarcodePrintSetupScreenState extends ConsumerState<BarcodePrintSetupScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final service = BarcodePrintService();
      ref.read(barcodePrintSetupProvider.notifier).init(widget.template, service);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(barcodePrintSetupProvider);
    final controller = ref.read(barcodePrintSetupProvider.notifier);

    // Initial state handling
    if (state.template == null) {
      return const Dialog(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(40),
      child: Container(
        width: 1000,
        height: 800,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('สร้างบาร์โค้ดสินค้า',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side: Settings
                  SizedBox(
                    width: 400,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildField('ชื่อแม่แบบ', controller.nameCtrl),
                          const SizedBox(height: 16),
                          const Text('ขนาดกระดาษ',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              _buildInlineField(
                                  controller, 'ความกว้าง', controller.paperWidthCtrl, 'มม'),
                              const SizedBox(width: 8),
                              _buildInlineField(
                                  controller, 'ความสูง', controller.paperHeightCtrl, 'มม'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('เค้าโครง',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              _buildInlineField(controller, 'แถว', controller.rowsCtrl, ''),
                              const SizedBox(width: 8),
                              _buildInlineField(controller, 'คอลัมน์', controller.colsCtrl, ''),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('ขอบกระดาษ',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              _buildInlineField(controller, 'บน', controller.marginTopCtrl, 'มม'),
                              const SizedBox(width: 8),
                              _buildInlineField(controller, 'ซ้าย', controller.marginLeftCtrl, 'มม'),
                            ],
                          ),
                          Row(
                            children: [
                              _buildInlineField(
                                  controller, 'ล่าง', controller.marginBottomCtrl, 'มม'),
                              const SizedBox(width: 8),
                              _buildInlineField(controller, 'ขวา', controller.marginRightCtrl, 'มม'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('ขนาดแม่แบบ',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              ElevatedButton(
                                onPressed: () async {
                                  controller.updateTemplateFromUI();
                                  if (state.template == null) return;
                                  
                                  final result =
                                      await showDialog<BarcodeTemplate>(
                                    context: context,
                                    builder: (ctx) => BarcodeDesignerScreen(
                                      template: state.template!,
                                    ),
                                  );
                                  if (result != null) {
                                    controller.updateTemplate(result);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('ออกแบบบาร์โค้ดเอง'),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildInlineField(controller, 'กว้าง', controller.labelWidthCtrl, 'มม'),
                              const SizedBox(width: 8),
                              _buildInlineField(controller, 'สูง', controller.labelHeightCtrl, 'มม'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('ช่องว่าง',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Checkbox(
                                value: state.autoGap,
                                onChanged: (v) {
                                  controller.setAutoGap(v ?? false);
                                },
                              ),
                              const Text('อัตโนมัติ',
                                  style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 8),
                              CustomButton(
                                onPressed: () {
                                  controller.autoCalculateGaps();
                                },
                                icon: Icons.calculate,
                                label: 'คำนวณ',
                                type: ButtonType.secondary,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildInlineField(controller, 'แนวนอน', controller.hGapCtrl, 'มม',
                                  enabled: !state.autoGap),
                              const SizedBox(width: 8),
                              _buildInlineField(controller, 'แนวตั้ง', controller.vGapCtrl, 'มม',
                                  enabled: !state.autoGap),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('รูปทรง',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          CustomRadioGroup<bool>(
                            groupValue: state.isRound,
                            onChanged: (v) => controller.setTemplateShape(v ?? true),
                            child: Row(
                              children: [
                                Radio<bool>(
                                  value: false,
                                ),
                                const Text('สี่เหลี่ยมผืนผ้า'),
                                const SizedBox(width: 16),
                                Radio<bool>(
                                  value: true,
                                ),
                                const Text('สี่เหลี่ยมขอบมน'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('การวางแนว (Orientation)',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          CustomRadioGroup<String>(
                            groupValue: state.template?.orientation ?? 'landscape',
                            onChanged: (v) {
                              if (v != null) {
                                controller.setOrientation(v);
                              }
                            },
                            child: Row(
                              children: [
                                const Radio<String>(
                                  value: 'landscape',
                                ),
                                const Text('แนวนอน (Landscape)'),
                                const SizedBox(width: 16),
                                const Radio<String>(
                                  value: 'portrait',
                                ),
                                const Text('แนวตั้ง (Portrait)'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('พิมพ์เส้นขอบ',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              Checkbox(
                                value: state.printBorder,
                                onChanged: (v) =>
                                    controller.setPrintBorder(v ?? false),
                              ),
                              const Text('พิมพ์เส้นขอบ'),
                              const SizedBox(width: 16),
                              _buildInlineField(
                                  controller, 'ขนาดเส้น', controller.borderWidthCtrl, 'มม'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('โหมดทดสอบ (Debug)',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              Checkbox(
                                value: state.printDebug,
                                onChanged: (v) =>
                                    controller.setPrintDebug(v ?? false),
                              ),
                              const Expanded(
                                child: Text(
                                    'วาดเส้นขอบแดงรอบพื้นที่พิมพ์\n(ถ้าพิมพ์แล้วขาด แปลว่าพื้นที่นั้นพิมพ์ไม่ได้)',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Right Side: Preview
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Center(
                        child: SingleChildScrollView(
                          child: _buildPreview(controller, state),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 45,
                  child: CustomButton(
                    onPressed: () async {
                      controller.updateTemplateFromUI();
                      if (state.template != null) {
                        final service = BarcodePrintService();
                        await service.saveTemplate(state.template!);
                        if (!context.mounted) return;
                        Navigator.pop(context, state.template);
                      }
                    },
                    icon: Icons.check,
                    label: 'บันทึก',
                    type: ButtonType.primary,
                    backgroundColor: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 150,
                  height: 45,
                  child: CustomButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icons.close,
                    label: 'ยกเลิก',
                    type: ButtonType.secondary,
                    backgroundColor: Colors.blueGrey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        CustomTextField(
          controller: ctrl,
          label: label,
          filled: true,
          fillColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildInlineField(
      BarcodePrintSetupController controller, String label, TextEditingController ctrl, String suffix,
      {bool enabled = true}) {
    return Expanded(
      child: Row(
        children: [
          SizedBox(
              width: 70,
              child: Text(label, style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 4),
          Expanded(
            child: CustomTextField(
              controller: ctrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              readOnly: !enabled,
              label: label,
              filled: true,
              fillColor: enabled ? Colors.white : Colors.grey[200],
              onChanged: (_) => controller.onFieldChanged(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BarcodePrintSetupController controller, BarcodePrintSetupState state) {
    double lw = double.tryParse(controller.labelWidthCtrl.text) ?? 32;
    double lh = double.tryParse(controller.labelHeightCtrl.text) ?? 25;
    int cols = int.tryParse(controller.colsCtrl.text) ?? 3;
    int rows = int.tryParse(controller.rowsCtrl.text) ?? 1;
    double hGap = double.tryParse(controller.hGapCtrl.text) ?? 2;
    double vGap = double.tryParse(controller.vGapCtrl.text) ?? 0;
    double paperWidthVal = double.tryParse(controller.paperWidthCtrl.text) ?? 100;
    double paperHeightVal = double.tryParse(controller.paperHeightCtrl.text) ?? 30;

    // Scale for display (limited to fit within reasonable bounds)
    double maxPreviewWidth = 450.0;
    double maxPreviewHeight = 500.0;

    double scaleX = maxPreviewWidth / (paperWidthVal > 0 ? paperWidthVal : 100);
    double scaleY =
        maxPreviewHeight / (paperHeightVal > 0 ? paperHeightVal : 30);

    // Use the smaller scale to ensure it fits in both dimensions
    double scale = (scaleX < scaleY) ? scaleX : scaleY;

    // Keep scale reasonable
    if (scale > 10.0) scale = 10.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: paperWidthVal * scale,
          height: paperHeightVal * scale,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.blue.shade200, width: 2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)
            ],
          ),
          child: Stack(
            children: [
              // Margins visualization (Subtle)
              Positioned(
                left: (double.tryParse(controller.marginLeftCtrl.text) ?? 0) * scale,
                top: (double.tryParse(controller.marginTopCtrl.text) ?? 0) * scale,
                right: (double.tryParse(controller.marginRightCtrl.text) ?? 0) * scale,
                bottom: (double.tryParse(controller.marginBottomCtrl.text) ?? 0) * scale,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.1), width: 1),
                    color: Colors.blue.withValues(alpha: 0.02),
                  ),
                ),
              ),
              // Labels
              Positioned(
                left: (double.tryParse(controller.marginLeftCtrl.text) ?? 0) * scale,
                top: (double.tryParse(controller.marginTopCtrl.text) ?? 0) * scale,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(rows, (rIndex) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(cols, (cIndex) {
                            return Row(
                              children: [
                                Container(
                                  width: lw * scale,
                                  height: lh * scale,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border:
                                        Border.all(color: Colors.grey[400]!),
                                    borderRadius: state.isRound
                                        ? BorderRadius.circular(
                                            lw * scale * 0.15)
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${(rIndex * cols) + cIndex + 1}',
                                      style: TextStyle(
                                          fontSize: 8, color: Colors.grey[400]),
                                    ),
                                  ),
                                ),
                                if (cIndex < cols - 1)
                                  SizedBox(width: hGap * scale),
                              ],
                            );
                          }),
                        ),
                        if (rIndex < rows - 1) SizedBox(height: vGap * scale),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ภาพตัวอย่าง (${paperWidthVal.toStringAsFixed(0)} x ${paperHeightVal.toStringAsFixed(0)} มม)',
          style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
        ),
      ],
    );
  }
}
