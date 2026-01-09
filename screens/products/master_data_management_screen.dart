import 'package:flutter/material.dart';
import '../../models/unit.dart';
import '../../models/product_type.dart';
import '../../repositories/unit_repository.dart';
import '../../repositories/product_type_repository.dart';
import '../../services/alert_service.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/confirm_dialog.dart';

class MasterDataManagementScreen extends StatefulWidget {
  const MasterDataManagementScreen({super.key});

  @override
  State<MasterDataManagementScreen> createState() =>
      _MasterDataManagementScreenState();
}

class _MasterDataManagementScreenState extends State<MasterDataManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final UnitRepository _unitRepo = UnitRepository();
  final ProductTypeRepository _typeRepo = ProductTypeRepository();

  List<Unit> _units = [];
  List<ProductType> _productTypes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadUnits(),
      _loadProductTypes(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadUnits() async {
    final res = await _unitRepo.getAllUnits();
    setState(() => _units = res);
  }

  Future<void> _loadProductTypes() async {
    final res = await _typeRepo.getAllProductTypes();
    setState(() => _productTypes = res);
  }

  // --- CRUD Units ---
  Future<void> _showUnitDialog({Unit? unit}) async {
    final isEditing = unit != null;
    final ctrl = TextEditingController(text: isEditing ? unit.name : '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'แก้ไขหน่วยนับ' : 'เพิ่มหน่วยนับใหม่'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              controller: ctrl,
              label: 'ชื่อหน่วยนับ (เช่น ชิ้น, กล่อง)',
              autofocus: true,
            ),
          ],
        ),
        actions: [
          CustomButton(
            label: 'ยกเลิก',
            type: ButtonType.secondary,
            onPressed: () => Navigator.pop(ctx),
          ),
          CustomButton(
            label: 'บันทึก',
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final navigator = Navigator.of(ctx);
              bool success = false;

              if (isEditing) {
                success = await _unitRepo.updateUnit(unit.id, ctrl.text.trim());
              } else {
                final id = await _unitRepo.saveUnit(ctrl.text.trim());
                success = id > 0;
              }

              if (success && mounted) {
                navigator.pop();
                _loadUnits(); // Reload
                AlertService.show(
                  context: context, // Use parent context
                  message: 'บันทึกข้อมูลเรียบร้อย',
                  type: 'success',
                );
              } else if (mounted) {
                AlertService.show(
                  context: context,
                  message: 'เกิดข้อผิดพลาด หรือชื่อซ้ำ',
                  type: 'error',
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUnit(Unit unit) async {
    final confirm = await ConfirmDialog.show(
      context,
      title: 'ยืนยันการลบ',
      content: 'ต้องการลบหน่วยนับ "${unit.name}" หรือไม่?',
      isDestructive: true,
      confirmText: 'ลบ',
    );

    if (confirm == true) {
      final success = await _unitRepo.deleteUnit(unit.id);
      if (success) {
        _loadUnits();
      } else {
        if (mounted) {
          AlertService.show(
            context: context,
            message: 'ไม่สามารถลบได้ (อาจมีการใช้งานอยู่)',
            type: 'error',
          );
        }
      }
    }
  }

  // --- CRUD Product Types ---
  Future<void> _showTypeDialog({ProductType? type}) async {
    final isEditing = type != null;
    final nameCtrl = TextEditingController(text: isEditing ? type.name : '');
    bool isWeighing = isEditing ? type.isWeighing : false;

    // Check if system default (ID 0 or 1)
    final bool isSystemDefault =
        isEditing && (type.id == 0 || type.id == 1); // 0=General, 1=Weighing

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(isEditing ? 'แก้ไขประเภทสินค้า' : 'เพิ่มประเภทสินค้า'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: nameCtrl,
                  label: 'ชื่อประเภท (เช่น ผัก, เครื่องดื่ม)',
                  autofocus: true,
                ),
                const SizedBox(height: 15),
                CheckboxListTile(
                  title: const Text('ต้องชั่งน้ำหนัก (Weighing Required)'),
                  subtitle: const Text(
                      'เมื่อเลือกขายสินค้าในหมวดนี้ ระบบจะแสดงหน้าจอเครื่องชั่ง'),
                  value: isWeighing,
                  onChanged: (val) {
                    setState(() => isWeighing = val ?? false);
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
                            style: TextStyle(
                                fontSize: 12, color: Colors.deepOrange),
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
                onPressed: () => Navigator.pop(ctx),
              ),
              CustomButton(
                label: 'บันทึก',
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final navigator = Navigator.of(ctx);

                  final newObj = ProductType(
                    id: type?.id ?? 0,
                    name: nameCtrl.text.trim(),
                    isWeighing: isWeighing,
                  );

                  final id = await _typeRepo.saveProductType(newObj);
                  if (id != 0 && mounted) {
                    navigator.pop();
                    _loadProductTypes(); // Reload
                    AlertService.show(
                      context: context,
                      message: 'บันทึกข้อมูลเรียบร้อย',
                      type: 'success',
                    );
                  } else if (mounted) {
                    AlertService.show(
                      context: context,
                      message: 'เกิดข้อผิดพลาด',
                      type: 'error',
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteProductType(ProductType type) async {
    if (type.id <= 1) {
      AlertService.show(
        context: context,
        message: 'ไม่สามารถลบประเภทเริ่มต้นของระบบได้',
        type: 'warning',
      );
      return;
    }

    final confirm = await ConfirmDialog.show(
      context,
      title: 'ยืนยันการลบ',
      content: 'ต้องการลบประเภทสินค้า "${type.name}" หรือไม่?',
      isDestructive: true,
      confirmText: 'ลบ',
    );

    if (confirm == true) {
      final success = await _typeRepo.deleteProductType(type.id);
      if (success) {
        _loadProductTypes();
      } else {
        if (mounted) {
          AlertService.show(
            context: context,
            message: 'ไม่สามารถลบได้ (อาจมีการใช้งานอยู่)',
            type: 'error',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการข้อมูลหลัก (Master Data Management)'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.straighten), text: 'หน่วยนับ (Units)'),
            Tab(icon: Icon(Icons.category), text: 'ประเภทสินค้า (Types)'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUnitList(),
                _buildTypeList(),
              ],
            ),
    );
  }

  Widget _buildUnitList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('รายการหน่วยนับทั้งหมด (${_units.length})',
                  style: Theme.of(context).textTheme.titleMedium),
              CustomButton(
                label: 'เพิ่มหน่วยนับ',
                icon: Icons.add,
                onPressed: () => _showUnitDialog(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _units.length,
            separatorBuilder: (ctx, i) => const Divider(),
            itemBuilder: (ctx, i) {
              final u = _units[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.shade50,
                  foregroundColor: Colors.teal,
                  child: const Icon(Icons.straighten, size: 20),
                ),
                title: Text(u.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showUnitDialog(unit: u)),
                    IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteUnit(u)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTypeList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('รายการประเภทสินค้าทั้งหมด (${_productTypes.length})',
                  style: Theme.of(context).textTheme.titleMedium),
              CustomButton(
                label: 'เพิ่มประเภทสินค้า',
                icon: Icons.add,
                onPressed: () => _showTypeDialog(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _productTypes.length,
            separatorBuilder: (ctx, i) => const Divider(),
            itemBuilder: (ctx, i) {
              final t = _productTypes[i];
              final isSystem = t.id <= 1;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: t.isWeighing
                      ? Colors.orange.shade50
                      : Colors.indigo.shade50,
                  foregroundColor:
                      t.isWeighing ? Colors.deepOrange : Colors.indigo,
                  child: Icon(t.isWeighing ? Icons.scale : Icons.category,
                      size: 20),
                ),
                title: Row(
                  children: [
                    Text(t.name),
                    const SizedBox(width: 8),
                    if (t.isWeighing)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('ชั่งน้ำหนัก',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                subtitle: isSystem
                    ? const Text('System Default',
                        style: TextStyle(fontSize: 11, color: Colors.grey))
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showTypeDialog(type: t)),
                    if (!isSystem)
                      IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteProductType(t))
                    else
                      const IconButton(
                          icon: Icon(Icons.delete, color: Colors.grey),
                          onPressed: null), // Disabled delete for system
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
