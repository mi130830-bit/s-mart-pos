import 'package:flutter/material.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../models/barcode_template.dart';
import '../../services/printing/barcode_print_service.dart';
import 'barcode_designer_screen.dart';
import '../../widgets/custom_radio_group.dart';

class BarcodePrintSetupScreen extends StatefulWidget {
  final BarcodeTemplate? template;

  const BarcodePrintSetupScreen({super.key, this.template});

  @override
  State<BarcodePrintSetupScreen> createState() =>
      _BarcodePrintSetupScreenState();
}

class _BarcodePrintSetupScreenState extends State<BarcodePrintSetupScreen> {
  final _service = BarcodePrintService();
  late BarcodeTemplate _template;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _paperWidthCtrl = TextEditingController();
  final TextEditingController _paperHeightCtrl = TextEditingController();
  final TextEditingController _rowsCtrl = TextEditingController();
  final TextEditingController _colsCtrl = TextEditingController();
  final TextEditingController _marginTopCtrl = TextEditingController();
  final TextEditingController _marginBottomCtrl = TextEditingController();
  final TextEditingController _marginLeftCtrl = TextEditingController();
  final TextEditingController _marginRightCtrl = TextEditingController();
  final TextEditingController _labelWidthCtrl = TextEditingController();
  final TextEditingController _labelHeightCtrl = TextEditingController();
  final TextEditingController _hGapCtrl = TextEditingController();
  final TextEditingController _vGapCtrl = TextEditingController();
  final TextEditingController _borderWidthCtrl = TextEditingController();

