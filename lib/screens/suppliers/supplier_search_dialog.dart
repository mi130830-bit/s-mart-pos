import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/supplier.dart';
import '../../repositories/supplier_repository.dart';
import '../../widgets/common/custom_text_field.dart';

class SupplierSearchDialog extends StatefulWidget {
  const SupplierSearchDialog({super.key});

  @override
  State<SupplierSearchDialog> createState() => _SupplierSearchDialogState();
}

class _SupplierSearchDialogState extends State<SupplierSearchDialog> {
  final SupplierRepository _repo = SupplierRepository();
  List<Supplier> _items = [];
  bool _isLoading = true;
  String _searchTerm = '';
  Timer? _debounce;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await _repo.getSuppliersPaginated(1, 20, searchTerm: _searchTerm);
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchTerm = val;
      });
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ค้นหาและเลือกผู้จำหน่าย'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            CustomTextField(
              controller: _searchCtrl,
              label: 'พิมพ์ชื่อเพื่อค้นหา',
              prefixIcon: Icons.search,
              autofocus: true,
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(child: Text('ไม่พบข้อมูล'))
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (ctx, i) => const Divider(),
                          itemBuilder: (ctx, i) {
                            final s = _items[i];
                            return ListTile(
                              title: Text(s.name),
                              subtitle: Text(s.phone ?? ''),
                              onTap: () {
                                Navigator.of(context).pop(s);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
      ],
    );
  }
}
