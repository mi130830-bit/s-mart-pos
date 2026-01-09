import 'package:decimal/decimal.dart';
import 'product.dart';

class OrderItem {
  final int? id; // สำหรับกรณีดึงจาก DB
  final int productId;
  final String productName;
  final Decimal quantity;
  final Decimal price;
  final Decimal discount;
  final Decimal total;

  final String comment;
  final double
      conversionFactor; // Stock Deduction Factor (e.g. 6 for Pack) allow double for simple factor? Or Decimal? Let's keep it simple double for now or Decimal? Decimal is safer. Let's start with financial fields + quantity.

  // เก็บ Product ต้นฉบับ
  final Product? product;

  OrderItem({
    this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    Decimal? discount,
    required this.total,
    this.comment = '',
    this.conversionFactor = 1.0,
    this.product,
  }) : discount = discount ?? Decimal.zero;

  // ✅ เพิ่มเมธอด copyWith
  OrderItem copyWith({
    int? id,
    int? productId,
    String? productName,
    Decimal? quantity,
    Decimal? price,
    Decimal? discount,
    Decimal? total,
    String? comment,
    double? conversionFactor,
    Product? product,
  }) {
    return OrderItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      comment: comment ?? this.comment,
      conversionFactor: conversionFactor ?? this.conversionFactor,
      product: product ?? this.product,
    );
  }

  // แปลงจาก JSON (Database) เป็น Object
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Helper function แปลงตัวเลข
    Decimal parseDecimal(dynamic value) {
      if (value == null) return Decimal.zero;
      if (value is Decimal) return value;
      if (value is String) return Decimal.tryParse(value) ?? Decimal.zero;
      if (value is int) return Decimal.fromInt(value);
      if (value is double) return Decimal.parse(value.toString());
      return Decimal.zero;
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return OrderItem(
      id: int.tryParse(json['id'].toString()),
      productId: int.tryParse(json['productId'].toString()) ?? 0,
      productName: json['productName']?.toString() ?? '',
      quantity: parseDecimal(json['quantity']),
      price: parseDecimal(json['price']),
      discount: parseDecimal(json['discount']),
      total: parseDecimal(json['total']),
      comment: json['comment']?.toString() ?? '',
      conversionFactor: parseDouble(json['conversionFactor']) == 0.0
          ? 1.0
          : parseDouble(json['conversionFactor']),
      product: json['product'] != null
          ? Product.fromJson(json['product'] as Map<String, dynamic>)
          : null,
    );
  }

  // แปลง Object เป็น Map (เผื่อต้องใช้บันทึก)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'quantity': quantity
          .toDouble(), // Serialize as double/string for DB/JSON compatibility
      'price': price.toDouble(),
      'discount': discount.toDouble(),
      'total': total.toDouble(),
      'comment': comment,
      'conversionFactor': conversionFactor,
      'product': product?.toJson(),
    };
  }
}
