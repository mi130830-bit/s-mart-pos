class ProductPriceTier {
  final int id;
  int productId;
  double minQuantity;
  double price;
  String? note;

  ProductPriceTier({
    required this.id,
    required this.productId,
    required this.minQuantity,
    required this.price,
    this.note,
  });

  factory ProductPriceTier.fromJson(Map<String, dynamic> json) {
    return ProductPriceTier(
      id: int.tryParse(json['id'].toString()) ?? 0,
      productId: int.tryParse(json['product_id'].toString()) ?? 0,
      minQuantity: double.tryParse(json['min_quantity'].toString()) ?? 0.0,
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      note: json['note']?.toString(),
    );
  }
}
