import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/supplier.dart';
import '../../services/alert_service.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/confirm_dialog.dart';
import 'supplier_form_dialog.dart';
import 'supplier_provider.dart';

class SupplierListView extends ConsumerStatefulWidget {
  const SupplierListView({super.key});

  @override
  ConsumerState<SupplierListView> createState() => _SupplierListViewState();
}

class _SupplierListViewState extends ConsumerState<SupplierListView> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showForm([Supplier? s]) async {
    final saved = await showDialog<Supplier?>(
      context: context,
      builder: (ctx) => SupplierFormDialog(supplier: s),
    );

    if (saved != null) {
      if (!mounted) return;
      ref.read(supplierProvider).loadData();
    }
  }

  Future<void> _confirmDelete(Supplier s) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'ยืนยันการลบ',
      content: 'ต้องการลบผู้ขาย "${s.name}" หรือไม่?',
      confirmText: 'ลบ',
      isDestructive: true,
    );

    if (ok == true) {
      final res = await ref.read(supplierProvider).deleteSupplier(s.id);
      if (!mounted) return;
      AlertService.show(
        context: context,
        message: res ? 'ลบสำเร็จ' : 'ลบไม่สำเร็จ',
        type: res ? 'success' : 'error',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(supplierProvider);
    final totalPages = (provider.totalItems / provider.pageSize).ceil();
    int currentPage = provider.currentPage;
    
    if (totalPages > 0 && currentPage > totalPages) currentPage = totalPages;
    if (currentPage < 1) currentPage = 1;

    return Scaffold(
      appBar: AppBar(title: const Text('ข้อมูลผู้ขาย')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CustomTextField(
              controller: _searchCtrl,
              label: 'ค้นหาผู้ขาย',
              prefixIcon: Icons.search,
              onChanged: (val) {
                ref.read(supplierProvider).onSearchChanged(val);
              },
            ),
          ),

          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.items.isEmpty
                    ? const Center(child: Text('ไม่พบข้อมูล'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.items.length,
                        separatorBuilder: (ctx, i) => const Divider(),
                        itemBuilder: (ctx, i) {
                          final s = provider.items[i];
                          return ListTile(
                            title: Text(s.name),
                            subtitle:
                                Text('${s.phone ?? ''} ${s.address ?? ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () => _showForm(s),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _confirmDelete(s),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Pagination Controls
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('รวม ${provider.totalItems} รายการ'),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: currentPage > 1
                      ? () => ref.read(supplierProvider).changePage(currentPage - 1)
                      : null,
                ),
                Text(
                    'หน้า $currentPage / ${totalPages == 0 ? 1 : totalPages}'),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: currentPage < totalPages
                      ? () => ref.read(supplierProvider).changePage(currentPage + 1)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 60), // Space for FAB
        ],
      ),
    );
  }
}
