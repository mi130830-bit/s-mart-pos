class ProductType {
  final int id;
  final String name;
  final bool isWeighing;

  ProductType({
    required this.id,
    required this.name,
    this.isWeighing = false,
  });

  factory ProductType.fromJson(Map<String, dynamic> json) {
    return ProductType(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      isWeighing: (json['isWeighing'] == 1 || json['isWeighing'] == true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isWeighing': isWeighing ? 1 : 0,
    };
  }
}
