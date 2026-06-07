class EmployeeProfile {
  final int id;
  final int? userId;
  final String? firebaseUid;
  final String? employeeCode;
  final String? displayName;
  final String? idCard;
  final String? phone;
  final String? position;
  final String roleType; // 'OFFICE', 'DRIVER', etc.
  final String wageType; // 'DAILY', 'MONTHLY'
  final double dailyWage;
  final double baseSalary;
  final String payCycle; // 'DAILY', 'WEEKLY', 'MONTHLY'
  final int payDayOfWeek; // 1-7
  final double tripRate;
  final int annualSickLeave;
  final int annualPersonalLeave;
  final int annualVacationLeave;
  final DateTime? hireDate;
  final DateTime? resignDate;
  final String? pinCode; // BCrypt hash
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int sortOrder;
  
  // Removed duplicate joined field

  EmployeeProfile({
    required this.id,
    this.userId,
    this.firebaseUid,
    this.employeeCode,
    this.displayName,
    this.idCard,
    this.phone,
    this.position,
    required this.roleType,
    required this.wageType,
    this.dailyWage = 0.0,
    this.baseSalary = 0.0,
    this.payCycle = 'MONTHLY',
    this.payDayOfWeek = 1,
    this.tripRate = 0.0,
    this.annualSickLeave = 30,
    this.annualPersonalLeave = 3,
    this.annualVacationLeave = 6,
    this.hireDate,
    this.resignDate,
    this.pinCode,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.sortOrder = 0,
  });

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) {
    return EmployeeProfile(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      userId: json['user_id'] != null ? int.tryParse(json['user_id'].toString()) : null,
      firebaseUid: json['firebase_uid']?.toString(),
      employeeCode: json['employee_code']?.toString(),
      displayName: json['display_name']?.toString() ?? json['nickname']?.toString(),
      idCard: json['id_card']?.toString(),
      phone: json['phone']?.toString(),
      position: json['position']?.toString(),
      roleType: json['role_type']?.toString() ?? json['employee_type']?.toString() ?? 'OFFICE',
      wageType: json['wage_type']?.toString() ?? 'MONTHLY',
      dailyWage: double.tryParse(json['daily_wage']?.toString() ?? '0') ?? 0.0,
      baseSalary: double.tryParse(json['base_salary']?.toString() ?? '0') ?? 0.0,
      payCycle: json['pay_cycle']?.toString() ?? 'MONTHLY',
      payDayOfWeek: int.tryParse(json['pay_day_of_week']?.toString() ?? '1') ?? 1,
      tripRate: double.tryParse(json['trip_rate']?.toString() ?? '0') ?? 0.0,
      annualSickLeave: int.tryParse(json['annual_sick_leave']?.toString() ?? '30') ?? 30,
      annualPersonalLeave: int.tryParse(json['annual_personal_leave']?.toString() ?? '3') ?? 3,
      annualVacationLeave: int.tryParse(json['annual_vacation_leave']?.toString() ?? '6') ?? 6,
      hireDate: DateTime.tryParse(json['hire_date']?.toString() ?? ''),
      resignDate: DateTime.tryParse(json['resign_date']?.toString() ?? ''),
      pinCode: json['pin_code']?.toString(),
      isActive: (json['is_active'].toString() == '1' || json['is_active'] == true || json['is_active'].toString().toLowerCase() == 'true'),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'firebase_uid': firebaseUid,
      'employee_code': employeeCode,
      'display_name': displayName,
      'id_card': idCard,
      'phone': phone,
      'position': position,
      'role_type': roleType,
      'wage_type': wageType,
      'daily_wage': dailyWage,
      'base_salary': baseSalary,
      'pay_cycle': payCycle,
      'pay_day_of_week': payDayOfWeek,
      'trip_rate': tripRate,
      'annual_sick_leave': annualSickLeave,
      'annual_personal_leave': annualPersonalLeave,
      'annual_vacation_leave': annualVacationLeave,
      'hire_date': hireDate?.toIso8601String(),
      'resign_date': resignDate?.toIso8601String(),
      'pin_code': pinCode,
      'is_active': isActive ? 1 : 0,
      'sort_order': sortOrder,
    };
  }
}
