import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/fingerprint_network_service.dart';
import '../../repositories/hr/employee_repository.dart';
import '../../repositories/hr/attendance_repository.dart';

/// บริการประสานงานระหว่าง FingerprintNetworkService (ฮาร์ดแวร์)
/// และ AttendanceRepository (ฐานข้อมูล)
///
/// ทำงานเป็น Global Background Listener:
/// 1. รับ fingerprintSlotId จาก ESP32
/// 2. ค้นหา employeeId จากตาราง employee_fingerprint
/// 3. บันทึกเวลาเข้างานลงตาราง attendance_log
///
/// ⚠️ ข้อควรระวัง: Service นี้เป็น Singleton และทำงานในพื้นหลังตลอดเวลา
/// ห้ามสร้าง Instance ซ้ำ และห้าม call start() มากกว่าหนึ่งครั้ง
class FingerprintAttendanceService {
  // ---------------------------------------------------------------------------
  // Singleton Setup
  // ---------------------------------------------------------------------------
  static final FingerprintAttendanceService _instance =
      FingerprintAttendanceService._internal();
  factory FingerprintAttendanceService() => _instance;
  FingerprintAttendanceService._internal();

  // ---------------------------------------------------------------------------
  // Dependencies (ใช้ Repository ที่มีอยู่แล้ว ไม่สร้างใหม่)
  // ---------------------------------------------------------------------------
  final FingerprintNetworkService _network = FingerprintNetworkService();
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  final AttendanceRepository _attendanceRepo = AttendanceRepository();

  // ---------------------------------------------------------------------------
  static const String _keyFingerprintHost = 'fingerprint_host';

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // Public State
  // ---------------------------------------------------------------------------
  bool _started = false;
  
  // ป้องกันการแสกนซ้ำซ้อนภายในระยะเวลาอันสั้น (Cooldown 60 วินาที)
  final Map<int, DateTime> _lastScanMap = {};

  /// callback ที่ฝั่ง UI สามารถตั้งค่าไว้เพื่อรับการแจ้งเตือนแบบ Snackbar/Toast
  /// ตัวอย่าง: FingerprintAttendanceService().onAttendanceRecorded = (name, type) { ... }
  Function(String employeeName, String attendanceType)? onAttendanceRecorded;

  /// callback เมื่อแสกนแล้วไม่พบลายนิ้วมือในระบบ
  Function(String message)? onUnknownFingerprint;

  /// callback เมื่อการแสกนนิ้วต้องมีการตัดสินใจเลือกสถานะเพิ่มเติม (เช่น ออกชั่วคราว vs เลิกงาน)
  Function(
    String employeeName,
    String currentStatus, // 'CLOCK_IN', 'TEMP_LEAVE'
    Function(String chosenAction) onActionSelected,
  )? onActionRequired;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  bool get isConnected => _network.isConnected;
  String? get connectedAddress => _network.connectedAddress;

  // ---------------------------------------------------------------------------
  // Private: Helpers
  // ---------------------------------------------------------------------------

  /// ตรวจสอบว่าตอนนี้อยู่ในช่วงเวลาเลิกงาน (16:40 - 17:30)
  /// ถ้าใช่ → Auto Clock Out ทันที ไม่ต้องขึ้น card ให้เลือก
  bool _isEndOfDay() {
    final now = DateTime.now();
    final startMinute = 16 * 60 + 40; // 16:40
    final endMinute   = 17 * 60 + 30; // 17:30
    final currentMinute = now.hour * 60 + now.minute;
    return currentMinute >= startMinute && currentMinute <= endMinute;
  }

