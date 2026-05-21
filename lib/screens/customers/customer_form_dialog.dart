import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/customer.dart';
import '../../repositories/customer_repository.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import 'controllers/customer_form_controller.dart';

class CustomerFormDialog extends ConsumerWidget {
  final CustomerRepository repo;
  final Customer? customer;

  const CustomerFormDialog({super.key, required this.repo, this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _CustomerFormDialogContent();
  }
}

class _CustomerFormDialogContent extends ConsumerStatefulWidget {
  const _CustomerFormDialogContent();

  @override
  ConsumerState<_CustomerFormDialogContent> createState() => _CustomerFormDialogContentState();
}

class _CustomerFormDialogContentState extends ConsumerState<_CustomerFormDialogContent> {
  Future<void> _pickDate(BuildContext context, CustomerFormController controller, CustomerFormState state, {required bool isBirthDate}) async {
    final initialDate = isBirthDate
        ? (state.dateOfBirth ?? DateTime(1990))
        : (state.expiryDate ?? DateTime.now().add(const Duration(days: 365)));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      if (isBirthDate) {
        controller.setDateOfBirth(picked);
      } else {
        controller.setExpiryDate(picked);
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
    // Get the initialCustomer from the parent widget if it exists via Provider or context...
    // But actually, we need to pass the parameter. The easiest way is to read it from the Widget tree if we can.
    // Wait, since we are inside a widget that is a child of CustomerFormDialog, we can just access widget.customer if we move it.
    // Let's refactor this slightly so that we can pass the customer to the provider.
    final parentWidget = context.findAncestorWidgetOfExactType<CustomerFormDialog>();
    final customer = parentWidget?.customer;

    final provider = customerFormProvider(customer);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    
    final dateFormat = DateFormat('dd/MM/yyyy');

    return AlertDialog(
      title: Text(
          customer == null ? 'เพิ่มลูกค้าใหม่' : 'แก้ไขข้อมูลลูกค้า'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: controller.formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: controller.memberCodeCtrl,
                  label: 'รหัสสมาชิก (เว้นว่างเพื่อสร้างอัตโนมัติ)',
                ),
                const SizedBox(height: 10),
                // Tier Dropdown
                if (state.tiers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DropdownButtonFormField<int>(
                      key: ValueKey(state.selectedTierId), // Force rebuild when ID changes
                      initialValue: state.tiers.any((t) => t.id == state.selectedTierId)
                          ? state.selectedTierId
                          : null,
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('ทั่วไป (General)'),
                        ),
                        ...state.tiers.map((t) => DropdownMenuItem<int>(
                              value: t.id,
                              child: Text('${t.name} (ลด ${t.discountPercentage}%)'),
                            ))
                      ],
                      onChanged: (val) {
                        controller.setTierId(val);
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
                        controller: controller.firstNameCtrl,
                        label: 'ชื่อ *',
                        validator: (v) =>
                            v == null || v.isEmpty ? 'กรุณากรอกชื่อ' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        controller: controller.lastNameCtrl,
                        label: 'นามสกุล',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: controller.phoneCtrl,
                  label: 'เบอร์โทรศัพท์',
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
                            text: state.dateOfBirth != null
                                ? dateFormat.format(state.dateOfBirth!)
                                : ''),
                        label: 'วันเกิด',
                        readOnly: true,
                        suffixIcon: const Icon(Icons.cake),
                        onTap: () => _pickDate(context, controller, state, isBirthDate: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        controller: TextEditingController(
                            text: state.expiryDate != null
                                ? dateFormat.format(state.expiryDate!)
                                : ''),
                        label: 'หมดอายุสมาชิก',
                        readOnly: true,
                        suffixIcon: const Icon(Icons.event_busy),
                        onTap: () => _pickDate(context, controller, state, isBirthDate: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: controller.nationalIdCtrl,
                        label: 'เลขบัตรประชาชน',
                        prefixIcon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        controller: controller.taxIdCtrl,
                        label: 'เลขผู้เสียภาษี',
                        prefixIcon: Icons.receipt_long_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: controller.addressCtrl,
                  label: 'ที่อยู่ตามบัตรประชาชน',
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: controller.shippingAddressCtrl,
                  label: 'ที่อยู่จัดส่งสินค้า',
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: controller.remarksCtrl,
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
                  controller: controller.distanceKmCtrl,
                  label: 'ระยะทางจัดส่งตั้งต้นจากร้าน (กิโลเมตร ไป-กลับ)',
                  prefixIcon: Icons.route,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                if (customer != null) ...[
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
                          '${customer.currentPoints}',
                          Icons.star,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatBox(
                          'ยอดหนี้',
                          NumberFormat('#,##0.00')
                              .format(customer.currentDebt),
                          Icons.money_off,
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatBox(
                          'ยอดซื้อรวม',
                          NumberFormat('#,##0.00')
                              .format(customer.totalSpending),
                          Icons.shopping_bag,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),

                  // Line CRM Section
                  const SizedBox(height: 15),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Line Official CRM',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                      if (customer.lineUserId != null)
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
                  if (state.lineUserId != null)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage: state.linePictureUrl != null
                            ? NetworkImage(state.linePictureUrl!)
                            : null,
                        backgroundColor: Colors.grey.shade200,
                        child: state.linePictureUrl == null
                            ? const Icon(Icons.person, color: Colors.grey)
                            : null,
                      ),
                      title: Text(state.lineDisplayName ?? 'Unknown'),
                      subtitle: Text(
                          'Line ID: ...${state.lineUserId!.substring(state.lineUserId!.length - 4)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.link_off, color: Colors.red),
                        tooltip: 'ยกเลิกการเชื่อมต่อ (Unlink)',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('ยกเลิกการเชื่อมต่อ Line?'),
                              content: Text(
                                  'คุณต้องการยกเลิกการเชื่อมต่อกับคุณ ${state.lineDisplayName} หรือไม่?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('ยกเลิก'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    controller.unlinkLine();
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
                            'REF-ID: ${customer.id}',
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
          onPressed: state.isSaving ? null : () => Navigator.of(context).pop(null),
        ),
        CustomButton(
          label: state.isSaving ? 'กำลังบันทึก...' : 'บันทึกข้อมูล',
          onPressed: state.isSaving ? null : () => controller.save(context),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
      ],
    );
  }
}
