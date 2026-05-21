import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

import '../../../../models/product.dart';
import '../../../../repositories/product_repository.dart';
import '../../../../services/printing/barcode_print_service.dart';
import '../../../../services/pdf/barcode_label_pdf.dart';
import '../../../../services/alert_service.dart';
import '../../../../services/printing/label_printer_service.dart';
import '../../../../models/label_config.dart';

final productRepositoryProvider = Provider((ref) => ProductRepository());
final barcodePrintServiceProvider = Provider((ref) => BarcodePrintService());

class BarcodePrintingState {
  final List<Product> filteredProducts;
  final Map<int, int> printCounts;
  final Map<int, Product> selectedProductsCache;
  final bool isLoading;
  final String orientation;

  BarcodePrintingState({
    this.filteredProducts = const [],
    this.printCounts = const {},
    this.selectedProductsCache = const {},
    this.isLoading = true,
    this.orientation = 'landscape',
  });

  BarcodePrintingState copyWith({
    List<Product>? filteredProducts,
    Map<int, int>? printCounts,
    Map<int, Product>? selectedProductsCache,
    bool? isLoading,
    String? orientation,
  }) {
    return BarcodePrintingState(
      filteredProducts: filteredProducts ?? this.filteredProducts,
      printCounts: printCounts ?? this.printCounts,
      selectedProductsCache: selectedProductsCache ?? this.selectedProductsCache,
      isLoading: isLoading ?? this.isLoading,
      orientation: orientation ?? this.orientation,
    );
  }
}

class BarcodePrintingController extends AutoDisposeNotifier<BarcodePrintingState> {
  Timer? _debounce;
  final TextEditingController searchController = TextEditingController();

  late final ProductRepository _productRepo;
  late final BarcodePrintService _barcodePrintService;

  @override
  BarcodePrintingState build() {
    _productRepo = ref.read(productRepositoryProvider);
    _barcodePrintService = ref.read(barcodePrintServiceProvider);

    ref.onDispose(() {
      _debounce?.cancel();
      searchController.dispose();
    });

    Future.microtask(() => _init());
    return BarcodePrintingState();
  }

  void _init() {
    loadProducts();
    final initialPrintCounts = Map<int, int>.from(_barcodePrintService.printQueue);
    final initialCache = Map<int, Product>.from(_barcodePrintService.productCache);
    
    state = state.copyWith(
      printCounts: initialPrintCounts,
      selectedProductsCache: initialCache,
    );
  }

  Future<void> loadProducts({String searchTerm = ''}) async {
    state = state.copyWith(isLoading: true);
    try {
      final products = await _productRepo.getProductsPaginated(
        1,
        50,
        searchTerm: searchTerm,
      );
      state = state.copyWith(
        filteredProducts: products,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error loading products: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      loadProducts(searchTerm: query);
    });
  }

  void updateCount(int productId, int delta) {
    final currentCounts = Map<int, int>.from(state.printCounts);
    final currentCache = Map<int, Product>.from(state.selectedProductsCache);

    int current = currentCounts[productId] ?? 0;
    int next = current + delta;

    if (delta > 0) {
      try {
        final p = state.filteredProducts.firstWhere((p) => p.id == productId);
        currentCache[productId] = p;
      } catch (_) {}
    }

    if (next <= 0) {
      currentCounts.remove(productId);
    } else {
      currentCounts[productId] = next;
    }

    state = state.copyWith(
      printCounts: currentCounts,
      selectedProductsCache: currentCache,
    );

    _barcodePrintService.updateQueue(
        productId,
        next,
        next > 0
            ? state.filteredProducts.firstWhere((p) => p.id == productId,
                orElse: () => currentCache[productId]!)
            : null);
  }

  void updateCountExact(int productId, int value) {
    final currentCounts = Map<int, int>.from(state.printCounts);
    final currentCache = Map<int, Product>.from(state.selectedProductsCache);

    if (value <= 0) {
      currentCounts.remove(productId);
    } else {
      currentCounts[productId] = value;
    }

    state = state.copyWith(
      printCounts: currentCounts,
    );

    _barcodePrintService.updateQueue(
        productId,
        value,
        value > 0
            ? state.filteredProducts.firstWhere((p) => p.id == productId,
                orElse: () => currentCache[productId]!)
            : null);
  }

  void clearQueue() {
    state = state.copyWith(printCounts: {});
    _barcodePrintService.clearQueue();
  }

  void setOrientation(String val) {
    state = state.copyWith(orientation: val);
  }

