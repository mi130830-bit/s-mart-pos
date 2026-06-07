class AttendanceLog {
  final int id;
  final int employeeId;
  final DateTime date;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final DateTime? tempOut;
  final DateTime? backToWork;
  final String method; // 'PIN', 'ADMIN_OVERRIDE', 'MOBILE_GPS', 'FINGERPRINT'
  final String? deviceInfo;
  final double? latitude;
  final double? longitude;
  final String status; // 'ON_TIME', 'LATE', 'ABSENT', 'HALF_DAY', 'LEAVE'
  final String? overrideReason;
  final int? overrideBy;
  final String? note;
  final DateTime? createdAt;
  
  // Joined field
  final String? employeeName;

  AttendanceLog({
    required this.id,
    required this.employeeId,
    required this.date,
    this.clockIn,
    this.clockOut,
    this.tempOut,
    this.backToWork,
    required this.method,
    this.deviceInfo,
    this.latitude,
    this.longitude,
    required this.status,
    this.overrideReason,
    this.overrideBy,
    this.note,
    this.createdAt,
    this.employeeName,
  });

  factory AttendanceLog.fromJson(Map<String, dynamic> json) {
    return AttendanceLog(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      employeeId: int.tryParse(json['employee_id']?.toString() ?? '0') ?? 0,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      clockIn: DateTime.tryParse(json['clock_in']?.toString() ?? ''),
      clockOut: DateTime.tryParse(json['clock_out']?.toString() ?? ''),
      tempOut: DateTime.tryParse(json['temp_out']?.toString() ?? ''),
      backToWork: DateTime.tryParse(json['back_to_work']?.toString() ?? ''),
      method: json['method']?.toString() ?? 'PIN',
      deviceInfo: json['device_info']?.toString(),
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'ON_TIME',
      overrideReason: json['override_reason']?.toString(),
      overrideBy: int.tryParse(json['override_by']?.toString() ?? ''),
      note: json['note']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      employeeName: json['employeeName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'date': "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
      'clock_in': clockIn?.toIso8601String(),
      'clock_out': clockOut?.toIso8601String(),
      'temp_out': tempOut?.toIso8601String(),
      'back_to_work': backToWork?.toIso8601String(),
      'method': method,
      'device_info': deviceInfo,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'override_reason': overrideReason,
      'override_by': overrideBy,
      'note': note,
    };
  }
}
