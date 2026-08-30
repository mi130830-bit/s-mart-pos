import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/theme_provider.dart';
import '../../screens/pos/pos_state_manager.dart'; // ✅ Added
import '../../services/customer_display_service.dart';
import '../../services/alert_service.dart';

class DisplaySettingsScreen extends ConsumerStatefulWidget {
  const DisplaySettingsScreen({super.key});

  @override
  ConsumerState<DisplaySettingsScreen> createState() => _DisplaySettingsScreenState();
}

class _DisplaySettingsScreenState extends ConsumerState<DisplaySettingsScreen> {
  bool _darkMode = false;
  bool _autoOpenDisplay = false;
  bool _isLoading = true;

  // LINE OA Settings
  final TextEditingController _lineOaUrlCtrl = TextEditingController();
  final TextEditingController _lineOaIdCtrl = TextEditingController();
  String? _lineOaQrBase64;
  bool _showLineOaOnDisplay = true;
  bool _showLineOaOnReceipt = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _lineOaUrlCtrl.dispose();
    _lineOaIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _autoOpenDisplay = prefs.getBool('auto_open_customer_display') ?? false;
      _lineOaUrlCtrl.text = prefs.getString('line_oa_url') ?? '';
      _lineOaIdCtrl.text = prefs.getString('line_oa_id') ?? '';
      _lineOaQrBase64 = prefs.getString('line_oa_qr_image_base64');
      _showLineOaOnDisplay = prefs.getBool('show_line_oa_on_display') ?? true;
      _showLineOaOnReceipt = prefs.getBool('show_line_oa_on_receipt') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _darkMode);
    await prefs.setBool('auto_open_customer_display', _autoOpenDisplay);
    await prefs.setString('line_oa_url', _lineOaUrlCtrl.text.trim());
    await prefs.setString('line_oa_id', _lineOaIdCtrl.text.trim());
    if (_lineOaQrBase64 != null) {
      await prefs.setString('line_oa_qr_image_base64', _lineOaQrBase64!);
    } else {
      await prefs.remove('line_oa_qr_image_base64');
    }
    await prefs.setBool('show_line_oa_on_display', _showLineOaOnDisplay);
    await prefs.setBool('show_line_oa_on_receipt', _showLineOaOnReceipt);

    // Notify customer display to reload settings
    try {
      await CustomerDisplayService().reloadSettings();
    } catch (_) {}

    if (!mounted) return;
    AlertService.show(
      context: context,
      message: 'บันทึกการตั้งค่าเรียบร้อยแล้ว',
      type: 'success',
    );
  }

  Future<void> _pickLineOaQrImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        imageQuality: 75,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _lineOaQrBase64 = base64Encode(bytes);
        });
        await _saveSettings();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _removeLineOaQrImage() async {
    setState(() {
      _lineOaQrBase64 = null;
    });
    await _saveSettings();
  }

  Future<void> _openCustomerDisplay() async {
    await CustomerDisplayService().openDisplay();
    if (!mounted) return;

    // ✅ Sync current cart state to display
    ref.read(posProvider.notifier).resetDisplay();

    AlertService.show(
      context: context,
      message: 'เปิดหน้าจอฝั่งลูกค้าแล้ว',
      type: 'success',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่าหน้าจอ & ธีม (Display)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionHeader(
                    'ธีมและการแสดงผล (Theme)', Icons.palette, Colors.purple),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('โหมดมืด (Dark Mode)'),
                        subtitle: const Text('เปลี่ยนธีมแอปพลิเคชันเป็นสีเข้ม'),
                        secondary:
                            const Icon(Icons.dark_mode, color: Colors.purple),
                        value: _darkMode,
                        onChanged: (val) {
                          setState(() => _darkMode = val);
                          _saveSettings();
                        },
                      ),
                      Builder(
                        builder: (context) {
                          final theme = ref.watch(themeProvider);
                          return ListTile(
                            leading: const Icon(Icons.font_download,
                                color: Colors.purple),
                            title: const Text('รูปแบบตัวอักษร (Font)'),
                            subtitle: const Text('เลือกฟอนต์ที่ต้องการใช้งาน'),
                            trailing: DropdownButton<String>(
                              value: theme.fontFamily,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Sarabun',
                                    child: Text('Sarabun (Default)')),
                                DropdownMenuItem(
                                    value: 'Kanit',
                                    child: Text('Kanit (Modern)')),
                                DropdownMenuItem(
                                    value: 'Mali', child: Text('Mali (Cute)')),
                                DropdownMenuItem(
                                    value: 'Itim',
                                    child: Text('Itim (Friendly)')),
                              ],
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  ref.read(themeProvider.notifier).setFontFamily(newValue);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                _buildSectionHeader('หน้าจอฝั่งลูกค้า (Customer Display)',
                    Icons.monitor, Colors.orange),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('เปิดจอ 2 อัตโนมัติ (Auto-Open)'),
                        subtitle:
                            const Text('เปิดหน้าจอลูกค้าทันทีเมื่อเข้าโปรแกรม'),
                        secondary:
                            const Icon(Icons.auto_mode, color: Colors.green),
                        value: _autoOpenDisplay,
                        onChanged: (val) {
                          setState(() => _autoOpenDisplay = val);
                          _saveSettings();
                        },
                      ),
                      const Divider(),
                      // ✅ Font Size Slider
                      FutureBuilder<double>(
                        future: SharedPreferences.getInstance().then((p) =>
                            double.tryParse(
                                p.getString('customer_display_font_size') ??
                                    '14.0') ??
                            14.0),
                        builder: (context, snapshot) {
                          double currentSize = snapshot.data ?? 14.0;
                          return StatefulBuilder(
                            builder: (context, setStateSlider) {
                              return Column(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.format_size,
                                        color: Colors.orange),
                                    title:
                                        const Text('ขนาดตัวอักษรรายการสินค้า'),
                                    subtitle: Text(
                                        'ขนาดปัจจุบัน: ${currentSize.toStringAsFixed(0)}'),
                                    trailing: Text(
                                        '${currentSize.toStringAsFixed(0)} pt',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                  ),
                                  Slider(
                                    value: currentSize,
                                    min: 12.0,
                                    max: 40.0,
                                    divisions: 28,
                                    label: currentSize.toStringAsFixed(0),
                                    activeColor: Colors.orange,
                                    onChanged: (val) {
                                      setStateSlider(() => currentSize = val);
                                    },
                                    onChangeEnd: (val) async {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setString(
                                          'customer_display_font_size',
                                          val.toString());

                                      // ✅ Real-time Update
                                      await CustomerDisplayService()
                                          .updateFontSize(val);
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text('เปิดหน้าจอที่ 2 เดี๋ยวนี้'),
                        subtitle:
                            const Text('กดเพื่อเปิดหน้าจอสำหรับลูกค้าทันที'),
                        leading:
                            const Icon(Icons.open_in_new, color: Colors.blue),
                        onTap: _openCustomerDisplay,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // ── LINE Official Account (LINE OA) Card ──
                _buildSectionHeader('LINE Official Account (LINE OA) & QR Code',
                    Icons.qr_code_2, const Color(0xFF059669)),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('แสดง QR LINE OA ที่หน้าจอลูกค้า'),
                          subtitle: const Text(
                              'แสดงอัตโนมัติที่ช่องขวาล่าง และสลับเป็น PromptPay เมื่อชำระเงิน'),
                          secondary: const Icon(Icons.monitor,
                              color: Color(0xFF059669)),
                          value: _showLineOaOnDisplay,
                          onChanged: (val) {
                            setState(() => _showLineOaOnDisplay = val);
                            _saveSettings();
                          },
                        ),
                        const Divider(),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title:
                              const Text('พิมพ์ QR LINE OA ที่ท้ายสลิปใบเสร็จ 80mm'),
                          subtitle: const Text(
                              'พิมพ์ QR สมัครสมาชิก/สั่งของออนไลน์ที่ท้ายใบเสร็จ'),
                          secondary: const Icon(Icons.receipt_long,
                              color: Color(0xFF059669)),
                          value: _showLineOaOnReceipt,
                          onChanged: (val) {
                            setState(() => _showLineOaOnReceipt = val);
                            _saveSettings();
                          },
                        ),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Form Inputs
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _lineOaUrlCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'LINE OA Link / URL',
                                      hintText: 'https://lin.ee/xxxxx',
                                      prefixIcon: Icon(Icons.link,
                                          color: Color(0xFF059669)),
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _lineOaIdCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'LINE ID (ข้อความแสดงใต้ QR)',
                                      hintText: '@smartpos',
                                      prefixIcon: Icon(Icons.chat_bubble_outline,
                                          color: Color(0xFF059669)),
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _pickLineOaQrImage,
                                        icon: const Icon(Icons.upload_file),
                                        label: const Text(
                                            'อัปโหลดรูป QR Code'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF059669),
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                      if (_lineOaQrBase64 != null) ...[
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: _removeLineOaQrImage,
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.red),
                                          label: const Text('ลบรูป',
                                              style: TextStyle(
                                                  color: Colors.red)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),

                            // QR Preview Box
                            Expanded(
                              flex: 4,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'ตัวอย่าง QR บนหน้าจอ/สลิป',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 8),
                                    if (_lineOaQrBase64 != null)
                                      Image.memory(
                                        base64Decode(_lineOaQrBase64!),
                                        width: 110,
                                        height: 110,
                                        fit: BoxFit.contain,
                                      )
                                    else if (_lineOaUrlCtrl.text.isNotEmpty)
                                      QrImageView(
                                        data: _lineOaUrlCtrl.text.trim(),
                                        size: 110,
                                        backgroundColor: Colors.white,
                                      )
                                    else
                                      Container(
                                        width: 110,
                                        height: 110,
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                          child: Icon(Icons.qr_code,
                                              size: 48,
                                              color: Colors.grey),
                                        ),
                                      ),
                                    if (_lineOaIdCtrl.text.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'LINE: ${_lineOaIdCtrl.text.trim()}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF059669)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: _saveSettings,
                            icon: const Icon(Icons.save),
                            label: const Text('บันทึกการตั้งค่า LINE OA'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
