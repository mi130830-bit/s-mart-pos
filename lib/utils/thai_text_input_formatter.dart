import 'package:flutter/services.dart';

/// แก้ปัญหาการลบสระ/วรรณยุกต์ภาษาไทยทีละตัว (Windows Behavior)
/// ปกติ Flutter จะลบทั้งก้อน (Grapheme Cluster) เช่น "ปู่" ลบทีเดียวหายหมด
/// Formatter นี้จะช่วยให้ลบทีละส่วน: "ปู่" -> "ปู" -> "ป"
class ThaiChildTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 1. ถ้าไม่ได้เป็นการลบ (เช่น พิมพ์เพิ่ม) -> ปล่อยผ่าน
    if (newValue.text.length >= oldValue.text.length) {
      return newValue;
    }

    // 2. ถ้ามีการเลือกข้อความ (Selection) แล้วลบ -> ลบตามปกติ (ลบทั้ง Selection)
    if (!oldValue.selection.isCollapsed) {
      return newValue;
    }

    // 3. คำนวณจำนวนตัวอักษรที่หายไป
    final int deletedCount = oldValue.text.length - newValue.text.length;

    // 4. ถ้าลบไปแค่ 1 ตัว (Code Unit) แปลว่าเป็นตัวปกติอยู่แล้ว -> ปล่อยผ่าน
    if (deletedCount <= 1) {
      return newValue;
    }

    // 5. หาว่าลบอะไรออกไป
    // ตำแหน่ง Cursor ใหม่ คือจุดสิ้นสุดของข้อความที่เหลืออยู่ (กรณีลบจากท้าย)
    // หรือถ้าลบตรงกลาง ต้องดูจาก cursor
    final int deleteEnd = oldValue.selection.end;
    final int deleteStart = deleteEnd - deletedCount;

    // ป้องกัน index error (ไม่น่าเกิดขึ้นถ้าวัดจาก selection เดิม)
    if (deleteStart < 0) return newValue;

    final String deletedSegment =
        oldValue.text.substring(deleteStart, deleteEnd);

    // 6. เช็คว่าสิ่งที่ลบ มีภาษาไทยไหม (ก-ฮ, สระ, วรรณยุกต์)
    // Range: \u0E00-\u0E7F
    final bool hasThai = deletedSegment.contains(RegExp(r'[\u0E00-\u0E7F]'));

    if (hasThai) {
      // 7. บังคับลบแค่ตัวเดียว (Last Code Unit of the deleted segment)
      // เอาข้อความเก่า ตัดออกแค่ 1 ตัวท้ายสุดของส่วนที่ถูกลบ
      // ตัวอย่าง: "ปู (่)" -> ลบ ่ (length 1) - อันนี้ปกติ
      // ตัวอย่าง: "ป (ู่)" -> ระบบลบ "ู่" (2 chars) -> เราบังคับลบแค่ ่ (1 char)
      // เหลือ "ปู"

      // ส่วนหน้า (คงเดิม)
      final String prefix = oldValue.text.substring(0, deleteStart);
      // ส่วนที่ถูกระบบลบไป (deletedSegment) -> เราดึงกลับมาเกือบหมด ยกเว้นตัวขวาสุด
      final String restore =
          deletedSegment.substring(0, deletedSegment.length - 1);
      // ส่วนหลัง (กรณีลบตรงกลาง)
      final String suffix = oldValue.text.substring(deleteEnd);

      final String newText = prefix + restore + suffix;

      // จัดการ Cursor ให้ไปอยู่หลัง restored text
      final int newCursorIndex = deleteStart + restore.length;

      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorIndex),
      );
    }

    return newValue;
  }
}
