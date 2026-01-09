class ProductComponent {
  final int id;
  final int parentProductId;
  final int childProductId;
  final double quantity;

  // Optional: For UI display
  final String? childProductName;
  final double? childProductCost;
  final String? childProductUnit;
  final double? childProductStock; // Added

  ProductComponent({
    required this.id,
    required this.parentProductId,
    required this.childProductId,
    required this.quantity,
    this.childProductName,
    this.childProductCost,
    this.childProductUnit,
    this.childProductStock,
  });

  factory ProductComponent.fromJson(Map<String, dynamic> json) {
    return ProductComponent(
      id: int.tryParse(json['id'].toString()) ?? 0,
      parentProductId: int.tryParse(json['parent_product_id'].toString()) ?? 0,
      childProductId: int.tryParse(json['child_product_id'].toString()) ?? 0,
      quantity: double.tryParse(json['quantity'].toString()) ?? 0.0,
      childProductName: json['child_name']?.toString(), // Added via JOIN
      childProductCost: double.tryParse(json['child_cost']?.toString() ??
              json['costPrice']?.toString() ??
              '0') ??
          0.0,
      childProductUnit: json['child_unit']?.toString(),
      childProductStock:
          double.tryParse(json['child_stock']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parent_product_id': parentProductId,
      'child_product_id': childProductId,
      'quantity': quantity,
    };
  }
}
