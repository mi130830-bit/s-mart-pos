import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/promotion.dart';
import '../products/product_multi_selection_dialog.dart';
import 'controllers/promotion_edit_controller.dart';

class PromotionEditScreen extends ConsumerStatefulWidget {
  final Promotion? promotion;
  const PromotionEditScreen({super.key, this.promotion});

  @override
  ConsumerState<PromotionEditScreen> createState() => _PromotionEditScreenState();
}

class _PromotionEditScreenState extends ConsumerState<PromotionEditScreen> {
  @override
  void initState() {
    super.initState();
    final controller = ref.read(promotionEditProvider.notifier);
    controller.initialize(widget.promotion);
  }

  Future<void> _selectProducts(bool isCondition) async {
    final state = ref.read(promotionEditProvider);
    final controller = ref.read(promotionEditProvider.notifier);
    
    final initialIds = isCondition ? state.conditionProductIds : state.rewardProductIds;
    final result = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => ProductMultiSelectionDialog(initialSelectedIds: initialIds),
    );
    
    if (result != null) {
      if (isCondition) {
        controller.setConditionProductIds(result);
      } else {
        controller.setRewardProductIds(result);
      }
    }
  }

  Future<void> _save() async {
    final controller = ref.read(promotionEditProvider.notifier);
    final success = await controller.save();
    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(promotionEditProvider);
    final controller = ref.read(promotionEditProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.promotion == null ? 'เพิ่มโปรโมชั่นใหม่' : 'แก้ไขโปรโมชั่น'),
        actions: [
          TextButton.icon(
            onPressed: state.isSaving ? null : _save,
            icon: state.isSaving 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, color: Colors.white),
            label: const Text('บันทึก', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: Form(
        key: controller.formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Section 1: ข้อมูลทั่วไป ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ข้อมูลทั่วไป', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: controller.nameCtrl,
                      decoration: const InputDecoration(labelText: 'ชื่อโปรโมชั่น', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'กรุณากรอกชื่อ' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: controller.priorityCtrl,
                            decoration: const InputDecoration(labelText: 'Priority (สูง=คำนวณก่อน)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text('เฉพาะสมาชิก'),
                            value: state.memberOnly,
                            onChanged: (v) => controller.setMemberOnly(v ?? false),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Section 2: เงื่อนไข ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('เงื่อนไขการรับโปรโมชั่น', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: state.conditionType,
                      decoration: const InputDecoration(labelText: 'ประเภทเงื่อนไข', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'min_spend', child: Text('ยอดซื้อรวมขั้นต่ำ')),
                        DropdownMenuItem(value: 'buy_items', child: Text('ซื้อสินค้าตามจำนวนที่กำหนด')),
                        DropdownMenuItem(value: 'target_products', child: Text('ลดราคาสินค้าเฉพาะรายการ (ไม่กำหนดยอด)')),
                      ],
                      onChanged: (v) => controller.setConditionType(v!),
                    ),
                    const SizedBox(height: 16),
                    if (state.conditionType == 'min_spend')
                      TextFormField(
                        controller: controller.minSpendCtrl,
                        decoration: const InputDecoration(labelText: 'ยอดขั้นต่ำ (บาท)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    if (state.conditionType == 'buy_items')
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () => _selectProducts(true),
                              icon: const Icon(Icons.search),
                              label: Text('เลือกสินค้า (${state.conditionProductIds.length})'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: controller.buyQtyCtrl,
                              decoration: const InputDecoration(labelText: 'จำนวน (ชิ้น)', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    if (state.conditionType == 'target_products')
                      ElevatedButton.icon(
                        onPressed: () => _selectProducts(true),
                        icon: const Icon(Icons.list),
                        label: Text('เลือกสินค้าที่ร่วมรายการ (${state.conditionProductIds.length} รายการ)'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Section 3: รางวัล ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('รางวัล / ส่วนลด', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: state.rewardType,
                      decoration: const InputDecoration(labelText: 'ประเภทส่วนลด', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'discount_amount', child: Text('ส่วนลด (บาท)')),
                        DropdownMenuItem(value: 'discount_percent', child: Text('ส่วนลด (%)')),
                        DropdownMenuItem(value: 'get_items', child: Text('แถมฟรีสินค้า')),
                      ],
                      onChanged: (v) => controller.setRewardType(v!),
                    ),
                    const SizedBox(height: 16),
                    if (state.rewardType != 'get_items')
                      TextFormField(
                        controller: controller.rewardValCtrl,
                        decoration: const InputDecoration(labelText: 'มูลค่าส่วนลด', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    if (state.rewardType == 'get_items')
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () => _selectProducts(false),
                              icon: const Icon(Icons.card_giftcard),
                              label: Text('เลือกสินค้าแถม (${state.rewardProductIds.length})'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: controller.rewardValCtrl,
                              decoration: const InputDecoration(labelText: 'จำนวนแถม (ชิ้น)', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Section 4: ระยะเวลา ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ระยะเวลา (ปล่อยว่างคือตลอดไป)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            title: const Text('เริ่มวันที่'),
                            subtitle: Text(state.startDate != null ? DateFormat('dd/MM/yyyy').format(state.startDate!) : 'ไม่ระบุ'),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final d = await showDatePicker(
                                  context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                              if (d != null) controller.setStartDate(d);
                            },
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            title: const Text('ถึงวันที่'),
                            subtitle: Text(state.endDate != null ? DateFormat('dd/MM/yyyy').format(state.endDate!) : 'ไม่ระบุ'),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final d = await showDatePicker(
                                  context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                              if (d != null) controller.setEndDate(d);
                            },
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            title: const Text('เวลาเริ่ม'),
                            subtitle: Text(state.startTime?.format(context) ?? 'ไม่ระบุ'),
                            trailing: const Icon(Icons.access_time),
                            onTap: () async {
                              final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                              if (t != null) controller.setStartTime(t);
                            },
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            title: const Text('เวลาสิ้นสุด'),
                            subtitle: Text(state.endTime?.format(context) ?? 'ไม่ระบุ'),
                            trailing: const Icon(Icons.access_time),
                            onTap: () async {
                              final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                              if (t != null) controller.setEndTime(t);
                            },
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('วันในสัปดาห์ (เว้นว่างคือทุกวัน)'),
                    ),
                    Wrap(
                      spacing: 8,
                      children: List.generate(7, (index) {
                        final dayVal = index + 1; // 1=Mon, 7=Sun
                        final dayName = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'][index];
                        final isSelected = state.daysOfWeek.contains(dayVal);
                        return FilterChip(
                          label: Text(dayName),
                          selected: isSelected,
                          onSelected: (val) {
                            controller.toggleDayOfWeek(dayVal, val);
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
