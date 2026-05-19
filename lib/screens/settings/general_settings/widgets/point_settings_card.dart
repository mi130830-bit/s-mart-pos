// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously
part of '../../general_settings_screen.dart';

/// Point system cards: Redemption (use points) + Accumulation (earn points).
extension PointSettingsCardExtension on _GeneralSettingsScreenState {
  Widget _buildPointRedemptionCard() {
    return Card(
      child: Column(
        children: [
          Container(
            color: Colors.grey[700],
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            child: const Text('การใช้แต้ม (Redemption)',
                style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                const Text('แต้ม / 1 บาท', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointAccumulationCard() {
    return Card(
      child: Column(
        children: [
          Container(
            color: Colors.grey[700],
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            child: const Text('สะสมแต้ม (Accumulation)',
                style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Enable toggle + Exclude products button
                Row(
                  children: [
                    Checkbox(
                      value: _pointEnabled,
                      onChanged: (val) {
                        setState(() => _pointEnabled = val!);
                        _saveSettings();
                      },
                    ),
                    const Text('สะสมแต้ม',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () async {
                        final settings = SettingsService();
                        final currentExcluded = settings.pointExcludedProductIds;
                        final result = await showDialog<List<Product>>(
                          context: context,
                          builder: (context) => ProductMultiSelectionDialog(
                            initialSelectedIds: currentExcluded,
                          ),
                        );
                        if (result != null) {
                          final ids = result.map((p) => p.id).toList();
                          await settings.set('point_excluded_product_ids', ids.join(','));
                          if (!context.mounted) return;
                          AlertService.show(
                            context: context,
                            type: 'success',
                            message: 'บันทึกรายการยกเว้น ${ids.length} รายการ',
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, foregroundColor: Colors.white),
                      child: const Text('ยกเว้นสินค้า'),
                    ),
                  ],
                ),
                // Calc type radios
                Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('ใช้แต้มตามสินค้า'),
                      value: 'product',
                      groupValue: _pointCalcType,
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
                          child: RadioListTile<String>(
                            title: const Text('ใช้แต้มตามราคาขาย'),
                            value: 'price',
                            groupValue: _pointCalcType,
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
                            enabled: _pointCalcType == 'price',
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('บาท / 1 แต้ม'),
                      ],
                    ),
                  ],
                ),
                // Point after discount
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
    );
  }
}
