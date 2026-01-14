import 'package:flutter/material.dart';
import '../../utils/barcode_utils.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/confirm_dialog.dart';

class BarcodeSettingsScreen extends StatefulWidget {
  const BarcodeSettingsScreen({super.key});

  @override
  State<BarcodeSettingsScreen> createState() => _BarcodeSettingsScreenState();
}

class _BarcodeSettingsScreenState extends State<BarcodeSettingsScreen> {
  bool _isEnabled = true;
  Map<String, String> _mapping = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await BarcodeUtils.init(); // Ensure loaded
    setState(() {
      _isEnabled = BarcodeUtils.isEnabled;
      _mapping = Map.from(BarcodeUtils.getCurrentMapping());
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    await BarcodeUtils.saveSettings(enabled: _isEnabled, mapping: _mapping);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('บันทึกการตั้งค่าแล้ว'), backgroundColor: Colors.green),
    );
  }

  Future<void> _resetDefaults() async {
    final confirm = await ConfirmDialog.show(
      context,
      title: 'รีเซ็ตค่าเริ่มต้น?',
      content: 'ต้องการคืนค่าการ Mapping กลับเป็นค่าเริ่มต้น (เกษมณี) หรือไม่?',
      confirmText: 'ยืนยัน',
    );

    if (confirm == true) {
      await BarcodeUtils.resetToDefault();
      _loadSettings();
    }
  }

  void _addMapping() {
    final srcCtrl = TextEditingController();
    final destCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เพิ่ม Mapping'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              controller: srcCtrl,
              label: 'ต้นทาง (ภาษาไทย)',
              hint: 'เช่น ภ',
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: destCtrl,
              label: 'ปลายทาง (ตัวเลข/Eng)',
              hint: 'เช่น 4',
            ),
          ],
        ),
        actions: [
          CustomButton(
            onPressed: () => Navigator.pop(ctx),
            label: 'ยกเลิก',
            type: ButtonType.secondary,
          ),
          CustomButton(
            onPressed: () {
              final src = srcCtrl.text;
              final dest = destCtrl.text;
              if (src.isNotEmpty && dest.isNotEmpty) {
                setState(() {
                  _mapping[src] = dest;
                });
                _save(); // Auto save
                Navigator.pop(ctx);
              }
            },
            label: 'บันทึก',
            type: ButtonType.primary,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Convert map to list for easy display
    final sortedKeys = _mapping.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าเครื่องอ่านบาร์โค้ด'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'ค่าเริ่มต้น',
            onPressed: _resetDefaults,
          )
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('เปิดใช้งานการแปลงรหัสบาร์โค้ด',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle:
                const Text('แปลงรหัสจากภาษาไทยเป็นตัวเลข กรณีลืมเปลี่ยนภาษา'),
            value: _isEnabled,
            onChanged: (val) {
              setState(() => _isEnabled = val);
              _save();
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mapping List',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                CustomButton(
                  onPressed: _addMapping,
                  icon: Icons.add,
                  label: 'เพิ่ม',
                  type: ButtonType.primary,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: sortedKeys.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final key = sortedKeys[i];
                final val = _mapping[key];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                  title: Row(
                    children: [
                      Container(
                        width: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(key,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Icon(Icons.arrow_forward,
                            color: Colors.grey, size: 16),
                      ),
                      Container(
                        width: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(val ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue)),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _mapping.remove(key);
                      });
                      _save();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
