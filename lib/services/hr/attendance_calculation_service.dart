import '../../models/hr/attendance_log.dart';

class AttendanceCalculationService {
  /// แมป roleType → เวลาเข้างาน (กะเริ่มงาน)
  ///   - DRIVER (หลังบ้าน) → 07:30
  ///   - REQUESTER, GAS_STATION, ADMIN, อื่นๆ (หน้าบ้าน/ปั้ม) → 07:00
  static ({int hour, int minute}) getShiftStart(String roleType) {
    switch (roleType.toUpperCase()) {
      case 'DRIVER':
        return (hour: 7, minute: 30);
      default:
        return (hour: 7, minute: 0);
    }
  }

  /// ตรวจสอบว่าเข้างานสายหรือไม่ โดยเทียบกับเวลาเริ่มกะของ role นั้น
  static bool isLate(DateTime clockInTime, String roleType) {
    final shift = getShiftStart(roleType);
    final shiftStart = DateTime(
      clockInTime.year, clockInTime.month, clockInTime.day,
      shift.hour, shift.minute,
    );
    return clockInTime.isAfter(shiftStart);
  }

  /// คำนวณวันทำงานของ 1 บันทึก (1 วัน) เป็นสัดส่วน (0.0 – 1.0)
  /// ฐาน: 1 วัน = 10 ชั่วโมง (07:00–17:00 หรือ 07:30–17:00 ตาม role)
  ///
  /// [roleType] ใช้กำหนดเวลาเริ่มกะ ค่า default คือ 'REQUESTER' (07:00)
  static double calculateFractionalDays(
    AttendanceLog log, {
    bool isFinalDay = false,
    String roleType = 'REQUESTER',
  }) {
    if (log.clockIn == null) return 0.0;
    if (log.status == 'ABSENT') return 0.0;

    // พี่ติสั่ง: วันสุดท้ายของรอบบิลให้ตีเป็น 1.0 เต็มวันเสมอ
    if (isFinalDay) return 1.0;

    final shift = getShiftStart(roleType);

    DateTime actualIn = log.clockIn!;

    // ถ้าเข้างานก่อนเวลากะ → normalize เป็นเวลาเริ่มกะ (ไม่ให้ได้เปรียบ OT)
    final shiftStart = DateTime(
      actualIn.year, actualIn.month, actualIn.day,
      shift.hour, shift.minute,
    );
    if (!actualIn.isAfter(shiftStart)) {
      actualIn = shiftStart;
    }

    // เวลาออก: ถ้าลืมกดออก → ถือว่าออก 17:00
    DateTime actualOut;
    if (log.clockOut == null) {
      actualOut = DateTime(actualIn.year, actualIn.month, actualIn.day, 17, 0);
    } else {
      actualOut = log.clockOut!;
      // ออก 16:45–17:00 หรือหลัง 17:00 → ปัดเป็น 17:00 (ไม่มี OT)
      if ((actualOut.hour == 16 && actualOut.minute >= 45) ||
          actualOut.hour >= 17) {
        actualOut = DateTime(
          actualOut.year, actualOut.month, actualOut.day, 17, 0,
        );
      }
    }

    final standardIn  = shiftStart;
    final standardOut = DateTime(actualIn.year, actualIn.month, actualIn.day, 17, 0);

    // 1. สาย (มาหลังเวลากะ)
    int lateMinutes = 0;
    if (actualIn.isAfter(standardIn)) {
      lateMinutes = actualIn.difference(standardIn).inMinutes;
    }

    // 2. ออกก่อน
    int earlyMinutes = 0;
    if (actualOut.isBefore(standardOut)) {
      earlyMinutes = standardOut.difference(actualOut).inMinutes;
    }

    // 3. ออกชั่วคราว (บวกทุกรอบ)
    int tempOutMinutes = 0;
    // รอบที่ 1
    if (log.tempOut != null) {
      DateTime outTime  = log.tempOut!;
      DateTime backTime = log.backToWork ?? actualOut;
      if (backTime.isAfter(actualOut)) backTime = actualOut;
      if (outTime.isBefore(actualIn)) outTime = actualIn;
      if (outTime.isBefore(backTime)) tempOutMinutes += backTime.difference(outTime).inMinutes;
    }
    // รอบที่ 2
    if (log.tempOut2 != null) {
      DateTime outTime  = log.tempOut2!;
      DateTime backTime = log.backToWork2 ?? actualOut;
      if (backTime.isAfter(actualOut)) backTime = actualOut;
      if (outTime.isBefore(actualIn)) outTime = actualIn;
      if (outTime.isBefore(backTime)) tempOutMinutes += backTime.difference(outTime).inMinutes;
    }
    // รอบที่ 3
    if (log.tempOut3 != null) {
      DateTime outTime  = log.tempOut3!;
      DateTime backTime = log.backToWork3 ?? actualOut;
      if (backTime.isAfter(actualOut)) backTime = actualOut;
      if (outTime.isBefore(actualIn)) outTime = actualIn;
      if (outTime.isBefore(backTime)) tempOutMinutes += backTime.difference(outTime).inMinutes;
    }

    // รวมเวลาที่ขาดหายไป
    final int totalShortfall = lateMinutes + earlyMinutes + tempOutMinutes;

    // กฎปัดเศษ: ≤ 10 นาที → ปัดทิ้ง, > 10 นาที → ปัดขึ้น 1 ชั่วโมง
    int deductionHours = totalShortfall ~/ 60;
    final int remainder = totalShortfall % 60;
    if (remainder > 10) deductionHours += 1;

    int workHours = (10 - deductionHours).clamp(0, 10);
    return workHours / 10.0;
  }
}
