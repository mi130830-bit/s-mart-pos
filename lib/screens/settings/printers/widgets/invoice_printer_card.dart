// ignore_for_file: deprecated_member_use, invalid_use_of_protected_member, library_private_types_in_public_api
part of '../../printer_settings_screen.dart';

/// Tax invoice + Delivery note printer cards.
extension InvoicePrinterCardExtension on _PrinterSettingsScreenState {
  Widget _buildPrinterCard({
    required Printer? printer,
    required ValueChanged<Printer?> onChanged,
    required String label,
  }) {
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
                  value: _printers.any((p) => p.name == printer?.name) ? printer?.name : null,
                  isExpanded: true,
                  hint: const Text('เลือกเครื่องพิมพ์'),
                  items: _printers
                      .map((p) => DropdownMenuItem(value: p.name, child: Text(p.name)))
                      .toList(),
                  onChanged: (val) {
                    onChanged(val == null ? null : _printers.firstWhere((p) => p.name == val));
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    if (label == 'TAX') {
                      _showPreviewDialog(
                          'ใบกำกับภาษี', () => ReceiptService().testTaxInvoicePreview());
                    }
                  },
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('ดูตัวอย่าง'),
                ),
                const SizedBox(width: 10),
                if (printer != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      if (label == 'TAX') {
                        ReceiptService().testTaxInvoice(printer, false);
                      }
                    },
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

  Widget _buildDeliveryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'เลือกเครื่องพิมพ์', border: OutlineInputBorder()),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _printers.any((p) => p.name == _selectedDeliveryPrinter?.name)
                      ? _selectedDeliveryPrinter?.name
                      : null,
                  isExpanded: true,
                  hint: const Text('เลือกเครื่องพิมพ์'),
                  items: _printers
                      .map((p) => DropdownMenuItem(value: p.name, child: Text(p.name)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedDeliveryPrinter =
                          val == null ? null : _printers.firstWhere((p) => p.name == val);
                    });
                    _autoSavePrinters();
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
                  value: _selectedDeliveryPaperSize,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'A4', child: Text('A4 (เต็มแผ่น)')),
                    DropdownMenuItem(value: 'A5', child: Text('A5 (ครึ่งแผ่น - Laser)')),
                    DropdownMenuItem(
                        value: 'Continuous',
                        child: Text('ต่อเนื่อง 9"x5.5" (Dot Matrix)')),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedDeliveryPaperSize = val!);
                    LocalSettingsService().setDeliveryPaperSize(val!);
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
                      'ใบส่งของ',
                      () => ReceiptService()
                          .testDeliveryNotePreview(_selectedDeliveryPaperSize)),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('ดูตัวอย่าง'),
                ),
                const SizedBox(width: 10),
                if (_selectedDeliveryPrinter != null)
                  ElevatedButton.icon(
                    onPressed: () => ReceiptService().testDeliveryNote(
                        _selectedDeliveryPrinter, _selectedDeliveryPaperSize, false),
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
}
