class AttendanceLog {
  final int id;
  final int employeeId;
  final DateTime date;
  final DateTime? clockIn;
  final DateTime? clockOut;
  // รอบที่ 1
  final DateTime? tempOut;
  final DateTime? backToWork;
  // รอบที่ 2
  final DateTime? tempOut2;
  final DateTime? backToWork2;
  // รอบที่ 3
  final DateTime? tempOut3;
  final DateTime? backToWork3;
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

  /// Helper: รอบที่กำลังออกพักอยู่ (tempOut มีค่า แต่ backToWork ยังไม่มี)
  /// คืนค่า 1, 2, 3 ถ้ากำลังออกพักในรอบนั้น หรือ null ถ้าไม่ได้ออกพัก
  int? get activeTempLeaveRound {
    if (tempOut != null && backToWork == null) return 1;
    if (tempOut2 != null && backToWork2 == null) return 2;
    if (tempOut3 != null && backToWork3 == null) return 3;
    return null;
  }

  /// Helper: รอบที่เพิ่งออกพักไปล่าสุด (ทั้งรอบที่กลับแล้วและยังออกอยู่)
  DateTime? get latestTempOutTime {
    if (tempOut3 != null) return tempOut3;
    if (tempOut2 != null) return tempOut2;
    return tempOut;
  }

  /// Helper: เวลากลับของรอบล่าสุด
  DateTime? get latestBackToWorkTime {
    if (tempOut3 != null) return backToWork3;
    if (tempOut2 != null) return backToWork2;
    if (tempOut != null) return backToWork;
    return null;
  }

  /// Helper: จำนวนรอบที่ออกพักชั่วคราวครบแล้ว (กลับเข้างานแล้ว)
  int get completedTempLeaveRounds {
    int count = 0;
    if (tempOut != null && backToWork != null) count++;
    if (tempOut2 != null && backToWork2 != null) count++;
    if (tempOut3 != null && backToWork3 != null) count++;
    return count;
  }

  /// Helper: รวมเวลาออกพักชั่วคราวทุกรอบที่กลับแล้ว (นาที)
  int get totalTempLeaveMinutes {
    int total = 0;
    if (tempOut != null && backToWork != null) total += backToWork!.difference(tempOut!).inMinutes;
    if (tempOut2 != null && backToWork2 != null) total += backToWork2!.difference(tempOut2!).inMinutes;
    if (tempOut3 != null && backToWork3 != null) total += backToWork3!.difference(tempOut3!).inMinutes;
    return total;
  }

  /// Helper: ยังมีรอบพักที่ว่างอยู่หรือไม่ (ยังออกพักได้อีก)
  bool get canStartNewTempLeave {
    // ถ้ากำลังออกพักอยู่ → ออกซ้ำไม่ได้
    if (activeTempLeaveRound != null) return false;
    // นับรอบที่ใช้ไปแล้ว (ทั้ง active และ completed)
    int usedRounds = 0;
    if (tempOut != null) usedRounds++;
    if (tempOut2 != null) usedRounds++;
    if (tempOut3 != null) usedRounds++;
    return usedRounds < 3;
  }

  AttendanceLog({
    required this.id,
    required this.employeeId,
    required this.date,
    this.clockIn,
    this.clockOut,
    this.tempOut,
    this.backToWork,
    this.tempOut2,
    this.backToWork2,
    this.tempOut3,
    this.backToWork3,
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
      tempOut2: DateTime.tryParse(json['temp_out_2']?.toString() ?? ''),
      backToWork2: DateTime.tryParse(json['back_to_work_2']?.toString() ?? ''),
      tempOut3: DateTime.tryParse(json['temp_out_3']?.toString() ?? ''),
      backToWork3: DateTime.tryParse(json['back_to_work_3']?.toString() ?? ''),
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
      'temp_out_2': tempOut2?.toIso8601String(),
      'back_to_work_2': backToWork2?.toIso8601String(),
      'temp_out_3': tempOut3?.toIso8601String(),
      'back_to_work_3': backToWork3?.toIso8601String(),
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
