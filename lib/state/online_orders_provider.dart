import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/online_order_model.dart';
import '../repositories/online_order_repository.dart';

final onlineOrderRepoProvider = Provider<OnlineOrderRepository>((ref) {
  return OnlineOrderRepository();
});

class OnlineOrdersState {
  final List<OnlineOrder> orders;
  final int pendingCount;
  final bool isLoading;
  final String selectedFilter; // 'ALL', 'PENDING', 'CONFIRMED', 'DISPATCHED', 'COMPLETED'
  final String? errorMessage;

  OnlineOrdersState({
    this.orders = const [],
    this.pendingCount = 0,
    this.isLoading = false,
    this.selectedFilter = 'ALL',
    this.errorMessage,
  });

  OnlineOrdersState copyWith({
    List<OnlineOrder>? orders,
    int? pendingCount,
    bool? isLoading,
    String? selectedFilter,
    String? errorMessage,
  }) {
    return OnlineOrdersState(
      orders: orders ?? this.orders,
      pendingCount: pendingCount ?? this.pendingCount,
      isLoading: isLoading ?? this.isLoading,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      errorMessage: errorMessage,
    );
  }
}

class OnlineOrdersNotifier extends StateNotifier<OnlineOrdersState> {
  final OnlineOrderRepository _repo;
  Timer? _pollingTimer;
  int _lastKnownPendingCount = 0;

  OnlineOrdersNotifier(this._repo) : super(OnlineOrdersState()) {
    fetchOrders();
    startPolling();
  }

  void startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      checkNewOrdersSilent();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void setFilter(String filter) {
    state = state.copyWith(selectedFilter: filter);
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final orders = await _repo.getOrders(status: state.selectedFilter);
      final count = await _repo.getPendingCount();
      state = state.copyWith(
        orders: orders,
        pendingCount: count,
        isLoading: false,
      );
      _lastKnownPendingCount = count;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> checkNewOrdersSilent() async {
    try {
      final count = await _repo.getPendingCount();
      if (count > _lastKnownPendingCount) {
        // Play system notification chime
        SystemSound.play(SystemSoundType.alert);
      }
      _lastKnownPendingCount = count;

      final orders = await _repo.getOrders(status: state.selectedFilter);
      state = state.copyWith(orders: orders, pendingCount: count);
    } catch (_) {}
  }

  Future<bool> updateStatus(int orderId, String newStatus, {String? staffName}) async {
    final success = await _repo.updateStatus(orderId, newStatus, staffName: staffName);
    if (success) {
      await fetchOrders();
    }
    return success;
  }
}

final onlineOrdersProvider =
    StateNotifierProvider<OnlineOrdersNotifier, OnlineOrdersState>((ref) {
  final repo = ref.watch(onlineOrderRepoProvider);
  return OnlineOrdersNotifier(repo);
});

final onlineOrdersPendingCountProvider = Provider<int>((ref) {
  return ref.watch(onlineOrdersProvider.select((s) => s.pendingCount));
});
