import 'package:flutter/material.dart';
import '../../models/supplier.dart';
import '../../services/alert_service.dart';
import '../../repositories/supplier_repository.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/confirm_dialog.dart';

class SupplierListView extends StatefulWidget {
  const SupplierListView({super.key});

  @override
  State<SupplierListView> createState() => _SupplierListViewState();
}

class _SupplierListViewState extends State<SupplierListView> {
  final SupplierRepository _repo = SupplierRepository();

  // State
  List<Supplier> _items = [];
  bool _isLoading = false;
  int _currentPage = 1;
  final int _pageSize = 10;
  int _totalItems = 0;
  String _searchTerm = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final total = await _repo.getSupplierCount(searchTerm: _searchTerm);
      final items = await _repo.getSuppliersPaginated(_currentPage, _pageSize,
          searchTerm: _searchTerm);

      if (mounted) {
        setState(() {
          _totalItems = total;
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchTerm = val;
      _currentPage = 1; // Reset to first page
    });
    _loadData();
  }

  void _changePage(int newPage) {
    setState(() {
      _currentPage = newPage;
    });
    _loadData();
  }

  Future<void> _showForm([Supplier? s]) async {
    final nameCtrl = TextEditingController(text: s?.name ?? '');
    final phoneCtrl = TextEditingController(text: s?.phone ?? '');
    final addrCtrl = TextEditingController(text: s?.address ?? '');
    final saleNameCtrl = TextEditingController(text: s?.saleName ?? '');
    final saleLineIdCtrl = TextEditingController(text: s?.saleLineId ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s == null ? 'เพิ่มผู้ขาย' : 'แก้ไขผู้ขาย'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: nameCtrl,
                label: 'ชื่อ',
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: phoneCtrl,
                label: 'โทรศัพท์',
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: addrCtrl,
                label: 'ที่อยู่',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: saleNameCtrl,
                      label: 'ชื่อเซลล์',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomTextField(
                      controller: saleLineIdCtrl,
                      label: 'ไลน์ของเซล',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          CustomButton(
            onPressed: () => Navigator.pop(ctx, false),
            label: 'ยกเลิก',
            type: ButtonType.secondary,
          ),
          CustomButton(
            onPressed: () async {
              final sup = Supplier(
                id: s?.id ?? 0,
                name: nameCtrl.text,
                phone: phoneCtrl.text,
                address: addrCtrl.text,
                saleName: saleNameCtrl.text,
                saleLineId: saleLineIdCtrl.text,
              );
              final navigator = Navigator.of(ctx);
              final ok = await _repo.saveSupplier(sup);
              navigator.pop(ok);
            },
            label: 'บันทึก',
            type: ButtonType.primary,
          ),
        ],
      ),
    );

    if (saved == true) {
      if (!mounted) return;
      _loadData();
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
      final res = await _repo.deleteSupplier(s.id);
      if (!mounted) return;
      AlertService.show(
        context: context,
        message: res ? 'ลบสำเร็จ' : 'ลบไม่สำเร็จ',
        type: res ? 'success' : 'error',
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_totalItems / _pageSize).ceil();
    if (totalPages > 0 && _currentPage > totalPages) _currentPage = totalPages;
    if (_currentPage < 1) _currentPage = 1;

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
              onChanged: _onSearchChanged,
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('ไม่พบข้อมูล'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (ctx, i) => const Divider(),
                        itemBuilder: (ctx, i) {
                          final s = _items[i];
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
                Text('รวม $_totalItems รายการ'),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 1
                      ? () => _changePage(_currentPage - 1)
                      : null,
                ),
                Text(
                    'หน้า $_currentPage / ${totalPages == 0 ? 1 : totalPages}'),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < totalPages
                      ? () => _changePage(_currentPage + 1)
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
