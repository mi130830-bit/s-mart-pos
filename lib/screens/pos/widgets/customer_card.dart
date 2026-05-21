import 'package:flutter/material.dart';
import '../../../models/customer.dart';

class CustomerCard extends StatelessWidget {
  final Customer? customer;
  final VoidCallback onClearCustomer;
  final VoidCallback onQuickAddPressed;
  final VoidCallback onSearchPressed;

  const CustomerCard({
    super.key,
    required this.customer,
    required this.onClearCustomer,
    required this.onQuickAddPressed,
    required this.onSearchPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person, size: 36),
        title: Text(
          customer?.firstName ?? 'ลูกค้าทั่วไป',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(customer?.phone ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (customer != null)
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                tooltip: 'ยกเลิกเลือกเมมเบอร์',
                onPressed: onClearCustomer,
              ),
            IconButton(
              icon: const Icon(Icons.person_add, color: Colors.green),
              tooltip: 'สมัครสมาชิกด่วน',
              onPressed: onQuickAddPressed,
            ),
          ],
        ),
        onTap: onSearchPressed, // รับ Action มาจากหน้า POS Core
      ),
    );
  }
}
