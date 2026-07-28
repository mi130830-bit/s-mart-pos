import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/alert_service.dart';
import '../services/hr/fingerprint_attendance_service.dart';
import '../services/integration/fingerprint_network_service.dart';
import '../state/auth_provider.dart';
import '../state/hr/attendance_provider.dart';

/// Controller สำหรับจัดการ Fingerprint Listeners ทั้งหมดใน MainScreen
/// แยก Logic ออกจาก UI (main_screen.dart) เพื่อลด Fat Widget
class FingerprintOverlayController {
  void setup(
    BuildContext context,
    WidgetRef ref, {
    required void Function(
      String name,
      String currentStatus,
      void Function(String action) onActionSelected,
    ) onActionRequired,
    required void Function(bool isConnected, String? address) onConnectionChanged,
  }) {
    FingerprintAttendanceService().onAttendanceRecorded = (name, type) {
      if (context.mounted) {
        AlertService.show(
          context: context,
          message: 'บันทึกสำเร็จ: คุณ $name ได้ทำการ $type แล้วครับ 🟢',
          type: 'success',
          duration: const Duration(seconds: 4),
        );
        ref.read(attendanceProvider.notifier).loadToday();
      }
    };
    FingerprintAttendanceService().onUnknownFingerprint = (msg) {
      if (context.mounted) {
        AlertService.show(
          context: context,
          message: msg,
          type: 'warning',
          duration: const Duration(seconds: 5),
        );
      }
    };
    FingerprintAttendanceService().onActionRequired = (name, currentStatus, onActionSelected) {
      if (!context.mounted) return;
      final authState = ref.read(authProvider);
      if (!authState.isAdmin) {
        final statusText = currentStatus == 'CLOCK_IN' ? 'กำลังทำงานอยู่' : 'ออกชั่วคราวอยู่';
        AlertService.show(
          context: context,
          message: '👆 $name สแกนนิ้วแล้ว ($statusText)',
          type: 'info',
          duration: const Duration(seconds: 3),
        );
        return;
      }
      onActionRequired(name, currentStatus, onActionSelected);
    };
    FingerprintNetworkService().onConnectionChanged = (isConn, address) {
      if (!context.mounted) return;
      onConnectionChanged(isConn, address);
    };
  }

  void dispose() {
    FingerprintAttendanceService().onAttendanceRecorded = null;
    FingerprintAttendanceService().onUnknownFingerprint = null;
    FingerprintAttendanceService().onActionRequired = null;
    FingerprintNetworkService().onConnectionChanged = null;
  }
}
