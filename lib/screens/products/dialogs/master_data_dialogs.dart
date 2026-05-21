import 'package:flutter/material.dart';

import '../../../models/product_type.dart';
import '../../../models/shelf.dart';
import '../../../models/unit.dart';
import '../../../widgets/common/custom_buttons.dart';
import '../../../widgets/common/custom_text_field.dart';
// --- Unit Dialog ---
class MasterDataUnitDialog extends StatefulWidget {
  final Unit? unit;
  const MasterDataUnitDialog({super.key, this.unit});

  @override
  State<MasterDataUnitDialog> createState() => _MasterDataUnitDialogState();
}

class _MasterDataUnitDialogState extends State<MasterDataUnitDialog> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.unit?.name ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.unit != null;
    return AlertDialog(
      title: Text(isEditing ? 'แก้ไขหน่วยนับ' : 'เพิ่มหน่วยนับใหม่'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomTextField(
            controller: _ctrl,
            label: 'ชื่อหน่วยนับ (เช่น ชิ้น, กล่อง)',
            autofocus: true,
          ),
        ],
      ),
      actions: [
        CustomButton(
          label: 'ยกเลิก',
          type: ButtonType.secondary,
          onPressed: () => Navigator.pop(context),
        ),
        CustomButton(
          label: 'บันทึก',
          onPressed: () {
            if (_ctrl.text.trim().isEmpty) return;
            Navigator.pop(context, _ctrl.text.trim());
          },
        ),
      ],
    );
  }
}

// --- Product Type Dialog ---
class MasterDataTypeDialog extends StatefulWidget {
  final ProductType? type;
  const MasterDataTypeDialog({super.key, this.type});

  @override
  State<MasterDataTypeDialog> createState() => _MasterDataTypeDialogState();
}

class _MasterDataTypeDialogState extends State<MasterDataTypeDialog> {
  late TextEditingController _nameCtrl;
  late bool _isWeighing;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.type?.name ?? '');
    _isWeighing = widget.type?.isWeighing ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.type != null;
    final isSystemDefault =
        isEditing && (widget.type!.id == 0 || widget.type!.id == 1);

    return AlertDialog(
      title: Text(isEditing ? 'แก้ไขประเภทสินค้า' : 'เพิ่มประเภทสินค้า'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomTextField(
            controller: _nameCtrl,
            label: 'ชื่อประเภท (เช่น ผัก, เครื่องดื่ม)',
            autofocus: true,
          ),
          const SizedBox(height: 15),
          CheckboxListTile(
            title: const Text('ต้องชั่งน้ำหนัก (Weighing Required)'),
            subtitle: const Text(
                'เมื่อเลือกขายสินค้าในหมวดนี้ ระบบจะแสดงหน้าจอเครื่องชั่ง'),
            value: _isWeighing,
            onChanged: (val) {
              setState(() => _isWeighing = val ?? false);
            },
            activeColor: Colors.teal,
          ),
          if (isSystemDefault) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.orange.shade50,
              child: const Row(
                children: [
                  Icon(Icons.lock, size: 16, color: Colors.orange),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'นี่คือประเภทเริ่มต้นของระบบ (System Default)',
                      style: TextStyle(fontSize: 12, color: Colors.deepOrange),
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
      actions: [
        CustomButton(
          label: 'ยกเลิก',
          type: ButtonType.secondary,
          onPressed: () => Navigator.pop(context),
        ),
        CustomButton(
          label: 'บันทึก',
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            final newObj = ProductType(
              id: widget.type?.id ?? 0,
              name: _nameCtrl.text.trim(),
              isWeighing: _isWeighing,
            );
            Navigator.pop(context, newObj);
          },
        ),
      ],
    );
  }
}

// --- Shelf Dialog ---
class MasterDataShelfDialog extends StatefulWidget {
  final Shelf? shelf;
  const MasterDataShelfDialog({super.key, this.shelf});

  @override
  State<MasterDataShelfDialog> createState() => _MasterDataShelfDialogState();
}

class _MasterDataShelfDialogState extends State<MasterDataShelfDialog> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.shelf?.name ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.shelf != null;
    return AlertDialog(
      title: Text(isEditing ? 'แก้ไขชั้นวาง' : 'เพิ่มชั้นวางใหม่'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomTextField(
            controller: _ctrl,
            label: 'ชื่อชั้นวาง (เช่น โซน A, ชั้น 1)',
            autofocus: true,
          ),
        ],
      ),
      actions: [
        CustomButton(
          label: 'ยกเลิก',
          type: ButtonType.secondary,
          onPressed: () => Navigator.pop(context),
        ),
        CustomButton(
          label: 'บันทึก',
          onPressed: () {
            if (_ctrl.text.trim().isEmpty) return;
            Navigator.pop(context, _ctrl.text.trim());
          },
        ),
      ],
    );
  }
}
