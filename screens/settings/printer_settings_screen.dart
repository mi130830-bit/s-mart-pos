// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../services/printing/receipt_service.dart';
import '../../services/printing/barcode_print_service.dart';

import 'barcode_print_setup_screen.dart';
import '../../services/alert_service.dart';
import '../../widgets/custom_radio_group.dart';
import '../../services/printing/label_printer_service.dart';
import '../../models/label_config.dart';
import 'package:pos_desktop/services/local_settings_service.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/confirm_dialog.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  List<Printer> _printers = [];
  Printer? _selectedCashPrinter;
  Printer? _selectedCashBillPrinter; // New
  Printer? _selectedTaxPrinter;
  Printer? _selectedDeliveryPrinter;
  bool _isLoading = true;

  String _selectedDeliveryPaperSize = 'A5';
  String _selectedCashPaperSize = '80mm';
  String _selectedCashBillPaperSize = 'A4'; // New
  String _selectedBarcodePaperSize = '40mmx30mm';

  Printer? _selectedBarcodePrinter;

  bool _autoPrintCash = true;
  bool _autoPrintDebt = true;

  // Drawer Settings
  bool _drawerAutoOpen = false;
  String _drawerPort = 'COM1';
  String _drawerCommand = '27,112,0,25,250';
  bool _drawerUsePrinter = true;

  @override
  void initState() {
    super.initState();
    _loadPrintersAndSettings();
  }

  Future<void> _loadPrintersAndSettings() async {
    setState(() => _isLoading = true);
    final printers = await Printing.listPrinters();
    final settings = LocalSettingsService();

    setState(() {
      // Deduplicate printers based on URL (or name if URL is standard)
      final uniquePrinters = <String, Printer>{};
      for (final p in printers) {
        uniquePrinters[p.name] = p; // Use name as unique key
      }
      _printers = uniquePrinters.values.toList();
    });

    // Load Printers (Local Settings)
    final cashName = await settings.getCashPrinterName();
    final cashBillName = await settings.getCashBillPrinterName(); // New
    final taxName = await settings.getTaxPrinterName();
    final deliveryName = await settings.getDeliveryPrinterName();
    final barcodeName = await settings.getBarcodePrinterName();

    // Load Settings
    final delSize = await settings.getDeliveryPaperSize();
    final cashSize = await settings.getCashPaperSize();
    final cashBillSize = await settings.getCashBillPaperSize(); // New
    final barSize = await settings.getBarcodePaperSize();
    final apCash = await settings.getAutoPrintReceipt();
    final apDebt = await settings.getAutoPrintDeliveryNote();

    // Load Cash Drawer Settings
    final drAuto = await settings.getDrawerAutoOpen();
    final drPort = await settings.getDrawerPort();
    final drCmd = await settings.getDrawerCommand();
    final drUsePrn = await settings.getDrawerUsePrinter();

    if (!mounted) return;

    setState(() {
      _selectedDeliveryPaperSize = delSize;
      _selectedCashPaperSize = cashSize;
      _selectedCashBillPaperSize = cashBillSize; // New
      _selectedBarcodePaperSize = barSize;

      _autoPrintCash = apCash;
      _autoPrintDebt = apDebt;

      _drawerAutoOpen = drAuto;
      _drawerPort = drPort;
      _drawerCommand = drCmd;
      _drawerUsePrinter = drUsePrn;

      // Match Printer Names
      if (cashName != null) {
        try {
          _selectedCashPrinter =
              _printers.firstWhere((p) => p.name == cashName);
        } catch (_) {}
      }
      if (cashBillName != null) {
        try {
          _selectedCashBillPrinter =
              _printers.firstWhere((p) => p.name == cashBillName);
        } catch (_) {}
      }
      if (taxName != null) {
        try {
          _selectedTaxPrinter = _printers.firstWhere((p) => p.name == taxName);
        } catch (_) {}
      }
      if (deliveryName != null) {
        try {
          _selectedDeliveryPrinter =
              _printers.firstWhere((p) => p.name == deliveryName);
        } catch (_) {}
      }
      if (barcodeName != null) {
        try {
          _selectedBarcodePrinter =
              _printers.firstWhere((p) => p.name == barcodeName);
        } catch (_) {}
      }

      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final settings = LocalSettingsService();

    // Save Printers
    await settings.setCashPrinterName(_selectedCashPrinter?.name);
    await settings
        .setCashBillPrinterName(_selectedCashBillPrinter?.name); // New
    await settings.setTaxPrinterName(_selectedTaxPrinter?.name);
    await settings.setDeliveryPrinterName(_selectedDeliveryPrinter?.name);
    await settings.setBarcodePrinterName(_selectedBarcodePrinter?.name);

    // Save Paper Sizes
    await settings.setDeliveryPaperSize(_selectedDeliveryPaperSize);
    await settings.setCashPaperSize(_selectedCashPaperSize);
    await settings.setCashBillPaperSize(_selectedCashBillPaperSize); // New
    await settings.setBarcodePaperSize(_selectedBarcodePaperSize);

    // Save Auto Print
    await settings.setAutoPrintReceipt(_autoPrintCash);
    await settings.setAutoPrintDeliveryNote(_autoPrintDebt);

    // Save Drawer
    await settings.setDrawerAutoOpen(_drawerAutoOpen);
    await settings.setDrawerPort(_drawerPort);
    await settings.setDrawerCommand(_drawerCommand);
    await settings.setDrawerUsePrinter(_drawerUsePrinter);

    if (mounted) {
      AlertService.show(
        context: context,
        message: 'บันทึกการตั้งค่าลงในเครื่องนี้แล้ว (Saved Locally)',
        type: 'success',
      );
    }
  }

//   Widget _buildLogoSection() { ... Removed ... }

  // ✅ New Function to Show In-App Preview
  void _showPreviewDialog(String title, Future<Uint8List> Function() builder) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          children: [
            AppBar(
              title: Text('ตัวอย่าง: $title'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: PdfPreview(
                build: (format) => builder(),
                allowPrinting: false,
                allowSharing: false,
                canChangeOrientation: false,
                canChangePageFormat: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('ตั้งค่าเครื่องพิมพ์ (Printer Settings)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo Removed (Moved to Shop Info)
                  // const SizedBox(height: 30),
                  _buildSectionHeader('เครื่องพิมพ์บิลเงินสด (POS Slip)',
                      Icons.payments, Colors.green),
                  _buildCashPrinterCard(),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text(
                        'พิมพ์ใบเสร็จอัตโนมัติเมื่อขายสด (Auto-Print)'),
                    subtitle: const Text(
                        'พิมพ์ทันทีที่กดรับเงินสำเร็จ (ไม่ต้องกดพิมพ์เอง)'),
                    value: _autoPrintCash,
                    onChanged: (val) => setState(() => _autoPrintCash = val),
                  ),
                  const SizedBox(height: 30),
                  _buildSectionHeader('เครื่องพิมพ์บิลเงินสด (Full Receipt)',
                      Icons.description, Colors.indigo),
                  _buildCashBillPrinterCard(),
                  const SizedBox(height: 30),

                  _buildSectionHeader('เครื่องพิมพ์ใบกำกับภาษี (Full Tax)',
                      Icons.receipt_long, Colors.orange),
                  _buildPrinterCard(
                    printer: _selectedTaxPrinter,
                    onChanged: (p) => setState(() => _selectedTaxPrinter = p),
                    label: 'TAX',
                  ),
                  const SizedBox(height: 30),
                  _buildSectionHeader('เครื่องพิมพ์ใบส่งของ/ลูกหนี้',
                      Icons.local_shipping, Colors.blue),
                  _buildDeliveryCard(),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text(
                        'พิมพ์ใบส่งของอัตโนมัติเมื่อขายเชื่อ (Auto-Print)'),
                    subtitle:
                        const Text('พิมพ์ทันทีที่บันทึกบิลขายเชื่อสำเร็จ'),
                    value: _autoPrintDebt,
                    onChanged: (val) => setState(() => _autoPrintDebt = val),
                  ),
                  const SizedBox(height: 30),
                  _buildSectionHeader('เครื่องพิมพ์สติกเกอร์ (Label Printer)',
                      Icons.label, Colors.teal),
                  _buildBarcodePrinterCard(),
                  const SizedBox(height: 30),
                  _buildSectionHeader('ลิ้นชักเก็บเงิน (Cash Drawer)',
                      Icons.point_of_sale, Colors.blueGrey),
                  _buildDrawerCard(),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: CustomButton(
                      onPressed: _saveSettings,
                      label: 'บันทึกการตั้งค่าทั้งหมด',
                      type: ButtonType.primary,
                      backgroundColor: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

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
                // Ensure unique names for DropdownItems
                final uniqueNames = _printers.map((p) => p.name).toSet();

                // Ensure selected value exists in the list
                String? currentValue = _selectedBarcodePrinter?.name;
                if (currentValue != null &&
                    !uniqueNames.contains(currentValue)) {
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
                      if (val == null) {
                        _selectedBarcodePrinter = null;
                      } else {
                        try {
                          _selectedBarcodePrinter =
                              _printers.firstWhere((p) => p.name == val);
                        } catch (_) {
                          _selectedBarcodePrinter = null;
                        }
                      }
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    onPressed: _showTemplateSelector,
                    icon: Icons.dashboard_customize,
                    label: 'จัดการแม่แบบ (Manage Templates)',
                    type: ButtonType.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomButton(
                    onPressed: () => _showBarcodePreviewDialog(),
                    icon: Icons.visibility,
                    label: 'ดูตัวอย่าง (Preview)',
                    type: ButtonType.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
                    value: _printers
                            .any((p) => p.name == _selectedCashPrinter?.name)
                        ? _selectedCashPrinter?.name
                        : null,
                    isExpanded: true,
                    hint: const Text('เลือกเครื่องพิมพ์'),
                    items: _printers
                        .map((p) => DropdownMenuItem(
                            value: p.name, child: Text(p.name)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        if (val == null) {
                          _selectedCashPrinter = null;
                        } else {
                          _selectedCashPrinter =
                              _printers.firstWhere((p) => p.name == val);
                        }
                      });
                    }),
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
                    DropdownMenuItem(
                        value: '80mm', child: Text('80mm (สลิปม้วน)')),
                    DropdownMenuItem(
                        value: '58mm', child: Text('58mm (สลิปเล็ก)')),
                  ],
                  onChanged: (val) =>
                      setState(() => _selectedCashPaperSize = val!),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CustomButton(
                  onPressed: _showUsbDeviceList,
                  icon: Icons.usb,
                  label: 'Check USB',
                  type: ButtonType.secondary,
                ),
                const SizedBox(width: 10),
                CustomButton(
                  onPressed: () => _showPreviewDialog(
                      'บิลเงินสด',
                      () => ReceiptService()
                          .testReceiptPreview(_selectedCashPaperSize)),
                  icon: Icons.visibility,
                  label: 'ดูตัวอย่าง',
                  type: ButtonType.secondary,
                ),
                const SizedBox(width: 10),
                if (_selectedCashPrinter != null)
                  CustomButton(
                    onPressed: () => ReceiptService().testReceipt(
                        _selectedCashPrinter, _selectedCashPaperSize, false),
                    icon: Icons.print,
                    label: 'ทดสอบพิมพ์',
                    type: ButtonType.primary,
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
                    value: _printers.any(
                            (p) => p.name == _selectedCashBillPrinter?.name)
                        ? _selectedCashBillPrinter?.name
                        : null,
                    isExpanded: true,
                    hint: const Text('เลือกเครื่องพิมพ์'),
                    items: _printers
                        .map((p) => DropdownMenuItem(
                            value: p.name, child: Text(p.name)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        if (val == null) {
                          _selectedCashBillPrinter = null;
                        } else {
                          _selectedCashBillPrinter =
                              _printers.firstWhere((p) => p.name == val);
                        }
                      });
                    }),
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
                    DropdownMenuItem(
                        value: 'A5', child: Text('A5 (ครึ่งแผ่น)')),
                  ],
                  onChanged: (val) =>
                      setState(() => _selectedCashBillPaperSize = val!),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CustomButton(
                  onPressed: () => _showPreviewDialog(
                      'บิลเงินสด (เต็มรูปแบบ)',
                      () => ReceiptService().testReceiptPreview(
                          _selectedCashBillPaperSize)), // Reuse basic preview logic
                  icon: Icons.visibility,
                  label: 'ดูตัวอย่าง',
                  type: ButtonType.secondary,
                ),
                const SizedBox(width: 10),
                if (_selectedCashBillPrinter != null)
                  CustomButton(
                    onPressed: () => ReceiptService().testReceipt(
                        _selectedCashBillPrinter,
                        _selectedCashBillPaperSize,
                        false),
                    icon: Icons.print,
                    label: 'ทดสอบพิมพ์',
                    type: ButtonType.primary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ New Method: Check USB/COM Ports
  Future<void> _showUsbDeviceList() async {
    setState(() => _isLoading = true);
    try {
      // Run PowerShell command to get comfortable list of COM ports
      // "Get-WmiObject Win32_SerialPort | Select-Object Name, Description | Format-Table -HideTableHeaders"
      // Or simpler: "mode" command in generic shell, but "wmic" is better for names.

      final result = await Process.run('powershell', [
        '-Command',
        'Get-PnpDevice -Class Ports -Status OK | Select-Object FriendlyName'
      ]);

      String devices = 'ไม่พบอุปกรณ์ (No devices found)';
      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        // Clean up output (remove "FriendlyName" header and "---" separator)
        final lines = result.stdout.toString().trim().split('\n');
        final filtered = lines
            .where((l) =>
                !l.contains('FriendlyName') &&
                !l.contains('----') &&
                l.trim().isNotEmpty)
            .map((l) => l.trim())
            .toList();

        if (filtered.isNotEmpty) {
          devices = filtered.join('\n');
        }
      } else {
        // Fallback or Error
        devices = 'Error reading ports: ${result.stderr}';
      }

      if (mounted) {
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                  title:
                      const Text('รายการพอร์ตที่เชื่อมต่อ (Connected Ports)'),
                  content: SingleChildScrollView(
                      child:
                          Text(devices, style: const TextStyle(fontSize: 16))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('ปิด'))
                  ],
                ));
      }
    } catch (e) {
      if (mounted) {
        if (mounted) {
          AlertService.show(
            context: context,
            message: 'เกิดข้อผิดพลาด: $e',
            type: 'error',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                    value: _printers.any(
                            (p) => p.name == _selectedDeliveryPrinter?.name)
                        ? _selectedDeliveryPrinter?.name
                        : null,
                    isExpanded: true,
                    hint: const Text('เลือกเครื่องพิมพ์'),
                    items: _printers
                        .map((p) => DropdownMenuItem(
                            value: p.name, child: Text(p.name)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        if (val == null) {
                          _selectedDeliveryPrinter = null;
                        } else {
                          _selectedDeliveryPrinter =
                              _printers.firstWhere((p) => p.name == val);
                        }
                      });
                    }),
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
                    DropdownMenuItem(
                        value: 'A5', child: Text('A5 (ครึ่งแผ่น)')),
                    DropdownMenuItem(value: 'A4', child: Text('A4 (เต็มแผ่น)')),
                  ],
                  onChanged: (val) =>
                      setState(() => _selectedDeliveryPaperSize = val!),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CustomButton(
                  onPressed: () => _showPreviewDialog(
                      'ใบส่งของ',
                      () => ReceiptService()
                          .testDeliveryNotePreview(_selectedDeliveryPaperSize)),
                  icon: Icons.visibility,
                  label: 'ดูตัวอย่าง',
                  type: ButtonType.secondary,
                ),
                const SizedBox(width: 10),
                if (_selectedDeliveryPrinter != null)
                  CustomButton(
                    onPressed: () => ReceiptService().testDeliveryNote(
                        _selectedDeliveryPrinter,
                        _selectedDeliveryPaperSize,
                        false),
                    icon: Icons.print,
                    label: 'ทดสอบพิมพ์',
                    type: ButtonType.primary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBarcodePreviewDialog() {
    bool showRuler = true; // Default to true as requested "in example"

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
                        onChanged: (val) {
                          setState(() => showRuler = val!);
                        },
                      ),
                      const Text('แสดงไม้บรรทัด (Show Ruler)'),
                    ],
                  ),
                  Expanded(
                    child: PdfPreview(
                      build: (format) =>
                          LabelPrinterService().testBarcodePreview(
                        LabelType
                            .barcode406x108, // Default or selected? Maybe assume 4.06x1.08 as main
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
              CustomButton(
                onPressed: () => Navigator.pop(context),
                label: 'ปิด',
                type: ButtonType.secondary,
              ),
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
              _showTemplateSelector(); // Refresh
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
                                builder: (c) =>
                                    BarcodePrintSetupScreen(template: t),
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
                )
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _loadPrintersAndSettings(); // Refresh templates in main dropdown
              },
              child: const Text('ปิด'))
        ],
      ),
    ).then((_) => _loadPrintersAndSettings());
  }

  Widget _buildPrinterCard(
      {required Printer? printer,
      required ValueChanged<Printer?> onChanged,
      required String label}) {
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
                  value: _printers.any((p) => p.name == printer?.name)
                      ? printer?.name
                      : null,
                  isExpanded: true,
                  hint: const Text('เลือกเครื่องพิมพ์'),
                  items: _printers
                      .map((p) =>
                          DropdownMenuItem(value: p.name, child: Text(p.name)))
                      .toList(),
                  onChanged: (val) {
                    if (val == null) {
                      onChanged(null);
                    } else {
                      onChanged(_printers.firstWhere((p) => p.name == val));
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CustomButton(
                  onPressed: () {
                    if (label == 'TAX') {
                      _showPreviewDialog('ใบกำกับภาษี',
                          () => ReceiptService().testTaxInvoicePreview());
                    }
                  },
                  icon: Icons.visibility,
                  label: 'ดูตัวอย่าง',
                  type: ButtonType.secondary,
                ),
                const SizedBox(width: 10),
                if (printer != null)
                  CustomButton(
                    onPressed: () {
                      if (label == 'TAX') {
                        ReceiptService().testTaxInvoice(printer, false);
                      }
                    },
                    icon: Icons.print,
                    label: 'ทดสอบพิมพ์',
                    type: ButtonType.primary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text('เปิดลิ้นชักอัตโนมัติเมื่อคิดเงิน (Auto Open)'),
              value: _drawerAutoOpen,
              onChanged: (val) =>
                  setState(() => _drawerAutoOpen = val ?? false),
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
                    onChanged: (val) =>
                        setState(() => _drawerUsePrinter = val ?? true),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('ใช้พอร์ต COM (Direct Serial)'),
                    subtitle: const Text('ต่อตรงกับคอมพิวเตอร์'),
                    value: false,
                    groupValue: _drawerUsePrinter,
                    onChanged: (val) =>
                        setState(() => _drawerUsePrinter = val ?? false),
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
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Port', border: OutlineInputBorder()),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _drawerPort,
                          isExpanded: true,
                          items: List.generate(10, (index) => 'COM${index + 1}')
                              .map((p) =>
                                  DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _drawerPort = val ?? 'COM1'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: CustomTextField(
                      initialValue: _drawerCommand,
                      label: 'Command (Decimal Array or Text)',
                      hint: 'e.g., 27,112,0,25,250',
                      onChanged: (val) => _drawerCommand = val,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                onPressed: _testOpenDrawer,
                icon: Icons.open_in_browser, // Icon nearest to "Open"
                label: 'ทดสอบเปิดลิ้นชัก (Test Open Drawer)',
                type: ButtonType.primary,
                backgroundColor: Colors.teal,
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _testOpenDrawer() async {
    try {
      if (_drawerUsePrinter) {
        // Method 1: Send to Printer
        if (_selectedCashPrinter == null) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('กรุณาเลือกเครื่องพิมพ์บิลก่อน')));
          return;
        }

        // This requires the 'printing' package to support raw commands which it often abstracts away.
        // However, we can try to print a dummy job with raw ESC/POS if the driver supports it
        // Or we use a specific "Open Drawer" command integration.
        // Since Flutter Printing package creates PDF/Images, sending raw bytes is tricky without 'flutter_pos_printer_platform' or native code.
        // WORKAROUND: Many drivers trigger drawer on "Document Start" if configured in Windows Printer Properties.
        // But if we want to force it, we need raw write.

        // Let's assume the user configures the Driver to open on print for now, OR we try to send a raw text job if possible (Printing package -> directPrintPdf is PDF only usually).
        // Wait! The user asked for "Send Text" in the image even for Printer?? No, "Set at printer driver" is a checkbox.
        // If "Set at printer driver" is checked, we rely on Windows Driver settings.
        // If NOT checked, we send to COM port.

        // So for "Printer Driver" mode, we might just print a tiny dummy receipt to trigger it?
        await ReceiptService().printReceipt(
            orderId: 0,
            items: [],
            total: 0,
            grandTotal: 0,
            received: 0,
            change: 0,
            customer: null,
            printerOverride:
                _selectedCashPrinter); // Empty receipt triggers driver

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('ส่งคำสั่งพิมพ์เพื่อเปิดลิ้นชักแล้ว')));
      } else {
        // Method 2: COM Port (Windows)
        // Parse Command
        List<int> bytes = [];
        if (_drawerCommand.contains(',')) {
          // Parse "27,112,0..."
          bytes = _drawerCommand
              .split(',')
              .map((e) => int.tryParse(e.trim()) ?? 0)
              .toList();
        } else {
          // ASCII text
          bytes = _drawerCommand.codeUnits;
        }

        // On Windows, detailed serial port control needs C++, but simple writing to "COM1" file works sometimes
        // Or using 'mode' command to configure and 'type' or 'echo' to write.
        final file =
            File('\\\\.\\$_drawerPort'); // Windows path namespace for devices
        await file.writeAsBytes(bytes);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ส่งคำสั่งไปที่ $_drawerPort เรียบร้อย')));
      }
    } catch (e) {
      debugPrint('Drawer Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 10),
        Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800]))),
      ],
    );
  }
}
