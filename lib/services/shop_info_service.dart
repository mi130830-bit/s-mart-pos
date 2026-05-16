import '../models/shop_info.dart';
import 'settings_service.dart';

class ShopInfoService {
  // Keys are now managed in SettingsService

  Future<ShopInfo> getShopInfo() async {
    final settings = SettingsService();
    // Ensure settings are loaded or load them?
    // Usually SettingsService is loaded at startup.
    // But safely we assume it might be accessed directly.

    // Note: SettingsService.loadSettings() is async but getters are synchronous from memory cache.
    // If cache is empty, it might need reloading?
    // For now we assume the app Init loads settings.

    return ShopInfo(
      name: settings.shopName,
      address: settings.shopAddress,
      phone: settings.shopPhone,
      taxId: settings.shopTaxId,
      footer: settings.shopFooter,
      promptPayId: settings.promptPayId,
      shortName: settings.shopShortName,
      shortAddress: settings.shopShortAddress,
    );
  }

  Future<void> saveShopInfo(ShopInfo info) async {
    final settings = SettingsService();
    // These setters are async (return Future<void>)
    await settings.set('shop_name', info.name);
    await settings.set('shop_address', info.address);
    await settings.set('shop_phone', info.phone);
    await settings.set('shop_tax_id', info.taxId);
    await settings.set('shop_footer', info.footer);
    await settings.set('promptpay_id', info.promptPayId);
    await settings.set('shop_short_name', info.shortName);
    await settings.set('shop_short_address', info.shortAddress);
  }
}
