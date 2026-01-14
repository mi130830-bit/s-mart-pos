import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../state/theme_provider.dart';
import '../../screens/pos/pos_state_manager.dart'; // ✅ Added
import '../../services/customer_display_service.dart';

class DisplaySettingsScreen extends StatefulWidget {
  const DisplaySettingsScreen({super.key});

  @override
  State<DisplaySettingsScreen> createState() => _DisplaySettingsScreenState();
}

class _DisplaySettingsScreenState extends State<DisplaySettingsScreen> {
  bool _darkMode = false;
  bool _autoOpenDisplay = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _autoOpenDisplay = prefs.getBool('auto_open_customer_display') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _darkMode);
    await prefs.setBool('auto_open_customer_display', _autoOpenDisplay);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('บันทึกการตั้งค่าหน้าจอเรียบร้อย'),
          backgroundColor: Colors.green),
    );
  }

  Future<void> _openCustomerDisplay() async {
    await CustomerDisplayService().openDisplay();
    if (!mounted) return;

    // ✅ Sync current cart state to display
    context.read<PosStateManager>().resetDisplay();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('เปิดหน้าจอฝั่งลูกค้าแล้ว')),
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
                      Consumer<ThemeProvider>(
                        builder: (context, theme, _) {
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
                                  theme.setFontFamily(newValue);
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
