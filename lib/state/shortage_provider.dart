import 'dart:async';
import 'package:flutter/foundation.dart';
import '../repositories/shortage_repository.dart';
import '../repositories/product_repository.dart';
import '../models/shortage_log_model.dart';
import '../models/product.dart';
import '../models/user.dart';

class ShortageProvider extends ChangeNotifier {
  final ShortageRepository _repo = ShortageRepository();
  final ProductRepository _productRepo = ProductRepository();

  List<ShortageLogModel> _openShortages = [];
  List<ShortageLogModel> _orderedShortages = [];
  List<Product> _lowStockProducts = [];
  Map<int, List<Map<String, dynamic>>> _priceSuggestions = {};
  Map<int, Map<String, dynamic>?> _stockQuantities = {};

  bool _isLoading = false;
  Timer? _pollingTimer;

  List<ShortageLogModel> get openShortages => _openShortages;
  List<ShortageLogModel> get orderedShortages => _orderedShortages;
  List<Product> get lowStockProducts => _lowStockProducts;
  Map<int, List<Map<String, dynamic>>> get priceSuggestions => _priceSuggestions;
  Map<int, Map<String, dynamic>?> get stockQuantities => _stockQuantities;
  bool get isLoading => _isLoading;

  ShortageProvider() {
    // Start polling automatically when provider is created
    startPolling();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
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
      _isLoading = true;
      notifyListeners();
    }
    try {
      final results = await Future.wait([
        _repo.getOpenShortages(),
        _repo.getOrderedShortages(),
      ]);
      _openShortages = results[0];
      _orderedShortages = results[1];
      // Load low stock products from system
      _lowStockProducts = await _productRepo.getLowStockProducts();

      // Reset suggestions cache each cycle so new PO data is picked up
      _priceSuggestions = {};
      _stockQuantities = {};

      // Load suggestions + stock qty with stagger to avoid DB overload
      for (var i = 0; i < _openShortages.length; i++) {
        final item = _openShortages[i];
        Future.delayed(Duration(milliseconds: i * 40), () {
          if (!hasListeners) return; // disposed
          _repo.getCheapestSupplierSuggestions(item.itemName).then((suggestions) {
            _priceSuggestions[item.id] = suggestions;
            if (suggestions.isNotEmpty) notifyListeners();
          }).catchError((e) {
            debugPrint('❌ [Suggestion Error] ${item.itemName}: $e');
          });

          _repo.getProductStockByName(item.itemName).then((info) {
            _stockQuantities[item.id] = info;
            notifyListeners();
          }).catchError((_) {});
        });
      }
    } catch (e) {
      debugPrint('Error loading shortages: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
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
