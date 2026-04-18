import 'package:flutter/material.dart';
import '../../models/supplier.dart';
import '../../repositories/supplier_repository.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../services/alert_service.dart';

class SupplierFormDialog extends StatefulWidget {
  final Supplier? supplier;

  const SupplierFormDialog({super.key, this.supplier});

  @override
  State<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<SupplierFormDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addrCtrl;
  late TextEditingController _saleNameCtrl;
  late TextEditingController _saleLineIdCtrl;
  final SupplierRepository _repo = SupplierRepository();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.supplier?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.supplier?.phone ?? '');
    _addrCtrl = TextEditingController(text: widget.supplier?.address ?? '');
    _saleNameCtrl =
        TextEditingController(text: widget.supplier?.saleName ?? '');
    _saleLineIdCtrl =
        TextEditingController(text: widget.supplier?.saleLineId ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addrCtrl.dispose();
    _saleNameCtrl.dispose();
    _saleLineIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty) {
      AlertService.show(
        context: context,
        message: 'กรุณากรอกชื่อผู้ขาย',
        type: 'warning',
      );
      return;
    }

    final sup = Supplier(
      id: widget.supplier?.id ?? 0,
      name: _nameCtrl.text,
      phone: _phoneCtrl.text,
      address: _addrCtrl.text,
      saleName: _saleNameCtrl.text,
      saleLineId: _saleLineIdCtrl.text,
    );

    final newSupplier = await _repo.saveSupplier(sup);
    if (mounted) {
      if (newSupplier != null) {
        // Return created/updated Supplier
        Navigator.pop(context, newSupplier);
      } else {
        AlertService.show(
          context: context,
          message: 'บันทึกไม่สำเร็จ',
          type: 'error',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.supplier == null ? 'เพิ่มผู้ขาย' : 'แก้ไขผู้ขาย'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: _nameCtrl,
                label: 'ชื่อ *',
                autofocus: true,
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _phoneCtrl,
                label: 'โทรศัพท์',
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _addrCtrl,
                label: 'ที่อยู่',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _saleNameCtrl,
                      label: 'ชื่อเซลล์',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomTextField(
                      controller: _saleLineIdCtrl,
                      label: 'ไลน์ของเซล',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        CustomButton(
          onPressed: () => Navigator.pop(context, false), // Return False
          label: 'ยกเลิก',
          type: ButtonType.secondary,
        ),
        CustomButton(
          onPressed: _save,
          label: 'บันทึก',
          type: ButtonType.primary,
        ),
      ],
    );
  }
}
