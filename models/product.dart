import 'product_price_tier.dart';

class Product {
  final int id;
  final String? barcode;
  final String name;
  final String? alias;
  final int productType; // 0=ทั่วไป, 1=ชั่งน้ำหนัก
  final int? categoryId;
  final int? unitId;
  final int? supplierId;
  final double costPrice;
  final double retailPrice;
  final double? wholesalePrice;
  final double? memberRetailPrice;
  final double? memberWholesalePrice;
  final int vatType; // 0=No VAT, 1=VAT Included, 2=VAT Excluded
  final bool allowPriceEdit;
  final double stockQuantity;
  final bool trackStock;
  final double? reorderPoint;
  final double? overstockPoint;
  final int? purchaseLimit;
  final String? shelfLocation;
  final String? warehousePattern;
  final int points;
  final String? imageUrl;
  final DateTime? expiryDate;
  final List<dynamic>? components;
  final List<ProductPriceTier>? priceTiers;

  bool get isComposite => components != null && components!.isNotEmpty;

  Product({
    required this.id,
    this.barcode,
    required this.name,
    this.alias,
    required this.productType,
    this.categoryId,
    this.unitId,
    this.supplierId,
    required this.costPrice,
    required this.retailPrice,
    this.wholesalePrice,
    this.memberRetailPrice,
    this.memberWholesalePrice,
    this.vatType = 0,
    this.allowPriceEdit = false,
    required this.stockQuantity,
    this.trackStock = true,
    this.reorderPoint,
    this.overstockPoint,
    this.purchaseLimit,
    this.shelfLocation,
    this.warehousePattern,
    required this.points,
    this.imageUrl,
    this.expiryDate,
    this.components,
    this.priceTiers,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        String cleaned = value.trim().replaceAll(RegExp(r'[^\d.-]'), '');
        return double.tryParse(cleaned) ?? 0.0;
      }
      return 0.0;
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    bool parseBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value == 1;
      return value.toString() == '1';
    }

    // Helper สำหรับแปลงวันที่
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return Product(
      id: parseInt(json['id']),
      barcode: json['barcode']?.toString(),
      name: json['name']?.toString() ?? '',
      alias: json['alias']?.toString(),
      productType: parseInt(json['productType']),
      categoryId:
          json['categoryId'] != null ? parseInt(json['categoryId']) : null,
      unitId: json['unitId'] != null ? parseInt(json['unitId']) : null,
      supplierId:
          json['supplierId'] != null ? parseInt(json['supplierId']) : null,

      costPrice: parseDouble(json['costPrice']),
      retailPrice: parseDouble(json['retailPrice']),
      wholesalePrice: parseDouble(json['wholesalePrice']),
      memberRetailPrice: parseDouble(json['memberRetailPrice']),
      memberWholesalePrice: parseDouble(json['memberWholesalePrice']),

      vatType: parseInt(json['vatType']),

      allowPriceEdit: parseBool(json['allowPriceEdit']),
      stockQuantity: parseDouble(json['stockQuantity']),
      trackStock: parseBool(json['trackStock']),
      reorderPoint: parseDouble(json['reorderPoint']),
      overstockPoint: parseDouble(json['overstockPoint']),

      purchaseLimit: json['purchaseLimit'] != null
          ? parseInt(json['purchaseLimit'])
          : null,
      shelfLocation: json['shelfLocation']?.toString(),
      warehousePattern: json['warehousePattern']?.toString(),
      points: parseInt(json['points']),
      imageUrl: json['imageUrl']?.toString(),
      expiryDate: parseDate(json['expiryDate']),
      components: json['components'],
      // priceTiers usually not loaded in basic list to save perf, keeping null by default unless populated
    );
  }

  Product copyWith({
    int? id,
    String? barcode,
    String? name,
    String? alias,
    int? productType,
    int? categoryId,
    int? unitId,
    int? supplierId,
    double? costPrice,
    double? retailPrice,
    double? wholesalePrice,
    double? memberRetailPrice,
    double? memberWholesalePrice,
    int? vatType,
    bool? allowPriceEdit,
    double? stockQuantity,
    bool? trackStock,
    double? reorderPoint,
    double? overstockPoint,
    int? purchaseLimit,
    String? shelfLocation,
    String? warehousePattern,
    int? points,
    String? imageUrl,
    DateTime? expiryDate,
    List<dynamic>? components,
    List<ProductPriceTier>? priceTiers,
  }) {
    return Product(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      alias: alias ?? this.alias,
      productType: productType ?? this.productType,
      categoryId: categoryId ?? this.categoryId,
      unitId: unitId ?? this.unitId,
      supplierId: supplierId ?? this.supplierId,
      costPrice: costPrice ?? this.costPrice,
      retailPrice: retailPrice ?? this.retailPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      memberRetailPrice: memberRetailPrice ?? this.memberRetailPrice,
      memberWholesalePrice: memberWholesalePrice ?? this.memberWholesalePrice,
      vatType: vatType ?? this.vatType,
      allowPriceEdit: allowPriceEdit ?? this.allowPriceEdit,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      trackStock: trackStock ?? this.trackStock,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      overstockPoint: overstockPoint ?? this.overstockPoint,
      purchaseLimit: purchaseLimit ?? this.purchaseLimit,
      shelfLocation: shelfLocation ?? this.shelfLocation,
      warehousePattern: warehousePattern ?? this.warehousePattern,
      points: points ?? this.points,
      imageUrl: imageUrl ?? this.imageUrl,
      expiryDate: expiryDate ?? this.expiryDate,
      components: components ?? this.components,
      priceTiers: priceTiers ?? this.priceTiers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'alias': alias,
      'productType': productType,
      'categoryId': categoryId,
      'unitId': unitId,
      'supplierId': supplierId,
      'costPrice': costPrice,
      'retailPrice': retailPrice,
      'wholesalePrice': wholesalePrice,
      'memberRetailPrice': memberRetailPrice,
      'memberWholesalePrice': memberWholesalePrice,
      'vatType': vatType,
      'allowPriceEdit': allowPriceEdit ? 1 : 0,
      'stockQuantity': stockQuantity,
      'trackStock': trackStock ? 1 : 0,
      'reorderPoint': reorderPoint,
      'overstockPoint': overstockPoint,
      'purchaseLimit': purchaseLimit,
      'shelfLocation': shelfLocation,
      'warehousePattern': warehousePattern,
      'points': points,
      'imageUrl': imageUrl,
      'expiryDate': expiryDate?.toIso8601String(),
      'components': components,
    };
  }
}
