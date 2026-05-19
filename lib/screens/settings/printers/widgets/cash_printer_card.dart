// ignore_for_file: deprecated_member_use, invalid_use_of_protected_member, library_private_types_in_public_api
part of '../../printer_settings_screen.dart';

/// Cash slip (80mm) + Cash bill (Full receipt) cards.
extension CashPrinterCardExtension on _PrinterSettingsScreenState {
  Widget _buildCashPrinterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'เลือกเครื่องพิมพ์', border: OutlineInputBorder()),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _printers.any((p) => p.name == _selectedCashPrinter?.name)
                      ? _selectedCashPrinter?.name
                      : null,
                  isExpanded: true,
                  hint: const Text('เลือกเครื่องพิมพ์'),
                  items: _printers
                      .map((p) => DropdownMenuItem(value: p.name, child: Text(p.name)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCashPrinter =
                          val == null ? null : _printers.firstWhere((p) => p.name == val);
                    });
                    _autoSavePrinters(showMessage: true);
                  },
                ),
              ),
            ),
            const SizedBox(height: 15),
            InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'ขนาดกระดาษ', border: OutlineInputBorder()),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCashPaperSize,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: '80mm', child: Text('80mm (สลิปม้วน)')),
                    DropdownMenuItem(value: '58mm', child: Text('58mm (สลิปเล็ก)')),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedCashPaperSize = val!);
                    _autoSavePrinters(showMessage: true);
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _showUsbDeviceList,
                  icon: const Icon(Icons.usb, size: 16),
                  label: const Text('Check USB'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _showPreviewDialog(
                      'บิลเงินสด',
                      () => ReceiptService().testReceiptPreview(_selectedCashPaperSize)),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('ดูตัวอย่าง'),
                ),
                const SizedBox(width: 10),
                if (_selectedCashPrinter != null)
                  ElevatedButton.icon(
                    onPressed: () => ReceiptService()
                        .testReceipt(_selectedCashPrinter, _selectedCashPaperSize, false),
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('ทดสอบพิมพ์'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashBillPrinterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'เลือกเครื่องพิมพ์', border: OutlineInputBorder()),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _printers.any((p) => p.name == _selectedCashBillPrinter?.name)
                      ? _selectedCashBillPrinter?.name
                      : null,
                  isExpanded: true,
                  hint: const Text('เลือกเครื่องพิมพ์'),
                  items: _printers
                      .map((p) => DropdownMenuItem(value: p.name, child: Text(p.name)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCashBillPrinter =
                          val == null ? null : _printers.firstWhere((p) => p.name == val);
                    });
                    _autoSavePrinters(showMessage: true);
                  },
                ),
              ),
            ),
            const SizedBox(height: 15),
            InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'ขนาดกระดาษ', border: OutlineInputBorder()),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCashBillPaperSize,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'A4', child: Text('A4 (เต็มแผ่น)')),
                    DropdownMenuItem(value: 'A5', child: Text('A5 (ครึ่งแผ่น - Laser)')),
                    DropdownMenuItem(
                        value: 'Continuous',
                        child: Text('ต่อเนื่อง 9"x5.5" (Dot Matrix)')),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedCashBillPaperSize = val!);
                    _autoSavePrinters(showMessage: true);
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showPreviewDialog(
                      'บิลเงินสด (เต็มรูปแบบ)',
                      () => ReceiptService().testReceiptPreview(_selectedCashBillPaperSize)),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('ดูตัวอย่าง'),
                ),
                const SizedBox(width: 10),
                if (_selectedCashBillPrinter != null)
                  ElevatedButton.icon(
                    onPressed: () => ReceiptService()
                        .testReceipt(_selectedCashBillPrinter, _selectedCashBillPaperSize, false),
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('ทดสอบพิมพ์'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // USB Port dialog — used from cash card's "Check USB" button
  Future<void> _showUsbDeviceList() async {
    setState(() => _isLoading = true);
    try {
      final result = await Process.run('powershell', [
        '-Command',
        'Get-PnpDevice -Class Ports -Status OK | Select-Object FriendlyName'
      ]);
      String devices = 'ไม่พบอุปกรณ์ (No devices found)';
      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        final lines = result.stdout.toString().trim().split('\n');
        final filtered = lines
            .where((l) =>
                !l.contains('FriendlyName') && !l.contains('----') && l.trim().isNotEmpty)
            .map((l) => l.trim())
            .toList();
        if (filtered.isNotEmpty) devices = filtered.join('\n');
      } else {
        devices = 'Error reading ports: ${result.stderr}';
      }
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('รายการพอร์ตที่เชื่อมต่อ (Connected Ports)'),
            content: SingleChildScrollView(
                child: Text(devices, style: const TextStyle(fontSize: 16))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ปิด'))
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
