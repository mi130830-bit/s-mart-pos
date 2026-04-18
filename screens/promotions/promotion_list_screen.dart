import 'package:flutter/material.dart';
import '../../models/promotion.dart';
import '../../repositories/promotion_repository.dart';

// Temporary Enums for UI (Mapped to Strings in logic)
enum UiConditionType { totalSpend, itemQty }

enum UiActionType { discountAmount, discountPercent, freeItem }

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
    final newPromo = Promotion(
      id: promo.id,
      name: promo.name,
      type: promo.type,
      startDate: promo.startDate,
      endDate: promo.endDate,
      startTime: promo.startTime,
      endTime: promo.endTime,
      daysOfWeek: promo.daysOfWeek,
      memberOnly: promo.memberOnly,
      priority: promo.priority,
      isActive: !promo.isActive,
      conditions: promo.conditions,
      rewards: promo.rewards,
    );
    await _repo.savePromotion(newPromo);
    _loadData();
  }

  Future<void> _showDialog([Promotion? promo]) async {
    final nameCtrl = TextEditingController(text: promo?.name ?? '');

    // Defaults for UI state
    UiConditionType uiCondType = UiConditionType.totalSpend;
    double uiCondVal = 1000.0;

    UiActionType uiActType = UiActionType.discountAmount;
    double uiActVal = 100.0;

    // Parse existing conditions for UI
    if (promo != null) {
      if (promo.conditions.containsKey('min_spend')) {
        uiCondType = UiConditionType.totalSpend;
        uiCondVal =
            double.tryParse(promo.conditions['min_spend'].toString()) ?? 0;
      } else if (promo.conditions.containsKey('buy_items')) {
        uiCondType = UiConditionType.itemQty;
        // Simplified view: show qty of first item requirement
        final list = promo.conditions['buy_items'] as List?;
        if (list != null && list.isNotEmpty) {
          uiCondVal = double.tryParse(list[0]['qty'].toString()) ?? 0;
        }
      }

      if (promo.rewards.containsKey('discount_amount')) {
        uiActType = UiActionType.discountAmount;
        uiActVal =
            double.tryParse(promo.rewards['discount_amount'].toString()) ?? 0;
      } else if (promo.rewards.containsKey('discount_percent')) {
        uiActType = UiActionType.discountPercent;
        uiActVal =
            double.tryParse(promo.rewards['discount_percent'].toString()) ?? 0;
      }
    }

    final condValCtrl = TextEditingController(text: uiCondVal.toString());
    final actValCtrl = TextEditingController(text: uiActVal.toString());

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
                DropdownButtonFormField<UiConditionType>(
                  initialValue: uiCondType,
                  items: UiConditionType.values
                      .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setState(() => uiCondType = v!),
                  decoration: const InputDecoration(labelText: 'เงื่อนไข'),
                ),
                TextField(
                  controller: condValCtrl,
                  decoration: const InputDecoration(
                      labelText: 'มูลค่าเงื่อนไข (บาท/ชิ้น)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<UiActionType>(
                  initialValue: uiActType,
                  items: UiActionType.values
                      .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setState(() => uiActType = v!),
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
                const Text(
                    'หมายเหตุ: สำหรับเงื่อนไขซับซ้อน กรุณาใช้ระบบหลังบ้าน (Web)',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก')),
            ElevatedButton(
              onPressed: () async {
                final cVal = double.tryParse(condValCtrl.text) ?? 0;
                final aVal = double.tryParse(actValCtrl.text) ?? 0;

                // Construct JSON
                Map<String, dynamic> conditions = {};
                if (uiCondType == UiConditionType.totalSpend) {
                  conditions['min_spend'] = cVal;
                } else {
                  // Dummy buy_items for MVP UI creation
                  conditions['buy_items'] = [
                    {'product_id': 0, 'qty': cVal}
                  ]; // 0=Any
                }

                Map<String, dynamic> rewards = {};
                if (uiActType == UiActionType.discountAmount) {
                  rewards['discount_amount'] = aVal;
                  rewards['type'] = 'discount_amount';
                } else if (uiActType == UiActionType.discountPercent) {
                  rewards['discount_percent'] = aVal;
                  rewards['type'] = 'discount_percent';
                }

                final newP = Promotion(
                  id: promo?.id ?? 0,
                  name: nameCtrl.text,
                  type: 'simple', // defaulting for simple creation
                  conditions: conditions,
                  rewards: rewards,
                  isActive: promo?.isActive ?? true,
                  startDate: promo?.startDate ?? DateTime.now(),
                  endDate: promo?.endDate ??
                      DateTime.now().add(const Duration(days: 365)),
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
      appBar: AppBar(title: const Text('จัดการโปรโมชั่น (Advanced)')),
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
                        'Rules: ${p.conditions.keys.join(", ")} -> ${p.rewards.keys.join(", ")}'),
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
