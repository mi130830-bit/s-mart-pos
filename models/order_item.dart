import 'package:decimal/decimal.dart';
import 'product.dart';

class OrderItem {
  final int? id; // For DB retrieval
  final int productId;
  final String productName;
  final Decimal quantity;
  final Decimal price;
  final Decimal discount;
  final Decimal total;
  final Decimal costPrice; // [Added] Cost Price

  final String comment;
  final double conversionFactor;

  // ✅ Flag: true = ราคาถูก override โดย user (ห้าม recalc อัตโนมัติ)
  final bool isPriceOverridden;

  // Store original Product
  final Product? product;

  OrderItem({
    this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    Decimal? discount,
    required this.total,
    Decimal? costPrice,
    this.comment = '',
    this.conversionFactor = 1.0,
    this.isPriceOverridden = false,
    this.product,
  })  : discount = discount ?? Decimal.zero,
        costPrice = costPrice ?? Decimal.zero;

  // [Method] copyWith method
  OrderItem copyWith({
    int? id,
    int? productId,
    String? productName,
    Decimal? quantity,
    Decimal? price,
    Decimal? discount,
    Decimal? total,
    Decimal? costPrice,
    String? comment,
    double? conversionFactor,
    bool? isPriceOverridden,
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
      costPrice: costPrice ?? this.costPrice,
      comment: comment ?? this.comment,
      conversionFactor: conversionFactor ?? this.conversionFactor,
      isPriceOverridden: isPriceOverridden ?? this.isPriceOverridden,
      product: product ?? this.product,
    );
  }

  // Convert from JSON (Database) to Object
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Helper function to parse numbers
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
      costPrice: parseDecimal(json['costPrice']),
      comment: json['comment']?.toString() ?? '',
      conversionFactor: parseDouble(json['conversionFactor']) == 0.0
          ? 1.0
          : parseDouble(json['conversionFactor']),
      isPriceOverridden: json['isPriceOverridden'] == true,
      product: json['product'] != null
          ? Product.fromJson(json['product'] as Map<String, dynamic>)
          : null,
    );
  }

  // Convert Object to Map (for saving)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'quantity': quantity.toDouble(),
      'price': price.toDouble(),
      'discount': discount.toDouble(),
      'total': total.toDouble(),
      'costPrice': costPrice.toDouble(),
      'comment': comment,
      'conversionFactor': conversionFactor,
      'isPriceOverridden': isPriceOverridden,
      'product': product?.toJson(),
    };
  }
}
