import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/product.dart';
import '../../repositories/product_repository.dart';
import '../../widgets/generic_search_dialog.dart';

class ProductSelectionDialog extends StatefulWidget {
  final List<Product>? products;
  final ProductRepository? repo;
  final bool enableScanner;

  const ProductSelectionDialog({
    super.key,
    this.products,
    this.repo,
    this.enableScanner = true,
  });

  @override
  State<ProductSelectionDialog> createState() => _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends State<ProductSelectionDialog> {
  final GlobalKey<GenericSearchDialogState<Product>> _dialogKey = GlobalKey();

  // Cache for pre-loaded products or first repo fetch
  List<Product>? _cachedProducts;

  Future<List<Product>> _search(String query) async {
    // 1. Load Data if needed
    if (_cachedProducts == null) {
      if (widget.products != null) {
        _cachedProducts = widget.products!;
      } else if (widget.repo != null) {
        _cachedProducts = await widget.repo!.getAllProductsLight();
      } else {
        _cachedProducts = [];
      }
    }

    if (query.isEmpty) return _cachedProducts!;

    final lower = query.toLowerCase();
    return _cachedProducts!.where((p) {
      final nameMatch = p.name.toLowerCase().contains(lower);
      final barcodeMatch = p.barcode?.toLowerCase().contains(lower) ?? false;
      final aliasMatch = p.alias?.toLowerCase().contains(lower) ?? false;
      return nameMatch || barcodeMatch || aliasMatch;
    }).toList();
  }

  Future<void> _openScanner() async {
    final barcode = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: EdgeInsets.zero,
        child: SizedBox(
          width: 500,
          height: 500,
          child: Column(
            children: [
              AppBar(
                title: const Text('Scan Barcode'),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        Navigator.pop(ctx, barcode.rawValue);
                        break;
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (barcode != null && mounted) {
      // Update search text in GenericDialog
      _dialogKey.currentState?.updateSearchText(barcode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GenericSearchDialog<Product>(
      key: _dialogKey,
      title: 'เลือกสินค้า / Select Product',
      hintText: 'ค้นหา (ชื่อ, Barcode, Alias)',
      emptyMessage: 'ไม่พบสินค้า',
      onSearch: _search,
      onScan: widget.enableScanner ? _openScanner : null,
      itemBuilder: (context, p) {
        return ListTile(
          title:
              Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            'Barcode: ${p.barcode ?? '-'} | คงเหลือ: ${p.stockQuantity.toStringAsFixed(0)}',
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          hoverColor: Colors.indigo.withValues(alpha: 0.05),
          onTap: () => Navigator.pop(context, p),
        );
      },
    );
  }
}
