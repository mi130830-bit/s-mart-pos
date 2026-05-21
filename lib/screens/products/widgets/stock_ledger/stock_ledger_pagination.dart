import 'package:flutter/material.dart';

class StockLedgerPagination extends StatelessWidget {
  final int currentPage;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool useShadow;

  const StockLedgerPagination({
    super.key,
    required this.currentPage,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
    this.useShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: hasPrevious ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          'หน้า $currentPage',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        IconButton(
          onPressed: hasNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );

    if (useShadow) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            )
          ],
        ),
        child: child,
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey[100],
      child: child,
    );
  }
}
