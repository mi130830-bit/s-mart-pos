class PointReward {
  final int id;
  final String name;
  final String? description;
  final int pointPrice;
  final int stockQuantity;
  final String? imageUrl;
  final bool isActive;
  // Phase 2: Coupon support
  final String rewardType; // 'GIFT' or 'COUPON'
  final double discountValue; // amount in baht for COUPON type
  final int couponExpiryDays; // days until coupon expires

  bool get isCoupon => rewardType == 'COUPON';

  PointReward({
    required this.id,
    required this.name,
    this.description,
    required this.pointPrice,
    required this.stockQuantity,
    this.imageUrl,
    this.isActive = true,
    this.rewardType = 'GIFT',
    this.discountValue = 0,
    this.couponExpiryDays = 30,
  });

  factory PointReward.fromJson(Map<String, dynamic> json) {
    return PointReward(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      pointPrice: int.tryParse(json['point_price']?.toString() ?? '0') ?? 0,
      stockQuantity: int.tryParse(json['stock_quantity']?.toString() ?? '0') ?? 0,
      imageUrl: json['image_url']?.toString(),
      isActive: json['is_active']?.toString() == '1',
      rewardType: json['reward_type']?.toString() ?? 'GIFT',
      discountValue: double.tryParse(json['discount_value']?.toString() ?? '0') ?? 0,
      couponExpiryDays: int.tryParse(json['coupon_expiry_days']?.toString() ?? '30') ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'id': id,
      'name': name,
      'description': description,
      'point_price': pointPrice,
      'stock_quantity': stockQuantity,
      'image_url': imageUrl,
      'is_active': isActive ? 1 : 0,
      'reward_type': rewardType,
      'discount_value': discountValue,
      'coupon_expiry_days': couponExpiryDays,
    };
  }

  PointReward copyWith({
    int? id,
    String? name,
    String? description,
    int? pointPrice,
    int? stockQuantity,
    String? imageUrl,
    bool? isActive,
    String? rewardType,
    double? discountValue,
    int? couponExpiryDays,
  }) {
    return PointReward(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      pointPrice: pointPrice ?? this.pointPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      rewardType: rewardType ?? this.rewardType,
      discountValue: discountValue ?? this.discountValue,
      couponExpiryDays: couponExpiryDays ?? this.couponExpiryDays,
    );
  }
}
