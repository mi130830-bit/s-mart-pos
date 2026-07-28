import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/supplier.dart';
import '../../repositories/supplier_repository.dart';
import 'dart:async';

final supplierProvider = ChangeNotifierProvider.autoDispose((ref) => SupplierProvider());

class SupplierProvider extends ChangeNotifier {
  final SupplierRepository _repo = SupplierRepository();

  List<Supplier> items = [];
  bool isLoading = false;
  int currentPage = 1;
  final int pageSize = 10;
  int totalItems = 0;
  String searchTerm = '';
  
  Timer? _debounceTimer;

  SupplierProvider() {
    loadData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> loadData() async {
    isLoading = true;
    notifyListeners();

    try {
      totalItems = await _repo.getSupplierCount(searchTerm: searchTerm);
      items = await _repo.getSuppliersPaginated(currentPage, pageSize, searchTerm: searchTerm);
    } catch (e) {
      debugPrint('Supplier load error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void onSearchChanged(String val) {
    searchTerm = val;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      currentPage = 1;
      loadData();
    });
  }

  void changePage(int newPage) {
    currentPage = newPage;
    loadData();
  }

  Future<bool> deleteSupplier(int id) async {
    final res = await _repo.deleteSupplier(id);
    if (res) {
      await loadData();
    }
    return res;
  }
}
