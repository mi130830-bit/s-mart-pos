import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/customer.dart';
import '../../models/member_tier.dart';
import '../../repositories/customer_repository.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../services/alert_service.dart';

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
  late TextEditingController _nationalIdCtrl;
  late TextEditingController _taxIdCtrl;
  late TextEditingController _remarksCtrl;
  late TextEditingController _distanceKmCtrl;

  DateTime? _dateOfBirth;
  DateTime? _expiryDate;

  // Tier
  List<MemberTier> _tiers = [];
  int? _selectedTierId;

  // Line OA State
  String? _lineUserId;
  String? _lineDisplayName;
  String? _linePictureUrl;

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
    _nationalIdCtrl = TextEditingController(text: c?.nationalId ?? '');
    _taxIdCtrl = TextEditingController(text: c?.taxId ?? '');
    _remarksCtrl = TextEditingController(text: c?.remarks ?? '');
    _distanceKmCtrl = TextEditingController(text: c?.distanceKm.toString() ?? '0.0');

    _dateOfBirth = c?.dateOfBirth;
    _expiryDate = c?.membershipExpiryDate;
    _selectedTierId = c?.tierId;

    _lineUserId = c?.lineUserId;
    _lineDisplayName = c?.lineDisplayName;
    _linePictureUrl = c?.linePictureUrl;

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
    _nationalIdCtrl.dispose();
    _taxIdCtrl.dispose();
    _remarksCtrl.dispose();
    _distanceKmCtrl.dispose();
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

  bool _isSaving = false;

  Future<void> _save() async {
    if (_isSaving) return; // Prevent double click
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

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
        nationalId: _nationalIdCtrl.text,
        email: widget.customer?.email,
        taxId: _taxIdCtrl.text,
        creditLimit: widget.customer?.creditLimit,
        currentDebt: widget.customer?.currentDebt ?? 0.0,
        remarks: _remarksCtrl.text,
        distanceKm: double.tryParse(_distanceKmCtrl.text) ?? 0.0,
        totalSpending: widget.customer?.totalSpending ?? 0.0,
        tierId: _selectedTierId,
        lineUserId: _lineUserId,
        lineDisplayName: _lineDisplayName,
        linePictureUrl: _linePictureUrl,
      );

      try {
        debugPrint('🔍 [CustomerForm]: Attempting to save customer...');
        debugPrint('  - ID: ${newCustomer.id}');
        debugPrint(
            '  - Name: ${newCustomer.firstName} ${newCustomer.lastName}');
        debugPrint('  - Phone: ${newCustomer.phone}');
        debugPrint('  - creditLimit: ${newCustomer.creditLimit}');
        debugPrint('  - tierId: ${newCustomer.tierId}');

        final savedId = await widget.repo.saveCustomer(newCustomer);
        debugPrint('✅ [CustomerForm]: Saved successfully with ID: $savedId');

        if (!mounted) return;

        if (savedId > 0) {
          // Update ID if it was 0
          final resultCustomer = newCustomer.copyWith(id: savedId);
          Navigator.of(context).pop(resultCustomer);
        } else {
          setState(() => _isSaving = false);
          AlertService.show(
            context: context,
            message: 'เกิดข้อผิดพลาดในการบันทึก (savedId <= 0)',
            type: 'error',
          );
        }
      } catch (e, stackTrace) {
        debugPrint('❌ [CustomerForm]: Error saving customer:');
        debugPrint('Error: $e');
        debugPrint('Stack trace:\n$stackTrace');

        if (!mounted) return;
        setState(() => _isSaving = false);
        AlertService.show(
          context: context,
          message: 'Error: $e\nดูรายละเอียดเพิ่มเติมใน console',
          type: 'error',
        );
      }
    } else {
      // ⚠️ Validation failed
      AlertService.show(
        context: context,
        message: 'กรุณากรอกข้อมูลที่จำเป็นให้ครบถ้วน',
        type: 'warning',
      );
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
                // Tier Dropdown
                if (_tiers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DropdownButtonFormField<int>(
                      key: ValueKey(
                          _selectedTierId), // Force rebuild when ID changes
                      initialValue: _tiers.any((t) => t.id == _selectedTierId)
                          ? _selectedTierId
                          : null,
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
                  label: 'เบอร์โทรศัพท์', // ไม่บังคับกรอกแล้ว
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
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
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _nationalIdCtrl,
                        label: 'เลขบัตรประชาชน',
                        prefixIcon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        controller: _taxIdCtrl,
                        label: 'เลขผู้เสียภาษี',
                        prefixIcon: Icons.receipt_long_outlined,
                      ),
                    ),
                  ],
                ),
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
                const SizedBox(height: 10),
                const Divider(),
                const Text('ข้อมูลการขนส่ง (Logistics)',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: _distanceKmCtrl,
                  label: 'ระยะทางจัดส่งตั้งต้นจากร้าน (กิโลเมตร ไป-กลับ)',
                  prefixIcon: Icons.route,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

                  // ✅ Line CRM Section
                  const SizedBox(height: 15),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Line Official CRM',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                      if (widget.customer!.lineUserId != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green)),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle,
                                  size: 14, color: Colors.green),
                              SizedBox(width: 4),
                              Text('เชื่อมต่อแล้ว',
                                  style: TextStyle(
                                      color: Colors.green, fontSize: 12)),
                            ],
                          ),
                        )
                    ],
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(height: 10),
                  if (_lineUserId != null)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage: _linePictureUrl != null
                            ? NetworkImage(_linePictureUrl!)
                            : null,
                        backgroundColor: Colors.grey.shade200,
                        child: _linePictureUrl == null
                            ? const Icon(Icons.person, color: Colors.grey)
                            : null,
                      ),
                      title: Text(_lineDisplayName ?? 'Unknown'),
                      subtitle: Text(
                          'Line ID: ...${_lineUserId!.substring(_lineUserId!.length - 4)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.link_off, color: Colors.red),
                        tooltip: 'ยกเลิกการเชื่อมต่อ (Unlink)',
                        onPressed: () {
                          // Unlink Action
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('ยกเลิกการเชื่อมต่อ Line?'),
                              content: Text(
                                  'คุณต้องการยกเลิกการเชื่อมต่อกับคุณ $_lineDisplayName หรือไม่?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('ยกเลิก'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _lineUserId = null;
                                      _lineDisplayName = null;
                                      _linePictureUrl = null;
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: const Text('ยืนยัน',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      contentPadding: EdgeInsets.zero,
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Text(
                              'ยังไม่ได้เชื่อมต่อกับ Line OA\nสามารถเชื่อมต่อได้โดยแจ้ง ID ด้านล่างให้ลูกค้ากรอกใน Line',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 8),
                          SelectableText(
                            'REF-ID: ${widget.customer!.id}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
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
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(null),
        ),
        CustomButton(
          label: _isSaving ? 'กำลังบันทึก...' : 'บันทึกข้อมูล',
          onPressed: _isSaving ? null : _save,
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          // If enabled, show loading indicator if CustomButton supports it.
          // Assuming simpler approach: just change label and disable.
        ),
      ],
    );
  }
}
