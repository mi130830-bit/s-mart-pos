import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../models/label_config.dart';
import '../pdf/barcode_label_pdf.dart';
import 'barcode_print_service.dart';
import '../../models/barcode_template.dart';
import '../settings_service.dart';

class LabelPrinterService {
  static final LabelPrinterService _instance = LabelPrinterService._internal();
  factory LabelPrinterService() => _instance;
  LabelPrinterService._internal();

  static const String _keyPrefix = 'printer_mapping_';

  /// Default configurations for each label type
  final Map<LabelType, LabelConfig> _defaults = {
    LabelType.barcode406x108: LabelConfig(
      id: 'barcode_406x108',
      name: 'Barcode (4.06 x 1.08 in)',
      format: PdfPageFormat(
        103.1 * PdfPageFormat.mm,
        27.4 * PdfPageFormat.mm,
        marginAll: 1 * PdfPageFormat.mm,
      ),
      columns: 3,
    ),
    LabelType.barcode32x25: LabelConfig(
      id: 'barcode_32x25',
      name: 'Barcode (32 x 25 mm)',
      format: PdfPageFormat(
        32 * PdfPageFormat.mm,
        25 * PdfPageFormat.mm,
        marginAll: 1 * PdfPageFormat.mm,
      ),
      columns: 1,
    ),
  };

  /// Get config with user-mapped printer name
  Future<LabelConfig> getConfig(LabelType type) async {
    final config = _defaults[type]!;
    final settings = SettingsService();
    final mappedName = settings.getString('$_keyPrefix${config.id}');
    final mappedForm =
        settings.getString('$_keyPrefix${config.id}_form'); // ✅ Load form name
    return config.copyWith(printerName: mappedName, paperFormName: mappedForm);
  }

  /// Map a LabelType to a specific printer name and form name
  Future<void> setPrinterMapping(LabelType type, String? printerName,
      {String? paperFormName}) async {
    final config = _defaults[type]!;
    final settings = SettingsService();
    if (printerName == null || printerName.isEmpty) {
      await settings.remove('$_keyPrefix${config.id}');
      await settings.remove('$_keyPrefix${config.id}_form');
    } else {
      await settings.set('$_keyPrefix${config.id}', printerName);
      if (paperFormName != null && paperFormName.isNotEmpty) {
        await settings.set('$_keyPrefix${config.id}_form', paperFormName);
      } else {
        await settings.remove('$_keyPrefix${config.id}_form');
      }
    }
  }

  /// Core "Smart Print" dispatcher
  Future<void> smartPrintBarcode({
    required LabelType type,
    required String barcode,
    required String name,
    required double price,
  }) async {
    final config = await getConfig(type);

    // ✅ Simplified: Always use the globally selected 'Barcode Printer'
    // ✅ Simplified: Always use the globally selected 'Barcode Printer'
    final settings = SettingsService();
    final String? printerName = settings.getString('barcode_printer_name');

    // 1. Generate PDF Bytes
    final bytes = await _generatePdf(type, config, barcode, name, price);

    // 2. Print
    if (printerName != null && printerName.isNotEmpty) {
      debugPrint('🖨️ Label Printing to: $printerName');
      // Check for virtual printers to use layoutPdf
      if (printerName.toLowerCase().contains('pdf') ||
          printerName.toLowerCase().contains('writer') ||
          printerName.toLowerCase().contains('virtual') ||
          printerName.toLowerCase().contains('save') ||
          printerName.toLowerCase().contains('document') ||
          printerName.toLowerCase().contains('microsoft')) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: 'Label_$barcode',
          format: config.format,
          usePrinterSettings: false,
        );
      } else {
        // Direct print to the selected printer
        await Printing.directPrintPdf(
          printer: Printer(url: printerName, name: printerName),
          onLayout: (_) async => bytes,
          name: 'Label_$barcode',
          format: config.format,
        );
      }
    } else {
      // Fallback: If no printer selected, show dialog
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Label_$barcode',
        format: config.format,
      );
    }
  }

  /// Generate a preview PDF for testing validation and alignment
  Future<Uint8List> testBarcodePreview(LabelType type,
      {bool showRuler = false}) async {
    final config = await getConfig(type);
    // Use a dummy product for preview
    return await _generatePdf(
      type,
      config,
      '885000011111',
      'สินค้าทดสอบ (Test Product)',
      125.00,
      showRuler: showRuler,
    );
  }

  Future<Uint8List> _generatePdf(
    LabelType type,
    LabelConfig config,
    String barcode,
    String name,
    double price, {
    bool showRuler = false,
  }) async {
    // If it's the 4.06x1.08 preset, we use the 3-column template for the user's specific stock
    if (type == LabelType.barcode406x108) {
      final printService = BarcodePrintService();

      // ✅ 1. Try to use the user's actively selected template first
      BarcodeTemplate? targetTemplate =
          await printService.getSelectedTemplate();

      // ✅ 2. Fallback: Find standard template by name
      if (targetTemplate == null) {
        final templates = await printService.getAllTemplates();
        targetTemplate = templates.firstWhere(
          (t) => t.name == 'barcode (4.06 x 1.08 in)',
          orElse: () => printService.createBarcode406x108(),
        );
      }

      return await BarcodeLabelPdf.generateFromTemplate(
        template: targetTemplate,
        products: List.generate(
          targetTemplate.columns,
          (_) => {'barcode': barcode, 'name': name, 'retailPrice': price},
        ),
        showRuler: showRuler,
      );
    }

    // Default legacy generation
    return await BarcodeLabelPdf.generate(
      barcode: barcode,
      name: name,
      price: price,
      pageFormat: config.format,
    );
  }
}
