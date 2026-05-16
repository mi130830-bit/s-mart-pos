import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/customer.dart';

/// Dialog ให้แคชเชียร์เลือกจำนวนแต้มที่จะแลกเป็นส่วนลด
class PointRedemptionDialog extends StatefulWidget {
  final Customer customer;
  final double grandTotal; // ยอดก่อนหักแต้ม
  final double pointRedemptionRate; // กี่แต้ม = 1 บาท (เช่น 10)
  final int currentPointsUsed; // แต้มที่เลือกไว้แล้ว (0 ถ้าเพิ่งเปิด)

  const PointRedemptionDialog({
    super.key,
    required this.customer,
    required this.grandTotal,
    required this.pointRedemptionRate,
    this.currentPointsUsed = 0,
  });

  @override
  State<PointRedemptionDialog> createState() => _PointRedemptionDialogState();
}

class _PointRedemptionDialogState extends State<PointRedemptionDialog> {
  late TextEditingController _pointsCtrl;
  int _pointsToUse = 0;

  // จำนวนแต้มสูงสุดที่ใช้ได้ — ไม่เกิน currentPoints และไม่เกิน grandTotal*rate
  int get _maxRedeemable {
    if (widget.pointRedemptionRate <= 0) return 0;
    final maxByAmount = (widget.grandTotal * widget.pointRedemptionRate).floor();
    return widget.customer.currentPoints < maxByAmount
        ? widget.customer.currentPoints
        : maxByAmount;
  }

  double get _discountAmount =>
      widget.pointRedemptionRate > 0 ? _pointsToUse / widget.pointRedemptionRate : 0;

  @override
  void initState() {
    super.initState();
    _pointsToUse = widget.currentPointsUsed.clamp(0, _maxRedeemable);
    _pointsCtrl = TextEditingController(
        text: _pointsToUse > 0 ? _pointsToUse.toString() : '');
  }

  @override
  void dispose() {
    _pointsCtrl.dispose();
    super.dispose();
  }

  void _useMax() {
    setState(() {
      _pointsToUse = _maxRedeemable;
      _pointsCtrl.text = _pointsToUse.toString();
      _pointsCtrl.selection =
          TextSelection(baseOffset: 0, extentOffset: _pointsCtrl.text.length);
    });
  }

  void _clearPoints() {
    setState(() {
      _pointsToUse = 0;
      _pointsCtrl.text = '';
    });
  }

  void _onChanged(String val) {
    final parsed = int.tryParse(val) ?? 0;
    setState(() {
      _pointsToUse = parsed.clamp(0, _maxRedeemable);
      // ถ้า input เกิน max ให้ clamp แต่ไม่แก้ text ระหว่างพิมพ์
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    final fmtMoney = NumberFormat('#,##0.00');
    final hasPoints = widget.customer.currentPoints > 0;
    final canRedeem = _maxRedeemable > 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 28),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('แลกคะแนนสะสม',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('ใช้แต้มเพื่อรับส่วนลด',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
      ]),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── ข้อมูลลูกค้า ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200)),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.customer.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('รหัส: ${widget.customer.memberCode}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(fmt.format(widget.customer.currentPoints),
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber)),
                      const Text('คะแนน',
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── อัตราแลก + ยอดที่ใช้ได้ ──────────────────
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    label: 'อัตราแลก',
                    value: '${fmt.format(widget.pointRedemptionRate.toInt())} แต้ม / 1 ฿',
                    icon: Icons.swap_horiz,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoTile(
                    label: 'ใช้ได้สูงสุด',
                    value: '${fmt.format(_maxRedeemable)} แต้ม',
                    icon: Icons.star_border,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Input ──────────────────────────────────────
            if (!hasPoints || !canRedeem) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        !hasPoints
                            ? 'ลูกค้าไม่มีคะแนนสะสม'
                            : 'คะแนนไม่เพียงพอสำหรับการแลก',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pointsCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'จำนวนแต้มที่ต้องการใช้',
                        suffixText: 'แต้ม',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.amber, width: 2),
                        ),
                      ),
                      onChanged: _onChanged,
                      onSubmitted: (_) => _confirm(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _useMax,
                    icon: const Icon(Icons.star, size: 18),
                    label: const Text('MAX'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── ผลการคำนวณ ─────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _pointsToUse > 0
                      ? Colors.green.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _pointsToUse > 0
                          ? Colors.green.shade300
                          : Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ใช้ ${fmt.format(_pointsToUse)} แต้ม',
                            style: TextStyle(
                                color: Colors.grey.shade700, fontSize: 14)),
                        const Text('ส่วนลดที่ได้รับ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    Text(
                      '- ฿${fmtMoney.format(_discountAmount)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color:
                            _pointsToUse > 0 ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_pointsToUse > 0)
          TextButton.icon(
            onPressed: _clearPoints,
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('ยกเลิกแต้ม'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, 0),
          child: const Text('ปิด'),
        ),
        ElevatedButton.icon(
          onPressed: canRedeem && hasPoints ? _confirm : null,
          icon: const Icon(Icons.check),
          label: Text(_pointsToUse > 0
              ? 'ยืนยัน (ลด ฿${NumberFormat('#,##0.00').format(_discountAmount)})'
              : 'ยืนยัน'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade700,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  void _confirm() {
    if (_pointsToUse < 0) return;
    Navigator.pop(context, _pointsToUse);
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
