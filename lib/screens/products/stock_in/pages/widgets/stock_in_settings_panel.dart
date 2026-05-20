import 'package:flutter/material.dart';
import '../../../../../models/supplier.dart';
import '../../../widgets/supplier_search_dialog.dart';
import '../../../../../widgets/common/custom_text_field.dart';

class StockInSettingsPanel extends StatelessWidget {
  final List<Supplier> suppliers;
  final int? selectedSupplierId;
  final int vatType;
  final TextEditingController docNoCtrl;
  final bool isPaid;
  final ValueChanged<Supplier?> onSupplierChanged;
  final ValueChanged<int?> onVatChanged;
  final VoidCallback onPaymentToggle;

  const StockInSettingsPanel({
    super.key,
    required this.suppliers,
    required this.selectedSupplierId,
    required this.vatType,
    required this.docNoCtrl,
    required this.isPaid,
    required this.onSupplierChanged,
    required this.onVatChanged,
    required this.onPaymentToggle,
  });

  String _getSupplierName() {
    if (selectedSupplierId == null || suppliers.isEmpty) {
      return '- เลือกผู้ขาย -';
    }
    for (var s in suppliers) {
      if (s.id == selectedSupplierId) {
        return s.name;
      }
    }
    return '- เลือกผู้ขาย -';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: InkWell(
            onTap: () async {
              final Supplier? selected = await showDialog<Supplier>(
                context: context,
                builder: (context) => const SupplierSearchDialog(),
              );
              if (selected != null) {
                onSupplierChanged(selected);
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'ผู้ขาย',
                border: OutlineInputBorder(),
                fillColor: Colors.white,
                filled: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                prefixIcon: Icon(Icons.search),
              ),
              child: Text(
                _getSupplierName(),
                style: TextStyle(
                    color: selectedSupplierId == null
                        ? Colors.grey
                        : Colors.black),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // VAT Selection
        Expanded(
          flex: 1,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'ประเภทภาษี',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              fillColor: Colors.white,
              filled: true,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: vatType,
                isDense: true,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('รวมภาษี')),
                  DropdownMenuItem(value: 1, child: Text('แยกภาษี')),
                  DropdownMenuItem(value: 2, child: Text('ไม่มีภาษี')),
                ],
                onChanged: onVatChanged,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 1,
          child: CustomTextField(
            controller: docNoCtrl,
            label: 'เลขที่เอกสาร',
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        // Payment Toggle
        Expanded(
          flex: 1,
          child: InkWell(
            onTap: onPaymentToggle,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'สถานะการเงิน',
                border: OutlineInputBorder(),
                fillColor: Colors.white,
                filled: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Row(
                children: [
                  Icon(
                    isPaid ? Icons.check_circle : Icons.error_outline,
                    color: isPaid ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPaid ? 'จ่ายเงินแล้ว' : 'ยังไม่จ่าย',
                    style: TextStyle(
                      color: isPaid ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
