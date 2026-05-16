import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class NetworkDiscoveryService {
  static final NetworkDiscoveryService _instance =
      NetworkDiscoveryService._internal();
  factory NetworkDiscoveryService() => _instance;
  NetworkDiscoveryService._internal();

  RawDatagramSocket? _socket;
  bool _isRunning = false;
  static const int _port = 4040;

  Future<void> start() async {
    if (_isRunning) return;

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _port);
      _socket?.broadcastEnabled = true;
      _isRunning = true;
      debugPrint('📡 [UDP Server] Listening on port $_port for "WHO_IS_POS"');

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          try {
            final datagram = _socket?.receive();
            if (datagram != null) {
              final message = utf8.decode(datagram.data).trim();
              if (message == 'WHO_IS_POS') {
                debugPrint(
                    '📡 [UDP Server] Responding to ${datagram.address.address}...');
                final reply = utf8.encode('I_AM_POS');
                _socket?.send(reply, datagram.address, datagram.port);
              }
            }
          } catch (e) {
            debugPrint('⚠️ [UDP Server] Error handling packet: $e');
          }
        }
      }, onError: (e) {
        debugPrint('❌ [UDP Server] Socket Error: $e');
      });
    } catch (e) {
      debugPrint('❌ [UDP Server] Error starting: $e');
    }
  }

  void stop() {
    _socket?.close();
    _isRunning = false;
    debugPrint('📡 [UDP Server] Stopped.');
  }
}
