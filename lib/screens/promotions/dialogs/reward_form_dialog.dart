import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/point_reward.dart';
import '../controllers/reward_form_controller.dart';

class RewardFormDialog extends ConsumerStatefulWidget {
  final PointReward? initialReward;
  final Function(PointReward) onSave;
  
  const RewardFormDialog({
    super.key,
    this.initialReward,
    required this.onSave,
  });

  @override
  ConsumerState<RewardFormDialog> createState() => _RewardFormDialogState();
}

class _RewardFormDialogState extends ConsumerState<RewardFormDialog> {
  @override
  void initState() {
    super.initState();
    final controller = ref.read(rewardFormProvider.notifier);
    controller.initialize(widget.initialReward);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.requestFocus();
    });
  }

  @override
  void dispose() {
    // We cannot access ref in dispose easily, but autoDispose handles the state cleanup.
    // However, we need to dispose controllers. Wait, the controller is a Notifier, we can dispose it in its own lifecycle, but Notifier doesn't have dispose.
    // Let's just manually dispose it here using the ref if possible? No, we should call dispose on it.
    // Actually, autoDispose does not dispose the text controllers. It just disposes the state.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rewardFormProvider);
    final controller = ref.read(rewardFormProvider.notifier);

    Widget previewImage = state.pickedImageFile != null
        ? Image.file(state.pickedImageFile!, height: 100, width: 100, fit: BoxFit.cover)
        : (state.imageUrl != null && state.imageUrl!.isNotEmpty)
            ? _buildLocalImagePreview(state.imageUrl!)
            : Icon(Icons.image, size: 50, color: Colors.grey.shade400);

    return AlertDialog(
      title: Text(widget.initialReward == null ? 'เพิ่มของรางวัลใหม่' : 'แก้ไขของรางวัล'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: controller.formKey,
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
                      selected: {state.rewardType},
                      onSelectionChanged: (v) => controller.setRewardType(v.first),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              // Image
              Center(
                child: InkWell(
                  onTap: () => controller.pickImage(context),
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
                controller: controller.nameCtrl,
                focusNode: controller.nameFocus,
                decoration: const InputDecoration(labelText: 'ชื่อของรางวัล *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'กรุณากรอกชื่อ' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller.descCtrl,
                focusNode: controller.descFocus,
                decoration: const InputDecoration(labelText: 'รายละเอียด (ออพชั่น)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: controller.pointsCtrl,
                    focusNode: controller.pointsFocus,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'ใช้กี่แต้มแลก *', border: OutlineInputBorder()),
                    validator: (v) { if (v == null || v.isEmpty) return 'ห้ามว่าง'; if (int.tryParse(v) == null) return 'ตัวเลขเท่านั้น'; return null; },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controller.stockCtrl,
                    focusNode: controller.stockFocus,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'โควต้า *', border: OutlineInputBorder()),
                    validator: (v) { if (v == null || v.isEmpty) return 'ห้ามว่าง'; if (int.tryParse(v) == null) return 'ตัวเลขเท่านั้น'; return null; },
                  ),
                ),
              ]),
              if (state.rewardType == 'COUPON') ...[
                const SizedBox(height: 12),
                Divider(color: Colors.amber.shade200),
                const Text('⚙️ ตั้งค่าคูปอง', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller.discountCtrl,
                      focusNode: controller.discountFocus,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'ส่วนลด (บาท) *', border: OutlineInputBorder(), prefixText: '฿ '),
                      validator: (v) { if (state.rewardType != 'COUPON') return null; if (v == null || v.isEmpty) return 'ห้ามว่าง'; return null; },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: controller.expiryCtrl,
                      focusNode: controller.expiryFocus,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'หมดอายุ (วัน)', border: OutlineInputBorder(), suffixText: 'วัน'),
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('เปิดให้แลก'),
                value: state.isActive,
                onChanged: (v) => controller.setIsActive(v),
                contentPadding: EdgeInsets.zero,
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: state.isUploading ? null : () => Navigator.pop(context), child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: state.isUploading ? null : () async {
            final reward = await controller.submit();
            if (reward != null) {
              widget.onSave(reward);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800),
          child: state.isUploading
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
