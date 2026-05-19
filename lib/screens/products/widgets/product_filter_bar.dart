import 'package:flutter/material.dart';
import '../../../models/product_type.dart';
import '../../../repositories/product_repository.dart';
import '../../../widgets/common/custom_buttons.dart';
import '../../../widgets/common/thai_aware_search_field.dart';

class ProductFilterBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final ProductSortOption currentSort;
  final int? filterTypeId;
  final List<ProductType> productTypes;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ProductSortOption> onSortChanged;
  final ValueChanged<int?> onFilterTypeChanged;
  final VoidCallback onSyncData;
  final VoidCallback onManageMasterData;
  final bool hasMasterDataPermission;

  const ProductFilterBar({
    super.key,
    required this.searchCtrl,
    required this.currentSort,
    required this.filterTypeId,
    required this.productTypes,
    required this.onSearchChanged,
    required this.onSortChanged,
    required this.onFilterTypeChanged,
    required this.onSyncData,
    required this.onManageMasterData,
    required this.hasMasterDataPermission,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ThaiAwareSearchField(
            controller: searchCtrl,
            label: 'ค้นหาสินค้า (ชื่อ, บาร์โค้ด, ตัวย่อ)',
            onChanged: onSearchChanged,
            autofocus: true,
          ),
        ),
        const SizedBox(width: 8),
        // Sort Button
        PopupMenuButton<ProductSortOption>(
          icon: const Icon(Icons.sort),
          tooltip: 'เรียงลำดับ',
          initialValue: currentSort,
          onSelected: onSortChanged,
          itemBuilder: (BuildContext context) =>
              <PopupMenuEntry<ProductSortOption>>[
            const PopupMenuItem<ProductSortOption>(
              value: ProductSortOption.recent,
              child: Text('ล่าสุด (Default)'),
            ),
            const PopupMenuItem<ProductSortOption>(
              value: ProductSortOption.nameAsc,
              child: Text('ชื่อ (ก-ฮ)'),
            ),
            const PopupMenuItem<ProductSortOption>(
              value: ProductSortOption.stockAsc,
              child: Text('สต็อก (น้อย -> มาก)'),
            ),
            const PopupMenuItem<ProductSortOption>(
              value: ProductSortOption.stockDesc,
              child: Text('สต็อก (มาก -> น้อย)'),
            ),
          ],
        ),
        const SizedBox(width: 8),
        // Filter Button (Product Type)
        PopupMenuButton<int?>(
          icon: Icon(
            Icons.filter_list,
            color: filterTypeId != null
                ? Theme.of(context).primaryColor
                : null,
          ),
          tooltip: 'กรองประเภทสินค้า',
          initialValue: filterTypeId,
          onSelected: onFilterTypeChanged,
          itemBuilder: (BuildContext context) {
            return [
              const PopupMenuItem<int?>(
                value: null,
                child: Text('ทั้งหมด (All)'),
              ),
              const PopupMenuDivider(),
              if (productTypes.isEmpty)
                const PopupMenuItem<int?>(
                  enabled: false,
                  value: null,
                  child: Text('(ไม่มีประเภทสินค้า)'),
                ),
              ...productTypes.map((type) {
                return PopupMenuItem<int?>(
                  value: type.id,
                  child: Text(type.name),
                );
              }),
            ];
          },
        ),
        const SizedBox(width: 8),
        // Sync Button
        IconButton(
          onPressed: onSyncData,
          tooltip: 'ดึงข้อมูลล่าสุด (Sync)',
          icon: const Icon(Icons.sync),
        ),
        const SizedBox(width: 8),
        if (hasMasterDataPermission)
          CustomButton(
            label: 'จัดการข้อมูลหลัก',
            icon: Icons.settings,
            onPressed: onManageMasterData,
          ),
      ],
    );
  }
}
