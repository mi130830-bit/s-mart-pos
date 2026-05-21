import 'package:flutter/material.dart';
import 'debtor_styles.dart';

class DebtorTableHeader extends StatelessWidget {
  const DebtorTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2d9cdb),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: const Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              'ที่',
              style: headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'วันที่',
              style: headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'ลูกค้า',
              style: headerStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'บิลที่',
              style: headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'ยอดเต็ม',
              style: headerStyle,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'ชำระแล้ว',
              style: headerStyle,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'ค้างชำระ',
              style: headerStyle,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'จัดการ',
              style: headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
