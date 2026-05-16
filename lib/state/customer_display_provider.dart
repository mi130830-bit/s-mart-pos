import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'dart:convert';

class CustomerDisplayProvider extends ChangeNotifier {
  final String windowId;
  VoidCallback? onReloadSettings;

  CustomerDisplayProvider(this.windowId);

  // State Variables
  String _state = 'idle';
  double _received = 0.0;
  double _change = 0.0;
  double _total = 0.0;
  List<dynamic> _items = [];
  String? _qrData;
  double _qrAmount = 0.0;

  // Settings
  double? _fontSize;

  // Getters
  String get state => _state;
  double get received => _received;
  double get change => _change;
  double get total => _total;
  List<dynamic> get items => _items;
  String? get qrData => _qrData;
  double get qrAmount => _qrAmount;
  double? get fontSize => _fontSize;

  void startSync() {
    debugPrint('🔄 Customer Display Sync Started (IPC Mode)');
    
    // Register IPC Handler synchronously using known windowId
    try {
      final controller = WindowController.fromWindowId(windowId);
      controller.setWindowMethodHandler((call) async {
        if (call.method == 'update_state') {
          _updateData(jsonDecode(call.arguments.toString()));
        } else if (call.method == 'reload_settings') {
          onReloadSettings?.call();
        }
        return "OK";
      });
    } catch (e) {
      debugPrint('⚠️ IPC Handler Registration Failed: $e');
    }
  }

  void stopSync() {
    debugPrint('🛑 Customer Display Sync Stopped');
    // IPC Handler is managed by the plugin, no specific clear needed here
  }

  void _updateData(Map<String, dynamic> data) {
    _state = data['state'] ?? 'idle';
    _total = (data['total'] ?? 0.0).toDouble();
    _items = data['items'] ?? [];
    _qrData = data['qrData'];
    _qrAmount = (data['amount'] ?? 0.0).toDouble();
    _received = (data['received'] ?? 0.0).toDouble();
    _change = (data['change'] ?? 0.0).toDouble();

    // ✅ Parse Settings
    if (data['settings'] != null) {
      _fontSize = (data['settings']['fontSize'] as num?)?.toDouble();
    }

    notifyListeners();
  }

  @override
  void dispose() {
    stopSync();
    super.dispose();
  }
}
