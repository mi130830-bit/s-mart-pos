class User {
  final int id;
  final String username;
  final String displayName;
  final String passwordHash; // Store hash in real app, plain for demo if needed
  final String role; // 'ADMIN', 'CASHIER'
  final bool isActive;
  final bool canViewCostPrice;
  final bool canViewProfit;

  User({
    required this.id,
    required this.username,
    required this.displayName,
    required this.passwordHash,
    required this.role,
    this.isActive = true,
    this.canViewCostPrice = false,
    this.canViewProfit = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: int.tryParse(json['id'].toString()) ?? 0,
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? '',
      passwordHash: json['passwordHash'] ?? '',
      role: json['role'] ?? 'CASHIER',
      isActive: (json['isActive'] == 1 || json['isActive'] == true),
      canViewCostPrice:
          (json['canViewCostPrice'] == 1 || json['canViewCostPrice'] == true),
      canViewProfit:
          (json['canViewProfit'] == 1 || json['canViewProfit'] == true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'passwordHash': passwordHash,
      'role': role,
      'isActive': isActive ? 1 : 0,
      'canViewCostPrice': canViewCostPrice ? 1 : 0,
      'canViewProfit': canViewProfit ? 1 : 0,
    };
  }
}
