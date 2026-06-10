import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/shortage_repository.dart';
import '../repositories/product_repository.dart';
import '../models/shortage_log_model.dart';
import '../models/product.dart';
import '../models/user.dart';

class ShortageState {
  final List<ShortageLogModel> openShortages;
  final List<ShortageLogModel> orderedShortages;
  final List<Product> lowStockProducts;
  final Map<int, List<Map<String, dynamic>>> priceSuggestions;
  final Map<int, Map<String, dynamic>?> stockQuantities;
  final bool isLoading;

  ShortageState({
    this.openShortages = const [],
    this.orderedShortages = const [],
    this.lowStockProducts = const [],
    this.priceSuggestions = const {},
    this.stockQuantities = const {},
    this.isLoading = false,
  });

  ShortageState copyWith({
    List<ShortageLogModel>? openShortages,
    List<ShortageLogModel>? orderedShortages,
    List<Product>? lowStockProducts,
    Map<int, List<Map<String, dynamic>>>? priceSuggestions,
    Map<int, Map<String, dynamic>?>? stockQuantities,
    bool? isLoading,
  }) {
    return ShortageState(
      openShortages: openShortages ?? this.openShortages,
      orderedShortages: orderedShortages ?? this.orderedShortages,
      lowStockProducts: lowStockProducts ?? this.lowStockProducts,
      priceSuggestions: priceSuggestions ?? this.priceSuggestions,
      stockQuantities: stockQuantities ?? this.stockQuantities,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final shortageProvider = AutoDisposeNotifierProvider<ShortageNotifier, ShortageState>(
  () => ShortageNotifier(),
);

class ShortageNotifier extends AutoDisposeNotifier<ShortageState> {
  final ShortageRepository _repo = ShortageRepository();
  final ProductRepository _productRepo = ProductRepository();
  Timer? _pollingTimer;

  @override
  ShortageState build() {
    ref.keepAlive();
    
    // Cleanup timer on dispose
    ref.onDispose(() {
      stopPolling();
    });

    // Start polling automatically when provider is created
    Future.microtask(() => startPolling());
    return ShortageState();
  }

  void startPolling() {
    stopPolling(); // Logically reset if called multiple times
    // Fetch immediately
    loadShortages(silent: true);
    // Poll every 30 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      loadShortages(silent: true);
    });
    debugPrint('🔄 ShortageProvider: Polling started.');
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> loadShortages({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true);
    }
    try {
      final results = await Future.wait([
        _repo.getOpenShortages(),
        _repo.getOrderedShortages(),
      ]);
      final openShortages = results[0];
      final orderedShortages = results[1];
      // Load low stock products from system
      final lowStockProducts = await _productRepo.getLowStockProducts();

      // Reset suggestions cache each cycle so new PO data is picked up
      state = state.copyWith(
        openShortages: openShortages,
        orderedShortages: orderedShortages,
        lowStockProducts: lowStockProducts,
        priceSuggestions: {},
        stockQuantities: {},
      );

      // Load suggestions + stock qty asynchronously in batches to avoid rapid UI flickering (วูบๆ)
      _fetchDetailsInBatches(openShortages);
    } catch (e) {
      debugPrint('Error loading shortages: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void _fetchDetailsInBatches(List<ShortageLogModel> openShortages) async {
    final Map<int, List<Map<String, dynamic>>> newSuggestions = {};
    final Map<int, Map<String, dynamic>?> newQuantities = {};

    for (var i = 0; i < openShortages.length; i++) {
      final item = openShortages[i];
      
      // Stagger DB load to prevent connection pool exhaustion
      await Future.delayed(const Duration(milliseconds: 20));

      try {
        newSuggestions[item.id] = await _repo.getCheapestSupplierSuggestions(item.itemName);
      } catch (e) {
        debugPrint('❌ [Suggestion Error] ${item.itemName}: $e');
      }

      try {
        newQuantities[item.id] = await _repo.getProductStockByName(item.itemName);
      } catch (_) {}

      // Batch UI updates every 15 items, or on the last item, to drastically reduce rebuilds.
      if ((i > 0 && i % 15 == 0) || i == openShortages.length - 1) {
        state = state.copyWith(
          priceSuggestions: {...state.priceSuggestions, ...newSuggestions},
          stockQuantities: {...state.stockQuantities, ...newQuantities},
        );
      }
    }
  }

  Future<List<ProductSearchResult>> searchProducts(String query) async {
    return await _repo.searchProducts(query);
  }

  Future<void> createShortage(String itemName, User? user) async {
    final reporterName =
        user != null ? '${user.displayName} (${user.role})' : 'Unknown';
    await _repo.createShortage(itemName, reporterName);
    loadShortages(silent: true); // Info: Refresh list immediately
  }

  Future<void> markAsOrdered(int id) async {
    await _repo.markAsOrdered(id);
    loadShortages(silent: true);
  }

  Future<void> markAsReceived(int id) async {
    await _repo.markAsReceived(id);
    loadShortages(silent: true);
  }

  Future<void> markAsDone(int id) async {
    await _repo.markAsDone(id);
    loadShortages(silent: true);
  }
}
