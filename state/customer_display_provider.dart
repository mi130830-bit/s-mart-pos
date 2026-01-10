import 'dart:async';
import 'package:flutter/material.dart';
import '../repositories/customer_display_repository.dart';

class CustomerDisplayProvider extends ChangeNotifier {
  // Use the restored File Repository
  final CustomerDisplayRepository _repository = CustomerDisplayRepository();

  // Constructor accepts dynamic to prevent error from main.dart injection
  // defined in lib/main.dart where it passes the Stream-based repo.
  // We ignore it and use our local file-based repo.
  CustomerDisplayProvider(dynamic ignoredRepo);

  Timer? _timer;

  // State Variables
  String _state = 'idle';
  double _received = 0.0;
  double _change = 0.0;
  double _total = 0.0;
  List<dynamic> _items = [];
  String? _qrData;
  double _qrAmount = 0.0;
  int _lastTimestamp = 0;

  // Getters
  String get state => _state;
  double get received => _received;
  double get change => _change;
  double get total => _total;
  List<dynamic> get items => _items;
  String? get qrData => _qrData;
  double get qrAmount => _qrAmount;

  void startSync() {
    _timer?.cancel();
    debugPrint('🔄 Customer Display Sync Started (File Polling Mode)');
    // Poll every 500ms
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      await _fetchData();
    });
  }

  void stopSync() {
    _timer?.cancel();
    debugPrint('🛑 Customer Display Sync Stopped');
  }

  Future<void> _fetchData() async {
    final data = await _repository.fetchDisplayState();
    if (data == null) return;

    final int timestamp = data['timestamp'] ?? 0;

    // Update only if timestamp is newer or different
    if (timestamp > _lastTimestamp) {
      _lastTimestamp = timestamp;

      _state = data['state'] ?? 'idle';
      _total = (data['total'] ?? 0.0).toDouble();
      _items = data['items'] ?? [];
      _qrData = data['qrData'];
      _qrAmount = (data['amount'] ?? 0.0).toDouble();
      _received = (data['received'] ?? 0.0).toDouble();
      _change = (data['change'] ?? 0.0).toDouble();

      notifyListeners();
      // debugPrint('✅ Display Updated from File: $_state (Time: $timestamp)');
    }
  }

  @override
  void dispose() {
    stopSync();
    super.dispose();
  }
}
