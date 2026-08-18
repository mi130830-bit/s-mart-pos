import 'dart:convert';

import 'package:http/http.dart' as http;

/// A best-effort barcode name helper. Results are suggestions only and are
/// never saved until the user explicitly chooses one in the product form.
class BarcodeProductSuggestion {
  const BarcodeProductSuggestion({required this.name, required this.source});

  final String name;
  final String source;
}

class BarcodeProductLookupService {
  BarcodeProductLookupService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<BarcodeProductSuggestion>> lookup(String barcode) async {
    final code = barcode.trim();
    if (!RegExp(r'^\d{8,14}$').hasMatch(code)) return [];

    final results = <BarcodeProductSuggestion>[];
    final seenNames = <String>{};

    Future<void> addFrom(Future<List<BarcodeProductSuggestion>> request) async {
      try {
        for (final item in await request) {
          if (item.name.isNotEmpty && seenNames.add(item.name.toLowerCase())) {
            results.add(item);
          }
        }
      } catch (_) {
        // External lookup is optional; one provider failing must not block the
        // normal product-creation flow or the other provider.
      }
    }

    await addFrom(_lookupUpcItemDb(code));
    await addFrom(_lookupOpenFoodFacts(code));
    return results.take(8).toList();
  }

  Future<List<BarcodeProductSuggestion>> _lookupUpcItemDb(String code) async {
    final response = await _client
        .get(
            Uri.https('api.upcitemdb.com', '/prod/trial/lookup', {'upc': code}))
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return [];
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['items'] is! List) return [];
    return decoded['items']
        .whereType<Map>()
        .map((item) {
          final title = item['title']?.toString().trim() ?? '';
          final brand = item['brand']?.toString().trim() ?? '';
          final name =
              brand.isEmpty || title.toLowerCase().contains(brand.toLowerCase())
                  ? title
                  : '$brand $title';
          return BarcodeProductSuggestion(name: name, source: 'UPCitemdb');
        })
        .where((item) => item.name.isNotEmpty)
        .toList();
  }

  Future<List<BarcodeProductSuggestion>> _lookupOpenFoodFacts(
      String code) async {
    final response = await _client.get(
      Uri.https(
        'world.openfoodfacts.org',
        '/api/v2/product/$code',
        {'fields': 'product_name,product_name_th,brands'},
      ),
      headers: const {
        'User-Agent': 'S-Mart-POS/1.0 (inventory product-name lookup)',
      },
    ).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return [];
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['product'] is! Map) return [];
    final product = decoded['product'] as Map;
    final title = (product['product_name_th'] ?? product['product_name'])
            ?.toString()
            .trim() ??
        '';
    final brand = product['brands']?.toString().trim() ?? '';
    if (title.isEmpty) return [];
    final name =
        brand.isEmpty || title.toLowerCase().contains(brand.toLowerCase())
            ? title
            : '$brand $title';
    return [BarcodeProductSuggestion(name: name, source: 'Open Food Facts')];
  }
}