  /// เริ่มต้น Background Listener
  /// เรียกครั้งเดียวตอน App Start ใน main.dart
  /// ระบบจะอ่านพอร์ตที่เคยบันทึกไว้ หรือ Auto-detect อัตโนมัติ
  ///
  /// ⚠️ ปลอดภัย: มีการป้องกันการเรียกซ้ำ (idempotent)
  /// ⚠️ ปลอดภัย: ถ้าเชื่อมต่อไม่ได้ จะ Fail Silently ไม่ทำให้แอปพลิเคชันพัง
  Future<void> start() async {
    // ป้องกันเรียกซ้ำ
    if (_started) {
      debugPrint('⚠️ [FingerprintAttendance] start() ถูกเรียกซ้ำ ข้ามไป');
      return;
    }
    _started = true;

    // ตั้งค่า Callbacks
    _network.onMatchDetected = _handleFingerprintMatch;
    _network.onAlertReceived = (msg) {
      debugPrint('⚠️ [FingerprintAttendance] Alert: $msg');
      onUnknownFingerprint?.call(msg);
    };

    // พยายามเชื่อมต่อแบบ Fail-Safe (ไม่ทำให้แอปพังถ้าไม่มีอุปกรณ์)
    // เริ่มโหมดค้นหาอัตโนมัติ (UDP Broadcast) วิ่งหาตลอดเวลา
    _network.startAutoDiscovery();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedHost = prefs.getString(_keyFingerprintHost) ?? 'fingerprint.local';

      debugPrint('🔌 [FingerprintAttendance] ลองเชื่อมต่อ WiFi: $savedHost');
      final connected = await _network.connect(savedHost);

      if (!connected) {
        debugPrint('⚠️ [FingerprintAttendance] ไม่พบอุปกรณ์แสกนลายนิ้วมือที่ $savedHost');
      } else {
        await prefs.setString(_keyFingerprintHost, savedHost);
      }
    } catch (e) {
      // ⚠️ ถ้า Serial Port มีปัญหา ให้ Fail Silently ห้ามทำให้แอปพังเด็ดขาด
      debugPrint('⚠️ [FingerprintAttendance] Startup Error (Ignored): $e');
    }
  }

  /// เปลี่ยน Host IP ที่ใช้งาน (สำหรับเรียกจาก Settings UI)
  Future<bool> changeHost(String hostName) async {
    final connected = await _network.connect(hostName);
    if (connected) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFingerprintHost, hostName);
    }
    return connected;
  }

  /// ตัดการเชื่อมต่ออุปกรณ์แสกนลายนิ้วมือ
  void stop() {
    _network.disconnect();
    _started = false;
    _lastScanMap.clear();
    debugPrint('🛑 [FingerprintAttendance] หยุดการทำงานแล้ว');
  }

  // ---------------------------------------------------------------------------
  // Private: Core Logic
  // ---------------------------------------------------------------------------

  /// เรียกเมื่อ ESP32 ส่ง MATCH_ID ขึ้นมา
  /// ค้นหาพนักงานและบันทึกเวลาเข้างาน
  Future<void> _handleFingerprintMatch(int fingerprintSlotId) async {
    try {
      // 1. หา employeeId จาก fingerprintSlotId
      final employeeId = await _employeeRepo.getEmployeeIdByFingerprint(fingerprintSlotId);
      if (employeeId == null) {
        debugPrint('⚠️ [FingerprintAttendance] ไม่พบ Employee ที่ผูกกับ Fingerprint ID: $fingerprintSlotId');
        onUnknownFingerprint?.call('ไม่พบข้อมูลพนักงานที่ผูกกับลายนิ้วมือนี้ (Slot #$fingerprintSlotId)');
        return;
      }

      // 1.5 ตรวจสอบ Cooldown (60 วินาที) เพื่อป้องกันการแตะเบิ้ลโดยไม่ตั้งใจ
      final now = DateTime.now();
      if (_lastScanMap.containsKey(employeeId)) {
        final lastScan = _lastScanMap[employeeId]!;
        final difference = now.difference(lastScan).inSeconds;
        if (difference < 60) {
          final employee = await _employeeRepo.getById(employeeId);
          final name = employee?.displayName ?? 'พนักงาน #$employeeId';
          debugPrint('⚠️ [FingerprintAttendance] คุณ $name เพิ่งสแกนไปเมื่อ $difference วินาทีก่อน ข้ามการสแกนซ้ำ');
          onUnknownFingerprint?.call('คุณ $name เพิ่งบันทึกเวลาไปเมื่อ $difference วินาทีก่อน (กรุณารออีก ${60 - difference} วินาที)');
          return;
        }
      }

      // 2. ดึงประวัติการบันทึกเวลางานของวันนี้
      final todayLog = await _attendanceRepo.getTodayLogByEmployee(employeeId);
      final employee = await _employeeRepo.getById(employeeId);
      final name = employee?.displayName ?? 'พนักงาน #$employeeId';

      if (todayLog == null) {
        // สถานะ 1: ยังไม่ได้เช็คอินวันนี้ -> ดำเนินการเข้างานอัตโนมัติ (Auto Clock In)
        await _attendanceRepo.clockIn(
          employeeId,
          'FINGERPRINT',
          deviceInfo: 'ESP32+R307S',
        );
        _lastScanMap[employeeId] = now;
        debugPrint('✅ [FingerprintAttendance] Auto Clock In: Employee #$employeeId');
        onAttendanceRecorded?.call(name, 'เข้างาน');
      } else if (todayLog.clockOut != null) {
        // สถานะ 5: เลิกงานไปแล้วสำหรับวันนี้
        onUnknownFingerprint?.call('คุณ $name ได้ทำการบันทึกเลิกงานสำหรับวันนี้ไปแล้วครับ 🟢');
      } else if (todayLog.tempOut == null) {
        // สถานะ 2: เช็คอินเข้างานแล้ว แต่ยังไม่ได้ออกชั่วคราว
        // ถ้าอยู่ในช่วงเวลาเลิกงาน → Auto Clock Out ทันที ไม่ขึ้น card
        if (_isEndOfDay()) {
          await _attendanceRepo.clockOut(employeeId, method: 'FINGERPRINT');
          _lastScanMap[employeeId] = now;
          debugPrint('🌆 [FingerprintAttendance] End-of-Day Auto Clock Out: Employee #$employeeId');
          onAttendanceRecorded?.call(name, 'เลิกงาน (Auto)');
        } else if (onActionRequired != null) {
          // นอกช่วงเวลาเลิกงาน → ขึ้น floating card ให้เลือก
          onActionRequired?.call(name, 'CLOCK_IN', (action) async {
            final actionTime = DateTime.now();
            if (action == 'TEMP_LEAVE') {
              await _attendanceRepo.startTempLeave(employeeId, method: 'FINGERPRINT', overrideTime: actionTime);
              _lastScanMap[employeeId] = actionTime;
              debugPrint('✅ [FingerprintAttendance] Temp Out: Employee #$employeeId');
              onAttendanceRecorded?.call(name, 'ออกชั่วคราว');
            } else if (action == 'CLOCK_OUT') {
              await _attendanceRepo.clockOut(employeeId, method: 'FINGERPRINT', overrideTime: actionTime);
              _lastScanMap[employeeId] = actionTime;
              debugPrint('✅ [FingerprintAttendance] Clock Out: Employee #$employeeId');
              onAttendanceRecorded?.call(name, 'เลิกงาน');
            }
          });
        } else {
          // Fallback หากไม่มี UI สแตนด์บายตอบรับ → บันทึกเลิกงานทันที
          await _attendanceRepo.clockOut(employeeId, method: 'FINGERPRINT');
          _lastScanMap[employeeId] = now;
          debugPrint('✅ [FingerprintAttendance] Fallback Clock Out: Employee #$employeeId');
          onAttendanceRecorded?.call(name, 'ออกงาน');
        }
      } else if (todayLog.backToWork == null) {
        // สถานะ 3: อยู่ระหว่างออกไปธุระชั่วคราว
        // ถ้าอยู่ในช่วงเวลาเลิกงาน → Auto Clock Out ทันที ไม่ขึ้น card
        if (_isEndOfDay()) {
          await _attendanceRepo.clockOut(employeeId, method: 'FINGERPRINT');
          _lastScanMap[employeeId] = now;
          debugPrint('🌆 [FingerprintAttendance] End-of-Day Auto Clock Out (from TempLeave): Employee #$employeeId');
          onAttendanceRecorded?.call(name, 'เลิกงาน (Auto)');
        } else if (onActionRequired != null) {
          // นอกช่วงเวลาเลิกงาน → ขึ้น floating card ให้เลือก
          onActionRequired?.call(name, 'TEMP_LEAVE', (action) async {
            final actionTime = DateTime.now();
            if (action == 'TEMP_RETURN') {
              await _attendanceRepo.endTempLeave(employeeId, method: 'FINGERPRINT', overrideTime: actionTime);
              _lastScanMap[employeeId] = actionTime;
              debugPrint('✅ [FingerprintAttendance] Temp Return: Employee #$employeeId');
              onAttendanceRecorded?.call(name, 'กลับเข้างาน');
            } else if (action == 'CLOCK_OUT') {
              await _attendanceRepo.clockOut(employeeId, method: 'FINGERPRINT', overrideTime: actionTime);
              _lastScanMap[employeeId] = actionTime;
              debugPrint('✅ [FingerprintAttendance] Clock Out: Employee #$employeeId');
              onAttendanceRecorded?.call(name, 'เลิกงาน');
            }
          });
        } else {
          // Fallback
          await _attendanceRepo.endTempLeave(employeeId, method: 'FINGERPRINT');
          _lastScanMap[employeeId] = now;
          debugPrint('✅ [FingerprintAttendance] Fallback Temp Return: Employee #$employeeId');
          onAttendanceRecorded?.call(name, 'กลับเข้างาน');
        }
      } else {
        // สถานะ 4: ผ่านกระบวนการออกชั่วคราวและกลับเข้างานครบถ้วนแล้ว -> เลิกงานทันที
        await _attendanceRepo.clockOut(employeeId, method: 'FINGERPRINT');
        _lastScanMap[employeeId] = now;
        debugPrint('✅ [FingerprintAttendance] Auto Clock Out: Employee #$employeeId');
        onAttendanceRecorded?.call(name, 'ออกงาน');
      }
    } catch (e) {
      // ⚠️ ป้องกันไม่ให้ Error จาก DB ทำให้ระบบ Serial Listener หยุดทำงาน
      debugPrint('❌ [FingerprintAttendance] DB Error: $e');
    }
  }
}
