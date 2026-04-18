import 'package:flutter/material.dart';
import '../../../models/product_component.dart';
import '../../../widgets/common/custom_text_field.dart';

class ComponentRow extends StatefulWidget {
  final ProductComponent component;
  final int index;
  final Function(double) onQuantityChanged;
  final VoidCallback onDelete;

  const ComponentRow({
    super.key,
    required this.component,
    required this.index,
    required this.onQuantityChanged,
    required this.onDelete,
  });

  @override
  State<ComponentRow> createState() => _ComponentRowState();
}

class _ComponentRowState extends State<ComponentRow> {
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    // Use formatted string to avoid .0 for integers if preferred, but standard toString is fine.
    // If it's 1.0, toString() gives "1.0".
    _qtyCtrl =
        TextEditingController(text: widget.component.quantity.toString());
  }

  @override
  void didUpdateWidget(covariant ComponentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update text if the value from parent is different from current text
    // This prevents overwriting "1." with "1.0" while typing
    double? currentVal = double.tryParse(_qtyCtrl.text);
    if (currentVal != widget.component.quantity) {
      // Avoid resetting if the difference is just formatting/precision,
      // but here we must sync if external change happened.
      // Since the parent only updates from THIS widget, we mostly assume sync.
      // But to be safe:
      if (widget.component.quantity != oldWidget.component.quantity) {
        _qtyCtrl.text = widget.component.quantity.toString();
        _qtyCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _qtyCtrl.text.length));
      }
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: widget.index % 2 == 0 ? Colors.white : Colors.grey[50],
      child: Row(
        children: [
          Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.component.childProductName ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              )),
          Expanded(
            flex: 2,
            child: Text('${widget.component.childProductCost}'),
          ),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48, // Slightly more height for full field
              child: CustomTextField(
                controller: _qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                onChanged: (val) {
                  final qty = double.tryParse(val);
                  if (qty != null) {
                    widget.onQuantityChanged(qty);
                  }
                },
              ),
            ),
          ),
          SizedBox(
            width: 40,
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
