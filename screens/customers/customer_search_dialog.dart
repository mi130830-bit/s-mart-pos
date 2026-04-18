import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../repositories/customer_repository.dart';
import '../../widgets/generic_search_dialog.dart';

class CustomerSearchDialog extends StatefulWidget {
  final CustomerRepository? repo;
  final List<Customer>? preloadedCustomers;

  const CustomerSearchDialog({super.key, this.repo, this.preloadedCustomers});

  @override
  State<CustomerSearchDialog> createState() => _CustomerSearchDialogState();
}

class _CustomerSearchDialogState extends State<CustomerSearchDialog> {
  final CustomerRepository _defaultRepo = CustomerRepository();

  // Cache for preloaded
  List<Customer>? _cachedList;

  Future<List<Customer>> _search(String query) async {
    // 1. Preloaded strategy
    if (widget.preloadedCustomers != null) {
      _cachedList ??= widget.preloadedCustomers!;
      if (query.isEmpty) return _cachedList!;
      final lower = query.toLowerCase();
      return _cachedList!.where((c) {
        final name = '${c.firstName} ${c.lastName ?? ""}'.toLowerCase();
        return name.contains(lower) || (c.phone?.contains(query) ?? false);
      }).toList();
    }

    // 2. Repository Search
    final repo = widget.repo ?? _defaultRepo;
    if (query.isEmpty) {
      // Recent 5
      return await repo.getCustomersPaginated(1, 5);
    } else {
      // Search up to 50 items
      return await repo.getCustomersPaginated(1, 50, searchTerm: query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GenericSearchDialog<Customer>(
      title: 'ค้นหาลูกค้า',
      hintText: 'ค้นหาชื่อ หรือ เบอร์โทร...',
      emptyMessage: 'ไม่พบข้อมูลลูกค้า',
      onSearch: _search,
      itemBuilder: (context, c) {
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.indigo.shade50,
            child: Text(
              c.firstName.isNotEmpty ? c.firstName[0] : '?',
              style: TextStyle(color: Colors.indigo.shade800),
            ),
          ),
          title: Text(
            '${c.firstName} ${c.lastName ?? ""}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('Tel: ${c.phone ?? "-"}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (c.currentDebt > 0)
                Text(
                  'ค้างชำระ: ${c.currentDebt.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              Text(
                'แต้ม: ${c.currentPoints}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          onTap: () => Navigator.pop(context, c),
        );
      },
    );
  }
}
