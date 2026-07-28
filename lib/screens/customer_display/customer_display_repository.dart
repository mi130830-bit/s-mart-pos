import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';

class CustomerDisplayRepository {
  final _updateController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get updates => _updateController.stream;

  final dynamic windowId;

  CustomerDisplayRepository(this.windowId) {
    debugPrint(
        '📢 CustomerDisplayRepository Initialized for Window: $windowId');
  }

  Future<void> init() async {
    try {
      final channelName = 'mixin.one/window_controller/$windowId';
      final channel = WindowMethodChannel(channelName, mode: ChannelMode.unidirectional);
      await channel.setMethodCallHandler(_handleCall);
      debugPrint('👂 Registered WindowMethodChannel: $channelName');
    } catch (e) {
      debugPrint('⚠️ Error setting up WindowMethodChannel: $e');
    }
  }

  Future<dynamic> _handleCall(MethodCall call) async {
    debugPrint('📩 Received MethodCall: ${call.method} on window $windowId');
    
    if (call.method == 'reload_settings') {
      _updateController.add({'action': 'reloadSettings'});
      return null;
    }

    if (call.method == 'update_state' || call.method == 'update') {
      try {
        Map<String, dynamic> args;
        if (call.arguments is String) {
          args = Map<String, dynamic>.from(jsonDecode(call.arguments));
        } else {
          args = Map<String, dynamic>.from(call.arguments);
        }
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
