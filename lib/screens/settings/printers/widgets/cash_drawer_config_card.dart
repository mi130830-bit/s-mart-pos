// ignore_for_file: deprecated_member_use, invalid_use_of_protected_member, library_private_types_in_public_api
part of '../../printer_settings_screen.dart';

/// Cash drawer config card + test open logic.
extension CashDrawerCardExtension on _PrinterSettingsScreenState {
  Widget _buildDrawerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text('เปิดลิ้นชักอัตโนมัติเมื่อคิดเงิน (Auto Open)'),
              value: _drawerAutoOpen,
              onChanged: (val) {
                setState(() => _drawerAutoOpen = val ?? false);
                _autoSavePrinters(showMessage: true);
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('ใช้ไดร์เวอร์เครื่องพิมพ์ (Printer)'),
                    subtitle: const Text('ส่งคำสั่งผ่าน Printer'),
                    value: true,
                    groupValue: _drawerUsePrinter,
                    onChanged: (val) {
                      setState(() => _drawerUsePrinter = val ?? true);
                      _autoSavePrinters(showMessage: true);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('ส่งตรงด้วย COM / IP Port (Native ESC/POS)'),
                    subtitle: const Text('ต่อตรง USB/Serial (COM1) หรือ LAN IP (192.x.x.x)'),
                    value: false,
                    groupValue: _drawerUsePrinter,
                    onChanged: (val) {
                      setState(() => _drawerUsePrinter = val ?? false);
                      _autoSavePrinters(showMessage: true);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            if (!_drawerUsePrinter) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: CustomTextField(
                      initialValue: _drawerPort,
                      label: 'Port / IP Address',
                      hint: 'COM1, หรือ 192.168.1.50',
                      onChanged: (val) {
                        setState(() => _drawerPort = val);
                        _autoSavePrinters(showMessage: true);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: CustomTextField(
                      initialValue: _drawerCommand,
                      label: 'Command (Decimal Array or Text)',
                      hint: 'e.g., 27,112,0,25,250',
                      onChanged: (val) {
                        setState(() => _drawerCommand = val);
                        _autoSavePrinters(showMessage: true);
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testOpenDrawer,
                icon: const Icon(Icons.open_in_browser),
                label: const Text('ทดสอบเปิดลิ้นชัก (Test Open Drawer)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testOpenDrawer() async {
    try {
      if (_drawerUsePrinter) {
        if (_selectedCashPrinter == null) {
          AlertService.show(
              context: context, message: 'กรุณาเลือกเครื่องพิมพ์บิลก่อน', type: 'warning');
          return;
        }
        await ReceiptService().printReceipt(
          orderId: 0, items: [], total: 0, grandTotal: 0,
          received: 0, change: 0, customer: null,
          printerOverride: _selectedCashPrinter,
        );
        if (!mounted) return;
        AlertService.show(context: context, message: 'ส่งคำสั่งพิมพ์เพื่อเปิดลิ้นชักแล้ว', type: 'success');
      } else {
        List<int> bytes = [];
        if (_drawerCommand.contains(',')) {
          bytes = _drawerCommand.split(',').map((e) => int.tryParse(e.trim()) ?? 0).toList();
        } else {
          bytes = _drawerCommand.codeUnits;
        }

        if (_drawerPort.contains('.')) {
          // IP Address
          String ip = _drawerPort.trim();
          int p = 9100;
          if (ip.contains(':')) {
            final parts = ip.split(':');
            ip = parts[0];
            p = int.tryParse(parts[1]) ?? 9100;
          }
          try {
            final socket = await Socket.connect(ip, p, timeout: const Duration(seconds: 3));
            socket.add(bytes);
            await socket.flush();
            await socket.close();
            if (!mounted) return;
            AlertService.show(context: context, message: 'ทดสอบสำเร็จ: เชื่อมต่อและส่งข้อมูลไปที่ $ip เรียบร้อย', type: 'success');
          } catch (e) {
            if (!mounted) return;
            _showDrawerError('IP Socket Error', '$e');
          }
        } else if (_drawerPort.startsWith(r'\\') || _drawerPort.startsWith('//')) {
          // Network share (UNC)
          try {
            final tempFile = File('${Directory.systemTemp.path}\\drawer_kick.bin');
            await tempFile.writeAsBytes(bytes);
            final result = await Process.run('cmd', ['/c', 'copy', '/b', tempFile.path, _drawerPort]);
            if (!mounted) return;
            if (result.exitCode == 0) {
              AlertService.show(context: context, message: 'ทดสอบสำเร็จ: ส่งคำสั่งลิ้นชักไปที่ $_drawerPort เรียบร้อย', type: 'success');
            } else {
              _showDrawerError('Network Share Error', result.stderr.toString());
            }
          } catch (e) {
            if (!mounted) return;
            _showDrawerError('เครือข่าย', '$e');
          }
        } else {
          // COM Port
          try {
            final file = File('\\\\.\\$_drawerPort');
            await file.writeAsBytes(bytes);
          } catch (e) {
            if (!mounted) return;
            _showDrawerError('COM Port Error', '$e');
            return;
          }
          if (!mounted) return;
          AlertService.show(context: context, message: 'ส่งคำสั่งไปที่ $_drawerPort เรียบร้อย', type: 'success');
        }
      }
    } catch (e) {
      if (!mounted) return;
      AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
    }
  }

  void _showDrawerError(String title, String detail) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ข้อผิดพลาดการเตะลิ้นชัก: $title'),
        content: SingleChildScrollView(child: Text(detail)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ปิด'))],
      ),
    );
  }
}
