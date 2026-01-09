class ProductBarcode {
  final int id;
  final int productId;
  final String barcode;
  final String unitName;
  final double price;
  final double quantity; // Conversion Factor e.g. 12 for Dozen

  ProductBarcode({
    this.id = 0,
    required this.productId,
    required this.barcode,
    required this.unitName,
    required this.price,
    required this.quantity,
  });

  factory ProductBarcode.fromJson(Map<String, dynamic> json) {
    return ProductBarcode(
      id: int.tryParse(json['id'].toString()) ?? 0,
      productId: int.tryParse(json['productId'].toString()) ?? 0,
      barcode: json['barcode']?.toString() ?? '',
      unitName: json['unitName']?.toString() ?? '',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      quantity: double.tryParse(json['quantity'].toString()) ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'barcode': barcode,
      'unitName': unitName,
      'price': price,
      'quantity': quantity,
    };
  }

  ProductBarcode copyWith({
    int? id,
    int? productId,
    String? barcode,
    String? unitName,
    double? price,
    double? quantity,
  }) {
    return ProductBarcode(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      barcode: barcode ?? this.barcode,
      unitName: unitName ?? this.unitName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }
}
