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
  // Logistics
  final double distanceKm;
  // Line CRM
  final String? lineUserId;
  final String? lineDisplayName;
  final String? linePictureUrl;

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
    this.distanceKm = 0.0,
    this.lineUserId,
    this.lineDisplayName,
    this.linePictureUrl,
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

    String? parseString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      // Handle BLOB/List<int> for TEXT columns
      if (value is List<int>) {
        try {
          return String.fromCharCodes(value);
        } catch (_) {
          return null;
        }
      }
      return value.toString();
    }

    return Customer(
      id: parseInt(json['id']),
      memberCode: parseString(json['memberCode']) ?? '',
      firebaseUid: parseString(json['firebaseUid']),
      currentPoints: parseInt(json['currentPoints']),
      title: parseString(json['title']),
      firstName: parseString(json['firstName']) ?? '',
      lastName: parseString(json['lastName']),
      nationalId: parseString(json['nationalId']),
      dateOfBirth: parseDate(json['dateOfBirth']),
      phone: parseString(json['phone']),
      email: parseString(json['email']),
      taxId: parseString(json['taxId']),
      creditLimit: double.tryParse(json['creditLimit'].toString()),
      membershipExpiryDate: parseDate(json['membershipExpiryDate']),
      address: parseString(json['address']),
      shippingAddress: parseString(json['shippingAddress']),
      currentDebt: double.tryParse(json['currentDebt'].toString()) ?? 0.0,
      remarks: parseString(json['remarks']),
      totalSpending: double.tryParse(json['totalSpending'].toString()) ?? 0.0,
      tierId: parseInt(json['tierId']),
      tierName: parseString(json['tierName']),
      lastActivity: parseDate(json['lastActivity']),
      distanceKm: double.tryParse(json['distanceKm'].toString()) ?? 0.0,
      lineUserId: parseString(json['line_user_id']),
      lineDisplayName: parseString(json['line_display_name']),
      linePictureUrl: parseString(json['line_picture_url']),
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
    double? distanceKm,
    String? lineUserId,
    String? lineDisplayName,
    String? linePictureUrl,
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
      distanceKm: distanceKm ?? this.distanceKm,
      lineUserId: lineUserId ?? this.lineUserId,
      lineDisplayName: lineDisplayName ?? this.lineDisplayName,
      linePictureUrl: linePictureUrl ?? this.linePictureUrl,
    );
  }
}
