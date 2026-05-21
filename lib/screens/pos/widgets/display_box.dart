import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DisplayBox extends StatelessWidget {
  final String label;
  final double val;
  final Color color;
  final bool isHighlight;
  final double fontSize;
  final IconData? icon;

  const DisplayBox({
    super.key,
    required this.label,
    required this.val,
    required this.color,
    this.isHighlight = false,
    this.fontSize = 24,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 5),
                Icon(icon, size: 16, color: Colors.grey),
              ],
            ],
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                NumberFormat.currency(symbol: '฿', locale: 'th_TH').format(val),
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
