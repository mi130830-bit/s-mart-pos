import 'package:flutter/material.dart';
import '../../models/promotion.dart';
import '../../repositories/promotion_repository.dart';
import '../products/product_multi_selection_dialog.dart';
import 'package:intl/intl.dart';

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

  Future<void> _deletePromotion(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบโปรโมชั่น'),
        content: const Text('คุณแน่ใจหรือไม่ที่จะลบโปรโมชั่นนี้?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repo.deletePromotion(id);
      _loadData();
    }
  }

  Future<void> _showDialog([Promotion? promo]) async {
    // Show the full screen dialog for editing/creating promotion
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PromotionEditScreen(promotion: promo),
        fullscreenDialog: true,
      ),
    );
    if (result == true) {
      _loadData();
    }
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
                
                String conditionStr = 'ยอดขั้นต่ำ';
                if (p.conditions.containsKey('buy_items')) conditionStr = 'ซื้อสินค้ากำหนด';
                if (p.conditions.containsKey('target_products')) conditionStr = 'ลดสินค้าเฉพาะ';

                String rewardStr = 'ไม่มี';
                if (p.rewards.containsKey('discount_amount')) rewardStr = 'ลด ฿${p.rewards['discount_amount']}';
                if (p.rewards.containsKey('discount_percent')) rewardStr = 'ลด ${p.rewards['discount_percent']}%';
                if (p.rewards.containsKey('get_items')) rewardStr = 'แถมฟรี!';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: p.isActive ? Colors.green.shade300 : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  color: p.isActive ? Colors.white : Colors.grey.shade50,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: p.isActive ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),
                        if (p.memberOnly)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('สมาชิกเท่านั้น', style: TextStyle(color: Colors.orange, fontSize: 12)),
                          ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Pri: ${p.priority}', style: TextStyle(color: Colors.blue.shade700, fontSize: 12)),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('เงื่อนไข: $conditionStr → รางวัล: $rewardStr', style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(
                            'ระยะเวลา: ${p.startDate != null ? DateFormat('dd/MM/yyyy').format(p.startDate!) : 'ไม่ระบุ'} - ${p.endDate != null ? DateFormat('dd/MM/yyyy').format(p.endDate!) : 'ไม่ระบุ'}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          if (p.startTime != null && p.endTime != null)
                            Text(
                              'เวลา: ${p.startTime} - ${p.endTime}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: p.isActive,
                          onChanged: (val) => _toggleStatus(p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showDialog(p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deletePromotion(p.id),
                        ),
                      ],
                    ),
                    onTap: () => _showDialog(p),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDialog(),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มโปรโมชั่น'),
      ),
    );
  }
}

class PromotionEditScreen extends StatefulWidget {
  final Promotion? promotion;
  const PromotionEditScreen({super.key, this.promotion});

  @override
  State<PromotionEditScreen> createState() => _PromotionEditScreenState();
}

