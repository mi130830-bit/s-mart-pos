import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../models/point_reward.dart';
import '../../repositories/reward_repository.dart';

class RewardManagementScreen extends StatefulWidget {
  const RewardManagementScreen({super.key});

  @override
  State<RewardManagementScreen> createState() => _RewardManagementScreenState();
}

class _RewardManagementScreenState extends State<RewardManagementScreen>
    with SingleTickerProviderStateMixin {
  final RewardRepository _repository = RewardRepository();
  List<PointReward> _rewards = [];
  List<RedemptionRecord> _redemptions = [];
  bool _isLoading = true;
  late TabController _tabController;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index == 1 || _tabController.index == 2) {
        _loadRedemptions();
      } else {
        _loadRewards();
      }
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadRewards();
    await _loadRedemptions();
  }

  Future<void> _loadRewards() async {
    setState(() => _isLoading = true);
    final data = await _repository.getAllRewards();
    setState(() {
      _rewards = data;
      _isLoading = false;
    });
  }

  Future<void> _loadRedemptions() async {
    final data = await _repository.getRedemptionList();
    setState(() {
      _redemptions = data;
      _pendingCount = data.where((r) => r.isPending && !r.isCoupon).length;
    });
  }

  void _showRewardForm({PointReward? reward}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => RewardFormDialog(
        initialReward: reward,
        onSave: (savedReward) async {
          final success = await _repository.saveReward(savedReward);
          if (success) {
            _loadRewards();
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ บันทึกของรางวัลสำเร็จ'), backgroundColor: Colors.green),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('❌ เกิดข้อผิดพลาดในการบันทึก'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteReward(PointReward reward) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('คุณต้องการลบ "${reward.name}" ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบข้อมูล', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final success = await _repository.deleteReward(reward.id);
      if (success && mounted) {
        _loadRewards();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ ลบข้อมูลเรียบร้อย'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _fulfillRedemption(RedemptionRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('✅ ยืนยันการให้ของรางวัล'),
        content: Text('ยืนยันว่าได้มอบ "${record.rewardName}" ให้กับคุณ ${record.customerName} แล้วหรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน ✅', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await _repository.fulfillRedemption(record.id);
      if (ok && mounted) {
        _loadRedemptions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ บันทึกการให้ของรางวัลเรียบร้อย'), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('จัดการของรางวัล'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll, tooltip: 'รีเฟรช'),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            const Tab(icon: Icon(Icons.card_giftcard), text: 'แค็ตตาล็อก'),
            Tab(
              icon: Badge(
                isLabelVisible: _pendingCount > 0,
                label: Text('$_pendingCount'),
                child: const Icon(Icons.inbox),
              ),
              text: 'รอจัดส่ง',
            ),
            const Tab(icon: Icon(Icons.history), text: 'ประวัติทั้งหมด'),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (_, __) => _tabController.index == 0
            ? FloatingActionButton.extended(
                onPressed: () => _showRewardForm(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('เพิ่มของรางวัล', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.blue.shade800,
              )
            : const SizedBox.shrink(),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Catalog
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _rewards.isEmpty
                  ? _buildEmptyState()
                  : _buildGridView(),

          // Tab 2: Pending (GIFT only)
          _buildPendingTab(),

          // Tab 3: All History
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.card_giftcard, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('ยังไม่มีของรางวัลในระบบ', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          const Text('กดเพิ่มของรางวัลด้านล่างขวาเพื่อเริ่มต้น', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, childAspectRatio: 0.8, crossAxisSpacing: 16, mainAxisSpacing: 16,
        ),
        itemCount: _rewards.length,
        itemBuilder: (context, index) {
          final reward = _rewards[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showRewardForm(reward: reward),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (reward.imageUrl != null && reward.imageUrl!.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: _buildLocalImage(reward.imageUrl!),
                            )
                          else
                            Icon(Icons.image_not_supported, size: 40, color: Colors.grey.shade400),
                          if (!reward.isActive)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                ),
                                child: const Center(child: Text('ปิดใช้งาน', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                              ),
                            ),
                          if (reward.isCoupon)
                            Positioned(
                              bottom: 6, left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('🎟️ คูปอง ฿${reward.discountValue.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          Positioned(
                            top: 8, right: 8,
                            child: Row(children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.white.withValues(alpha: 0.9),
                                child: IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.edit, size: 16, color: Colors.blue), onPressed: () => _showRewardForm(reward: reward)),
                              ),
                              const SizedBox(width: 4),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.white.withValues(alpha: 0.9),
                                child: IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.delete, size: 16, color: Colors.red), onPressed: () => _deleteReward(reward)),
                              ),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reward.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('คงเหลือ: ${reward.stockQuantity} ชิ้น', style: TextStyle(color: reward.stockQuantity > 0 ? Colors.green.shade700 : Colors.red, fontSize: 13)),
                          const Spacer(),
                          Row(children: [
                            Icon(Icons.stars, size: 18, color: Colors.amber.shade700),
                            const SizedBox(width: 4),
                            Text('${reward.pointPrice} แต้ม', style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold, fontSize: 15)),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPendingTab() {
    final pending = _redemptions.where((r) => r.isPending && !r.isCoupon).toList();
    if (pending.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
          const SizedBox(height: 16),
          Text('ไม่มีรายการที่รอจัดส่ง 🎉', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          const Text('ทุกรายการจัดส่งเรียบร้อยแล้ว', style: TextStyle(color: Colors.grey)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadRedemptions,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final r = pending[i];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.card_giftcard, color: Colors.amber.shade700),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.rewardName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${r.customerName} ${r.phone != null ? '(${r.phone})' : ''}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    Text(DateFormat('dd/MM/yyyy HH:mm').format(r.redeemedAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ),
                const SizedBox(width: 12),
                Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade300)),
                    child: Text('${r.pointsUsed} แต้ม', style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _fulfillRedemption(r),
                    icon: const Icon(Icons.check, size: 16, color: Colors.white),
                    label: const Text('ให้ของแล้ว', style: TextStyle(color: Colors.white, fontSize: 13)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                  ),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_redemptions.isEmpty) {
      return const Center(child: Text('ยังไม่มีประวัติการแลกรางวัล', style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _loadRedemptions,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: DataTable(
          columnSpacing: 12,
          headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
          columns: const [
            DataColumn(label: Text('ลูกค้า', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('ของรางวัล', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('แต้ม', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('ประเภท', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('วันที่', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('สถานะ', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _redemptions.map((r) {
            final statusWidget = r.isCoupon
                ? _statusChip(r.status == 'FULFILLED' ? 'ใช้แล้ว' : 'รอใช้', r.status == 'FULFILLED' ? Colors.grey : Colors.blue)
                : _statusChip(r.isFulfilled ? 'จัดส่งแล้ว' : 'รอจัดส่ง', r.isFulfilled ? Colors.green : Colors.orange);
            return DataRow(cells: [
              DataCell(Text('${r.customerName}\n${r.phone ?? ''}', style: const TextStyle(fontSize: 12))),
              DataCell(Text(r.rewardName, style: const TextStyle(fontSize: 12))),
              DataCell(Text('${r.pointsUsed}', style: const TextStyle(fontSize: 12))),
              DataCell(r.isCoupon
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🎟️ ', style: TextStyle(fontSize: 14)),
                      Text('ลด ฿${r.discountValue?.toStringAsFixed(0) ?? '-'}', style: const TextStyle(fontSize: 12)),
                    ])
                  : const Text('🎁 ของรางวัล', style: TextStyle(fontSize: 12))),
              DataCell(Text(DateFormat('dd/MM/yy HH:mm').format(r.redeemedAt), style: const TextStyle(fontSize: 12))),
              DataCell(statusWidget),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildLocalImage(String relativeUrl) {
    final fileName = relativeUrl.split('/').last;
    final String baseDir = Directory.current.path;
    final String localPath = '$baseDir\\backend\\public\\rewards\\$fileName';
    final file = File(localPath);
    if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
    return Icon(Icons.broken_image, size: 40, color: Colors.grey.shade400);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class RewardFormDialog extends StatefulWidget {
  final PointReward? initialReward;
  final Function(PointReward) onSave;
  const RewardFormDialog({super.key, this.initialReward, required this.onSave});

  @override
  State<RewardFormDialog> createState() => _RewardFormDialogState();
}

class _RewardFormDialogState extends State<RewardFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl, _descCtrl, _pointsCtrl, _stockCtrl, _discountCtrl, _expiryCtrl;
  
  // ✅ FIX: Explicit FocusNodes to prevent SegmentedButton from stealing Backspace/Arrow keys
  late FocusNode _nameFocus, _descFocus, _pointsFocus, _stockFocus, _discountFocus, _expiryFocus;

  bool _isActive = true;
  String? _imageUrl;
  bool _isUploading = false;
  File? _pickedImageFile;
  String _rewardType = 'GIFT';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialReward?.name ?? '');
    _descCtrl = TextEditingController(text: widget.initialReward?.description ?? '');
    _pointsCtrl = TextEditingController(text: (widget.initialReward?.pointPrice ?? 0).toString());
    _stockCtrl = TextEditingController(text: (widget.initialReward?.stockQuantity ?? 1).toString());
    _discountCtrl = TextEditingController(text: (widget.initialReward?.discountValue ?? 50).toString());
    _expiryCtrl = TextEditingController(text: (widget.initialReward?.couponExpiryDays ?? 30).toString());
    
    _nameFocus = FocusNode();
    _descFocus = FocusNode();
    _pointsFocus = FocusNode();
    _stockFocus = FocusNode();
    _discountFocus = FocusNode();
    _expiryFocus = FocusNode();

    _isActive = widget.initialReward?.isActive ?? true;
    _imageUrl = widget.initialReward?.imageUrl;
    _rewardType = widget.initialReward?.rewardType ?? 'GIFT';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); _pointsCtrl.dispose();
    _stockCtrl.dispose(); _discountCtrl.dispose(); _expiryCtrl.dispose();
    
    _nameFocus.dispose(); _descFocus.dispose(); _pointsFocus.dispose();
    _stockFocus.dispose(); _discountFocus.dispose(); _expiryFocus.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
      if (result != null && result.files.single.path != null) {
        setState(() => _pickedImageFile = File(result.files.single.path!));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ไม่สามารถเลือกรูปภาพได้: $e')));
    }
  }

  Future<String?> _uploadImage(File file) async {
    try {
      final String baseDir = Directory.current.path;
      final String targetDirPath = '$baseDir\\backend\\public\\rewards';
      final dir = Directory(targetDirPath);
      if (!await dir.exists()) await dir.create(recursive: true);
      final ext = file.path.contains('.') ? '.${file.path.split('.').last}' : '.png';
      final uniqueName = 'reward_${DateTime.now().millisecondsSinceEpoch}$ext';
      await file.copy('$targetDirPath\\$uniqueName');
      return '/rewards/$uniqueName';
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isUploading = true);
      String? finalImageUrl = _imageUrl;
      if (_pickedImageFile != null) {
        finalImageUrl = await _uploadImage(_pickedImageFile!);
      }
      setState(() => _isUploading = false);
      final reward = PointReward(
        id: widget.initialReward?.id ?? 0,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        pointPrice: int.tryParse(_pointsCtrl.text) ?? 0,
        stockQuantity: int.tryParse(_stockCtrl.text) ?? 0,
        imageUrl: finalImageUrl,
        isActive: _isActive,
        rewardType: _rewardType,
        discountValue: double.tryParse(_discountCtrl.text) ?? 0,
        couponExpiryDays: int.tryParse(_expiryCtrl.text) ?? 30,
      );
      widget.onSave(reward);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget previewImage = _pickedImageFile != null
        ? Image.file(_pickedImageFile!, height: 100, width: 100, fit: BoxFit.cover)
        : (_imageUrl != null && _imageUrl!.isNotEmpty)
            ? _buildLocalImagePreview(_imageUrl!)
            : Icon(Icons.image, size: 50, color: Colors.grey.shade400);

    return AlertDialog(
      title: Text(widget.initialReward == null ? 'เพิ่มของรางวัลใหม่' : 'แก้ไขของรางวัล'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Type Toggle
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('ประเภทรางวัล', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'GIFT', label: Text('🎁 ของรางวัล'), icon: Icon(Icons.card_giftcard)),
                        ButtonSegment(value: 'COUPON', label: Text('🎟️ คูปองส่วนลด'), icon: Icon(Icons.discount)),
                      ],
                      selected: {_rewardType},
                      onSelectionChanged: (v) => setState(() => _rewardType = v.first),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              // Image
              Center(
                child: InkWell(
                  onTap: _pickImage,
                  child: Container(
                    height: 100, width: 100,
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300, width: 2), borderRadius: BorderRadius.circular(10)),
                    child: ClipRRect(borderRadius: BorderRadius.circular(8), child: previewImage),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(child: Text('คลิกเพื่อเปลี่ยนรูป', style: TextStyle(color: Colors.blue, fontSize: 12))),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                focusNode: _nameFocus, // ✅ Fix Focus
                decoration: const InputDecoration(labelText: 'ชื่อของรางวัล *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'กรุณากรอกชื่อ' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                focusNode: _descFocus, // ✅ Fix Focus
                decoration: const InputDecoration(labelText: 'รายละเอียด (ออพชั่น)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _pointsCtrl,
                    focusNode: _pointsFocus, // ✅ Fix Focus
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'ใช้กี่แต้มแลก *', border: OutlineInputBorder()),
                    validator: (v) { if (v == null || v.isEmpty) return 'ห้ามว่าง'; if (int.tryParse(v) == null) return 'ตัวเลขเท่านั้น'; return null; },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stockCtrl,
                    focusNode: _stockFocus, // ✅ Fix Focus
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'โควต้า *', border: OutlineInputBorder()),
                    validator: (v) { if (v == null || v.isEmpty) return 'ห้ามว่าง'; if (int.tryParse(v) == null) return 'ตัวเลขเท่านั้น'; return null; },
                  ),
                ),
              ]),
              if (_rewardType == 'COUPON') ...[
                const SizedBox(height: 12),
                Divider(color: Colors.amber.shade200),
                const Text('⚙️ ตั้งค่าคูปอง', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _discountCtrl,
                      focusNode: _discountFocus, // ✅ Fix Focus
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'ส่วนลด (บาท) *', border: OutlineInputBorder(), prefixText: '฿ '),
                      validator: (v) { if (_rewardType != 'COUPON') return null; if (v == null || v.isEmpty) return 'ห้ามว่าง'; return null; },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _expiryCtrl,
                      focusNode: _expiryFocus, // ✅ Fix Focus
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'หมดอายุ (วัน)', border: OutlineInputBorder(), suffixText: 'วัน'),
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('เปิดให้แลก'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                contentPadding: EdgeInsets.zero,
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isUploading ? null : () => Navigator.pop(context), child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: _isUploading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800),
          child: _isUploading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('บันทึกข้อมูล', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildLocalImagePreview(String relativeUrl) {
    final fileName = relativeUrl.split('/').last;
    final String baseDir = Directory.current.path;
    final String localPath = '$baseDir\\backend\\public\\rewards\\$fileName';
    final file = File(localPath);
    if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
    return Icon(Icons.broken_image, size: 30, color: Colors.grey.shade400);
  }
}
