import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/product_type.dart';
import '../../models/shelf.dart';
import '../../models/unit.dart';
import '../../services/alert_service.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/confirm_dialog.dart';
import 'controllers/master_data_controller.dart';
import 'dialogs/master_data_dialogs.dart';

class MasterDataManagementScreen extends ConsumerStatefulWidget {
  const MasterDataManagementScreen({super.key});

  @override
  ConsumerState<MasterDataManagementScreen> createState() =>
      _MasterDataManagementScreenState();
}

class _MasterDataManagementScreenState extends ConsumerState<MasterDataManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() {
      if (mounted) {
        ref.read(masterDataProvider.notifier).loadData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(masterDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการข้อมูลหลัก (Master Data Management)'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.straighten), text: 'หน่วยนับ (Units)'),
            Tab(icon: Icon(Icons.category), text: 'ประเภทสินค้า (Types)'),
            Tab(icon: Icon(Icons.shelves), text: 'ชั้นวาง (Shelves)'),
          ],
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: const [
                _UnitListTab(),
                _TypeListTab(),
                _ShelfListTab(),
              ],
            ),
    );
  }
}

class _UnitListTab extends ConsumerWidget {
  const _UnitListTab();

  Future<void> _showUnitDialog(BuildContext context, WidgetRef ref, {Unit? unit}) async {
    final controller = ref.read(masterDataProvider.notifier);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => MasterDataUnitDialog(unit: unit),
    );

