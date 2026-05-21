import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:decimal/decimal.dart';
import '../../../models/order_item.dart';
import '../../../services/settings_service.dart';
import 'pos_cart_constants.dart';

class CartItemTile extends StatefulWidget {
  final int index;
  final OrderItem item;
  final Function(int) onEdit;
  final Function(int) onDelete;
  final Function(int, Decimal) onUpdateQuantity;
  final Function(int, Decimal) onUpdatePrice;
  final Function(int, Decimal)? onUpdateDiscount;

  const CartItemTile({
    super.key,
    required this.index,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onUpdateQuantity,
    required this.onUpdatePrice,
    this.onUpdateDiscount,
  });

  @override
  State<CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends State<CartItemTile> {
  late TextEditingController _qtyCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _discountCtrl;
  final FocusNode _qtyFocus = FocusNode();
  final FocusNode _priceFocus = FocusNode();
  final FocusNode _discountFocus = FocusNode();

  double _getDisplayDiscount(OrderItem item) {
    if (item.discount <= Decimal.zero) return 0.0;
    final String mode = SettingsService().itemDiscountMode;
    if (mode == 'per_piece' && item.quantity > Decimal.zero) {
      return (item.discount / item.quantity).toDouble();
    }
    return item.discount.toDouble();
  }

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
        text: NumberFormat('#.##').format(widget.item.quantity.toDouble()));
    _priceCtrl = TextEditingController(
        text: NumberFormat('#.##').format(widget.item.price.toDouble()));
    _discountCtrl = TextEditingController(
        text: NumberFormat('#.##').format(_getDisplayDiscount(widget.item)));
  }

  @override
  void didUpdateWidget(covariant CartItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_qtyFocus.hasFocus &&
        widget.item.quantity != oldWidget.item.quantity) {
      _qtyCtrl.text =
          NumberFormat('#.##').format(widget.item.quantity.toDouble());
    }
    if (!_priceFocus.hasFocus && widget.item.price != oldWidget.item.price) {
      _priceCtrl.text =
          NumberFormat('#.##').format(widget.item.price.toDouble());
    }
    if (!_discountFocus.hasFocus && widget.item.discount != oldWidget.item.discount) {
      _discountCtrl.text =
          NumberFormat('#.##').format(_getDisplayDiscount(widget.item));
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    _qtyFocus.dispose();
    _priceFocus.dispose();
    _discountFocus.dispose();
    super.dispose();
  }

  void _submitQty() {
    final val = Decimal.tryParse(_qtyCtrl.text);
    if (val != null) {
      widget.onUpdateQuantity(widget.index, val);
    } else {
      // Revert
      _qtyCtrl.text =
          NumberFormat('#.##').format(widget.item.quantity.toDouble());
    }
  }

  void _submitPrice() {
    final val = Decimal.tryParse(_priceCtrl.text);
    if (val != null) {
      widget.onUpdatePrice(widget.index, val);
    } else {
      // Revert
      _priceCtrl.text =
          NumberFormat('#.##').format(widget.item.price.toDouble());
    }
  }

  void _submitDiscount() {
    final val = Decimal.tryParse(_discountCtrl.text);
    if (val != null) {
      widget.onUpdateDiscount?.call(widget.index, val);
    } else {
      _discountCtrl.text =
          NumberFormat('#.##').format(_getDisplayDiscount(widget.item));
    }
  }

  void _incrementQty() {
    final current = Decimal.tryParse(_qtyCtrl.text) ?? widget.item.quantity;
    widget.onUpdateQuantity(widget.index, current + Decimal.fromInt(1));
  }

  void _decrementQty() {
    final current = Decimal.tryParse(_qtyCtrl.text) ?? widget.item.quantity;
    final newQty = current - Decimal.fromInt(1);
    if (newQty >= Decimal.fromInt(1)) {
      widget.onUpdateQuantity(widget.index, newQty);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => widget.onEdit(widget.index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Sequence
            SizedBox(
              width: PosCartConstants.colSequence,
              child: Text(
                '${widget.index + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
            // 1.5 Product Code (Barcode)
            Expanded(
              flex: PosCartConstants.flexCode,
              child: Text(
                widget.item.product?.barcode ?? widget.item.productId.toString(),
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 2. Item Name
            Expanded(
              flex: PosCartConstants.flexItem,
              child: Text.rich(
                TextSpan(
                  text: widget.item.productName,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyLarge?.color),
                  children: [
                    if (widget.item.comment.isNotEmpty)
                      TextSpan(
                        text: ' (${widget.item.comment})',
                        style: const TextStyle(
                            fontWeight: FontWeight.normal,
                            color: Colors.blueAccent,
                            fontSize: 14),
                      ),
                  ],
                ),
                softWrap: true,
              ),
            ),
            // 3. Quantity (Editable with +/-)
            Expanded(
              flex: PosCartConstants.flexQty,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Decrement Button
                  SizedBox(
                    width: 30, // Small button width
                    child: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _decrementQty,
                      tooltip: 'ลดจำนวน',
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Quantity Field
                  Padding(
                    padding: const EdgeInsets.only(
                        top:
                            3.0), // 👈 ปรับตำแหน่งกล่องขึ้น-ลง ตรงนี้ได้เลยครับ (Adjust Y position)
                    child: SizedBox(
                      width: 50, // Slightly reduced width for input to fit
                      height: 35,
                      child: TextField(
                        controller: _qtyCtrl,
                        focusNode: _qtyFocus,
                        textAlign: TextAlign.center,
                        textAlignVertical:
                            TextAlignVertical.center, // ✅ Fix floating text
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets
                              .zero, // ✅ Reset to zero for perfect center
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        onTap: () {
                          // ✅ Auto-select text on click
                          _qtyCtrl.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _qtyCtrl.text.length);
                        },
                        onSubmitted: (_) => _submitQty(),
                        onTapOutside: (_) {
                          if (_qtyFocus.hasFocus) {
                            _qtyFocus.unfocus();
                            _submitQty();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Increment Button
                  SizedBox(
                    width: 30, // Small button width
                    child: IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          color: Colors.green),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _incrementQty,
                      tooltip: 'เพิ่มจำนวน',
                    ),
                  ),
                ],
              ),
            ),
            // 4. Price (Editable)
            Expanded(
              flex: PosCartConstants.flexPrice,
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 70,
                  height: 35,
                  child: TextField(
                    controller: _priceCtrl,
                    focusNode: _priceFocus,
                    textAlign: TextAlign.right,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 4),
                      border:
                          OutlineInputBorder(), // Or InputBorder.none for cleaner look? User asked for "typing slot"
                      isDense: true,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    onTap: () {
                      // ✅ Auto-select text on click
                      _priceCtrl.selection = TextSelection(
                          baseOffset: 0, extentOffset: _priceCtrl.text.length);
                    },
                    onSubmitted: (_) => _submitPrice(),
                    onTapOutside: (_) {
                      if (_priceFocus.hasFocus) {
                        _priceFocus.unfocus();
                        _submitPrice();
                      }
                    },
                  ),
                ),
              ),
            ),
            // 4.5 Discount (Editable)
            Expanded(
              flex: PosCartConstants.flexDiscount,
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 55,
                  height: 35,
                  child: TextField(
                    controller: _discountCtrl,
                    focusNode: _discountFocus,
                    textAlign: TextAlign.right,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 4),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    onTap: () {
                      _discountCtrl.selection = TextSelection(
                          baseOffset: 0, extentOffset: _discountCtrl.text.length);
                    },
                    onSubmitted: (_) => _submitDiscount(),
                    onTapOutside: (_) {
                      if (_discountFocus.hasFocus) {
                        _discountFocus.unfocus();
                        _submitDiscount();
                      }
                    },
                  ),
                ),
              ),
            ),
            // 5. Total
            Expanded(
              flex: PosCartConstants.flexTotal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    NumberFormat('#,##0.00')
                        .format(widget.item.total.toDouble()),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  // Removed the small discount text because we now have a dedicated column
                ],
              ),
            ),
            // 6. Delete
            SizedBox(
              width: PosCartConstants.colAction,
              child: IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                onPressed: () => widget.onDelete(widget.index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            )
          ],
        ),
      ),
    );
  }
}
