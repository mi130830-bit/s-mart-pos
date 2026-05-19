import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../services/alert_service.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/settings_section_header.dart';
import '../../models/product.dart';
import 'package:provider/provider.dart';
import '../pos/pos_state_manager.dart';
import '../products/product_multi_selection_dialog.dart';

// ── Part files ────────────────────────────────────────────────────────────────
part 'general_settings/widgets/policy_settings_card.dart';
part 'general_settings/widgets/point_settings_card.dart';
part 'general_settings/widgets/security_settings_card.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  // ── Policy State ──────────────────────────────────────────────────────────
  double _vatRate = 7.0;
  double _memberDiscountRate = 0.0;
  bool _allowPosPriceEdit = false;
  bool _allowNegativeStock = true;
  bool _enableWarehouseAutoTag = true;
  String _roundingMode = 'none';
  String _itemDiscountMode = 'per_item';

  // ── Security State ────────────────────────────────────────────────────────
  String _adminPin = '1234';
  bool _requireAdminForVoid = false;
  bool _requireAdminForStockAdjust = false;

  // ── Point State ───────────────────────────────────────────────────────────
  bool _pointEnabled = false;
  String _pointCalcType = 'price';
  final TextEditingController _pointPriceRateCtrl =
      TextEditingController(text: '100');
  bool _pointAfterDiscount = false;
  final TextEditingController _pointRedemptionRateCtrl =
      TextEditingController(text: '10');

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _pointPriceRateCtrl.dispose();
    _pointRedemptionRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = SettingsService();
    setState(() {
      // Policy
      _vatRate = settings.vatRate;
      _memberDiscountRate = settings.memberDiscountRate;
      _allowPosPriceEdit = settings.getBool('allow_pos_price_edit', defaultValue: false);
      _allowNegativeStock = settings.allowNegativeStock;
      _enableWarehouseAutoTag = settings.enableWarehouseAutoTag;
      _roundingMode = settings.roundingMode;
      _itemDiscountMode = settings.itemDiscountMode;
      // Security
      _adminPin = settings.adminPin;
      _requireAdminForVoid = settings.requireAdminForVoid;
      _requireAdminForStockAdjust = settings.requireAdminForStockAdjust;
      // Points
      _pointEnabled = settings.pointEnabled;
      _pointCalcType = settings.pointCalcType;
      _pointPriceRateCtrl.text = settings.pointPriceRate.toStringAsFixed(0);
      _pointAfterDiscount = settings.pointAfterDiscount;
      _pointRedemptionRateCtrl.text = settings.pointRedemptionRate.toStringAsFixed(0);
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final settings = SettingsService();
    // Policy
    await settings.set('vat_rate', _vatRate);
    await settings.set('member_discount_rate', _memberDiscountRate);
    await settings.set('allow_pos_price_edit', _allowPosPriceEdit);
    await settings.set('allow_negative_stock', _allowNegativeStock);
    await settings.set('enable_warehouse_auto_tag', _enableWarehouseAutoTag);
    await settings.set('rounding_mode', _roundingMode);
    await settings.set('item_discount_mode', _itemDiscountMode);
    // Security
    await settings.set('admin_pin', _adminPin);
    await settings.set('require_admin_for_void', _requireAdminForVoid);
    await settings.set('require_admin_for_stock_adjust', _requireAdminForStockAdjust);
    // Points
    await settings.set('point_enabled', _pointEnabled);
    await settings.set('point_calc_type', _pointCalcType);
    await settings.set('point_price_rate', double.tryParse(_pointPriceRateCtrl.text) ?? 100);
    await settings.set('point_after_discount', _pointAfterDiscount);
    await settings.set('point_redemption_rate', double.tryParse(_pointRedemptionRateCtrl.text) ?? 10);

    if (mounted) {
      try {
        context.read<PosStateManager>().refreshGeneralSettings();
      } catch (_) {
        // Ignored if Provider is not found (e.g. testing)
      }
      AlertService.show(
        context: context,
        message: 'บันทึกการตั้งค่าแล้ว (Saved Globally)',
        type: 'success',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่าทั่วไป (General Policy)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Policy & Rounding ─────────────────────────────────────
                _buildPolicyCard(),
                const SizedBox(height: 10),
                _buildRoundingCard(),

                // ── Point System ──────────────────────────────────────────
                const SizedBox(height: 20),
                const SettingsSectionHeader(
                  title: 'ระบบแต้มสะสม (Point System)',
                  icon: Icons.stars,
                  color: Colors.amber,
                ),
                _buildPointRedemptionCard(),
                const SizedBox(height: 10),
                _buildPointAccumulationCard(),

                // ── Security ──────────────────────────────────────────────
                const SizedBox(height: 20),
                const SettingsSectionHeader(
                  title: 'ความปลอดภัย (Security Settings)',
                  icon: Icons.security,
                  color: Colors.red,
                ),
                _buildSecurityCard(),

                const SizedBox(height: 30),
              ],
            ),
    );
  }
}
