import 'package:pdf/pdf.dart';

enum LabelType {
  barcode406x108, // 4.06 x 1.08 in
  barcode32x25, // 32 x 25 mm
  receipt80mm, // Standard receipt
  shippingA6, // Waybill A6
}

class LabelConfig {
  final String id;
  final String name;
  final PdfPageFormat format;
  final int columns;
  final String? printerName; // ✅ Restored Missing Field
  final String?
      paperFormName; // ✅ New: Stores the driver form name (e.g. "barcode 32x25")

  LabelConfig({
    required this.id,
    required this.name,
    required this.format,
    this.columns = 1,
    this.printerName,
    this.paperFormName,
  });

  LabelConfig copyWith({String? printerName, String? paperFormName}) {
    return LabelConfig(
      id: id,
      name: name,
      format: format,
      columns: columns,
      printerName: printerName ?? this.printerName,
      paperFormName: paperFormName ?? this.paperFormName,
    );
  }
}
