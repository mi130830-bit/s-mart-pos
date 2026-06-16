import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

/// บริการดักฟังข้อมูลจาก ESP32 ผ่าน WiFi TCP Socket
/// ออกแบบให้เป็น Singleton ดักฟังตลอดเวลาตั้งแต่เปิดแอป
class FingerprintNetworkService {
  // ---------------------------------------------------------------------------
  // Singleton Setup
  // ---------------------------------------------------------------------------
  static final FingerprintNetworkService _instance = FingerprintNetworkService._internal();
  factory FingerprintNetworkService() => _instance;
  FingerprintNetworkService._internal();

  // ---------------------------------------------------------------------------
  // Private State
  // ---------------------------------------------------------------------------
  Socket? _socket;
  bool _isListening = false;
  String? _connectedAddress;
  StreamSubscription? _socketSubscription;
  RawDatagramSocket? _udpSocket;
  bool _shouldReconnect = false; // 👈 เพิ่มสถานะควบคุมการต่อใหม่
  Timer? _reconnectTimer; // 👈 ตัวจับเวลาสำหรับต่อใหม่

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------
  Function(int fingerprintSlotId)? onMatchDetected;
  Function(String message)? onAlertReceived;
  Function(bool success, int slotId)? onEnrollResult;
  Function(int step, String message)? onEnrollStep;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  bool get isConnected => _socket != null && _isListening;
  String? get connectedAddress => _connectedAddress;

