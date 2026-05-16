import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class OnlineProductLookupService {
  static const String _baseUrl =
      'https://world.openfoodfacts.org/api/v0/product';

  /// Searches for a product by barcode using OpenFoodFacts API.
  /// Returns a Map with 'name' and 'image_url' if found, otherwise null.
  Future<Map<String, dynamic>?> lookup(String barcode) async {
    try {
      final uri = Uri.parse('$_baseUrl/$barcode.json');
      debugPrint('🌍 [OnlineLookup] Searching: $uri');

      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1) {
          // 1 = Found
          final product = data['product'];
          final name = product['product_name'] ??
              product['product_name_th'] ??
              product['product_name_en'] ??
              '';
          final imageUrl =
              product['image_front_url'] ?? product['image_url'] ?? '';

          if (name.isNotEmpty) {
            debugPrint('✅ [OnlineLookup] Found: $name');
            return {
              'name': name,
              'image_url': imageUrl,
              'brands': product['brands'] ?? '',
              'categories': product['categories'] ?? '',
            };
          }
        } else {
          debugPrint('⚠️ [OnlineLookup] Product not found in OFF DB');
        }
      } else {
        debugPrint('⚠️ [OnlineLookup] API Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🔥 [OnlineLookup] Error: $e');
    }
    return null;
  }
}
