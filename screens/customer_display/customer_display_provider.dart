import 'package:flutter/material.dart';
import 'customer_display_repository.dart';

enum CustomerDisplayMode { idle, cart, payment, success }

class CustomerDisplayProvider extends ChangeNotifier {
  final CustomerDisplayRepository _repository;

  CustomerDisplayMode _mode = CustomerDisplayMode.idle;
  List<Map<String, dynamic>> _items = [];
  double _total = 0.0;
  double _received = 0.0;
  double _change = 0.0;
  String? _qrData;
  double _qrAmount = 0.0;

  // Getters
  CustomerDisplayMode get mode => _mode;
  List<Map<String, dynamic>> get items => _items;
  double get total => _total;
  double get received => _received;
  double get change => _change;
  String? get qrData => _qrData;
  double get qrAmount => _qrAmount;

  CustomerDisplayProvider(this._repository) {
    _repository.updates.listen(_handleUpdate);
  }

  void _handleUpdate(Map<String, dynamic> data) {
    // Determine State
    final stateStr = data['state'] as String? ?? 'idle';
    switch (stateStr) {
      case 'payment':
        _mode = CustomerDisplayMode.payment;
        break;
      case 'success':
        _mode = CustomerDisplayMode.success;
        break;
      case 'active':
        _mode = CustomerDisplayMode.cart;
        break;
      default:
        _mode = CustomerDisplayMode.idle;
        break;
    }

    // Update Totals
    _total = (data['total'] as num?)?.toDouble() ?? 0.0;
    _received = (data['received'] as num?)?.toDouble() ?? 0.0;
    _change = (data['change'] as num?)?.toDouble() ?? 0.0;
    _qrAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    _qrData = data['qrData']; // Can be null

    // Update Items
    if (data['items'] != null) {
      _items = List<Map<String, dynamic>>.from(
          (data['items'] as List).map((e) => Map<String, dynamic>.from(e)));
    } else {
      _items = [];
    }

    notifyListeners();
  }
}
