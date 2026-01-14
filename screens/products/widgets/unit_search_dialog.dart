import 'package:flutter/material.dart';
import '../../../models/unit.dart';
import '../../../repositories/unit_repository.dart';
import '../../../widgets/generic_search_dialog.dart';

class UnitSearchDialog extends StatefulWidget {
  const UnitSearchDialog({super.key});

  @override
  State<UnitSearchDialog> createState() => _UnitSearchDialogState();
}

class _UnitSearchDialogState extends State<UnitSearchDialog> {
  final UnitRepository _repo = UnitRepository();
  List<Unit> _allUnits = [];

  Future<List<Unit>> _search(String query) async {
    if (_allUnits.isEmpty) {
      _allUnits = await _repo.getAllUnits();
    }

    if (query.isEmpty) return _allUnits;

    final lower = query.toLowerCase();
    return _allUnits
        .where((u) => u.name.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return GenericSearchDialog<Unit>(
      title: 'ค้นหาหน่วยนับ (Search Unit)',
      hintText: 'พิมพ์ชื่อหน่วย...',
      emptyMessage: 'ไม่พบหน่วยนับ',
      onSearch: _search,
      itemBuilder: (context, u) {
        return ListTile(
          title: Text(u.name),
          hoverColor: Colors.blue.withValues(alpha: 0.05),
          onTap: () => Navigator.pop(context, u),
          trailing: const Icon(Icons.chevron_right),
        );
      },
    );
  }
}
