// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/hr/employee_profile.dart';
import '../../../state/hr/employee_provider.dart';
import '../../../state/hr/advance_provider.dart';

class AdvanceFormDialog extends ConsumerStatefulWidget {
  const AdvanceFormDialog({super.key});

  @override
  ConsumerState<AdvanceFormDialog> createState() => _AdvanceFormDialogState();
}

class _AdvanceFormDialogState extends ConsumerState<AdvanceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  
  EmployeeProfile? _selectedEmployee;
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _installmentController = TextEditingController();
  
  bool _isInstallment = false;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _installmentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกพนักงาน'), backgroundColor: Colors.red),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('จำนวนเงินต้องมากกว่า 0'), backgroundColor: Colors.red),
      );
      return;
    }

    double? installmentAmount;
    if (_isInstallment) {
      installmentAmount = double.tryParse(_installmentController.text.replaceAll(',', ''));
      if (installmentAmount == null || installmentAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาระบุจำนวนเงินที่ต้องการหักต่อรอบให้ถูกต้อง'), backgroundColor: Colors.red),
        );
        return;
      }
      if (installmentAmount > amount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('จำนวนหักต่อรอบต้องไม่เกินยอดเบิกทั้งหมด'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    try {
      await ref.read(advanceProvider.notifier).requestAdvance(
        _selectedEmployee!.id,
        amount,
        _reasonController.text.trim(),
        installmentAmount: installmentAmount,
      );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกคำขอเบิกเงินล่วงหน้าสำเร็จ'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final empState = ref.watch(employeeProvider);
    final employees = empState.employees.where((e) => e.isActive).toList();

    return AlertDialog(
      title: const Text('💸 สร้างคำขอเบิกเงินล่วงหน้า'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<EmployeeProfile>(
                  decoration: const InputDecoration(
                    labelText: 'พนักงาน',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  initialValue: _selectedEmployee,
                  items: employees.map((e) {
                    return DropdownMenuItem(
                      value: e,
                      child: Text('${e.employeeCode ?? ''} - ${e.displayName ?? 'ไม่ระบุชื่อ'}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedEmployee = val);
                  },
                  validator: (val) => val == null ? 'กรุณาเลือกพนักงาน' : null,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'จำนวนเงิน (บาท)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'กรุณาระบุจำนวนเงิน';
                    if (double.tryParse(val) == null || double.parse(val) <= 0) {
                      return 'จำนวนเงินไม่ถูกต้อง';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'เหตุผลการเบิก',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'กรุณาระบุเหตุผล' : null,
                ),
                const SizedBox(height: 16),
                
                const Text('รูปแบบการหักเงินคืน', style: TextStyle(fontWeight: FontWeight.bold)),
                RadioListTile<bool>(
                  title: const Text('หักทั้งหมดรวดเดียว (ในรอบบิลถัดไป)'),
                  value: false,
                  groupValue: _isInstallment,
                  onChanged: (val) => setState(() => _isInstallment = val!),
                ),
                RadioListTile<bool>(
                  title: const Text('หักเป็นงวด (แบ่งจ่ายต่อรอบ)'),
                  value: true,
                  groupValue: _isInstallment,
                  onChanged: (val) => setState(() => _isInstallment = val!),
                ),
                
                if (_isInstallment) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _installmentController,
                    decoration: const InputDecoration(
                      labelText: 'จำนวนเงินที่หักต่อรอบ (บาท)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.money_off),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    validator: (val) {
                      if (!_isInstallment) return null;
                      if (val == null || val.isEmpty) return 'กรุณาระบุยอดหักต่อรอบ';
                      if (double.tryParse(val) == null || double.parse(val) <= 0) {
                        return 'จำนวนเงินไม่ถูกต้อง';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          child: const Text('บันทึกคำขอ'),
        ),
      ],
    );
  }
}
