import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomerDisplayRepository {
  final _updateController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get updates => _updateController.stream;

  final dynamic windowId;

  CustomerDisplayRepository(this.windowId) {
    debugPrint(
        '📢 CustomerDisplayRepository Initialized for Window: $windowId');
    _initMethodHandler();
  }

  void _initMethodHandler() {
    // 1. Listen on Specific Channel (UUID/ID based)
    final specificChannel = 'mixin.one/window_controller/$windowId';
    debugPrint('👂 Listening on: $specificChannel');
    MethodChannel(specificChannel).setMethodCallHandler(_handleCall);

    // 2. Listen on Generic Channel (Fallback)
    debugPrint('👂 Listening on: desktop_multi_window');
    const MethodChannel('desktop_multi_window')
        .setMethodCallHandler(_handleCall);
    // 3. Listen on Zero ID (Fallback for int parsing failure)
    debugPrint('👂 Listening on: mixin.one/window_controller/0');
    const MethodChannel('mixin.one/window_controller/0')
        .setMethodCallHandler(_handleCall);
  }

  Future<dynamic> _handleCall(MethodCall call) async {
    debugPrint('📩 Received MethodCall: ${call.method} on window $windowId');
    if (call.method == 'update') {
      try {
        final args = Map<String, dynamic>.from(call.arguments);
        _updateController.add(args);
      } catch (e) {
        debugPrint('Error processing update: $e');
      }
    } else if (call.method == 'close') {
      SystemNavigator.pop();
    }
    return null;
  }

  void dispose() {
    _updateController.close();
  }
}
