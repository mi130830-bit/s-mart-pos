import '../../models/hr/attendance_log.dart';

class AttendanceCalculationService {
  /// คำนวณวันทำงานของ 1 บันทึก (1 วัน) เป็นจำนวนชั่วโมง (ทศนิยม) โดยฐาน 1 วัน = 10 ชั่วโมง (สูงสุด 1.0 วัน)
  static double calculateFractionalDays(AttendanceLog log) {
    if (log.clockIn == null) return 0.0;
    if (log.status == 'ABSENT') return 0.0;

    DateTime actualIn = log.clockIn!;
    // ถ้าเข้างานก่อน 07:10 ให้ถือว่าเข้า 07:00 (เวลามาตรฐาน)
    final inHour = actualIn.hour;
    final inMin = actualIn.minute;
    if (inHour < 7 || (inHour == 7 && inMin <= 10)) {
      actualIn = DateTime(actualIn.year, actualIn.month, actualIn.day, 7, 0);
    }

    DateTime actualOut;
    if (log.clockOut == null) {
      // ลืมกดออกงาน ให้คิดถึง 17:00
      actualOut = DateTime(actualIn.year, actualIn.month, actualIn.day, 17, 0);
    } else {
      actualOut = log.clockOut!;
      final outHour = actualOut.hour;
      final outMin = actualOut.minute;
      // เลิกงาน 16:45 - 17:00 ถือเป็น 17:00
      // หรือออกเกิน 17:00 ก็ปัดลงเป็น 17:00 (ไม่มี OT)
      if ((outHour == 16 && outMin >= 45) || outHour >= 17) {
        actualOut = DateTime(actualOut.year, actualOut.month, actualOut.day, 17, 0);
      }
    }

    // กำหนดเวลามาตรฐาน
    DateTime standardIn = DateTime(actualIn.year, actualIn.month, actualIn.day, 7, 0);
    DateTime standardOut = DateTime(actualIn.year, actualIn.month, actualIn.day, 17, 0);

    // 1. คำนวณสาย
    int lateMinutes = 0;
    if (actualIn.isAfter(standardIn)) {
      lateMinutes = actualIn.difference(standardIn).inMinutes;
    }

    // 2. คำนวณออกก่อน
    int earlyMinutes = 0;
    if (actualOut.isBefore(standardOut)) {
      earlyMinutes = standardOut.difference(actualOut).inMinutes;
    }

    // 3. คำนวณออกชั่วคราว
    int tempOutMinutes = 0;
    if (log.tempOut != null) {
      DateTime outTime = log.tempOut!;
      DateTime backTime = log.backToWork ?? actualOut;
      if (backTime.isAfter(actualOut)) backTime = actualOut;
      if (outTime.isBefore(actualIn)) outTime = actualIn;
      
      if (outTime.isBefore(backTime)) {
        tempOutMinutes = backTime.difference(outTime).inMinutes;
      }
    }

    // รวมเวลาที่ขาดหายไปจาก 10 ชั่วโมง
    int totalShortfall = lateMinutes + earlyMinutes + tempOutMinutes;

    // กฎการปัดเศษ: ไม่เกิน 10 นาที ปัดทิ้ง, เกิน 10 นาที ปัดขึ้น 1 ชั่วโมง
    int deductionHours = totalShortfall ~/ 60;
    int remainder = totalShortfall % 60;

    if (remainder > 10) {
      deductionHours += 1;
    }

    // คำนวณชั่วโมงทำงานจริง
    int workHours = 10 - deductionHours;
    if (workHours < 0) workHours = 0;
    if (workHours > 10) workHours = 10; // Capped at 10

    return workHours / 10.0;
  }
}
