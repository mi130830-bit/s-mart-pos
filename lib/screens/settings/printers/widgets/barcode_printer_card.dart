// ignore_for_file: deprecated_member_use, invalid_use_of_protected_member, library_private_types_in_public_api
part of '../../printer_settings_screen.dart';

/// Barcode/label printer card including preview dialog and template selector.
extension BarcodePrinterCardExtension on _PrinterSettingsScreenState {
  Widget _buildBarcodePrinterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'เลือกเครื่องพิมพ์บาร์โค้ด',
                  border: OutlineInputBorder()),
              child: Builder(builder: (context) {
                final uniqueNames = _printers.map((p) => p.name).toSet();
                String? currentValue = _selectedBarcodePrinter?.name;
                if (currentValue != null && !uniqueNames.contains(currentValue)) {
                  currentValue = null;
                }
                return DropdownButton<String>(
                  value: currentValue,
                  isExpanded: true,
                  hint: const Text('เลือกเครื่องพิมพ์'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('ไม่ระบุ (เลือกทุกครั้ง)'),
                    ),
                    ...uniqueNames.map((name) =>
                        DropdownMenuItem(value: name, child: Text(name))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedBarcodePrinter = val == null
                          ? null
                          : _printers.firstWhere((p) => p.name == val,
                              orElse: () => Printer(url: val, name: val));
                    });
                    _autoSavePrinters(showMessage: true);
                  },
                );
              }),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showTemplateSelector,
                    icon: const Icon(Icons.dashboard_customize, size: 16),
                    label: const Text('จัดการแม่แบบ (Manage Templates)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showBarcodePreviewDialog,
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('ดูตัวอย่าง (Preview)'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBarcodePreviewDialog() {
    bool showRuler = true;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('ตัวอย่างสติกเกอร์ (Preview)'),
            content: SizedBox(
              width: 600,
              height: 500,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Checkbox(
                        value: showRuler,
                        onChanged: (val) => setState(() => showRuler = val!),
                      ),
                      const Text('แสดงไม้บรรทัด (Show Ruler)'),
                    ],
                  ),
                  Expanded(
                    child: PdfPreview(
                      build: (format) => LabelPrinterService().testBarcodePreview(
                        LabelType.barcode406x108,
                        showRuler: showRuler,
                      ),
                      allowPrinting: false,
                      allowSharing: false,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ปิด')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showTemplateSelector() async {
    final service = BarcodePrintService();
    final templates = await service.getAllTemplates();
    final selected = await service.getSelectedTemplate();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('จัดการแม่แบบสติกเกอร์'),
        content: SizedBox(
          width: 500,
          child: CustomRadioGroup<String>(
            groupValue: selected?.id,
            onChanged: (val) async {
              await service.setSelectedTemplateId(val!);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _showTemplateSelector();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (templates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('ยังไม่มีแม่แบบที่คุณสร้างไว้'),
                  ),
                ...templates.map((t) => ListTile(
                      title: Text(t.name),
                      subtitle: Text(
                          '${t.labelWidth}x${t.labelHeight} mm (${t.columns} คอลัมน์)'),
                      leading: Radio<String>(
                        value: t.id,
                        groupValue: selected?.id,
                        onChanged: (val) async {
                          if (val == null) return;
                          await service.setSelectedTemplateId(val);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _showTemplateSelector();
                        },
                      ),
                      onTap: () async {
                        await service.setSelectedTemplateId(t.id);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _showTemplateSelector();
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await showDialog(
                                context: context,
                                builder: (c) => BarcodePrintSetupScreen(template: t),
                              );
                              _showTemplateSelector();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await ConfirmDialog.show(
                                context,
                                title: 'ยืนยันการลบ',
                                content: 'ต้องการลบแม่แบบ "${t.name}" หรือไม่?',
                                confirmText: 'ลบ',
                                isDestructive: true,
                              );
                              if (confirm == true) {
                                await service.deleteTemplate(t.id);
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                _showTemplateSelector();
                              }
                            },
                          ),
                        ],
                      ),
                    )),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.add, color: Colors.green),
                  title: const Text('สร้างแม่แบบใหม่'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await showDialog(
                      context: context,
                      builder: (c) => const BarcodePrintSetupScreen(),
                    );
                    _showTemplateSelector();
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadPrintersAndSettings();
            },
            child: const Text('ปิด'),
          ),
        ],
      ),
    ).then((_) => _loadPrintersAndSettings());
  }
}
