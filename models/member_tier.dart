class MemberTier {
  final int id;
  final String name;
  final double discountPercentage; // e.g. 5.0 for 5%
  final double pointsMultiplier; // e.g. 2.0 for 2x points
  final double minTotalSpending; // e.g. 10000 to reach this tier
  final String priceLevel; // 'retail', 'member', 'wholesale'

  MemberTier({
    required this.id,
    required this.name,
    this.discountPercentage = 0.0,
    this.pointsMultiplier = 1.0,
    this.minTotalSpending = 0.0,
    this.priceLevel = 'member',
  });

  factory MemberTier.fromJson(Map<String, dynamic> json) {
    return MemberTier(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      discountPercentage:
          double.tryParse(json['discountPercentage'].toString()) ?? 0.0,
      pointsMultiplier:
          double.tryParse(json['pointsMultiplier'].toString()) ?? 1.0,
      minTotalSpending:
          double.tryParse(json['minTotalSpending'].toString()) ?? 0.0,
      priceLevel: json['priceLevel']?.toString() ?? 'member',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'discountPercentage': discountPercentage,
      'pointsMultiplier': pointsMultiplier,
      'minTotalSpending': minTotalSpending,
      'priceLevel': priceLevel,
    };
  }
}