class _PromotionEditScreenState extends State<PromotionEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final PromotionRepository _repo = PromotionRepository();

  late TextEditingController _nameCtrl;
  late TextEditingController _priorityCtrl;
  late bool _memberOnly;

  // Condition
  String _conditionType = 'min_spend'; // min_spend, buy_items, target_products
  late TextEditingController _minSpendCtrl;
  late TextEditingController _buyQtyCtrl;
  List<int> _conditionProductIds = [];

  // Reward
  String _rewardType = 'discount_percent'; // discount_amount, discount_percent, get_items
  late TextEditingController _rewardValCtrl; // amount or percent or qty
  List<int> _rewardProductIds = [];

  // Schedule
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  List<int> _daysOfWeek = [];

  @override
  void initState() {
    super.initState();
    final p = widget.promotion;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _priorityCtrl = TextEditingController(text: p?.priority.toString() ?? '0');
    _memberOnly = p?.memberOnly ?? false;

    _startDate = p?.startDate;
    _endDate = p?.endDate;
    if (p?.startTime != null) {
      final parts = p!.startTime!.split(':');
      if (parts.length == 2) _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    if (p?.endTime != null) {
      final parts = p!.endTime!.split(':');
      if (parts.length == 2) _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    _daysOfWeek = List<int>.from(p?.daysOfWeek ?? []);

    _minSpendCtrl = TextEditingController(text: '0');
    _buyQtyCtrl = TextEditingController(text: '1');
    _rewardValCtrl = TextEditingController(text: '0');

    if (p != null) {
      if (p.conditions.containsKey('min_spend')) {
        _conditionType = 'min_spend';
        _minSpendCtrl.text = p.conditions['min_spend'].toString();
      } else if (p.conditions.containsKey('buy_items')) {
        _conditionType = 'buy_items';
        final list = p.conditions['buy_items'] as List;
        if (list.isNotEmpty) {
          _conditionProductIds = [int.parse(list[0]['product_id'].toString())];
          _buyQtyCtrl.text = list[0]['qty'].toString();
        }
      } else if (p.conditions.containsKey('target_products')) {
        _conditionType = 'target_products';
        _conditionProductIds = (p.conditions['target_products'] as List).map((e) => int.parse(e.toString())).toList();
      }

      if (p.rewards.containsKey('discount_amount')) {
        _rewardType = 'discount_amount';
        _rewardValCtrl.text = p.rewards['discount_amount'].toString();
      } else if (p.rewards.containsKey('discount_percent')) {
        _rewardType = 'discount_percent';
        _rewardValCtrl.text = p.rewards['discount_percent'].toString();
      } else if (p.rewards.containsKey('get_items')) {
        _rewardType = 'get_items';
        final list = p.rewards['get_items'] as List;
        if (list.isNotEmpty) {
          _rewardProductIds = [int.parse(list[0]['product_id'].toString())];
          _rewardValCtrl.text = list[0]['qty'].toString();
        }
      }
    }
  }

  Future<void> _selectProducts(bool isCondition) async {
    final initialIds = isCondition ? _conditionProductIds : _rewardProductIds;
    final result = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => ProductMultiSelectionDialog(initialSelectedIds: initialIds),
    );
    if (result != null) {
      setState(() {
        if (isCondition) {
          _conditionProductIds = result;
        } else {
          _rewardProductIds = result;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    Map<String, dynamic> conditions = {};
    if (_conditionType == 'min_spend') {
      conditions['min_spend'] = double.parse(_minSpendCtrl.text);
    } else if (_conditionType == 'buy_items') {
      conditions['buy_items'] = [
        {'product_id': _conditionProductIds.isNotEmpty ? _conditionProductIds.first : 0, 'qty': double.parse(_buyQtyCtrl.text)}
      ];
    } else if (_conditionType == 'target_products') {
      conditions['target_products'] = _conditionProductIds;
    }

    Map<String, dynamic> rewards = {};
    if (_rewardType == 'discount_amount') {
      rewards['type'] = 'discount_amount';
      rewards['discount_amount'] = double.parse(_rewardValCtrl.text);
    } else if (_rewardType == 'discount_percent') {
      rewards['type'] = 'discount_percent';
      rewards['discount_percent'] = double.parse(_rewardValCtrl.text);
    } else if (_rewardType == 'get_items') {
      rewards['type'] = 'get_items';
      rewards['get_items'] = [
        {'product_id': _rewardProductIds.isNotEmpty ? _rewardProductIds.first : 0, 'qty': double.parse(_rewardValCtrl.text)}
      ];
    }

    String? startT;
    String? endT;
    if (_startTime != null) {
      startT = "\${_startTime!.hour.toString().padLeft(2, '0')}:\${_startTime!.minute.toString().padLeft(2, '0')}";
    }
    if (_endTime != null) {
      endT = "\${_endTime!.hour.toString().padLeft(2, '0')}:\${_endTime!.minute.toString().padLeft(2, '0')}";
    }

    final newP = Promotion(
      id: widget.promotion?.id ?? 0,
      name: _nameCtrl.text,
      type: _conditionType == 'target_products' ? 'per_product' : 'simple',
      priority: int.tryParse(_priorityCtrl.text) ?? 0,
      memberOnly: _memberOnly,
      isActive: widget.promotion?.isActive ?? true,
      conditions: conditions,
      rewards: rewards,
      startDate: _startDate,
      endDate: _endDate,
      startTime: startT,
      endTime: endT,
      daysOfWeek: _daysOfWeek,
    );

    await _repo.savePromotion(newP);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.promotion == null ? 'เพิ่มโปรโมชั่นใหม่' : 'แก้ไขโปรโมชั่น'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('บันทึก', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: Form(
        key: _formKey,
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
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'ชื่อโปรโมชั่น', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'กรุณากรอกชื่อ' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priorityCtrl,
                            decoration: const InputDecoration(labelText: 'Priority (สูง=คำนวณก่อน)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text('เฉพาะสมาชิก'),
                            value: _memberOnly,
                            onChanged: (v) => setState(() => _memberOnly = v ?? false),
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
                      initialValue: _conditionType,
                      decoration: const InputDecoration(labelText: 'ประเภทเงื่อนไข', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'min_spend', child: Text('ยอดซื้อรวมขั้นต่ำ')),
                        DropdownMenuItem(value: 'buy_items', child: Text('ซื้อสินค้าตามจำนวนที่กำหนด')),
                        DropdownMenuItem(value: 'target_products', child: Text('ลดราคาสินค้าเฉพาะรายการ (ไม่กำหนดยอด)')),
                      ],
                      onChanged: (v) => setState(() => _conditionType = v!),
                    ),
                    const SizedBox(height: 16),
                    if (_conditionType == 'min_spend')
                      TextFormField(
                        controller: _minSpendCtrl,
                        decoration: const InputDecoration(labelText: 'ยอดขั้นต่ำ (บาท)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    if (_conditionType == 'buy_items')
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () => _selectProducts(true),
                              icon: const Icon(Icons.search),
                              label: Text('เลือกสินค้า (${_conditionProductIds.length})'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _buyQtyCtrl,
                              decoration: const InputDecoration(labelText: 'จำนวน (ชิ้น)', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    if (_conditionType == 'target_products')
                      ElevatedButton.icon(
                        onPressed: () => _selectProducts(true),
                        icon: const Icon(Icons.list),
                        label: Text('เลือกสินค้าที่ร่วมรายการ (${_conditionProductIds.length} รายการ)'),
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
                      initialValue: _rewardType,
                      decoration: const InputDecoration(labelText: 'ประเภทส่วนลด', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'discount_amount', child: Text('ส่วนลด (บาท)')),
                        DropdownMenuItem(value: 'discount_percent', child: Text('ส่วนลด (%)')),
                        DropdownMenuItem(value: 'get_items', child: Text('แถมฟรีสินค้า')),
                      ],
                      onChanged: (v) => setState(() => _rewardType = v!),
                    ),
                    const SizedBox(height: 16),
                    if (_rewardType != 'get_items')
                      TextFormField(
                        controller: _rewardValCtrl,
                        decoration: const InputDecoration(labelText: 'มูลค่าส่วนลด', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    if (_rewardType == 'get_items')
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () => _selectProducts(false),
                              icon: const Icon(Icons.card_giftcard),
                              label: Text('เลือกสินค้าแถม (${_rewardProductIds.length})'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _rewardValCtrl,
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
                            subtitle: Text(_startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : 'ไม่ระบุ'),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final d = await showDatePicker(
                                  context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                              if (d != null) setState(() => _startDate = d);
                            },
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            title: const Text('ถึงวันที่'),
                            subtitle: Text(_endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : 'ไม่ระบุ'),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final d = await showDatePicker(
                                  context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                              if (d != null) setState(() => _endDate = d);
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
                            subtitle: Text(_startTime?.format(context) ?? 'ไม่ระบุ'),
                            trailing: const Icon(Icons.access_time),
                            onTap: () async {
                              final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                              if (t != null) setState(() => _startTime = t);
                            },
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            title: const Text('เวลาสิ้นสุด'),
                            subtitle: Text(_endTime?.format(context) ?? 'ไม่ระบุ'),
                            trailing: const Icon(Icons.access_time),
                            onTap: () async {
                              final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                              if (t != null) setState(() => _endTime = t);
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
                        final isSelected = _daysOfWeek.contains(dayVal);
                        return FilterChip(
                          label: Text(dayName),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _daysOfWeek.add(dayVal);
                              } else {
                                _daysOfWeek.remove(dayVal);
                              }
                            });
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