  bool _isRound = true;
  bool _printBorder = false;
  bool _printDebug = false;
  bool _autoGap = false; // ✅

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _template = widget.template!;
    } else {
      _template = _service.createBarcode406x108();
    }
    _initControllers();
  }

  void _initControllers() {
    _nameCtrl.text = _template.name;
    _paperWidthCtrl.text = _template.paperWidth.toString();
    _paperHeightCtrl.text = _template.paperHeight.toString();
    _rowsCtrl.text = _template.rows.toString();
    _colsCtrl.text = _template.columns.toString();
    _marginTopCtrl.text = _template.marginTop.toString();
    _marginBottomCtrl.text = _template.marginBottom.toString();
    _marginLeftCtrl.text = _template.marginLeft.toString();
    _marginRightCtrl.text = _template.marginRight.toString();
    _labelWidthCtrl.text = _template.labelWidth.toString();
    _labelHeightCtrl.text = _template.labelHeight.toString();
    _hGapCtrl.text = _template.horizontalGap.toString();
    _vGapCtrl.text = _template.verticalGap.toString();
    _borderWidthCtrl.text = _template.borderWidth.toString();
    _isRound = _template.shape == 'rounded';
    _printBorder = _template.printBorder;
    _printDebug = _template.printDebug; // ✅
  }

  void _updateTemplateFromUI() {
    _template.name = _nameCtrl.text;
    _template.paperWidth = double.tryParse(_paperWidthCtrl.text) ?? 100;
    _template.paperHeight = double.tryParse(_paperHeightCtrl.text) ?? 30;
    _template.rows = int.tryParse(_rowsCtrl.text) ?? 1;
    _template.columns = int.tryParse(_colsCtrl.text) ?? 3;
    _template.marginTop = double.tryParse(_marginTopCtrl.text) ?? 0;
    _template.marginBottom = double.tryParse(_marginBottomCtrl.text) ?? 0;
    _template.marginLeft = double.tryParse(_marginLeftCtrl.text) ?? 0;
    _template.marginRight = double.tryParse(_marginRightCtrl.text) ?? 0;
    _template.labelWidth = double.tryParse(_labelWidthCtrl.text) ?? 32;
    _template.labelHeight = double.tryParse(_labelHeightCtrl.text) ?? 25;
    _template.horizontalGap = double.tryParse(_hGapCtrl.text) ?? 2;
    _template.verticalGap = double.tryParse(_vGapCtrl.text) ?? 0;
    _template.borderWidth = double.tryParse(_borderWidthCtrl.text) ?? 1;
    _template.shape = _isRound ? 'rounded' : 'rectangle';
    _template.printBorder = _printBorder;
    _template.printDebug = _printDebug; // ✅
  }

  @override
  Widget build(BuildContext context) {
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
                          _buildField('ชื่อแม่แบบ', _nameCtrl),
                          const SizedBox(height: 16),
                          const Text('ขนาดกระดาษ',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              _buildInlineField(
                                  'ความกว้าง', _paperWidthCtrl, 'มม'),
                              const SizedBox(width: 8),
                              _buildInlineField(
                                  'ความสูง', _paperHeightCtrl, 'มม'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('เค้าโครง',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              _buildInlineField('แถว', _rowsCtrl, ''),
                              const SizedBox(width: 8),
                              _buildInlineField('คอลัมน์', _colsCtrl, ''),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('ขอบกระดาษ',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              _buildInlineField('บน', _marginTopCtrl, 'มม'),
                              const SizedBox(width: 8),
                              _buildInlineField('ซ้าย', _marginLeftCtrl, 'มม'),
                            ],
                          ),
                          Row(
                            children: [
                              _buildInlineField(
                                  'ล่าง', _marginBottomCtrl, 'มม'),
                              const SizedBox(width: 8),
                              _buildInlineField('ขวา', _marginRightCtrl, 'มม'),
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
                                  _updateTemplateFromUI();
                                  final result =
                                      await showDialog<BarcodeTemplate>(
                                    context: context,
                                    builder: (ctx) => BarcodeDesignerScreen(
                                      template: _template,
                                    ),
                                  );
                                  if (result != null) {
                                    setState(() {
                                      _template = result;
                                    });
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
                              _buildInlineField('กว้าง', _labelWidthCtrl, 'มม'),
                              const SizedBox(width: 8),
                              _buildInlineField('สูง', _labelHeightCtrl, 'มม'),
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
                                value: _autoGap,
                                onChanged: (v) {
                                  setState(() {
                                    _autoGap = v!;
                                    if (_autoGap) _autoCalculateGaps();
                                  });
                                },
                              ),
                              const Text('อัตโนมัติ',
                                  style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 8),
                              CustomButton(
                                onPressed: () {
                                  setState(() {
                                    _autoCalculateGaps();
                                  });
                                },
                                icon: Icons.calculate,
                                label: 'คำนวณ',
                                type: ButtonType.secondary,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildInlineField('แนวนอน', _hGapCtrl, 'มม',
                                  enabled: !_autoGap),
                              const SizedBox(width: 8),
                              _buildInlineField('แนวตั้ง', _vGapCtrl, 'มม',
                                  enabled: !_autoGap),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('รูปทรง',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          CustomRadioGroup<bool>(
                            groupValue: _isRound,
                            onChanged: (v) => setState(() => _isRound = v!),
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
                            groupValue: _template.orientation,
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _template.orientation = v);
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
                                value: _printBorder,
                                onChanged: (v) =>
                                    setState(() => _printBorder = v!),
                              ),
                              const Text('พิมพ์เส้นขอบ'),
                              const SizedBox(width: 16),
                              _buildInlineField(
                                  'ขนาดเส้น', _borderWidthCtrl, 'มม'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('โหมดทดสอบ (Debug)',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              Checkbox(
                                value: _printDebug,
                                onChanged: (v) =>
                                    setState(() => _printDebug = v!),
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
                          child: _buildPreview(),
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
                      _updateTemplateFromUI();
                      await _service.saveTemplate(_template);
                      if (!context.mounted) return;
                      Navigator.pop(context, _template);
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
      String label, TextEditingController ctrl, String suffix,
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
              onChanged: (_) {
                if (_autoGap) {
                  _autoCalculateGaps();
                }
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  void _autoCalculateGaps() {
    double pw = double.tryParse(_paperWidthCtrl.text) ?? 100;
    double ph = double.tryParse(_paperHeightCtrl.text) ?? 30;
    int rows = int.tryParse(_rowsCtrl.text) ?? 1;
    int cols = int.tryParse(_colsCtrl.text) ?? 3;
    double mt = double.tryParse(_marginTopCtrl.text) ?? 0;
    double mb = double.tryParse(_marginBottomCtrl.text) ?? 0;
    double ml = double.tryParse(_marginLeftCtrl.text) ?? 0;
    double mr = double.tryParse(_marginRightCtrl.text) ?? 0;
    double lw = double.tryParse(_labelWidthCtrl.text) ?? 32;
    double lh = double.tryParse(_labelHeightCtrl.text) ?? 25;

    // Horizontal Gap
    if (cols > 1) {
      double availableW = pw - ml - mr;
      double totalLabelsW = lw * cols;
      double hGap = (availableW - totalLabelsW) / (cols - 1);
      if (hGap < 0) hGap = 0;
      _hGapCtrl.text = hGap.toStringAsFixed(2);
    } else {
      _hGapCtrl.text = '0';
    }

    // Vertical Gap
    if (rows > 1) {
      double availableH = ph - mt - mb;
      double totalLabelsH = lh * rows;
      double vGap = (availableH - totalLabelsH) / (rows - 1);
      if (vGap < 0) vGap = 0;
      _vGapCtrl.text = vGap.toStringAsFixed(2);
    } else {
      _vGapCtrl.text = '0';
    }
  }

  Widget _buildPreview() {
    double lw = double.tryParse(_labelWidthCtrl.text) ?? 32;
    double lh = double.tryParse(_labelHeightCtrl.text) ?? 25;
    int cols = int.tryParse(_colsCtrl.text) ?? 3;
    int rows = int.tryParse(_rowsCtrl.text) ?? 1;
    double hGap = double.tryParse(_hGapCtrl.text) ?? 2;
    double vGap = double.tryParse(_vGapCtrl.text) ?? 0;
    double paperWidthVal = double.tryParse(_paperWidthCtrl.text) ?? 100;
    double paperHeightVal = double.tryParse(_paperHeightCtrl.text) ?? 30;

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
                left: (double.tryParse(_marginLeftCtrl.text) ?? 0) * scale,
                top: (double.tryParse(_marginTopCtrl.text) ?? 0) * scale,
                right: (double.tryParse(_marginRightCtrl.text) ?? 0) * scale,
                bottom: (double.tryParse(_marginBottomCtrl.text) ?? 0) * scale,
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
                left: (double.tryParse(_marginLeftCtrl.text) ?? 0) * scale,
                top: (double.tryParse(_marginTopCtrl.text) ?? 0) * scale,
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
                                    borderRadius: _isRound
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
