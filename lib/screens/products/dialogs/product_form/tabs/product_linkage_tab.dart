// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api, use_build_context_synchronously
part of '../product_form_dialog.dart';

extension ProductLinkageTabExtension on _ProductFormDialogState {
  Widget _buildLinkageContent() {
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
          child: _components.isEmpty
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
                  itemCount: _components.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final comp = _components[index];
                    return ComponentRow(
                      key: ValueKey(comp.childProductId),
                      component: comp,
                      index: index,
                      onQuantityChanged: (val) {
                        setState(() {
                          _components[index] = ProductComponent(
                            id: comp.id,
                            parentProductId: comp.parentProductId,
                            childProductId: comp.childProductId,
                            quantity: val,
                            childProductName: comp.childProductName,
                            childProductCost: comp.childProductCost,
                            childProductUnit: comp.childProductUnit,
                            childProductStock: comp.childProductStock,
                          );
                          _calculateCostAndStockFromComponents();
                        });
                      },
                      onDelete: () {
                        setState(() {
                          _components.removeAt(index);
                          _calculateCostAndStockFromComponents();
                        });
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

  double _calculateTotalCostValue() {
    double total = 0;
    for (var comp in _components) {
      total += (comp.childProductCost ?? 0) * comp.quantity;
    }
    return total;
  }

  // --- ฟังก์ชัน BOM ---
  Future<void> _addComponent() async {
    final selectedProduct = await showDialog<Product>(
      context: context,
      builder: (ctx) =>
          ProductSearchDialogForSelect(repo: widget.repo), // Pass repo here
    );

    if (selectedProduct != null) {
      if (_components.any((c) => c.childProductId == selectedProduct.id)) {
        if (!mounted) return;
        AlertService.show(
          context: context,
          message: 'สินค้านี้ถูกเพิ่มไปแล้ว',
          type: 'warning',
        );
        return;
      }

      if (widget.product != null && selectedProduct.id == widget.product!.id) {
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
        final foundUnit = _units.firstWhere(
          (u) => u.id == selectedProduct.unitId,
          orElse: () => Unit(id: 0, name: 'หน่วย'),
        );
        unitName = foundUnit.name;
      }

      setState(() {
        _components.add(ProductComponent(
          id: 0,
          parentProductId: widget.product?.id ?? 0,
          childProductId: selectedProduct.id,
          quantity: 1.0,
          childProductName: selectedProduct.name,
          childProductCost: selectedProduct.costPrice,
          childProductUnit: unitName,
          childProductStock: selectedProduct.stockQuantity, // Added stock
        ));
      });
      _calculateCostAndStockFromComponents(); // Update immediately
    }
  }

  void _calculateCostAndStockFromComponents() {
    double totalCost = 0;
    double maxPossibleStock = double.infinity;
    bool hasComponents = false;

    for (var comp in _components) {
      double childCost = comp.childProductCost ?? 0;
      totalCost += childCost * comp.quantity;

      // Stock Calculation
      if (comp.quantity > 0) {
        hasComponents = true;
        double childStock = comp.childProductStock ?? 0;
        double possible = childStock / comp.quantity;
        if (possible < maxPossibleStock) {
          maxPossibleStock = possible;
        }
      }
    }

    setState(() {
      _costCtrl.text = totalCost.toStringAsFixed(2);
      if (hasComponents && maxPossibleStock != double.infinity) {
        _stockCtrl.text = maxPossibleStock.floor().toString();
      }
    });

    AlertService.show(
      context: context,
      message:
          'คำนวณต้นทุน: $totalCost, สต็อกสูงสุด: ${hasComponents && maxPossibleStock != double.infinity ? maxPossibleStock.floor() : "N/A"}',
      type: 'info',
    );
  }
}
