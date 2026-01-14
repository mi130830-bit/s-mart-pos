import 'package:flutter/material.dart';
import '../../models/promotion.dart';
import '../../models/product.dart';
import '../../repositories/promotion_repository.dart';
import '../../repositories/product_repository.dart';
import '../products/product_selection_dialog.dart';

class PromotionListScreen extends StatefulWidget {
  const PromotionListScreen({super.key});

  @override
  State<PromotionListScreen> createState() => _PromotionListScreenState();
}

class _PromotionListScreenState extends State<PromotionListScreen> {
  final PromotionRepository _repo = PromotionRepository();
  List<Promotion> _promotions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _repo.getAllPromotions();
    if (mounted) {
      setState(() {
        _promotions = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleStatus(Promotion promo) async {
    // Toggle active status
    final newPromo = Promotion(
      id: promo.id,
      name: promo.name,
      startDate: promo.startDate,
      endDate: promo.endDate,
      isActive: !promo.isActive,
      conditionType: promo.conditionType,
      conditionValue: promo.conditionValue,
      actionType: promo.actionType,
      actionValue: promo.actionValue,
      eligibleProductIds: promo.eligibleProductIds,
    );
    await _repo.savePromotion(newPromo);
    _loadData();
  }

  Future<void> _showDialog([Promotion? promo]) async {
    // Simple Dialog for Add/Edit
    // For MVP, we allow editing Name, IsActive, Condition Value (Type=TotalSpend), Action Value (Type=DiscountAmount)
    // Complex editing can be added later.

    final nameCtrl = TextEditingController(text: promo?.name ?? '');
    final condValCtrl =
        TextEditingController(text: promo?.conditionValue.toString() ?? '1000');
    final actValCtrl =
        TextEditingController(text: promo?.actionValue.toString() ?? '100');

    // Defaults
    ConditionType condType = promo?.conditionType ?? ConditionType.totalSpend;
    ActionType actType = promo?.actionType ?? ActionType.discountAmount;
    List<int> selectedProductIds = List.from(promo?.eligibleProductIds ?? []);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(promo == null ? 'เพิ่มโปรโมชั่น' : 'แก้ไขโปรโมชั่น'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'ชื่อโปรโมชั่น'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ConditionType>(
                  initialValue: condType,
                  items: ConditionType.values
                      .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => condType = v!,
                  decoration: const InputDecoration(labelText: 'เงื่อนไข'),
                ),
                TextField(
                  controller: condValCtrl,
                  decoration: const InputDecoration(
                      labelText: 'มูลค่าเงื่อนไข (บาท/ชิ้น)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ActionType>(
                  initialValue: actType,
                  items: ActionType.values
                      .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => actType = v!,
                  decoration:
                      const InputDecoration(labelText: 'ผลลัพธ์ (Action)'),
                ),
                TextField(
                  controller: actValCtrl,
                  decoration:
                      const InputDecoration(labelText: 'มูลค่าผลลัพธ์ (บาท/%)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        selectedProductIds.isEmpty
                            ? 'ใช้กับสินค้าทั้งหมด (Eligible: All)'
                            : 'สินค้าที่ร่วมรายการ: ${selectedProductIds.length} รายการ',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final Product? p = await showDialog<Product>(
                          context: context,
                          builder: (ctx) =>
                              ProductSelectionDialog(repo: ProductRepository()),
                        );
                        if (p != null) {
                          setState(() {
                            if (!selectedProductIds.contains(p.id)) {
                              selectedProductIds.add(p.id);
                            }
                          });
                        }
                      },
                      child: const Text('เพิ่มสินค้า'),
                    ),
                  ],
                ),
                if (selectedProductIds.isNotEmpty)
                  Wrap(
                    spacing: 5,
                    children: selectedProductIds
                        .map((id) => Chip(
                              label: Text('ID: $id',
                                  style: const TextStyle(fontSize: 10)),
                              onDeleted: () {
                                setState(() {
                                  selectedProductIds.remove(id);
                                });
                              },
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก')),
            ElevatedButton(
              onPressed: () async {
                final newP = Promotion(
                  id: promo?.id ?? 0,
                  name: nameCtrl.text,
                  conditionType: condType,
                  conditionValue: double.tryParse(condValCtrl.text) ?? 0,
                  actionType: actType,
                  actionValue: double.tryParse(actValCtrl.text) ?? 0,
                  isActive: promo?.isActive ?? true,
                  startDate: promo?.startDate ?? DateTime.now(),
                  endDate: promo?.endDate ??
                      DateTime.now().add(const Duration(days: 365)),
                  eligibleProductIds: selectedProductIds,
                );
                await _repo.savePromotion(newP);

                if (!context.mounted) return;
                Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('บันทึก'),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('จัดการโปรโมชั่น (Promotions)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _promotions.length,
              itemBuilder: (context, index) {
                final p = _promotions[index];
                return Card(
                  color:
                      p.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                  child: ListTile(
                    title: Text(p.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${p.conditionType.name} >= ${p.conditionValue} -> ${p.actionType.name} ${p.actionValue}'),
                    trailing: Switch(
                      value: p.isActive,
                      onChanged: (val) => _toggleStatus(p),
                    ),
                    onTap: () => _showDialog(p),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
