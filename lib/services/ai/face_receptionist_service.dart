import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../logger_service.dart';

/// Service ที่คอยควบคุม Background Process ของกล้อง AI ตรวจจับใบหน้าหน้าร้าน
/// ทำงานอัตโนมัติตอนเปิดโปรแกรม POS Desktop และปิดตัวลงอย่างหมดจดตอนปิดโปรแกรม
class FaceReceptionistService {
  static final FaceReceptionistService _instance = FaceReceptionistService._internal();
  factory FaceReceptionistService() => _instance;
  FaceReceptionistService._internal();

  Process? _process;
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// เริ่มต้นรันระบบกล้องต้อนรับลูกค้าใน Background (Headless)
  Future<void> start() async {
    if (!Platform.isWindows) {
      LoggerService.info('FaceReceptionist', 'Skipping: Non-Windows platform');
      return;
    }

    if (_isRunning || _process != null) {
      LoggerService.info('FaceReceptionist', 'Already running.');
      return;
    }

    try {
      final scriptPath = '${Directory.current.path}\\scripts\\face_watcher.py';
      final file = File(scriptPath);
      if (!await file.exists()) {
        LoggerService.warning('FaceReceptionist', 'Script not found at: $scriptPath');
        return;
      }

      LoggerService.info('FaceReceptionist', 'Starting Face Receptionist process (Headless mode)...');
      
      _process = await Process.start(
        'python',
        [scriptPath, '--headless'],
        mode: ProcessStartMode.normal,
        workingDirectory: Directory.current.path,
      );

      _isRunning = true;
      LoggerService.info('FaceReceptionist', 'Process started with PID: ${_process?.pid}');

      // Listen to stdout
      _process?.stdout.transform(utf8.decoder).listen((data) {
        if (kDebugMode && data.trim().isNotEmpty) {
          debugPrint('📸 [FaceAI]: ${data.trim()}');
        }
      });

      // Listen to stderr
      _process?.stderr.transform(utf8.decoder).listen((data) {
        if (data.trim().isNotEmpty) {
          debugPrint('⚠️ [FaceAI Warning]: ${data.trim()}');
        }
      });

      // Handle process exit
      _process?.exitCode.then((code) {
        LoggerService.info('FaceReceptionist', 'Process exited with code: $code');
        _isRunning = false;
        _process = null;
      });
    } catch (e) {
      LoggerService.error('FaceReceptionist', 'Failed to start Face Receptionist', e);
      _isRunning = false;
      _process = null;
    }
  }

  /// ปิดการทำงานของกล้องและคืนทรัพยากรทั้งหมด
  Future<void> stop() async {
    if (_process != null) {
      LoggerService.info('FaceReceptionist', 'Stopping Face Receptionist process (PID: ${_process?.pid})...');
      try {
        _process?.kill(ProcessSignal.sigterm);
        // Force kill if still running after 500ms
        await Future.delayed(const Duration(milliseconds: 500));
        _process?.kill(ProcessSignal.sigkill);
      } catch (e) {
        debugPrint('⚠️ [FaceAI Kill error]: $e');
      } finally {
        _process = null;
        _isRunning = false;
      }
    }
  }
}
