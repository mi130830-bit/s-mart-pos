import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/stock_adjustment_controller.dart';

class AdjustmentItemList extends ConsumerWidget {
  const AdjustmentItemList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockAdjustmentProvider);
    final controller = ref.read(stockAdjustmentProvider.notifier);
    final pendingItems = state.pendingItems;

    if (pendingItems.isEmpty) {
      return const Center(
        child: Text('ยังไม่มีรายการที่เช็ค',
            style: TextStyle(fontSize: 18, color: Colors.grey)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: pendingItems.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final item = pendingItems[index];
        final diff = item.diff;
        final isMerch = diff == 0;
        final isOver = diff > 0;

        Color cardColor = Colors.white;
        if (isOver) {
          cardColor = Colors.green.shade50;
        } else if (!isMerch) {
          cardColor = Colors.red.shade50; // Short
        }

        return Card(
          color: cardColor,
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Product Info
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (item.note.isNotEmpty)
                        Text('Note: ${item.note}',
                            style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                // Stats
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('System',
                          item.systemQty.toStringAsFixed(0), Colors.black),
                      const Icon(Icons.arrow_forward, color: Colors.grey),
                      _buildStatColumn(
                          'Counted',
                          item.countedQty.toStringAsFixed(0),
                          Colors.blue.shade800),
                      _buildStatColumn(
                          'Diff',
                          '${diff > 0 ? "+" : ""}${diff.toStringAsFixed(0)}',
                          isMerch
                              ? Colors.grey
                              : (isOver ? Colors.green : Colors.red)),
                    ],
                  ),
                ),
                // Delete
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => controller.removePendingItem(index),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
