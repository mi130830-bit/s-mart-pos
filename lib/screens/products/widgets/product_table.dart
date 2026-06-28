import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../models/product.dart';
import '../../../models/unit.dart';
import '../../../services/alert_service.dart';

class ProductTable extends StatelessWidget {
  final List<Product> products;
  final List<Unit> units;
  final bool isLoading;
  final bool isAdmin;
  final int totalItems;
  final int currentPage;
  final int pageSize;
  final ValueChanged<Product> onEditProduct;
  final ValueChanged<Product> onDeleteProduct;
  final Function(Product, bool) onToggleWarehouseItem;
  final ValueChanged<int> onPageChanged;

  const ProductTable({
    super.key,
    required this.products,
    required this.units,
    required this.isLoading,
    required this.isAdmin,
    required this.totalItems,
    required this.currentPage,
    required this.pageSize,
    required this.onEditProduct,
    required this.onDeleteProduct,
    required this.onToggleWarehouseItem,
    required this.onPageChanged,
  });

  bool _isNearExpiry(DateTime? expiryDate) {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final difference = expiryDate.difference(now).inDays;
    return difference <= 30;
  }

  Widget _buildFeatureBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (products.isEmpty) {
      return const Center(child: Text('ไม่พบข้อมูลสินค้า'));
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 80),
            separatorBuilder: (context, index) => const Divider(),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];

              bool isLowStock = p.trackStock &&
                  p.reorderPoint != null &&
                  p.stockQuantity <= p.reorderPoint!;

              bool isExpired = _isNearExpiry(p.expiryDate);

              final unitName = units
                  .firstWhere(
                    (u) => u.id == p.unitId,
                    orElse: () => Unit(id: 0, name: 'หน่วย'),
                  )
                  .name;

              // ---- กำหนดสี theme ตามสถานะสินค้า ----
              final Color themeColor = isExpired
                  ? Colors.red
                  : (isLowStock ? Colors.deepOrange : Colors.teal);

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    left: BorderSide(color: themeColor, width: 4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  onTap: () => onEditProduct(p),
                  leading: CircleAvatar(
                    backgroundColor: isExpired
                        ? Colors.red.shade100
                        : (isLowStock
                            ? Colors.orange.shade100
                            : Colors.teal.shade100),
                    child: Icon(
                      isExpired
                          ? Icons.event_busy
                          : (isLowStock
                              ? Icons.warning_amber_rounded
                              : Icons.inventory_2),
                      color: themeColor,
                    ),
                  ),
                title: Text(
                  p.name,
                  style: TextStyle(
                    fontWeight: (isLowStock || isExpired)
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isExpired
                        ? Colors.red
                        : (isLowStock
                            ? Colors.deepOrange
                            : Colors.black),
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Barcode: '),
                        SelectableText(p.barcode ?? "-"),
                        if (p.barcode != null && p.barcode!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: p.barcode!));
                                AlertService.show(
                                  context: context,
                                  message: 'คัดลอกบาร์โค้ดแล้ว',
                                  type: 'success',
                                  duration: const Duration(seconds: 1),
                                );
                              },
                              child: const Icon(Icons.copy,
                                  size: 16, color: Colors.blueGrey),
                            ),
                          ),
                        Text(' | ขาย: ${p.retailPrice}'),
                      ],
                    ),
                    if (p.hasComponents || p.hasPriceTiers || p.hasExtraUnits)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (p.hasComponents)
                              _buildFeatureBadge('เชื่อมโยง', Icons.link, Colors.purple),
                            if (p.hasPriceTiers)
                              _buildFeatureBadge('หลายราคา', Icons.link, Colors.indigo),
                            if (p.hasExtraUnits)
                              _buildFeatureBadge('หน่วยเสริม', Icons.view_module, Colors.teal),
                          ],
                        ),
                      ),
                    if (isLowStock)
                      Text(
                        '⚠️ สต็อกต่ำกว่าจุดสั่งซื้อ (${p.reorderPoint!.toStringAsFixed(0)})',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (isExpired && p.expiryDate != null)
                      Text(
                        '⚠️ สินค้าใกล้หมดอายุ/หมดอายุ (${DateFormat('dd/MM/yyyy').format(p.expiryDate!)})',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAdmin)
                      IconButton(
                        icon: Icon(
                          Icons.local_shipping,
                          color: p.isWarehouseItem
                              ? Colors.deepOrange
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                        tooltip: p.isWarehouseItem
                            ? 'สินค้าส่ง (Warehouse Item)'
                            : 'ไม่ใช่สินค้าส่ง',
                        onPressed: () => onToggleWarehouseItem(p, !p.isWarehouseItem),
                      ),
                    Text(
                      '${p.stockQuantity.toStringAsFixed(0)} $unitName',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isLowStock ? Colors.red : Colors.green,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (isAdmin) ...[
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => onEditProduct(p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => onDeleteProduct(p),
                      ),
                    ],
                  ],
                ),
              ), // end ListTile
            ); // end Container
          },
          ),
        ),
        // Pagination Controls
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: const Border(top: BorderSide(color: Colors.grey)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('ทั้งหมด $totalItems รายการ'),
              const SizedBox(width: 20),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: currentPage > 1
                        ? () => onPageChanged(currentPage - 1)
                        : null,
                  ),
                  Text(
                      'หน้า $currentPage / ${(totalItems / pageSize).ceil() == 0 ? 1 : (totalItems / pageSize).ceil()}'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: currentPage < (totalItems / pageSize).ceil()
                        ? () => onPageChanged(currentPage + 1)
                        : null,
                  ),
                ],
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ],
    );
  }
}
