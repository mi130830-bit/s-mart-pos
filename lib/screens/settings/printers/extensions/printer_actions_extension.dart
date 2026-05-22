// ignore_for_file: deprecated_member_use, invalid_use_of_protected_member, library_private_types_in_public_api
part of '../../printer_settings_screen.dart';

/// Extension for save/load helpers and preview dialog.
/// Uses `part of` to access private state fields in _PrinterSettingsScreenState directly.
extension PrinterActionsExtension on _PrinterSettingsScreenState {
  // ─── Printer Resolution ─────────────────────────────────────────────────────

  Printer? _resolvePrinter(String? name) {
    if (name == null || name.isEmpty) return null;
    final existing = _findPrinterByName(name);
    if (existing != null) return existing;
    debugPrint('⚠️ Printer "$name" offline/missing. Restoring setting for display.');
    final restored = Printer(url: name, name: name);
    if (!_printers.any((p) => p.name == name)) {
      _printers.add(restored);
    }
    return restored;
  }

  Printer? _findPrinterByName(String? name) {
    if (name == null || name.isEmpty) return null;
    String normalize(String s) => s.trim().toLowerCase().replaceAll(r'\', '/');
    final target = normalize(name);
    try {
      return _printers.firstWhere((p) {
        final source = normalize(p.name);
        return source == target || p.name == name;
      });
    } catch (_) {
      return null;
    }
  }

  // ─── Auto-Save ──────────────────────────────────────────────────────────────

  Future<void> _autoSavePrinters({bool showMessage = false}) async {
    if (_isLoading) {
      debugPrint('⚠️ Skipped Auto-Save: Settings are still loading.');
      return;
    }
    try {
      final settings = LocalSettingsService();
      await settings.setCashPrinterName(_selectedCashPrinter?.name);
      await settings.setCashBillPrinterName(_selectedCashBillPrinter?.name);
      await settings.setTaxPrinterName(_selectedTaxPrinter?.name);
      await settings.setDeliveryPrinterName(_selectedDeliveryPrinter?.name);
      await settings.setBarcodePrinterName(_selectedBarcodePrinter?.name);
      await settings.setCashPaperSize(_selectedCashPaperSize);
      await settings.setCashBillPaperSize(_selectedCashBillPaperSize);
      await settings.setDeliveryPaperSize(_selectedDeliveryPaperSize);
      await settings.setAutoPrintReceipt(_autoPrintCash);
      await settings.setAutoPrintDeliveryNote(_autoPrintDebt);
      await settings.setDrawerAutoOpen(_drawerAutoOpen);
      await settings.setDrawerPort(_drawerPort);
      await settings.setDrawerCommand(_drawerCommand);
      await settings.setDrawerUsePrinter(_drawerUsePrinter);
      PrintSettingsHelper.clearCache();
      debugPrint('💾 Auto-saved printer settings');
      if (mounted && showMessage) {
        AlertService.show(
          context: context,
          message: 'บันทึกการตั้งค่าเครื่องพิมพ์เรียบร้อยแล้ว',
          type: 'success',
        );
      }
    } catch (e) {
      debugPrint('❌ Auto-save error: $e');
    }
  }

  // ─── PDF Preview Dialog ──────────────────────────────────────────────────────

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
}
