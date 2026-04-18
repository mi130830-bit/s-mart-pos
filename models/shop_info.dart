class ShopInfo {
  final String name;
  final String address;
  final String phone;
  final String taxId;
  final String footer;
  final String promptPayId;
  final String shortName; // For 80mm
  final String shortAddress; // For 80mm

  const ShopInfo({
    required this.name,
    required this.address,
    required this.phone,
    required this.taxId,
    required this.footer,
    required this.promptPayId,
    required this.shortName,
    required this.shortAddress,
  });

  factory ShopInfo.empty() {
    return const ShopInfo(
      name: 'My Shop',
      address: '',
      phone: '',
      taxId: '',
      footer: '',
      promptPayId: '',
      shortName: '',
      shortAddress: '',
    );
  }

  ShopInfo copyWith({
    String? name,
    String? address,
    String? phone,
    String? taxId,
    String? footer,
    String? promptPayId,
    String? shortName,
    String? shortAddress,
  }) {
    return ShopInfo(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      taxId: taxId ?? this.taxId,
      footer: footer ?? this.footer,
      promptPayId: promptPayId ?? this.promptPayId,
      shortName: shortName ?? this.shortName,
      shortAddress: shortAddress ?? this.shortAddress,
    );
  }
}