  /// เปิดโหมด Auto-Discovery (ฟัง UDP Broadcast จาก ESP32)
  void startAutoDiscovery() async {
    if (_udpSocket != null) return;
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8081);
      _udpSocket!.listen((RawSocketEvent e) {
        if (e == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            final msg = utf8.decode(datagram.data);
            if (msg == 'SMART_POS_FINGERPRINT_HERE') {
              final espIp = datagram.address.address;
              // ถ้ายังไม่ต่อ หรือ IP เปลี่ยน ให้ต่อใหม่ทันที
              if (!isConnected || _connectedAddress != espIp) {
                debugPrint('📡 [Fingerprint Auto-Discovery] พบอุปกรณ์ที่ IP: $espIp');
                connect(espIp);
              }
            }
          }
        }
      });
      debugPrint('📡 [Fingerprint] เริ่มโหมดค้นหาอุปกรณ์อัตโนมัติผ่าน UDP:8081');
    } catch (e) {
      debugPrint('⚠️ [Fingerprint] ไม่สามารถเปิดโหมด Auto-Discovery ได้: $e');
    }
  }

  /// เชื่อมต่อ TCP Socket ไปยัง IP/Hostname ของ ESP32
  Future<bool> connect(String address) async {
    try {
      disconnect(intentional: true);

      debugPrint('🔌 [Fingerprint] กำลังพยายามเชื่อมต่อ $address:8080 ...');
      _socket = await Socket.connect(address, 8080, timeout: const Duration(seconds: 5));
      _isListening = true;
      _connectedAddress = address;
      _shouldReconnect = true; // 👈 ตั้งให้พยายามต่อใหม่ถ้าหลุดเอง

      _socketSubscription = _socket!.listen(
        (Uint8List data) {
          final String lines = utf8.decode(data);
          for (final line in lines.split('\n')) {
            final trimmed = line.trim();
            if (trimmed.isNotEmpty) {
              _parseSerialLine(trimmed);
            }
          }
        },
        onError: (err) {
          debugPrint('❌ [Fingerprint] Socket Error: $err');
          onAlertReceived?.call('การเชื่อมต่อเครือข่ายขัดข้อง: $err');
          disconnect(intentional: false); // 👈 หลุดแบบไม่ตั้งใจ ให้ต่อใหม่
        },
        onDone: () {
          debugPrint('⚠️ [Fingerprint] Socket Connection Closed by Server');
          disconnect(intentional: false); // 👈 หลุดแบบไม่ตั้งใจ ให้ต่อใหม่
        },
      );

      debugPrint('✅ [Fingerprint] เชื่อมต่อ $address:8080 สำเร็จ');
      return true;
    } catch (e) {
      debugPrint('❌ [Fingerprint] เกิดข้อผิดพลาดในการเชื่อมต่อ: $e');
      onAlertReceived?.call('เกิดข้อผิดพลาดในการเชื่อมต่อ: $e');
      return false;
    }
  }

  /// ตัดการเชื่อมต่อ (ถ้า intentional = true จะไม่พยายามต่อใหม่)
  void disconnect({bool intentional = true}) {
    if (intentional) {
      _shouldReconnect = false;
      _reconnectTimer?.cancel();
    }
    
    _isListening = false;
    _socketSubscription?.cancel();
    _socketSubscription = null;
    
    if (_socket != null) {
      try {
        _socket!.destroy();
      } catch (_) {}
      _socket = null;
    }
    debugPrint('🔌 [Fingerprint] ตัดการเชื่อมต่อแล้ว');

    // 🚀 ระบบ Auto-Reconnect
    if (!intentional && _shouldReconnect && _connectedAddress != null) {
      debugPrint('⏳ [Fingerprint] กำลังพยายามเชื่อมต่อใหม่ในอีก 3 วินาที...');
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        if (_shouldReconnect && _connectedAddress != null) {
          connect(_connectedAddress!);
        }
      });
    } else if (intentional) {
      _connectedAddress = null; // เคลียร์ address เฉพาะตอนตั้งใจตัด
    }
  }

  /// ส่งคำสั่ง text ผ่าน Socket ไปยัง ESP32
  void sendCommand(String command) {
    if (_socket == null) {
      debugPrint('⚠️ [Fingerprint] ไม่สามารถส่งคำสั่งได้ เพราะไม่ได้เชื่อมต่ออยู่');
      return;
    }
    try {
      _socket!.writeln(command);
      _socket!.flush();
      debugPrint('📤 [Fingerprint] ส่งคำสั่ง: $command');
    } catch (e) {
      debugPrint('❌ [Fingerprint] ส่งคำสั่งล้มเหลว: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  /// วิเคราะห์ข้อความที่ได้รับจาก ESP32
  void _parseSerialLine(String line) {
    debugPrint('📟 [Fingerprint Raw] $line');

    if (line.startsWith('MATCH_ID:')) {
      final idStr = line.substring('MATCH_ID:'.length).trim();
      final matchedId = int.tryParse(idStr);
      if (matchedId != null) {
        debugPrint('👆 [Fingerprint] ตรวจพบลายนิ้วมือ ID: $matchedId');
        onMatchDetected?.call(matchedId);
      }
    } else if (line.startsWith('ENROLL_OK:')) {
      final idStr = line.substring('ENROLL_OK:'.length).trim();
      final slotId = int.tryParse(idStr);
      if (slotId != null) {
        debugPrint('✅ [Fingerprint] Enroll สำเร็จ Slot: $slotId');
        onEnrollResult?.call(true, slotId);
      }
    } else if (line.startsWith('ENROLL_FAIL:')) {
      final idStr = line.substring('ENROLL_FAIL:'.length).trim();
      final slotId = int.tryParse(idStr) ?? 0;
      debugPrint('❌ [Fingerprint] Enroll ล้มเหลว Slot: $slotId');
      onEnrollResult?.call(false, slotId);
    } else if (line.startsWith('ENROLL_STEP:')) {
      final rest = line.substring('ENROLL_STEP:'.length);
      final colonIdx = rest.indexOf(':');
      if (colonIdx >= 0) {
        final step = int.tryParse(rest.substring(0, colonIdx)) ?? 0;
        final msg = rest.substring(colonIdx + 1).trim();
        debugPrint('👆 [Fingerprint] Enroll Step $step: $msg');
        onEnrollStep?.call(step, msg);
      }
    } else if (line.startsWith('ALERT:')) {
      final msg = line.substring('ALERT:'.length).trim();
      onAlertReceived?.call(msg);
    }
  }
}
