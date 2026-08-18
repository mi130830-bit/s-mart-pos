import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../widgets/common/custom_text_field.dart';
import '../../models/stock_in_item.dart';

class StockInTableRow extends StatefulWidget {
  final StockInItem item;
  final int index;
  final String unitName;
  final String poStatus;
  final TextEditingController qtyCtrl;
  final TextEditingController costCtrl;
  final TextEditingController retailCtrl;
  final TextEditingController totalCtrl;
  final int vatType;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onQtyChanged;
  final ValueChanged<String> onCostChanged;
  final ValueChanged<String> onRetailChanged;
  final ValueChanged<String> onTotalChanged;

  const StockInTableRow({
    super.key,
    required this.item,
    required this.index,
    required this.unitName,
    required this.poStatus,
    required this.qtyCtrl,
    required this.costCtrl,
    required this.retailCtrl,
    required this.totalCtrl,
    required this.vatType,
    required this.onEdit,
    required this.onDelete,
    required this.onQtyChanged,
    required this.onCostChanged,
    required this.onRetailChanged,
    required this.onTotalChanged,
  });

  @override
  State<StockInTableRow> createState() => _StockInTableRowState();
}

class _StockInTableRowState extends State<StockInTableRow> {
  late FocusNode _qtyFocusNode;
  late FocusNode _costFocusNode;
  late FocusNode _retailFocusNode;

  @override
  void initState() {
    super.initState();
    _qtyFocusNode = FocusNode();
    _costFocusNode = FocusNode();
    _retailFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _qtyFocusNode.dispose();
    _costFocusNode.dispose();
    _retailFocusNode.dispose();
    super.dispose();
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
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey),
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
              child: (widget.item.receivedQuantity > 0 &&
                      widget.poStatus != 'RECEIVED')
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
                      controller: widget.qtyCtrl,
                      focusNode: _qtyFocusNode,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      onChanged: (val) {
                        setState(() {
                          widget.item.quantity =
                              double.tryParse(val.replaceAll(',', '')) ?? 0.0;
                        });
                        widget.onQtyChanged(val);
                      },
                      onSubmitted: (_) {
                        widget.onQtyChanged(widget.qtyCtrl.text);
                      },
                      selectAllOnFocus: true,
                      enabled: widget.poStatus == 'NEW' ||
                          widget.poStatus == 'DRAFT' ||
                          widget.poStatus ==
                              'RECEIVED', // Enable edit if NEW, DRAFT, or RECEIVED (editing mode)
                    ),
            ),
          ),
          Expanded(
              flex: 1,
              child: Text(widget.unitName, textAlign: TextAlign.center)),
          Expanded(
            flex: 2,
            child: Transform.translate(
              offset: const Offset(0, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: widget.costCtrl,
                          focusNode: _costFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          onChanged: (val) {
                            setState(() {
                              widget.item.costPrice =
                                  double.tryParse(val.replaceAll(',', '')) ??
                                      0.0;
                            });
                            widget.onCostChanged(val);
                          },
                          onSubmitted: (_) {
                            widget.onCostChanged(widget.costCtrl.text);
                          },
                          selectAllOnFocus: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ราคาแนะนำ: ${NumberFormat('#,##0.00').format(widget.item.costPrice * (widget.vatType == 2 ? 1.3 : 1.391))} (ทุน × ${widget.vatType == 2 ? '1.3' : '1.391'})',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: CustomTextField(
                controller: widget.retailCtrl,
                focusNode: _retailFocusNode,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                onChanged: widget.onRetailChanged,
                onSubmitted: (_) =>
                    widget.onRetailChanged(widget.retailCtrl.text),
                selectAllOnFocus: true,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: CustomTextField(
                controller: widget.totalCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.indigo,
                ),
                onChanged: widget.onTotalChanged,
                onSubmitted: (_) =>
                    widget.onTotalChanged(widget.totalCtrl.text),
                selectAllOnFocus: true,
              ),
            ),
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