  Future<void> handlePrint(BuildContext context) async {
    if (state.printCounts.isEmpty) {
      if (context.mounted) {
        AlertService.show(
          context: context,
          message: 'กรุณาเลือกสินค้าที่ต้องการพิมพ์',
          type: 'warning',
        );
      }
      return;
    }

    final List<Map<String, dynamic>> productData = [];
    for (var entry in state.printCounts.entries) {
      Product? product;
      try {
        product = state.filteredProducts.firstWhere((p) => p.id == entry.key);
      } catch (_) {
        product = await _productRepo.getProductById(entry.key);
      }

      if (product != null) {
        for (int i = 0; i < entry.value; i++) {
          productData.add({
            'barcode': product.barcode ?? '',
            'name': product.name,
            'retailPrice': product.retailPrice,
            'wholesalePrice': product.wholesalePrice,
          });
        }
      }
    }

    try {
      final template = await _barcodePrintService.getSelectedTemplate();
      if (template == null) {
        throw Exception('กรุณาเลือกแม่แบบบาร์โค้ดในหน้าตั้งค่าก่อน');
      }

      final pdfBytes = await BarcodeLabelPdf.generateFromTemplate(
        template: template,
        products: productData,
      );

      final prefs = await SharedPreferences.getInstance();

      String? savedPrinterName;
      if (template.paperWidth == 103.1 && template.paperHeight == 27.4) {
        final config = await LabelPrinterService().getConfig(LabelType.barcode406x108);
        savedPrinterName = config.printerName;
      } else if (template.paperWidth == 32 && template.paperHeight == 25) {
        final config = await LabelPrinterService().getConfig(LabelType.barcode32x25);
        savedPrinterName = config.printerName;
      }

      if (savedPrinterName == null || savedPrinterName.isEmpty) {
        savedPrinterName = prefs.getString('printer_barcode_name');
      }

      bool isVirtual = false;
      if (savedPrinterName != null) {
        final String pLower = savedPrinterName.toLowerCase();
        if (pLower.contains('pdf') ||
            pLower.contains('writer') ||
            pLower.contains('virtual') ||
            pLower.contains('save') ||
            pLower.contains('document') ||
            pLower.contains('one-note') ||
            pLower.contains('microsoft') ||
            pLower.contains('oxps')) {
          isVirtual = true;
        }
      }

      final useCurrentSettings = prefs.getBool('barcode_use_current_settings') ?? false;

      PdfPageFormat pageFormat = PdfPageFormat(
        template.paperWidth * PdfPageFormat.mm,
        template.paperHeight * PdfPageFormat.mm,
        marginAll: 0,
      );

      if (state.orientation == 'landscape') {
        pageFormat = pageFormat.landscape;
      } else {
        pageFormat = pageFormat.portrait;
      }

      if (savedPrinterName != null) {
        final printers = await Printing.listPrinters();
        final printer = printers.firstWhere(
            (p) => p.name == savedPrinterName || p.url == savedPrinterName,
            orElse: () => printers.first);

        final String pName = printer.name.toLowerCase();

        if (isVirtual ||
            pName.contains('pdf') ||
            pName.contains('writer') ||
            pName.contains('virtual') ||
            pName.contains('save') ||
            pName.contains('document') ||
            pName.contains('microsoft')) {
          await Printing.layoutPdf(
            onLayout: (format) async => pdfBytes,
            name: 'Barcodes_${DateTime.now().millisecondsSinceEpoch}',
            format: pageFormat,
            usePrinterSettings: false,
          );
        } else {
          await Printing.directPrintPdf(
            printer: printer,
            onLayout: (format) async => pdfBytes,
            name: 'Barcodes_${DateTime.now().millisecondsSinceEpoch}',
            format: pageFormat,
            usePrinterSettings: useCurrentSettings,
          );
        }
      } else {
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'Barcodes_${DateTime.now().millisecondsSinceEpoch}',
          format: pageFormat,
          usePrinterSettings: false,
        );
      }

      if (context.mounted) {
        AlertService.show(
          context: context,
          message: 'ส่งคำสั่งพิมพ์ไปยัง $savedPrinterName แล้ว',
          type: 'success',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AlertService.show(
          context: context,
          message: 'เกิดข้อผิดพลาด: $e',
          type: 'error',
        );
      }
    }
  }
}

final barcodePrintingProvider = NotifierProvider.autoDispose<BarcodePrintingController, BarcodePrintingState>(
  () => BarcodePrintingController(),
);
