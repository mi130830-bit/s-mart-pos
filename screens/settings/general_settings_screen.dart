import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../services/alert_service.dart';
// import '../../widgets/custom_radio_group.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../models/product.dart';
import 'package:provider/provider.dart';
import '../pos/pos_state_manager.dart';
import '../products/product_multi_selection_dialog.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  double _vatRate = 7.0;
  double _memberDiscountRate = 0.0;
  bool _allowPosPriceEdit = false;

  bool _allowNegativeStock = true;
  String _roundingMode = 'none';

  // Point Settings
  bool _pointEnabled = false;
  String _pointCalcType = 'price'; // 'product' or 'price'
  final TextEditingController _pointPriceRateCtrl =
      TextEditingController(text: '100'); // xx Baht / 1 Point
  bool _pointAfterDiscount = false;
  final TextEditingController _pointRedemptionRateCtrl =
      TextEditingController(text: '10'); // xx Points / 1 Baht

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = SettingsService();
    // Ensure settings are loaded or use cached
    // Assuming SettingsService is initialized at app start.

    setState(() {
      _vatRate = settings.vatRate;
      _memberDiscountRate = settings.memberDiscountRate;
      _allowPosPriceEdit = settings.getBool('allow_pos_price_edit',
          defaultValue: false); // Direct key for generic
      _allowNegativeStock = settings.allowNegativeStock;
      _roundingMode = settings.roundingMode;

      // Points
      _pointEnabled = settings.pointEnabled;
      _pointCalcType = settings.pointCalcType;
      _pointPriceRateCtrl.text = settings.pointPriceRate.toStringAsFixed(0);
      _pointAfterDiscount = settings.pointAfterDiscount;
      _pointRedemptionRateCtrl.text =
          settings.pointRedemptionRate.toStringAsFixed(0);

      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final settings = SettingsService();

    // Save Policies
    await settings.set('vat_rate', _vatRate);
    await settings.set('member_discount_rate', _memberDiscountRate);
    await settings.set('allow_pos_price_edit', _allowPosPriceEdit);
    await settings.set('allow_negative_stock', _allowNegativeStock);
    await settings.set('rounding_mode', _roundingMode);

    // Save Points
    await settings.set('point_enabled', _pointEnabled);
    await settings.set('point_calc_type', _pointCalcType);
    await settings.set(
        'point_price_rate', double.tryParse(_pointPriceRateCtrl.text) ?? 100);
    await settings.set('point_after_discount', _pointAfterDiscount);
    await settings.set('point_redemption_rate',
        double.tryParse(_pointRedemptionRateCtrl.text) ?? 10);

    if (mounted) {
      // Notify POS State Manager to reload settings instantly
      try {
        context.read<PosStateManager>().refreshGeneralSettings();
      } catch (e) {
        // Ignored in case Provider is not found (e.g. testing)
      }

      AlertService.show(
        context: context,
        message: 'บันทึกการตั้งค่าแล้ว (Saved Globally)',
        type: 'success',
      );
    }
  }

  void _showVatDialog() {
    final controller = TextEditingController(text: _vatRate.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ตั้งค่า VAT (%)'),
        content: CustomTextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          suffixIcon:
              const Padding(padding: EdgeInsets.all(12), child: Text('%')),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก')),
          CustomButton(
            onPressed: () {
              final newVal = double.tryParse(controller.text);
              if (newVal != null && newVal >= 0) {
                setState(() => _vatRate = newVal);
                _saveSettings();
              }
              Navigator.pop(context);
            },
            label: 'ตกลง',
            type: ButtonType.primary,
          ),
        ],
      ),
    );
  }

  void _showMemberDiscountDialog() {
    final controller =
        TextEditingController(text: _memberDiscountRate.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ตั้งค่าส่วนลดสมาชิก (%)'),
        content: CustomTextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          suffixIcon:
              const Padding(padding: EdgeInsets.all(12), child: Text('%')),
          label: 'ส่วนลดปกติสำหรับสมาชิก',
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก')),
          CustomButton(
            onPressed: () {
              final newVal = double.tryParse(controller.text);
              if (newVal != null && newVal >= 0) {
                setState(() => _memberDiscountRate = newVal);
                _saveSettings();
              }
              Navigator.pop(context);
            },
            label: 'ตกลง',
            type: ButtonType.primary,
          ),
        ],
      ),
    );
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
                // Existing General Settings
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading:
                            const Icon(Icons.percent, color: Colors.orange),
                        title: const Text('อัตราภาษีมูลค่าเพิ่ม (VAT Rate)'),
                        subtitle: const Text('ใช้สำหรับการคำนวณภาษีในบิล'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${_vatRate.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            const Icon(Icons.edit, size: 18),
                          ],
                        ),
                        onTap: _showVatDialog,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.person_outline,
                            color: Colors.blue),
                        title: const Text('ส่วนลดสมาชิก (Member Discount)'),
                        subtitle:
                            const Text('ส่วนลดเปอร์เซ็นต์พื้นฐานสำหรับสมาชิก'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${_memberDiscountRate.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            const Icon(Icons.edit, size: 18),
                          ],
                        ),
                        onTap: _showMemberDiscountDialog,
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('อนุญาตให้แก้ไขราคาหน้าจุดขาย'),
                        subtitle: const Text(
                            'พนักงานสามารถเปลี่ยนราคาต่อหน่วยได้ขณะขาย'),
                        secondary:
                            const Icon(Icons.price_change, color: Colors.green),
                        value: _allowPosPriceEdit,
                        onChanged: (val) {
                          setState(() => _allowPosPriceEdit = val);
                          _saveSettings();
                        },
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('อนุญาตให้ขายสินค้าหมดสต็อก (ติดลบ)'),
                        subtitle: const Text(
                            'หากปิด จะไม่สามารถขายสินค้าที่มีจำนวนไม่พอได้'),
                        secondary: const Icon(Icons.exposure_minus_1,
                            color: Colors.red),
                        value: _allowNegativeStock,
                        onChanged: (val) {
                          setState(() => _allowNegativeStock = val);
                          _saveSettings();
                        },
                      ),
                    ],
                  ),
                ),

                // Rounding Settings
                const SizedBox(height: 10),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading:
                            const Icon(Icons.money_off, color: Colors.purple),
                        title: const Text('การปัดเศษสตางค์ (Rounding)'),
                        subtitle: Text(_roundingMode == 'none'
                            ? 'ไม่ปัดเศษ (แสดงตามจริง)'
                            : _roundingMode == 'up'
                                ? 'ปัดขึ้น (บาทถ้วน)'
                                : _roundingMode == 'down'
                                    ? 'ปัดลง (บาทถ้วน)'
                                    : 'ปัดอัตโนมัติ (ตามหลักคณิตศาสตร์)'),
                        trailing: DropdownButton<String>(
                          value: _roundingMode,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(
                                value: 'none', child: Text('ไม่ปัดเศษ')),
                            DropdownMenuItem(
                                value: 'auto', child: Text('อัตโนมัติ')),
                            DropdownMenuItem(
                                value: 'up', child: Text('ปัดขึ้น (บาทถ้วน)')),
                            DropdownMenuItem(
                                value: 'down', child: Text('ปัดลง (บาทถ้วน)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _roundingMode = val);
                              _saveSettings();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Point Settings
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.only(left: 8.0, bottom: 5),
                  child: Text('ระบบแต้มสะสม (Point System)',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                // Redemption (Use Points)
                Card(
                  child: Column(
                    children: [
                      Container(
                        color: Colors.grey[700],
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        child: const Text('การใช้แต้ม (Redemption)',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('จำนวน', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 80,
                              child: CustomTextField(
                                controller: _pointRedemptionRateCtrl,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => _saveSettings(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text('แต้ม / 1 บาท',
                                style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Accumulation (Earn Points)
                const SizedBox(height: 10),
                Card(
                  child: Column(
                    children: [
                      Container(
                        color: Colors.grey[700],
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        child: const Text('สะสมแต้ม (Accumulation)',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                    value: _pointEnabled,
                                    onChanged: (val) {
                                      setState(() => _pointEnabled = val!);
                                      _saveSettings();
                                    }),
                                const Text('สะสมแต้ม',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                const Spacer(),
                                ElevatedButton(
                                    onPressed: () async {
                                      final settings = SettingsService();
                                      final currentExcluded =
                                          settings.pointExcludedProductIds;
                                      final result =
                                          await showDialog<List<Product>>(
                                        context: context,
                                        builder: (context) =>
                                            ProductMultiSelectionDialog(
                                          initialSelectedIds: currentExcluded,
                                        ),
                                      );

                                      if (result != null) {
                                        final ids =
                                            result.map((p) => p.id).toList();
                                        await settings.set(
                                            'point_excluded_product_ids',
                                            ids.join(','));
                                        if (!context.mounted) return;
                                        AlertService.show(
                                          context: context,
                                          type: 'success',
                                          message:
                                              'บันทึกรายการยกเว้น ${ids.length} รายการ',
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white),
                                    child: const Text('ยกเว้นสินค้า'))
                              ],
                            ),
                            Column(
                              children: [
                                // ignore: deprecated_member_use
                                RadioListTile<String>(
                                  title: const Text('ใช้แต้มตามสินค้า'),
                                  // ignore: deprecated_member_use
                                  value: 'product',
                                  // ignore: deprecated_member_use
                                  groupValue: _pointCalcType,
                                  // ignore: deprecated_member_use
                                  onChanged: (val) {
                                    setState(() => _pointCalcType = val!);
                                    _saveSettings();
                                  },
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      // ignore: deprecated_member_use
                                      child: RadioListTile<String>(
                                        title: const Text('ใช้แต้มตามราคาขาย'),
                                        // ignore: deprecated_member_use
                                        value: 'price',
                                        // ignore: deprecated_member_use
                                        groupValue: _pointCalcType,
                                        // ignore: deprecated_member_use
                                        onChanged: (val) {
                                          setState(() => _pointCalcType = val!);
                                          _saveSettings();
                                        },
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: CustomTextField(
                                        controller: _pointPriceRateCtrl,
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => _saveSettings(),
                                        readOnly: _pointCalcType != 'price',
                                        enabled: _pointCalcType ==
                                            'price', // Also set enabled
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('บาท / 1 แต้ม'),
                                  ],
                                ),
                              ],
                            ),
                            CheckboxListTile(
                              title: const Text('คิดแต้มหลังจากส่วนลด'),
                              value: _pointAfterDiscount,
                              onChanged: (val) {
                                setState(() => _pointAfterDiscount = val!);
                                _saveSettings();
                              },
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
