import 'package:flutter/material.dart';
import '../../../models/supplier.dart';
import '../../../repositories/supplier_repository.dart';
import '../../../widgets/generic_search_dialog.dart';

class SupplierSearchDialog extends StatefulWidget {
  const SupplierSearchDialog({super.key});

  @override
  State<SupplierSearchDialog> createState() => _SupplierSearchDialogState();
}

class _SupplierSearchDialogState extends State<SupplierSearchDialog> {
  final SupplierRepository _repo = SupplierRepository();
  List<Supplier> _allSuppliers = [];

  // Cache data to avoid hitting DB on every keystroke if dataset is small
  Future<List<Supplier>> _search(String query) async {
    if (_allSuppliers.isEmpty) {
      _allSuppliers = await _repo.getAllSuppliers();
    }

    if (query.isEmpty) return _allSuppliers;

    final lower = query.toLowerCase();
    return _allSuppliers
        .where((s) => s.name.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return GenericSearchDialog<Supplier>(
      title: 'ค้นหาผู้ขาย (Search Supplier)',
      hintText: 'พิมพ์ชื่อผู้ขาย...',
      emptyMessage: 'ไม่พบรายชื่อผู้ขาย',
      onSearch: _search,
      itemBuilder: (context, s) {
        return ListTile(
          title:
              Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(s.phone ?? '-'),
          hoverColor: Colors.blue.withValues(alpha: 0.05),
          onTap: () => Navigator.pop(context, s),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        );
      },
    );
  }
}
