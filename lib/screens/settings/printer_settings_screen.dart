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
import '../../widgets/common/settings_section_header.dart';

// ── Part files (share state via `part of`) ───────────────────────────────────
part 'printers/extensions/printer_actions_extension.dart';
part 'printers/widgets/cash_printer_card.dart';
part 'printers/widgets/invoice_printer_card.dart';
part 'printers/widgets/barcode_printer_card.dart';
part 'printers/widgets/cash_drawer_config_card.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  // ── Printer State ─────────────────────────────────────────────────────────
  List<Printer> _printers = [];
  Printer? _selectedCashPrinter;
  Printer? _selectedCashBillPrinter;
  Printer? _selectedTaxPrinter;
  Printer? _selectedDeliveryPrinter;
  Printer? _selectedBarcodePrinter;
  bool _isLoading = true;

  // ── Paper Size State ──────────────────────────────────────────────────────
  String _selectedDeliveryPaperSize = 'A5';
  String _selectedCashPaperSize = '80mm';
  String _selectedCashBillPaperSize = 'A4';

  // ── Auto-Print State ──────────────────────────────────────────────────────
  bool _autoPrintCash = true;
  bool _autoPrintDebt = true;

  // ── Cash Drawer State ─────────────────────────────────────────────────────
  bool _drawerAutoOpen = false;
  String _drawerPort = 'COM1';
  String _drawerCommand = '27,112,0,25,250';
  bool _drawerUsePrinter = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrintersAndSettings());
  }

  Future<void> _loadPrintersAndSettings() async {
    try {
      debugPrint('🚀 Starting Printer Load...');
      final printers = await Printing.listPrinters().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ Printing.listPrinters TIMEOUT');
          return [];
        },
      );

      final settings = LocalSettingsService();
      await settings.reload();
      if (!mounted) return;

      const ignoredPrinters = [
        'Microsoft Print to PDF', 'Microsoft XPS Document Writer',
        'Fax', 'OneNote', 'Send to OneNote'
      ];

      setState(() {
        final uniquePrinters = <String, Printer>{};
        for (final p in printers) {
          if (ignoredPrinters.any((i) => p.name.contains(i))) continue;
          if (!uniquePrinters.containsKey(p.name)) uniquePrinters[p.name] = p;
        }
        _printers = uniquePrinters.values.toList();
      });

      debugPrint('🖨️ Available Printers (${_printers.length}):');
      for (var p in _printers) { debugPrint('   - "${p.name}"'); }

      final cashName = await settings.getCashPrinterName();
      final cashBillName = await settings.getCashBillPrinterName();
      final taxName = await settings.getTaxPrinterName();
      final deliveryName = await settings.getDeliveryPrinterName();
      final barcodeName = await settings.getBarcodePrinterName();

      final delSize = await settings.getDeliveryPaperSize();
      final cashSize = await settings.getCashPaperSize();
      final cashBillSize = await settings.getCashBillPaperSize();
      final apCash = await settings.getAutoPrintReceipt();
      final apDebt = await settings.getAutoPrintDeliveryNote();

      final drAuto = await settings.getDrawerAutoOpen();
      final drPort = await settings.getDrawerPort();
      final drCmd = await settings.getDrawerCommand();
      final drUsePrn = await settings.getDrawerUsePrinter();

      if (!mounted) return;

      setState(() {
        _selectedDeliveryPaperSize = delSize;
        _selectedCashPaperSize = cashSize;
        _selectedCashBillPaperSize = cashBillSize;
        _autoPrintCash = apCash;
        _autoPrintDebt = apDebt;
        _drawerAutoOpen = drAuto;
        _drawerPort = drPort;
        _drawerCommand = drCmd;
        _drawerUsePrinter = drUsePrn;
        _selectedCashPrinter = _resolvePrinter(cashName);
        _selectedCashBillPrinter = _resolvePrinter(cashBillName);
        _selectedTaxPrinter = _resolvePrinter(taxName);
        _selectedDeliveryPrinter = _resolvePrinter(deliveryName);
        _selectedBarcodePrinter = _resolvePrinter(barcodeName);
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('❌ Load Printers Error: $e\n$stack');
      if (mounted) {
        setState(() => _isLoading = false);
        AlertService.show(
            context: context, message: 'โหลดข้อมูลเครื่องพิมพ์ไม่สำเร็จ: $e', type: 'error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าเครื่องพิมพ์ (Printer Settings)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'บันทึกการตั้งค่า',
            onPressed: () => _autoSavePrinters(showMessage: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Cash Slip ──────────────────────────────────────────
                  const SettingsSectionHeader(
                    title: 'เครื่องพิมพ์บิลเงินสด (POS Slip)',
                    icon: Icons.payments,
                    color: Colors.green,
                    isLocal: true,
                  ),
                  _buildCashPrinterCard(),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('พิมพ์ใบเสร็จอัตโนมัติเมื่อขายสด (Auto-Print)'),
                    subtitle: const Text('พิมพ์ทันทีที่กดรับเงินสำเร็จ (ไม่ต้องกดพิมพ์เอง)'),
                    value: _autoPrintCash,
                    onChanged: (val) {
                      setState(() => _autoPrintCash = val);
                      _autoSavePrinters(showMessage: true);
                    },
                  ),
                  const SizedBox(height: 30),

                  // ── Cash Bill (Full Receipt) ───────────────────────────
                  const SettingsSectionHeader(
                    title: 'เครื่องพิมพ์บิลเงินสด (Full Receipt)',
                    icon: Icons.description,
                    color: Colors.indigo,
                    isLocal: true,
                  ),
                  _buildCashBillPrinterCard(),
                  const SizedBox(height: 30),

                  // ── Tax Invoice ───────────────────────────────────────
                  const SettingsSectionHeader(
                    title: 'เครื่องพิมพ์ใบกำกับภาษี (Full Tax)',
                    icon: Icons.receipt_long,
                    color: Colors.orange,
                    isLocal: true,
                  ),
                  _buildPrinterCard(
                    printer: _selectedTaxPrinter,
                    onChanged: (p) {
                      setState(() => _selectedTaxPrinter = p);
                      _autoSavePrinters(showMessage: true);
                    },
                    label: 'TAX',
                  ),
                  const SizedBox(height: 30),

                  // ── Delivery ──────────────────────────────────────────
                  const SettingsSectionHeader(
                    title: 'เครื่องพิมพ์ใบส่งของ/ลูกหนี้',
                    icon: Icons.local_shipping,
                    color: Colors.blue,
                    isLocal: true,
                  ),
                  _buildDeliveryCard(),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('พิมพ์ใบส่งของอัตโนมัติเมื่อขายเชื่อ (Auto-Print)'),
                    subtitle: const Text('พิมพ์ทันทีที่บันทึกบิลขายเชื่อสำเร็จ'),
                    value: _autoPrintDebt,
                    onChanged: (val) {
                      setState(() => _autoPrintDebt = val);
                      _autoSavePrinters(showMessage: true);
                    },
                  ),
                  const SizedBox(height: 30),

                  // ── Label / Barcode ───────────────────────────────────
                  const SettingsSectionHeader(
                    title: 'เครื่องพิมพ์สติกเกอร์ (Label Printer)',
                    icon: Icons.label,
                    color: Colors.teal,
                    isLocal: true,
                  ),
                  _buildBarcodePrinterCard(),
                  const SizedBox(height: 30),

                  // ── Cash Drawer ───────────────────────────────────────
                  const SettingsSectionHeader(
                    title: 'ลิ้นชักเก็บเงิน (Cash Drawer)',
                    icon: Icons.point_of_sale,
                    color: Colors.blueGrey,
                    isLocal: true,
                  ),
                  _buildDrawerCard(),
                  const SizedBox(height: 30),

                  // ── Save All Button ───────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: CustomButton(
                      onPressed: () => _autoSavePrinters(showMessage: true),
                      icon: Icons.save,
                      label: 'บันทึกการตั้งค่าทั้งหมด (Save All Settings)',
                      type: ButtonType.primary,
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }
}
