import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/customer.dart';
import '../../models/member_tier.dart';
import '../../repositories/customer_repository.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';

class CustomerFormDialog extends StatefulWidget {
  final CustomerRepository repo;
  final Customer? customer;

  const CustomerFormDialog({super.key, required this.repo, this.customer});

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _memberCodeCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _shippingAddressCtrl;
  late TextEditingController _remarksCtrl;

  DateTime? _dateOfBirth;
  DateTime? _expiryDate;

  // Tier
  List<MemberTier> _tiers = [];
  int? _selectedTierId;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _firstNameCtrl = TextEditingController(text: c?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: c?.lastName ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _memberCodeCtrl = TextEditingController(text: c?.memberCode ?? '');
    _addressCtrl = TextEditingController(text: c?.address ?? '');
    _shippingAddressCtrl =
        TextEditingController(text: c?.shippingAddress ?? '');
    _remarksCtrl = TextEditingController(text: c?.remarks ?? '');

    _dateOfBirth = c?.dateOfBirth;
    _expiryDate = c?.membershipExpiryDate;
    _selectedTierId = c?.tierId;

    _loadTiers();
  }

  Future<void> _loadTiers() async {
    try {
      final tiers = await widget.repo.getAllTiers();
      if (mounted) {
        setState(() {
          _tiers = tiers;
        });
      }
    } catch (e) {
      debugPrint('Error loading tiers: $e');
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _memberCodeCtrl.dispose();
    _addressCtrl.dispose();
    _shippingAddressCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context,
      {required bool isBirthDate}) async {
    final initialDate = isBirthDate
        ? (_dateOfBirth ?? DateTime(1990))
        : (_expiryDate ?? DateTime.now().add(const Duration(days: 365)));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isBirthDate) {
          _dateOfBirth = picked;
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final newCustomer = Customer(
        id: widget.customer?.id ?? 0,
        memberCode: _memberCodeCtrl.text.isEmpty
            ? 'AUTO-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}'
            : _memberCodeCtrl.text,
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
        phone: _phoneCtrl.text,
        currentPoints: widget.customer?.currentPoints ?? 0,
        address: _addressCtrl.text,
        shippingAddress: _shippingAddressCtrl.text,
        dateOfBirth: _dateOfBirth,
        membershipExpiryDate: _expiryDate,
        firebaseUid: widget.customer?.firebaseUid,
        title: widget.customer?.title,
        nationalId: widget.customer?.nationalId,
        email: widget.customer?.email,
        taxId: widget.customer?.taxId,
        creditLimit: widget.customer?.creditLimit,
        currentDebt: widget.customer?.currentDebt ?? 0.0,
        remarks: _remarksCtrl.text,
        totalSpending: widget.customer?.totalSpending ?? 0.0,
        tierId: _selectedTierId,
      );

      try {
        final success = await widget.repo.saveCustomer(newCustomer);
        if (!mounted) return;

        if (success) {
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('เกิดข้อผิดพลาดในการบันทึก'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          Text(
            value,
            style: TextStyle(
                fontSize: 16, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return AlertDialog(
      title: Text(
          widget.customer == null ? 'เพิ่มลูกค้าใหม่' : 'แก้ไขข้อมูลลูกค้า'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: _memberCodeCtrl,
                  label: 'รหัสสมาชิก (เว้นว่างเพื่อสร้างอัตโนมัติ)',
                ),
                const SizedBox(height: 10),
                // Tier Dropdown (Keep as is or wrap if we had CustomDropdown, but standard is fine for now)
                if (_tiers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedTierId,
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('ทั่วไป (General)'),
                        ),
                        ..._tiers.map((t) => DropdownMenuItem<int>(
                              value: t.id,
                              child: Text(
                                  '${t.name} (ลด ${t.discountPercentage}%)'),
                            ))
                      ],
                      onChanged: (val) {
                        setState(() => _selectedTierId = val);
                      },
                      decoration: const InputDecoration(
                        labelText: 'ระดับสมาชิก (Member Tier)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.stars),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _firstNameCtrl,
                        label: 'ชื่อ *',
                        validator: (v) =>
                            v == null || v.isEmpty ? 'กรุณากรอกชื่อ' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        controller: _lastNameCtrl,
                        label: 'นามสกุล',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: _phoneCtrl,
                  label: 'เบอร์โทรศัพท์ *',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'กรุณากรอกเบอร์โทร' : null,
                ),
                const SizedBox(height: 15),
                const Divider(),
                const Text('ข้อมูลเพิ่มเติม',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: TextEditingController(
                            text: _dateOfBirth != null
                                ? dateFormat.format(_dateOfBirth!)
                                : ''),
                        label: 'วันเกิด',
                        readOnly: true,
                        suffixIcon: const Icon(Icons.cake),
                        onTap: () => _pickDate(context, isBirthDate: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        controller: TextEditingController(
                            text: _expiryDate != null
                                ? dateFormat.format(_expiryDate!)
                                : ''),
                        label: 'หมดอายุสมาชิก',
                        readOnly: true,
                        suffixIcon: const Icon(Icons.event_busy),
                        onTap: () => _pickDate(context, isBirthDate: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: _addressCtrl,
                  label: 'ที่อยู่ตามบัตรประชาชน',
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: _shippingAddressCtrl,
                  label: 'ที่อยู่จัดส่งสินค้า',
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: _remarksCtrl,
                  label: 'หมายเหตุ (Remarks)',
                  maxLines: 3,
                ),
                if (widget.customer != null) ...[
                  const SizedBox(height: 15),
                  const Divider(),
                  const Text('ข้อมูลสถิติ (Statistics)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.indigo)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBox(
                          'แต้มสะสม',
                          '${widget.customer!.currentPoints}',
                          Icons.star,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatBox(
                          'ยอดหนี้',
                          NumberFormat('#,##0.00')
                              .format(widget.customer!.currentDebt),
                          Icons.money_off,
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatBox(
                          'ยอดซื้อรวม',
                          NumberFormat('#,##0.00')
                              .format(widget.customer!.totalSpending),
                          Icons.shopping_bag,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        CustomButton(
          label: 'ยกเลิก',
          type: ButtonType.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        CustomButton(
          label: 'บันทึกข้อมูล',
          onPressed: _save,
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
      ],
    );
  }
}
