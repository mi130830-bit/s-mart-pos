import 'dart:convert';

enum BarcodeElementType { text, barcode, qrCode, logo, rectangle }

enum BarcodeDataSource {
  none,
  barcode,
  productName,
  retailPrice,
  wholesalePrice
}

class BarcodeElement {
  String id;
  BarcodeElementType type;
  double x;
  double y;
  double width;
  double height;
  String content;
  double fontSize;
  BarcodeDataSource dataSource;
  String textAlign; // left, center, right
  String color; // e.g., 'black'

  BarcodeElement({
    required this.id,
    required this.type,
    this.x = 0,
    this.y = 0,
    this.width = 100,
    this.height = 40,
    this.content = 'ข้อความ',
    this.fontSize = 12,
    this.dataSource = BarcodeDataSource.none,
    this.textAlign = 'center',
    this.color = 'black',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'content': content,
      'fontSize': fontSize,
      'dataSource': dataSource.name,
      'textAlign': textAlign,
      'color': color,
    };
  }

  factory BarcodeElement.fromMap(Map<String, dynamic> map) {
    return BarcodeElement(
      id: map['id'],
      type: BarcodeElementType.values.firstWhere((e) => e.name == map['type']),
      x: map['x']?.toDouble() ?? 0.0,
      y: map['y']?.toDouble() ?? 0.0,
      width: map['width']?.toDouble() ?? 100.0,
      height: map['height']?.toDouble() ?? 40.0,
      content: map['content'] ?? '',
      fontSize: map['fontSize']?.toDouble() ?? 12.0,
      dataSource: BarcodeDataSource.values.firstWhere(
          (e) => e.name == (map['dataSource'] ?? 'none'),
          orElse: () => BarcodeDataSource.none),
      textAlign: map['textAlign'] ?? 'center',
      color: map['color'] ?? 'black',
    );
  }
}

class BarcodeTemplate {
  String id;
  String name;
  double paperWidth; // mm
  double paperHeight; // mm
  int rows;
  int columns;
  double marginTop;
  double marginBottom;
  double marginLeft;
  double marginRight;
  double labelWidth;
  double labelHeight;
  double horizontalGap;
  double verticalGap;
  String shape; // rectangle, rounded
  bool printBorder;
  double borderWidth;
  bool printDebug; // เพิ่มมาเพื่อใช้ทดสอบขอบขาด
  String orientation; // 'portrait' หรือ 'landscape'

  BarcodeTemplate({
    required this.id,
    required this.name,
    this.paperWidth = 100,
    this.paperHeight = 30,
    this.rows = 1,
    this.columns = 3,
    this.marginTop = 0,
    this.marginBottom = 0,
    this.marginLeft = 0,
    this.marginRight = 0,
    this.labelWidth = 32,
    this.labelHeight = 25,
    this.horizontalGap = 2,
    this.verticalGap = 0,
    this.shape = 'rounded',
    this.printBorder = false,
    this.borderWidth = 1,
    this.printDebug = false,
    this.elements = const [],
    this.orientation =
        'landscape', // ตั้งค่าเริ่มต้นเป็น landscape สำหรับบาร์โค้ด
  });

  List<BarcodeElement> elements;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'paperWidth': paperWidth,
      'paperHeight': paperHeight,
      'rows': rows,
      'columns': columns,
      'marginTop': marginTop,
      'marginBottom': marginBottom,
      'marginLeft': marginLeft,
      'marginRight': marginRight,
      'labelWidth': labelWidth,
      'labelHeight': labelHeight,
      'horizontalGap': horizontalGap,
      'verticalGap': verticalGap,
      'shape': shape,
      'printBorder': printBorder,
      'borderWidth': borderWidth,
      'printDebug': printDebug,
      'orientation': orientation,
      'elements': elements.map((x) => x.toMap()).toList(),
    };
  }

  factory BarcodeTemplate.fromMap(Map<String, dynamic> map) {
    return BarcodeTemplate(
      id: map['id'],
      name: map['name'] ?? '',
      paperWidth: map['paperWidth']?.toDouble() ?? 100.0,
      paperHeight: map['paperHeight']?.toDouble() ?? 30.0,
      rows: map['rows']?.toInt() ?? 1,
      columns: map['columns']?.toInt() ?? 3,
      marginTop: map['marginTop']?.toDouble() ?? 0.0,
      marginBottom: map['marginBottom']?.toDouble() ?? 0.0,
      marginLeft: map['marginLeft']?.toDouble() ?? 0.0,
      marginRight: map['marginRight']?.toDouble() ?? 0.0,
      labelWidth: map['labelWidth']?.toDouble() ?? 32.0,
      labelHeight: map['labelHeight']?.toDouble() ?? 25.0,
      horizontalGap: map['horizontalGap']?.toDouble() ?? 2.0,
      verticalGap: map['verticalGap']?.toDouble() ?? 0.0,
      shape: map['shape'] ?? 'rounded',
      printBorder: map['printBorder'] ?? false,
      borderWidth: map['borderWidth']?.toDouble() ?? 1.0,
      printDebug: map['printDebug'] ?? false,
      orientation: map['orientation'] ?? 'landscape',
      elements: List<BarcodeElement>.from(
          map['elements']?.map((x) => BarcodeElement.fromMap(x)) ?? []),
    );
  }

  BarcodeTemplate copyWith({
    String? id,
    String? name,
    double? paperWidth,
    double? paperHeight,
    int? rows,
    int? columns,
    double? marginTop,
    double? marginBottom,
    double? marginLeft,
    double? marginRight,
    double? labelWidth,
    double? labelHeight,
    double? horizontalGap,
    double? verticalGap,
    String? shape,
    bool? printBorder,
    double? borderWidth,
    bool? printDebug,
    String? orientation,
    List<BarcodeElement>? elements,
  }) {
    return BarcodeTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      paperWidth: paperWidth ?? this.paperWidth,
      paperHeight: paperHeight ?? this.paperHeight,
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
      marginLeft: marginLeft ?? this.marginLeft,
      marginRight: marginRight ?? this.marginRight,
      labelWidth: labelWidth ?? this.labelWidth,
      labelHeight: labelHeight ?? this.labelHeight,
      horizontalGap: horizontalGap ?? this.horizontalGap,
      verticalGap: verticalGap ?? this.verticalGap,
      shape: shape ?? this.shape,
      printBorder: printBorder ?? this.printBorder,
      borderWidth: borderWidth ?? this.borderWidth,
      printDebug: printDebug ?? this.printDebug,
      orientation: orientation ?? this.orientation,
      elements: elements ?? this.elements,
    );
  }

  String toJson() => json.encode(toMap());

  factory BarcodeTemplate.fromJson(String source) =>
      BarcodeTemplate.fromMap(json.decode(source));
}
