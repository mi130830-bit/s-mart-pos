// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api
part of '../../general_settings_screen.dart';

/// Policy card (VAT, discount, stock, warehouse, rounding, item discount mode)
/// + the two edit dialogs that belong to it.
extension PolicySettingsCardExtension on _GeneralSettingsScreenState {
  // ─── Dialogs ────────────────────────────────────────────────────────────────

  void _showVatDialog() {
    final controller = TextEditingController(text: _vatRate.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ตั้งค่า VAT (%)'),
        content: CustomTextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          suffixIcon: const Padding(padding: EdgeInsets.all(12), child: Text('%')),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
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
    final controller = TextEditingController(text: _memberDiscountRate.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ตั้งค่าส่วนลดสมาชิก (%)'),
        content: CustomTextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          suffixIcon: const Padding(padding: EdgeInsets.all(12), child: Text('%')),
          label: 'ส่วนลดปกติสำหรับสมาชิก',
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
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

  // ─── Widgets ─────────────────────────────────────────────────────────────────

  Widget _buildPolicyCard() {
    return Card(
      child: Column(
        children: [
          // VAT Rate
          ListTile(
            leading: const Icon(Icons.percent, color: Colors.orange),
            title: const Text('อัตราภาษีมูลค่าเพิ่ม (VAT Rate)'),
            subtitle: const Text('ใช้สำหรับการคำนวณภาษีในบิล'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_vatRate.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                const Icon(Icons.edit, size: 18),
              ],
            ),
            onTap: _showVatDialog,
          ),
          const Divider(),
          // Member Discount
          ListTile(
            leading: const Icon(Icons.person_outline, color: Colors.blue),
            title: const Text('ส่วนลดสมาชิก (Member Discount)'),
            subtitle: const Text('ส่วนลดเปอร์เซ็นต์พื้นฐานสำหรับสมาชิก'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_memberDiscountRate.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                const Icon(Icons.edit, size: 18),
              ],
            ),
            onTap: _showMemberDiscountDialog,
          ),
          const Divider(),
          // Allow POS Price Edit
          SwitchListTile(
            title: const Text('อนุญาตให้แก้ไขราคาหน้าจุดขาย'),
            subtitle: const Text('พนักงานสามารถเปลี่ยนราคาต่อหน่วยได้ขณะขาย'),
            secondary: const Icon(Icons.price_change, color: Colors.green),
            value: _allowPosPriceEdit,
            onChanged: (val) {
              setState(() => _allowPosPriceEdit = val);
              _saveSettings();
            },
          ),
          const Divider(),
          // Negative Stock
          SwitchListTile(
            title: const Text('อนุญาตให้ขายสินค้าหมดสต็อก (ติดลบ)'),
            subtitle: const Text('หากปิด จะไม่สามารถขายสินค้าที่มีจำนวนไม่พอได้'),
            secondary: const Icon(Icons.exposure_minus_1, color: Colors.red),
            value: _allowNegativeStock,
            onChanged: (val) {
              setState(() => _allowNegativeStock = val);
              _saveSettings();
            },
          ),
          const Divider(),
          // Warehouse Auto Tag
          SwitchListTile(
            title: const Text('คัดกรองสินค้าหลังร้านอัตโนมัติ (Warehouse Auto Tag)'),
            subtitle: const Text(
                'หากเปิด จะส่งเฉพาะสินค้าที่มีสัญลักษณ์ 🚚 ไปยัง Mobile App คนขับ (ช่วยกรองของจุกจิก)'),
            secondary: const Icon(Icons.local_shipping, color: Colors.deepOrange),
            value: _enableWarehouseAutoTag,
            onChanged: (val) {
              setState(() => _enableWarehouseAutoTag = val);
              _saveSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoundingCard() {
    return Card(
      child: Column(
        children: [
          // Rounding Mode
          ListTile(
            leading: const Icon(Icons.money_off, color: Colors.purple),
            title: const Text('การปัดเศษสตางค์ (Rounding)'),
            subtitle: Text(_roundingMode == 'none'
                ? 'ไม่ปัดเศษ (แสดงตามจริง)'
                : _roundingMode == 'satang_25'
                    ? 'ปัดให้ลงตัว 0.25, 0.50, 0.75'
                    : _roundingMode == 'up'
                        ? 'ปัดเศษขึ้นให้เป็นเต็มบาทเสมอ'
                        : _roundingMode == 'down'
                            ? 'ตัดเศษสตางค์ทิ้งให้เป็นเต็มบาท'
                            : 'ปัดเศษตามคณิตศาสตร์ให้เป็นเต็มบาท'),
            trailing: DropdownButton<String>(
              value: _roundingMode,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('ไม่ปัดเศษ (ตามจริง)')),
                DropdownMenuItem(value: 'satang_25', child: Text('ปัดอัตโนมัติ (เต็ม 25 สตางค์)')),
                DropdownMenuItem(value: 'auto', child: Text('ปัดอัตโนมัติ (เต็มบาท)')),
                DropdownMenuItem(value: 'up', child: Text('ปัดขึ้น (เต็มบาท)')),
                DropdownMenuItem(value: 'down', child: Text('ปัดทิ้ง (เต็มบาท)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _roundingMode = val);
                  _saveSettings();
                }
              },
            ),
          ),
          const Divider(),
          // Item Discount Mode
          ListTile(
            leading: const Icon(Icons.discount, color: Colors.red),
            title: const Text('รูปแบบส่วนลดสินค้า (Item Discount)'),
            subtitle: Text(_itemDiscountMode == 'per_item'
                ? 'ลดต่อรายการ (กรอกเท่าไหร่ ลดเท่านั้น)'
                : 'ลดต่อชิ้น (กรอกเท่าไหร่ เอาไปคูณจำนวนชิ้น)'),
            trailing: DropdownButton<String>(
              value: _itemDiscountMode,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'per_item', child: Text('ลดต่อรายการ (รวม)')),
                DropdownMenuItem(value: 'per_piece', child: Text('ลดต่อชิ้น')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _itemDiscountMode = val);
                  _saveSettings();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
