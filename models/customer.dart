class Customer {
  final int id;
  final String memberCode;
  final String? firebaseUid;
  final int currentPoints;
  final String? title;
  final String firstName;
  final String? lastName;
  final String? nationalId;
  final DateTime? dateOfBirth;
  final String? phone;
  final String? email;
  final String? taxId;
  final double? creditLimit;
  final DateTime? membershipExpiryDate;
  final String? address;
  final String? shippingAddress;
  final double currentDebt;
  final String? remarks;
  final double totalSpending;
  // CRM
  final int? tierId;
  final String? tierName; // For easy display
  final DateTime? lastActivity;

  Customer({
    required this.id,
    required this.memberCode,
    this.firebaseUid,
    required this.currentPoints,
    this.title,
    required this.firstName,
    this.lastName,
    this.nationalId,
    this.dateOfBirth,
    this.phone,
    this.email,
    this.taxId,
    this.creditLimit,
    this.membershipExpiryDate,
    this.address,
    this.shippingAddress,
    this.currentDebt = 0.0,
    this.remarks,
    this.totalSpending = 0.0,
    this.tierId,
    this.tierName,
    this.lastActivity,
  });

  String get name => '$firstName ${lastName ?? ''}'.trim();

  // แปลงจาก JSON (Database) เป็น Object
  factory Customer.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is int) return value;
      return 0;
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String) return DateTime.tryParse(value);
      if (value is DateTime) return value;
      return null;
    }

    return Customer(
      id: parseInt(json['id']),
      memberCode: json['memberCode']?.toString() ?? '',
      firebaseUid: json['firebaseUid'] as String?,
      currentPoints: parseInt(json['currentPoints']),
      title: json['title'] as String?,
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName'] as String?,
      nationalId: json['nationalId'] as String?,
      dateOfBirth: parseDate(json['dateOfBirth']),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      taxId: json['taxId'] as String?,
      creditLimit: double.tryParse(json['creditLimit'].toString()),
      membershipExpiryDate: parseDate(json['membershipExpiryDate']),
      address: json['address'] as String?,
      shippingAddress: json['shippingAddress'] as String?,
      currentDebt: double.tryParse(json['currentDebt'].toString()) ?? 0.0,
      remarks: json['remarks'] as String?,
      totalSpending: double.tryParse(json['totalSpending'].toString()) ?? 0.0,
      tierId: parseInt(json['tierId']),
      tierName: json['tierName']?.toString(),
      lastActivity: parseDate(json['lastActivity']),
    );
  }

  // copyWith method
  Customer copyWith({
    int? id,
    String? memberCode,
    String? firebaseUid,
    int? currentPoints,
    String? title,
    String? firstName,
    String? lastName,
    String? nationalId,
    DateTime? dateOfBirth,
    String? phone,
    String? email,
    String? taxId,
    double? creditLimit,
    DateTime? membershipExpiryDate,
    String? address,
    String? shippingAddress,
    double? currentDebt,
    String? remarks,
    double? totalSpending,
    int? tierId,
    String? tierName,
    DateTime? lastActivity,
  }) {
    return Customer(
      id: id ?? this.id,
      memberCode: memberCode ?? this.memberCode,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      currentPoints: currentPoints ?? this.currentPoints,
      title: title ?? this.title,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      nationalId: nationalId ?? this.nationalId,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      taxId: taxId ?? this.taxId,
      creditLimit: creditLimit ?? this.creditLimit,
      membershipExpiryDate: membershipExpiryDate ?? this.membershipExpiryDate,
      address: address ?? this.address,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      currentDebt: currentDebt ?? this.currentDebt,
      remarks: remarks ?? this.remarks,
      totalSpending: totalSpending ?? this.totalSpending,
      tierId: tierId ?? this.tierId,
      tierName: tierName ?? this.tierName,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }
}
