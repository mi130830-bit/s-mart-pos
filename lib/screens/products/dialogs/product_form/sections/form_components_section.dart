import 'package:flutter/material.dart';
import '../../../../../models/product.dart';
import '../../../../../models/product_component.dart';
import '../../../../../models/unit.dart';
import '../../../../../repositories/product_repository.dart';
import '../../../../../services/alert_service.dart';
import '../../../../../widgets/common/custom_buttons.dart';
import '../../../widgets/component_row.dart';
import '../../../widgets/product_search_dialog_for_select.dart';

class FormComponentsSection extends StatefulWidget {
  final List<ProductComponent> components;
  final ProductRepository repo;
  final int? parentProductId;
  final List<Unit> units;
  final VoidCallback onRecalculate;

  const FormComponentsSection({
    super.key,
    required this.components,
    required this.repo,
    this.parentProductId,
    required this.units,
    required this.onRecalculate,
  });

  @override
  State<FormComponentsSection> createState() => _FormComponentsSectionState();
}

class _FormComponentsSectionState extends State<FormComponentsSection> {
  double _calculateTotalCostValue() {
    double total = 0;
    for (var comp in widget.components) {
      total += (comp.childProductCost ?? 0) * comp.quantity;
    }
    return total;
  }

  Future<void> _addComponent() async {
    final selectedProduct = await showDialog<Product>(
      context: context,
      builder: (ctx) =>
          ProductSearchDialogForSelect(repo: widget.repo),
    );

    if (selectedProduct != null) {
      if (widget.components.any((c) => c.childProductId == selectedProduct.id)) {
        if (!mounted) return;
        AlertService.show(
          context: context,
          message: 'สินค้านี้ถูกเพิ่มไปแล้ว',
          type: 'warning',
        );
        return;
      }

      if (widget.parentProductId != null && selectedProduct.id == widget.parentProductId) {
        if (!mounted) return;
        AlertService.show(
          context: context,
          message: 'ไม่สามารถเลือกตัวเองเป็นส่วนประกอบได้',
          type: 'warning',
        );
        return;
      }

      // Find unit name
      String unitName = 'หน่วย';
      if (selectedProduct.unitId != null) {
        final foundUnit = widget.units.firstWhere(
          (u) => u.id == selectedProduct.unitId,
          orElse: () => Unit(id: 0, name: 'หน่วย'),
        );
        unitName = foundUnit.name;
      }

      setState(() {
        widget.components.add(ProductComponent(
          id: 0,
          parentProductId: widget.parentProductId ?? 0,
          childProductId: selectedProduct.id,
          quantity: 1.0,
          childProductName: selectedProduct.name,
          childProductCost: selectedProduct.costPrice,
          childProductUnit: unitName,
          childProductStock: selectedProduct.stockQuantity,
        ));
      });
      widget.onRecalculate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search & Add
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'เชื่อมโยงส่วนประกอบเพื่อคำนวณต้นทุน',
                  style: TextStyle(color: Colors.blue[900]),
                ),
              ),
              CustomButton(
                onPressed: _addComponent,
                icon: Icons.search,
                label: 'ค้นหาสินค้าเชื่อมโยง',
                type: ButtonType.primary,
                backgroundColor: Colors.blue[700],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: Colors.grey[800],
          child: const Row(
            children: [
              Expanded(
                  flex: 4,
                  child: Text('ชื่อสินค้า',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 2,
                  child: Text('ต้นทุน/หน่วย',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 2,
                  child: Text('สัดส่วน (Qty)',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              SizedBox(
                  width: 40,
                  child: Text('ลบ',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center)),
            ],
          ),
        ),

        // List
        Expanded(
          child: widget.components.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.link_off, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('ยังไม่มีการเชื่อมโยงสินค้า',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 16)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: widget.components.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final comp = widget.components[index];
                    return ComponentRow(
                      key: ValueKey(comp.childProductId),
                      component: comp,
                      index: index,
                      onQuantityChanged: (val) {
                        setState(() {
                          widget.components[index] = ProductComponent(
                            id: comp.id,
                            parentProductId: comp.parentProductId,
                            childProductId: comp.childProductId,
                            quantity: val,
                            childProductName: comp.childProductName,
                            childProductCost: comp.childProductCost,
                            childProductUnit: comp.childProductUnit,
                            childProductStock: comp.childProductStock,
                          );
                        });
                        widget.onRecalculate();
                      },
                      onDelete: () {
                        setState(() {
                          widget.components.removeAt(index);
                        });
                        widget.onRecalculate();
                      },
                    );
                  },
                ),
        ),

        // Summary Footer
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('รวมต้นทุนจากส่วนประกอบ:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '${_calculateTotalCostValue().toStringAsFixed(2)} บาท',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.blue),
              ),
            ],
          ),
        )
      ],
    );
  }
}
