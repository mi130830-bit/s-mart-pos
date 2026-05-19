import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/customer.dart';
import '../../../models/shop_info.dart';
import '../../../repositories/customer_repository.dart';
import '../../shop_info_service.dart';

class PrintDataHelper {
  static const String _keyShopLogo = 'shop_logo_base64';

  static Future<ShopInfo> getShopInfo() async {
    return ShopInfoService().getShopInfo();
  }

  static Future<Uint8List?> getShopLogoBytes() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final logoPath = prefs.getString('shop_logo_path');
      if (logoPath != null && logoPath.isNotEmpty) {
        final file = File(logoPath);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }
      final base64String = prefs.getString(_keyShopLogo);
      if (base64String != null && base64String.isNotEmpty) {
        return base64Decode(base64String);
      }
    } catch (e) {
      debugPrint('Error loading logo: $e');
    }
    return null;
  }

  static Future<Customer?> refreshCustomer(Customer? customer) async {
    if (customer == null || customer.id <= 0) return customer;
    try {
      final repo = CustomerRepository();
      // Add Timeout to prevent hanging if DB locked
      final fetched = await repo.getCustomerById(customer.id).timeout(const Duration(seconds: 2));
      if (fetched != null) {
        return fetched;
      }
    } catch (e) {
      debugPrint('⚠️ [PrintDataHelper] Failed to refresh customer (Timeout/Error): $e');
    }
    return customer;
  }
}
