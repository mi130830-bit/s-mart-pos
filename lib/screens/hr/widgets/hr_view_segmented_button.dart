import 'package:flutter/material.dart';

class HrViewSegmentedButton extends StatelessWidget {
  final String selectedView;
  final void Function(String view) onSelectionChanged;

  const HrViewSegmentedButton({
    super.key,
    required this.selectedView,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'PENDING',
            icon: Icon(Icons.pending_actions),
            label: Text('รออนุมัติ'),
          ),
          ButtonSegment(
            value: 'ALL',
            icon: Icon(Icons.history),
            label: Text('ประวัติทั้งหมด'),
          ),
        ],
        selected: {selectedView},
        onSelectionChanged: (value) {
          onSelectionChanged(value.first);
        },
      ),
    );
  }
}
