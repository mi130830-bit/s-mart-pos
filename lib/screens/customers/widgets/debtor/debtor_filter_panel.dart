import 'package:flutter/material.dart';

class DebtorFilterPanel extends StatelessWidget {
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final String sortOption;
  final ValueChanged<String?> onSortOptionChanged;

  const DebtorFilterPanel({
    super.key,
    required this.searchCtrl,
    required this.onSearch,
    required this.sortOption,
    required this.onSortOptionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchCtrl,
              decoration: const InputDecoration(
                hintText: 'ค้นหาลูกหนี้... (ชื่อ, เบอร์โทร, เลขบิล)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
              onChanged: onSearch,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: sortOption,
                items: const [
                  DropdownMenuItem(
                    value: 'OUTSTANDING_NEW',
                    child: Text('ค้างชำระก่อน (ใหม่-เก่า)'),
                  ),
                  DropdownMenuItem(
                    value: 'OUTSTANDING_OLD',
                    child: Text('ค้างชำระก่อน (เก่า-ใหม่)'),
                  ),
                  DropdownMenuItem(
                    value: 'DATE_NEW',
                    child: Text('เวลา (ใหม่-เก่า)'),
                  ),
                  DropdownMenuItem(
                    value: 'DATE_OLD',
                    child: Text('เวลา (เก่า-ใหม่)'),
                  ),
                ],
                onChanged: onSortOptionChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