    if (result != null) {
      if (!context.mounted) return;
      final success = await controller.saveUnit(unit?.id ?? 0, result);
      if (success) {
        if (!context.mounted) return;
        AlertService.show(
            context: context, message: 'บันทึกเรียบร้อย', type: 'success');
      } else {
        if (!context.mounted) return;
        AlertService.show(
            context: context, message: 'เกิดข้อผิดพลาด/ชื่อซ้ำ', type: 'error');
      }
    }
  }

  Future<void> _deleteUnit(BuildContext context, WidgetRef ref, Unit unit) async {
    final controller = ref.read(masterDataProvider.notifier);
    final confirm = await ConfirmDialog.show(
      context,
      title: 'ยืนยันการลบ',
      content: 'ต้องการลบหน่วยนับ "${unit.name}" หรือไม่?',
      isDestructive: true,
      confirmText: 'ลบ',
    );

    if (confirm == true) {
      if (!context.mounted) return;
      final success = await controller.deleteUnit(unit.id);
      if (!success) {
        if (!context.mounted) return;
        AlertService.show(
            context: context,
            message: 'ไม่สามารถลบได้ (อาจถูกใช้งานอยู่)',
            type: 'error');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(masterDataProvider).units;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('รายการหน่วยนับทั้งหมด (${units.length})',
                  style: Theme.of(context).textTheme.titleMedium),
              CustomButton(
                label: 'เพิ่มหน่วยนับ',
                icon: Icons.add,
                onPressed: () => _showUnitDialog(context, ref),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: units.length,
            separatorBuilder: (ctx, i) => const Divider(),
            itemBuilder: (ctx, i) {
              final u = units[i];
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
                        onPressed: () => _showUnitDialog(context, ref, unit: u)),
                    IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteUnit(context, ref, u)),
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

class _TypeListTab extends ConsumerWidget {
  const _TypeListTab();

  Future<void> _showTypeDialog(BuildContext context, WidgetRef ref, {ProductType? type}) async {
    final controller = ref.read(masterDataProvider.notifier);
    final result = await showDialog<ProductType>(
      context: context,
      builder: (_) => MasterDataTypeDialog(type: type),
    );

    if (result != null) {
      if (!context.mounted) return;
      final success = await controller.saveProductType(result);
      if (success) {
        if (!context.mounted) return;
        AlertService.show(
            context: context, message: 'บันทึกเรียบร้อย', type: 'success');
      } else {
        if (!context.mounted) return;
        AlertService.show(
            context: context, message: 'เกิดข้อผิดพลาด', type: 'error');
      }
    }
  }

  Future<void> _deleteProductType(BuildContext context, WidgetRef ref, ProductType type) async {
    if (type.id <= 1) {
      AlertService.show(
          context: context,
          message: 'ไม่สามารถลบประเภทเริ่มต้นได้',
          type: 'warning');
      return;
    }

    final controller = ref.read(masterDataProvider.notifier);
    final confirm = await ConfirmDialog.show(
      context,
      title: 'ยืนยันการลบ',
      content: 'ต้องการลบประเภทสินค้า "${type.name}" หรือไม่?',
      isDestructive: true,
      confirmText: 'ลบ',
    );

    if (confirm == true) {
      if (!context.mounted) return;
      final success = await controller.deleteProductType(type.id);
      if (!success) {
        if (!context.mounted) return;
        AlertService.show(
            context: context,
            message: 'ไม่สามารถลบได้ (อาจถูกใช้งานอยู่)',
            type: 'error');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(masterDataProvider).productTypes;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('รายการประเภทสินค้าทั้งหมด (${types.length})',
                  style: Theme.of(context).textTheme.titleMedium),
              CustomButton(
                label: 'เพิ่มประเภทสินค้า',
                icon: Icons.add,
                onPressed: () => _showTypeDialog(context, ref),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: types.length,
            separatorBuilder: (ctx, i) => const Divider(),
            itemBuilder: (ctx, i) {
              final t = types[i];
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
                        onPressed: () => _showTypeDialog(context, ref, type: t)),
                    if (!isSystem)
                      IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteProductType(context, ref, t))
                    else
                      const IconButton(
                          icon: Icon(Icons.delete, color: Colors.grey),
                          onPressed: null),
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

class _ShelfListTab extends ConsumerWidget {
  const _ShelfListTab();

  Future<void> _showShelfDialog(BuildContext context, WidgetRef ref, {Shelf? shelf}) async {
    final controller = ref.read(masterDataProvider.notifier);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => MasterDataShelfDialog(shelf: shelf),
    );

    if (result != null) {
      if (!context.mounted) return;
      final success = await controller.saveShelf(shelf?.id ?? 0, result);
      if (success) {
        if (!context.mounted) return;
        AlertService.show(
            context: context, message: 'บันทึกเรียบร้อย', type: 'success');
      } else {
        if (!context.mounted) return;
        AlertService.show(
            context: context, message: 'เกิดข้อผิดพลาด/ชื่อซ้ำ', type: 'error');
      }
    }
  }

  Future<void> _deleteShelf(BuildContext context, WidgetRef ref, Shelf shelf) async {
    final controller = ref.read(masterDataProvider.notifier);
    final confirm = await ConfirmDialog.show(
      context,
      title: 'ยืนยันการลบ',
      content: 'ต้องการลบชั้นวาง "${shelf.name}" หรือไม่?',
      isDestructive: true,
      confirmText: 'ลบ',
    );

    if (confirm == true) {
      if (!context.mounted) return;
      final success = await controller.deleteShelf(shelf.id);
      if (!success) {
        if (!context.mounted) return;
        AlertService.show(
            context: context,
            message: 'ไม่สามารถลบได้ (อาจถูกใช้งานอยู่)',
            type: 'error');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelves = ref.watch(masterDataProvider).shelves;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('รายการชั้นวางทั้งหมด (${shelves.length})',
                  style: Theme.of(context).textTheme.titleMedium),
              CustomButton(
                label: 'เพิ่มชั้นวาง',
                icon: Icons.add,
                onPressed: () => _showShelfDialog(context, ref),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: shelves.length,
            separatorBuilder: (ctx, i) => const Divider(),
            itemBuilder: (ctx, i) {
              final shelf = shelves[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.brown.shade50,
                  foregroundColor: Colors.brown,
                  child: const Icon(Icons.shelves, size: 20),
                ),
                title: Text(shelf.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () =>
                            _showShelfDialog(context, ref, shelf: shelf)),
                    IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteShelf(context, ref, shelf)),
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
