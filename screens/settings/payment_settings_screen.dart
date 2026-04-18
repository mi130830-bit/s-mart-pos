import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../services/alert_service.dart';
import '../../utils/promptpay_helper.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final TextEditingController _promptPayIdController = TextEditingController();
  final TextEditingController _bankNameController =
      TextEditingController(); // Added
  final TextEditingController _bankAccNameController =
      TextEditingController(); // Added
  final TextEditingController _bankAccController =
      TextEditingController(); // Added
  final TextEditingController _qrAmountController = TextEditingController();

  String? _generatedPayload;
  bool _isLoading = true;

  // QR Settings
  String _qrMode = 'dynamic'; // 'dynamic' or 'static'
  String? _staticQrBase64;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = SettingsService();
    // Assuming settings initialized
    if (!mounted) return;
    setState(() {
      _promptPayIdController.text = settings.promptPayId;
      _bankNameController.text = settings.bankName; // Added
      _bankAccNameController.text = settings.bankAccountName; // Added
      _bankAccController.text = settings.bankAccount; // Added
      _qrMode = settings.getString('payment_qr_mode') ?? 'dynamic';
      _staticQrBase64 = settings.getString('payment_qr_image_base64');
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final settings = SettingsService();

    await settings.set('promptpay_id', _promptPayIdController.text);
    await settings.set('bank_name', _bankNameController.text); // Added
    await settings.set(
        'bank_account_name', _bankAccNameController.text); // Added
    await settings.set('bank_account', _bankAccController.text); // Added
    await settings.set('payment_qr_mode', _qrMode);

    if (_staticQrBase64 != null) {
      await settings.set('payment_qr_image_base64', _staticQrBase64!);
    } else {
      await settings.remove('payment_qr_image_base64');
    }

    if (!mounted) return;

    AlertService.show(
      context: context,
      message: 'บันทึกการตั้งค่ารับเงินเรียบร้อย (Saved Globally)',
      type: 'success',
    );
  }

  Future<void> _pickQrImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        List<int> imageBytes = await file.readAsBytes();

        // ✅ บีบอัดรูปก่อน encode base64 เพื่อไม่ให้ขนาดเกิน MySQL limit
        final compressed = await _compressImage(Uint8List.fromList(imageBytes));
        final String base64Image = base64Encode(compressed);

        // แจ้งขนาดรูปให้ผู้ใช้ทราบ
        final originalKb = (imageBytes.length / 1024).round();
        final compressedKb = (compressed.length / 1024).round();
        debugPrint('🖼️ QR Image compressed: ${originalKb}KB → ${compressedKb}KB (base64: ${(base64Image.length / 1024).round()}KB)');

        setState(() {
          _staticQrBase64 = base64Image;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (!mounted) return;
      AlertService.show(
        context: context,
        message: 'เกิดข้อผิดพลาดในการเลือกรูป: $e',
        type: 'error',
      );
    }
  }

  /// บีบอัดรูปโดย decode แล้ว resize เป็น max 600x600 px แล้ว encode เป็น PNG
  /// (สำหรับ QR Code ที่เน้นความชัดเจนเสมอ - lossless PNG ดีความ QR ไม่แตกต่างจาก JPEG)
  Future<Uint8List> _compressImage(Uint8List bytes, {int maxSize = 600}) async {
    // 1. Decode original image
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image original = frame.image;

    // 2. คำนวณขนาดใหม่ที่ scale ไม่เกิน maxSize
    final int srcW = original.width;
    final int srcH = original.height;
    double scale = 1.0;
    if (srcW > maxSize || srcH > maxSize) {
      scale = maxSize / (srcW > srcH ? srcW : srcH).toDouble();
    }
    final int dstW = (srcW * scale).round();
    final int dstH = (srcH * scale).round();

    // 3. ใช้ PictureRecorder + Canvas สำหรับ resize
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      original,
      ui.Rect.fromLTWH(0, 0, srcW.toDouble(), srcH.toDouble()),
      ui.Rect.fromLTWH(0, 0, dstW.toDouble(), dstH.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    original.dispose();

    final ui.Image resized =
        await recorder.endRecording().toImage(dstW, dstH);

    // 4. Encode เป็น PNG เพื่อให้ QR Code ยังอ่านได้ (lossless)
    final ByteData? byteData =
        await resized.toByteData(format: ui.ImageByteFormat.png);
    resized.dispose();

    if (byteData == null) return bytes; // Fallback
    return byteData.buffer.asUint8List();
  }

  void _generateTestQR() {
    if (_promptPayIdController.text.isEmpty) {
      return;
    }

    double? amount = double.tryParse(_qrAmountController.text);
    setState(() {
      _generatedPayload = PromptPayHelper.generatePayload(
        _promptPayIdController.text.trim(),
        amount: amount,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('การรับเงิน (Payment Settings)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildPromptPaySection(),
                const SizedBox(height: 20),
                _buildQrModeSection(),
                const SizedBox(height: 20),
                _buildTestQrSection(),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: CustomButton(
                    onPressed: _saveSettings,
                    icon: Icons.save,
                    label: 'บันทึกการตั้งค่าทั้งหมด (Save All)',
                    type: ButtonType.primary,
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPromptPaySection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.qr_code_2, size: 40, color: Colors.green),
                SizedBox(width: 10),
                Text('PromptPay Setup (Dynamic Mode)',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 30),
            const Text(
                'ระบุเบอร์โทรศัพท์ (08x...) หรือ เลขบัตรประชาชน (13 หลัก) สำหรับสร้าง QR อัตโนมัติ'),
            const SizedBox(height: 10),
            CustomTextField(
              controller: _promptPayIdController,
              keyboardType: TextInputType.number,
              label: 'PromptPay ID',
              prefixIcon: Icons.account_balance_wallet,
              hint: 'เช่น 0812345678',
            ),
            const SizedBox(height: 20),
            const Divider(),
            const Text('ข้อมูลบัญชีธนาคาร (Manual Transfer)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            CustomTextField(
              controller: _bankNameController,
              label: 'ชื่อธนาคาร (Bank Name)',
              prefixIcon: Icons.account_balance,
              hint: 'เช่น กสิกรไทย (K-Bank)',
            ),
            const SizedBox(height: 10),
            CustomTextField(
              controller: _bankAccNameController,
              label: 'ชื่อบัญชี (Account Name)',
              prefixIcon: Icons.person,
              hint: 'เช่น บริษัท ส.บริการ จำกัด',
            ),
            const SizedBox(height: 10),
            CustomTextField(
              controller: _bankAccController,
              keyboardType: TextInputType.number,
              label: 'เลขที่บัญชี (Account No.)',
              prefixIcon: Icons.numbers,
              hint: 'เช่น 123-4-56789-0',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrModeSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.monitor, size: 40, color: Colors.blue),
                SizedBox(width: 10),
                Text('Customer Display QR Mode',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            _buildRadioOption(
              title: 'Dynamic (PromptPay Auto Gen)',
              subtitle:
                  'สร้าง QR Code ตามยอดเงินอัตโนมัติ (ต้องระบุ PromptPay ID ด้านบน)',
              value: 'dynamic',
            ),
            _buildRadioOption(
              title: 'Static (Uploaded Image)',
              subtitle: 'แสดงรูป QR Code คงที่ (เช่น รูปป้ายแม่มณี/K Shop)',
              value: 'static',
            ),
            if (_qrMode == 'static') ...[
              const Divider(),
              const Text('รูป QR Code ที่จะแสดงบนจอลูกค้า:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Center(
                child: Column(
                  children: [
                    if (_staticQrBase64 != null)
                      Image.memory(
                        base64Decode(_staticQrBase64!),
                        height: 200,
                        fit: BoxFit.contain,
                      )
                    else
                      Container(
                        height: 150,
                        width: 150,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported,
                            size: 50, color: Colors.grey),
                      ),
                    const SizedBox(height: 10),
                    CustomButton(
                      onPressed: _pickQrImage,
                      icon: Icons.upload_file,
                      label: 'อัปโหลดรูป QR Code',
                      type: ButtonType.primary,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTestQrSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('ทดสอบสร้าง QR Code (Dynamic Test)',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _qrAmountController,
                    label: 'ยอดเงิน (บาท)',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    suffixIcon: const Padding(
                        padding: EdgeInsets.all(12), child: Text('฿')),
                  ),
                ),
                const SizedBox(width: 10),
                CustomButton(
                  onPressed: _generateTestQR,
                  icon: Icons.qr_code,
                  label: 'ดูตัวอย่าง',
                  type: ButtonType.primary,
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_generatedPayload != null)
              Column(
                children: [
                  // This is just a test api for display within setting (optional)
                  // In real app usage we use QrImage package
                  // Local Offline QR Generation
                  QrImageView(
                    data: _generatedPayload!,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 5),
                  SelectableText('Payload: $_generatedPayload',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioOption({
    required String title,
    required String subtitle,
    required String value,
  }) {
    bool isSelected = _qrMode == value;
    return ListTile(
      title: Text(title,
          style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(subtitle),
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Colors.blue : Colors.grey,
      ),
      onTap: () => setState(() => _qrMode = value),
      contentPadding: EdgeInsets.zero,
    );
  }
}
