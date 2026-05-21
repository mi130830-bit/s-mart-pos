import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'customer_display_repository.dart';

enum CustomerDisplayMode { idle, cart, payment, success }

@immutable
class CustomerDisplayState {
  final CustomerDisplayMode mode;
  final List<Map<String, dynamic>> items;
  final double total;
  final double received;
  final double change;
  final String? qrData;
  final double qrAmount;

  const CustomerDisplayState({
    this.mode = CustomerDisplayMode.idle,
    this.items = const [],
    this.total = 0.0,
    this.received = 0.0,
    this.change = 0.0,
    this.qrData,
    this.qrAmount = 0.0,
  });

  CustomerDisplayState copyWith({
    CustomerDisplayMode? mode,
    List<Map<String, dynamic>>? items,
    double? total,
    double? received,
    double? change,
    String? qrData,
    double? qrAmount,
  }) {
    return CustomerDisplayState(
      mode: mode ?? this.mode,
      items: items ?? this.items,
      total: total ?? this.total,
      received: received ?? this.received,
      change: change ?? this.change,
      qrData: qrData ?? this.qrData,
      qrAmount: qrAmount ?? this.qrAmount,
    );
  }
}

final customerDisplayProvider = NotifierProvider.family.autoDispose<CustomerDisplayNotifier, CustomerDisplayState, String>(
  CustomerDisplayNotifier.new,
);

class CustomerDisplayNotifier extends AutoDisposeFamilyNotifier<CustomerDisplayState, String> {
  late final CustomerDisplayRepository _repository;
  StreamSubscription? _subscription;
  void Function()? onReloadSettings;

  @override
  CustomerDisplayState build(String arg) {
    _repository = CustomerDisplayRepository(arg);
    _subscription = _repository.updates.listen(_handleUpdate);
    
    ref.onDispose(() {
      _subscription?.cancel();
    });
    
    return const CustomerDisplayState();
  }

  void startSync() {
    // Synchronization is started in build()
  }

  void _handleUpdate(Map<String, dynamic> data) {
    if (data['action'] == 'reloadSettings' || data['state'] == 'reloadSettings') {
      onReloadSettings?.call();
      return;
    }

    // Determine State
    final stateStr = data['state'] as String? ?? 'idle';
    CustomerDisplayMode newMode;
    switch (stateStr) {
      case 'payment':
        newMode = CustomerDisplayMode.payment;
        break;
      case 'success':
        newMode = CustomerDisplayMode.success;
        break;
      case 'active':
        newMode = CustomerDisplayMode.cart;
        break;
      default:
        newMode = CustomerDisplayMode.idle;
        break;
    }

    // Update Totals
    final newTotal = (data['total'] as num?)?.toDouble() ?? 0.0;
    final newReceived = (data['received'] as num?)?.toDouble() ?? 0.0;
    final newChange = (data['change'] as num?)?.toDouble() ?? 0.0;
    final newQrAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final newQrData = data['qrData'] as String?; // Can be null

    // Update Items
    List<Map<String, dynamic>> newItems;
    if (data['items'] != null) {
      newItems = List<Map<String, dynamic>>.from(
          (data['items'] as List).map((e) => Map<String, dynamic>.from(e)));
    } else {
      newItems = [];
    }

    state = state.copyWith(
      mode: newMode,
      total: newTotal,
      received: newReceived,
      change: newChange,
      qrAmount: newQrAmount,
      qrData: newQrData,
      items: newItems,
    );
  }
}
