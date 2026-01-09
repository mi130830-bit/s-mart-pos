class Supplier {
  final int id;
  final String name;
  final String? phone;
  final String? address;
  final String? saleName;
  final String? saleLineId;

  Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.saleName,
    this.saleLineId,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      if (v is double) return v.toInt();
      return 0;
    }

    return Supplier(
      id: parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      saleName: json['saleName']?.toString(),
      saleLineId: json['saleLineId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'saleName': saleName,
        'saleLineId': saleLineId,
      };
}
