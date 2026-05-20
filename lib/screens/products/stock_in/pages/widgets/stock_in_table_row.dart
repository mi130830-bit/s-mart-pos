import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../widgets/common/custom_text_field.dart';
import '../../models/stock_in_item.dart';

// ✅ Task 1: Refactored StockInTableRow to StatefulWidget to manage local TextField edits 
// without triggering full parent page rebuilds, preventing cursor jump and lag.
class StockInTableRow extends StatefulWidget {
  final StockInItem item;
  final int index;
  final String unitName;
  final String poStatus;
  final VoidCallback onEdit;
  final VoidCallback onCalculate;
  final VoidCallback onDelete;
  final VoidCallback onTotalChanged; // Notify parent to update grand totals

  const StockInTableRow({
    super.key,
    required this.item,
    required this.index,
    required this.unitName,
    required this.poStatus,
    required this.onEdit,
    required this.onCalculate,
    required this.onDelete,
    required this.onTotalChanged,
  });

  @override
  State<StockInTableRow> createState() => _StockInTableRowState();
}

class _StockInTableRowState extends State<StockInTableRow> {
  late FocusNode _qtyFocusNode;
  late FocusNode _costFocusNode;
  bool _qtyWasFocused = false;
  bool _costWasFocused = false;

  @override
  void initState() {
    super.initState();
    _qtyFocusNode = FocusNode();
    _costFocusNode = FocusNode();

    _qtyFocusNode.addListener(_onFocusChange);
    _costFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _qtyFocusNode.removeListener(_onFocusChange);
    _costFocusNode.removeListener(_onFocusChange);
    _qtyFocusNode.dispose();
    _costFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Notify parent ONLY when a textfield loses focus to recalculate grand total.
    if (_qtyWasFocused && !_qtyFocusNode.hasFocus) {
      widget.onTotalChanged();
    }
    if (_costWasFocused && !_costFocusNode.hasFocus) {
      widget.onTotalChanged();
    }
    _qtyWasFocused = _qtyFocusNode.hasFocus;
    _costWasFocused = _costFocusNode.hasFocus;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.index % 2 == 0
            ? Colors.white
            : Colors.indigo.withValues(alpha: 0.05),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text('${widget.index + 1}')),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.item.product.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // ✏️ Edit Product Button
                    InkWell(
                      onTap: widget.onEdit,
                      child: const Icon(Icons.edit_note,
                          color: Colors.blue, size: 20),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.item.product.barcode ?? '-',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '| ขาย: ${NumberFormat('#,##0.00').format(widget.item.product.retailPrice)}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.green,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: (widget.item.receivedQuantity > 0 && widget.poStatus != 'RECEIVED')
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${NumberFormat('#,##0.##').format(widget.item.receivedQuantity)} / ${NumberFormat('#,##0.##').format(widget.item.quantity)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Text(
                          '(รับแล้ว)',
                          style: TextStyle(fontSize: 10, color: Colors.green),
                        )
                      ],
                    )
                  : CustomTextField(
                      controller: widget.item.qtyCtrl,
                      focusNode: _qtyFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      onChanged: (val) {
                        setState(() {
                          widget.item.quantity = double.tryParse(val) ?? 0.0;
                        });
                      },
                      onSubmitted: (_) {
                        widget.onTotalChanged();
                      },
                      selectAllOnFocus: true,
                      enabled: widget.poStatus == 'NEW' ||
                          widget.poStatus == 'DRAFT' ||
                          widget.poStatus == 'RECEIVED', // Enable edit if NEW, DRAFT, or RECEIVED (editing mode)
                    ),
            ),
          ),
          Expanded(flex: 1, child: Text(widget.unitName, textAlign: TextAlign.center)),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: widget.item.costCtrl,
                    focusNode: _costFocusNode,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    onChanged: (val) {
                      setState(() {
                        widget.item.costPrice = double.tryParse(val) ?? 0.0;
                      });
                    },
                    onSubmitted: (_) {
                      widget.onTotalChanged();
                    },
                    selectAllOnFocus: true,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calculate,
                      color: Colors.blue, size: 24),
                  onPressed: widget.onCalculate,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(NumberFormat('#,##0.00').format(widget.item.total),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.indigo)),
          ),
          SizedBox(
            width: 50,
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: widget.onDelete,
            ),
          ),
        ],
      ),
    );
  }
}
