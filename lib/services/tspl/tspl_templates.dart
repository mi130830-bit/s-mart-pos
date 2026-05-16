import '../../models/label_data.dart';
import '../../models/label_config.dart';

abstract class TsplTemplate {
  String build(LabelData data);
}

/// Template for 4.06 x 1.08 inch (103.1 x 27.4 mm) - 3 Columns
class Barcode406x108Template implements TsplTemplate {
  @override
  String build(LabelData data) {
    // Note: TSPL coordinates are in dots. 203 DPI usually means 8 dots/mm.
    // 103mm width = ~824 dots
    // 27mm height = ~216 dots

    // We iterate the quantity within the command or rely on PRINT n,1
    // Usually, for bulk print, we generate one label and let the printer handle quantity.
    // But if we have 3 columns, we might need a specific layout.

    return '''
SIZE 103.1 mm, 27.4 mm
GAP 3 mm, 0
DIRECTION 1
CLS
TEXT 10,10,"TSS24.BF2",0,1,1,"${data.title}"
BARCODE 10,60,"128",60,1,0,2,2,"${data.barcode}"
TEXT 10,140,"TSS24.BF2",0,1,1,"BT: ${data.price.toStringAsFixed(2)}"
PRINT ${data.quantity},1
''';
  }
}

/// Template for 32 x 25 mm - Single Column
class Barcode32x25Template implements TsplTemplate {
  @override
  String build(LabelData data) {
    return '''
SIZE 32 mm, 25 mm
GAP 2 mm, 0
DIRECTION 1
CLS
OFFSET 0
TEXT 10,10,"TSS24.BF2",0,1,1,"${data.title}"
BARCODE 10,50,"128",50,1,0,2,2,"${data.barcode}"
PRINT ${data.quantity},1
''';
  }
}

class ShippingA6Template implements TsplTemplate {
  @override
  String build(LabelData data) {
    return '''
SIZE 100 mm, 150 mm
GAP 3 mm, 0
DIRECTION 1
CLS
TEXT 50,50,"TSS32.BF2",0,1,1,"${data.title}"
BARCODE 50,150,"128",100,1,0,3,3,"${data.barcode}"
TEXT 50,300,"TSS24.BF2",0,1,1,"SHIPMENT ID: ${data.barcode}"
PRINT ${data.quantity},1
''';
  }
}

class TsplTemplateFactory {
  static TsplTemplate getTemplate(LabelType type) {
    switch (type) {
      case LabelType.barcode406x108:
        return Barcode406x108Template();
      case LabelType.barcode32x25:
        return Barcode32x25Template();
      case LabelType.shippingA6:
        return ShippingA6Template();
      default:
        // Fallback for receipt80mm or others to 32x25 for now
        return Barcode32x25Template();
    }
  }
}
