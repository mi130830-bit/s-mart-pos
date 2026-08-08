import 'package:flutter/material.dart';
import '../../utils/date_range_helper.dart';

class QuickDateRangeSelector extends StatelessWidget {
  final DateTimeRange currentRange;
  final ValueChanged<DateTimeRange> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool compact;

  const QuickDateRangeSelector({
    super.key,
    required this.currentRange,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.compact = true,
  });

  Future<void> _select(BuildContext context, DateRangeType type) async {
    if (type != DateRangeType.custom) {
      onChanged(DateRangeHelper.getDateRange(type));
      return;
    }

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime.now(),
      initialDateRange: currentRange,
      initialEntryMode: DatePickerEntryMode.input,
      helpText: 'กำหนดช่วงวันที่',
      fieldStartLabelText: 'วันที่เริ่มต้น',
      fieldEndLabelText: 'วันที่สิ้นสุด',
      fieldStartHintText: 'วว/ดด/ปปปป',
      fieldEndHintText: 'วว/ดด/ปปปป',
      saveText: 'ใช้ช่วงนี้',
    );
    if (picked != null) onChanged(DateRangeHelper.normalize(picked));
  }

  @override
  Widget build(BuildContext context) {
    const types = [
      DateRangeType.today,
      DateRangeType.thisWeek,
      DateRangeType.thisMonth,
      DateRangeType.thisYear,
      DateRangeType.custom,
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: types.map((type) {
        final isCustom = type == DateRangeType.custom;
        return ActionChip(
          avatar: isCustom ? const Icon(Icons.date_range, size: 16) : null,
          label: Text(
            DateRangeHelper.getLabel(type),
            style: TextStyle(fontSize: compact ? 12 : 14),
          ),
          onPressed: () => _select(context, type),
        );
      }).toList(),
    );
  }
}
