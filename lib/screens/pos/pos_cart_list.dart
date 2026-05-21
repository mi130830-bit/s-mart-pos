import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart'; // ✅ Added Decimal import
import '../../models/order_item.dart';
import 'widgets/cart_item_tile.dart';
import 'widgets/pos_cart_constants.dart';
class PosCartList extends StatefulWidget {
  final List<OrderItem> items;
  final Function(int) onEdit;
  final Function(int) onDelete;
  final Function(int index, Decimal newQty) onUpdateQuantity;
  final Function(int index, Decimal newPrice) onUpdatePrice;
  final Function(int index, Decimal newDiscount)? onUpdateDiscount; // ✅ Added

  const PosCartList({
    super.key,
    required this.items,
    required this.onEdit,
    required this.onDelete,
    required this.onUpdateQuantity,
    required this.onUpdatePrice,
    this.onUpdateDiscount, // ✅ Added
  });

  @override
  State<PosCartList> createState() => _PosCartListState();
}

class _PosCartListState extends State<PosCartList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant PosCartList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If a new item is added, scroll to the bottom.
    if (widget.items.length > oldWidget.items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.grey[800] 
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: const Row(children: [
            SizedBox(
                width: PosCartConstants.colSequence,
                child: Text('ลำดับ',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(
                flex: PosCartConstants.flexCode,
                child: Text(' รหัสสินค้า',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(
                flex: PosCartConstants.flexItem,
                child: Text(' รายการสินค้า',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(
                flex: PosCartConstants.flexQty,
                child: Text('จำนวน',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(
                flex: PosCartConstants.flexPrice,
                child: Text('ราคา',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(
                flex: PosCartConstants.flexDiscount,
                child: Text('ส่วนลด',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(
                flex: PosCartConstants.flexTotal,
                child: Text('รวม',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold))),
            SizedBox(width: PosCartConstants.colAction)
          ]),
        ),

        // List Items
        Expanded(
          child: widget.items.isEmpty
              ? const Center(
                  child: Text('ตะกร้าว่างเปล่า',
                      style: TextStyle(color: Colors.grey, fontSize: 18)))
              : ListView.separated(
                  controller: _scrollController, // Attach controller
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    return CartItemTile(
                      key: ValueKey(widget.items[i].uiKey), // Unique Key by uiKey (UUID)
                      index: i,
                      item: widget.items[i],
                      onEdit: widget.onEdit,
                      onDelete: widget.onDelete,
                      onUpdateQuantity: widget.onUpdateQuantity,
                      onUpdatePrice: widget.onUpdatePrice,
                      onUpdateDiscount: widget.onUpdateDiscount,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
