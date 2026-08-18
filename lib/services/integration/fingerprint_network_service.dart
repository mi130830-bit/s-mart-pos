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
  static final FingerprintNetworkService _instance =
      FingerprintNetworkService._internal();
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
  bool _isStartingDiscovery = false;
  bool _shouldReconnect = false;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer; // ตรวจสอบสถานะการเชื่อมต่อเป็นระยะ
  Future<bool>? _connectionAttempt;
  int _connectionGeneration = 0;

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------
  Function(int fingerprintSlotId)? onMatchDetected;
  Function(int fingerprintSlotId)? onClockOutDetected;
  Function(int fingerprintSlotId)? onBreakStartDetected; // สำหรับปุ่มกดออกพัก
  Function(int fingerprintSlotId, DateTime timestamp)?
      onOfflineLogDetected; // ประวัติออฟไลน์
  Function(int fingerprintSlotId, DateTime timestamp)?
      onOfflineBreakDetected; // ประวัติออฟไลน์ (ออกพัก)
  Function(String message)? onAlertReceived;
  Function(bool success, int slotId)? onEnrollResult;
  Function(int step, String message)? onEnrollStep;

  /// 🔔 แจ้งเตือนเมื่อสถานะการเชื่อมต่อเปลี่ยน
  /// - true  = เพิ่งเชื่อมต่อสำเร็จ
  /// - false = การเชื่อมต่อขาดหาย
  Function(bool isConnected, String? address)? onConnectionChanged;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------
  bool get isConnected => _socket != null && _isListening;
  String? get connectedAddress => _connectedAddress;

  /// Runs exactly one immediate retry. Concurrent taps/discovery events share
  /// the same attempt instead of creating competing sockets.
  Future<bool> retryConnection() {
    final address = _connectedAddress;
    if (address == null || address.isEmpty) return Future.value(false);
    return connect(address);
  }

  /// ดึง IP จาก Hostname ด้วย ping บน Windows (.local)
  Future<String?> _resolveWindowsHostname(String hostname) async {
    if (!Platform.isWindows) return null;
    try {
      final result =
          await Process.run('ping', ['-4', '-n', '1', '-w', '1000', hostname]);
      if (result.exitCode == 0) {
        final RegExp match =
            RegExp(r'\[(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\]');
        final ipMatch = match.firstMatch(result.stdout.toString());
        if (ipMatch != null) return ipMatch.group(1);

        final RegExp match2 =
            RegExp(r'Reply from (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})');
        final ipMatch2 = match2.firstMatch(result.stdout.toString());
        if (ipMatch2 != null) return ipMatch2.group(1);
      }
    } catch (_) {}
    return null;
  }

  /// เปิดโหมด Auto-Discovery (ฟัง UDP Broadcast จาก ESP32)
  /// ESP32 จะส่ง `"SMART_POS_FINGERPRINT_HERE:<ip>"` ทุก 3 วินาที
  void startAutoDiscovery() async {
    if (_udpSocket != null || _isStartingDiscovery) return;
    _isStartingDiscovery = true;
    try {
      final udpSocket =
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8081);
      _udpSocket = udpSocket;
      udpSocket.listen((RawSocketEvent e) {
        if (e == RawSocketEvent.read) {
          final datagram = udpSocket.receive();
          if (datagram != null) {
            final msg = utf8.decode(datagram.data);
            if (msg.startsWith('SMART_POS_FINGERPRINT_HERE')) {
              // รองรับทั้งแบบเก่า "SMART_POS_FINGERPRINT_HERE"
              // และแบบใหม่ "SMART_POS_FINGERPRINT_HERE:<ip>"
              String espIp;
              if (msg.contains(':')) {
                espIp = msg.split(':').last.trim();
              } else {
                espIp = datagram.address.address;
              }

              // ถ้ายังไม่ต่อ หรือ IP เปลี่ยน → ต่อใหม่ทันที
              if (!isConnected || _connectedAddress != espIp) {
                debugPrint(
                    '📡 [Fingerprint Auto-Discovery] พบอุปกรณ์ที่ IP: $espIp');
                connect(espIp);
              }
            }
          }
        }
      });
      debugPrint(
          '📡 [Fingerprint] เริ่มโหมดค้นหาอุปกรณ์อัตโนมัติผ่าน UDP:8081');
    } catch (e) {
      debugPrint('⚠️ [Fingerprint] ไม่สามารถเปิดโหมด Auto-Discovery ได้: $e');
    } finally {
      _isStartingDiscovery = false;
    }
  }

  /// เชื่อมต่อ TCP Socket ไปยัง IP/Hostname ของ ESP32
  Future<bool> connect(String address) {
    if (isConnected && _connectedAddress == address) return Future.value(true);
    final pending = _connectionAttempt;
    if (pending != null) return pending;

    final attempt = _connectInternal(address);
    _connectionAttempt = attempt;
    return attempt.whenComplete(() {
      if (identical(_connectionAttempt, attempt)) {
        _connectionAttempt = null;
      }
    });
  }

  Future<bool> _connectInternal(String address) async {
    final generation = ++_connectionGeneration;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _disposeCurrentSocket();
    try {
      String resolvedAddress = address;

      // Smart IPv4 Resolution สำหรับ Windows (.local / Hostname)
      if (Platform.isWindows &&
          !RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(address)) {
        try {
          final addrs = await InternetAddress.lookup(address,
              type: InternetAddressType.IPv4);
          if (addrs.isNotEmpty) {
            resolvedAddress = addrs.first.address;
          }
        } catch (_) {
          final pingIp = await _resolveWindowsHostname(address);
          if (pingIp != null) {
            resolvedAddress = pingIp;
          }
        }
      }

      debugPrint(
          '🔌 [Fingerprint] กำลังพยายามเชื่อมต่อ $resolvedAddress:8080 (จาก $address) ...');
      final socket = await Socket.connect(resolvedAddress, 8080,
          timeout: const Duration(seconds: 5));
      if (generation != _connectionGeneration) {
        socket.destroy();
        return false;
      }
      _socket = socket;
      _isListening = true;
      _connectedAddress =
          address; // เก็บตัวดั้งเดิมไว้ (เช่น fingerprint.local)
      _shouldReconnect = true;

      final StringBuffer buffer = StringBuffer();

      _socketSubscription = socket.listen(
        (Uint8List data) {
          try {
            final String chunk = utf8.decode(data, allowMalformed: true);
            buffer.write(chunk);

            String content = buffer.toString();
            while (content.contains('\n')) {
              final int nextLineIdx = content.indexOf('\n');
              final String line = content.substring(0, nextLineIdx).trim();

              if (line.isNotEmpty) {
                _parseSerialLine(line);
              }

              content = content.substring(nextLineIdx + 1);
            }

            buffer.clear();
            buffer.write(content);
          } catch (e) {
            debugPrint('❌ [Fingerprint] Decode Error: $e');
          }
        },
        onError: (err) {
          if (generation != _connectionGeneration ||
              !identical(_socket, socket)) {
            return;
          }
          debugPrint('❌ [Fingerprint] Socket Error: $err');
          onAlertReceived?.call('การเชื่อมต่อเครือข่ายขัดข้อง: $err');
          _handleSocketLost(socket, generation);
        },
        onDone: () {
          debugPrint('⚠️ [Fingerprint] Socket Connection Closed by Server');
          _handleSocketLost(socket, generation);
        },
      );

      // เริ่ม Heartbeat checker หลังจากต่อสำเร็จ
      _startHeartbeat(socket, generation);

      debugPrint('✅ [Fingerprint] เชื่อมต่อ $address:8080 สำเร็จ');
      _emitConnectionChanged(true, address);
      return true;
    } catch (e) {
      debugPrint('❌ [Fingerprint] เกิดข้อผิดพลาดในการเชื่อมต่อ: $e');
      if (generation != _connectionGeneration) return false;
      _connectedAddress = address;
      _shouldReconnect = true;
      // หยอดระบบ Auto-Reconnect กรณีที่ตอนเปิดแอป เครื่องสแกนยังไม่ได้เปิด
      _transitionDisconnected(generation, scheduleRetry: true);
      return false;
    }
  }

  /// ตัดการเชื่อมต่อ (ถ้า intentional = true จะไม่พยายามต่อใหม่)
  void disconnect({bool intentional = true}) {
    ++_connectionGeneration;

    if (intentional) {
      _shouldReconnect = false;
      _reconnectTimer?.cancel();
    }

    final wasConnected = _isListening;
    _disposeCurrentSocket();
    debugPrint(
        '🔌 [Fingerprint] ตัดการเชื่อมต่อแล้ว (intentional: $intentional)');

    // แจ้ง UI ว่าการเชื่อมต่อขาดหาย (เฉพาะกรณีหลุดโดยไม่ตั้งใจ)
    if (!intentional && wasConnected) {
      _emitConnectionChanged(false, _connectedAddress);
    }

    // 🚀 Auto-Reconnect (กรณีหลุดโดยไม่ตั้งใจ)
    if (!intentional && _shouldReconnect && _connectedAddress != null) {
      debugPrint('⏳ [Fingerprint] กำลังพยายามเชื่อมต่อใหม่ในอีก 5 วินาที...');
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 5), () {
        if (_shouldReconnect && _connectedAddress != null) {
          connect(_connectedAddress!);
        }
      });
    } else if (intentional) {
      _connectedAddress = null;
    }
  }

  void _handleSocketLost(Socket socket, int generation) {
    // A socket from an older connection attempt has no authority to tear down
    // the socket that replaced it.
    if (generation != _connectionGeneration || !identical(_socket, socket)) {
      return;
    }
    _transitionDisconnected(generation, scheduleRetry: true);
  }

  void _transitionDisconnected(int generation, {required bool scheduleRetry}) {
    if (generation != _connectionGeneration) return;
    final wasConnected = _isListening;
    _disposeCurrentSocket();
    if (wasConnected) _emitConnectionChanged(false, _connectedAddress);
    if (scheduleRetry && _shouldReconnect && _connectedAddress != null) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 5), () {
        if (_shouldReconnect && _connectedAddress != null && !isConnected) {
          connect(_connectedAddress!);
        }
      });
    }
  }

  void _disposeCurrentSocket() {
    _stopHeartbeat();
    _isListening = false;
    _socketSubscription?.cancel();
    _socketSubscription = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        socket.destroy();
      } catch (_) {}
    }
  }

  bool? _lastNotifiedConnection;
  void _emitConnectionChanged(bool connected, String? address) {
    if (_lastNotifiedConnection == connected) return;
    _lastNotifiedConnection = connected;
    onConnectionChanged?.call(connected, address);
  }

  /// ส่งคำสั่ง text ผ่าน Socket ไปยัง ESP32
  void sendCommand(String command) {
    if (_socket == null) {
      debugPrint(
          '⚠️ [Fingerprint] ไม่สามารถส่งคำสั่งได้ เพราะไม่ได้เชื่อมต่ออยู่');
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
  // Heartbeat: เช็คสถานะทุก 15 วินาที
  // ถ้า socket ดูเหมือนเชื่อมอยู่ แต่ส่งข้อมูลไม่ได้ → ถือว่าหลุด
  // ---------------------------------------------------------------------------
  void _startHeartbeat(Socket socket, int generation) {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (generation != _connectionGeneration || !identical(_socket, socket)) {
        return;
      }
      try {
        // ส่ง empty byte เพื่อทดสอบว่า socket ยังมีชีวิตอยู่
        socket.add([]);
      } catch (e) {
        debugPrint('💔 [Fingerprint Heartbeat] Socket ตายแล้ว: $e');
        _handleSocketLost(socket, generation);
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Private: Parse ข้อความจาก ESP32
  // ---------------------------------------------------------------------------
  void _parseSerialLine(String line) {
    debugPrint('📟 [Fingerprint Raw] $line');

    if (line.startsWith('MATCH_ID:')) {
      final idStr = line.substring('MATCH_ID:'.length).trim();
      final matchedId = int.tryParse(idStr);
      if (matchedId != null) {
        debugPrint('👆 [Fingerprint] ตรวจพบลายนิ้วมือ ID: $matchedId');
        onMatchDetected?.call(matchedId);
      }
    } else if (line.startsWith('MATCH_OUT:')) {
      final idStr = line.substring('MATCH_OUT:'.length).trim();
      final matchedId = int.tryParse(idStr);
      if (matchedId != null) {
        debugPrint('👆 [Fingerprint] ตรวจพบลายนิ้วมือ (ออกงาน) ID: $matchedId');
        onClockOutDetected?.call(matchedId);
      }
    } else if (line.startsWith('BREAK_START:')) {
      final idStr = line.substring('BREAK_START:'.length).trim();
      final matchedId = int.tryParse(idStr);
      if (matchedId != null) {
        debugPrint('👆 [Fingerprint] ตรวจพบลายนิ้วมือ (ออกพัก) ID: $matchedId');
        onBreakStartDetected?.call(matchedId);
      }
    } else if (line.startsWith('OFFLINE_LOG:')) {
      // Format: OFFLINE_LOG:5:2026-08-01T08:00:00  หรือ OFFLINE_LOG:5:BREAK|2026-08-01T08:00:00
      final rest = line.substring('OFFLINE_LOG:'.length).trim();
      final parts = rest.split(':');
      if (parts.length >= 2) {
        final idStr = parts[0];
        final timePart = parts.sublist(1).join(':'); // reconnect

        final slotId = int.tryParse(idStr);
        if (slotId != null) {
          bool isBreak = false;
          String timeStr = timePart;
          if (timePart.startsWith('BREAK|')) {
            isBreak = true;
            timeStr = timePart.substring('BREAK|'.length);
          }

          try {
            final timestamp = DateTime.parse(timeStr);
            if (isBreak) {
              debugPrint(
                  '👆 [Fingerprint] รับข้อมูลออฟไลน์ (ออกพัก) ID: $slotId เวลา: $timestamp');
              onOfflineBreakDetected?.call(slotId, timestamp);
            } else {
              debugPrint(
                  '👆 [Fingerprint] รับข้อมูลออฟไลน์ ID: $slotId เวลา: $timestamp');
              onOfflineLogDetected?.call(slotId, timestamp);
            }
            // ส่ง ACK กลับไปให้ ESP32 เคลียร์คิว
            sendCommand('OFFLINE_ACK:1');
          } catch (e) {
            debugPrint('❌ [Fingerprint] แปลงเวลาออฟไลน์ไม่สำเร็จ: $timeStr');
          }
        }
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
