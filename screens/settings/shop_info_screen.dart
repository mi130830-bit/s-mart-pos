import 'package:flutter/material.dart';

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../services/settings_service.dart';
import '../../services/alert_service.dart';
import 'package:provider/provider.dart';
import '../pos/pos_state_manager.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';

class ShopInfoScreen extends StatefulWidget {
  const ShopInfoScreen({super.key});

  @override
  State<ShopInfoScreen> createState() => _ShopInfoScreenState();
}

class _ShopInfoScreenState extends State<ShopInfoScreen> {
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _shopAddressController = TextEditingController();
  final TextEditingController _shopTaxIdController = TextEditingController();
  final TextEditingController _shopFooterController = TextEditingController();
  final TextEditingController _shopPromptPayController =
      TextEditingController();
  // 80mm Specific
  final TextEditingController _shopName80mmController = TextEditingController();
  final TextEditingController _shopAddress80mmController =
      TextEditingController();
  final TextEditingController _shopPhoneController = TextEditingController();

  String? _logoPath; // For holding the logo path
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = SettingsService();
    // Assuming settings are initialized
    if (!mounted) return;
    setState(() {
      _shopNameController.text = settings.shopName;
      _shopAddressController.text = settings.shopAddress;
      _shopTaxIdController.text = settings.shopTaxId;
      _shopFooterController.text = settings.shopFooter;
      _shopPromptPayController.text = settings.promptPayId;

      _shopName80mmController.text = settings.shopShortName;
      _shopAddress80mmController.text = settings.shopShortAddress;
      _shopPhoneController.text = settings.shopPhone;
      _logoPath = settings.shopLogoPath;

      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final settings = SettingsService();

    await settings.set('shop_name', _shopNameController.text);
    await settings.set('shop_address', _shopAddressController.text);
    await settings.set('shop_phone', _shopPhoneController.text);
    await settings.set('shop_tax_id', _shopTaxIdController.text);
    await settings.set('shop_footer', _shopFooterController.text);
    await settings.set('promptpay_id', _shopPromptPayController.text);

    await settings.set('shop_short_name', _shopName80mmController.text);
    await settings.set('shop_short_address', _shopAddress80mmController.text);

    if (_logoPath != null) {
      await settings.set('shop_logo_path', _logoPath!);
    }

    if (mounted) {
      // Refresh provider if needed (though SettingsService handles memory cache)
      context.read<PosStateManager>().refreshGeneralSettings();
    }

    if (!mounted) return;
    AlertService.show(
      context: context,
      message: 'บันทึกข้อมูลร้านค้าเรียบร้อย (Saved Globally)',
      type: 'success',
    );
  }

  Future<void> _pickLogo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _logoPath = result.files.single.path!;
        });
      }
    } catch (e) {
      debugPrint('Error picking logo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ข้อมูลร้านค้า (Shop Profile)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'บันทึก',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickLogo,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[200],
                          backgroundImage:
                              _logoPath != null && _logoPath!.isNotEmpty
                                  ? FileImage(File(_logoPath!))
                                  : null,
                          child: _logoPath == null || _logoPath!.isEmpty
                              ? const Icon(Icons.add_a_photo,
                                  size: 30, color: Colors.grey)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                          onPressed: _pickLogo,
                          child: const Text('เปลี่ยนโลโก้ร้าน')),
                      const SizedBox(height: 20),
                      CustomTextField(
                        controller: _shopNameController,
                        label: 'ชื่อร้านค้า (Shop Name)',
                        prefixIcon: Icons.branding_watermark,
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        controller: _shopAddressController,
                        maxLines: 3,
                        label: 'ที่อยู่ร้านค้า (Address)',
                        prefixIcon: Icons.location_on,
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        controller: _shopTaxIdController,
                        keyboardType: TextInputType.number,
                        label: 'เลขประจำตัวผู้เสียภาษี (Tax ID)',
                        prefixIcon: Icons.confirmation_number,
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        controller: _shopFooterController,
                        label: 'ข้อความท้ายบิล (Footer Message)',
                        prefixIcon: Icons.message,
                        hint: 'เช่น ขอบคุณที่ใช้บริการ, สินค้ารับประกัน 7 วัน',
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        controller: _shopPhoneController,
                        label: 'เบอร์โทรศัพท์ร้าน (Shop Phone)',
                        prefixIcon: Icons.phone,
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        controller: _shopPromptPayController,
                        keyboardType: TextInputType.number,
                        label: 'เบอร์พร้อมเพย์ (PromptPay ID)',
                        prefixIcon: Icons.qr_code,
                        hint: 'เบอร์โทรศัพท์ หรือ เลขบัตรประชาชน',
                      ),
                      const SizedBox(height: 30),
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'สำหรับใบเสร็จอย่างย่อ 80mm (For 80mm Slip)',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal),
                        ),
                      ),
                      CustomTextField(
                        controller: _shopName80mmController,
                        label: 'ชื่อร้าน (80mm) - สั้นๆ',
                        prefixIcon: Icons.receipt,
                        hint: 'ใช้ชื่อปกติถ้าไม่ระบุ',
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        controller: _shopAddress80mmController,
                        maxLines: 2,
                        label: 'ที่อยู่ (80mm) - กระชับ',
                        prefixIcon: Icons.location_on_outlined,
                        hint: 'ใช้ที่อยู่ปกติถ้าไม่ระบุ',
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: CustomButton(
                          onPressed: _saveSettings,
                          icon: Icons.save,
                          label: 'บันทึกข้อมูล',
                          type: ButtonType.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
