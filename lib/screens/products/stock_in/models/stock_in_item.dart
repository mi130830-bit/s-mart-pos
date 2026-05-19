import 'package:flutter/material.dart';

import '../../../../models/product.dart';

class StockInItem {
  Product product; // ✅ Mutable for delayed ID update
  double quantity;
  double receivedQuantity; // ✅ New field
  double costPrice;
  int vatType;

  final TextEditingController qtyCtrl;
  final TextEditingController costCtrl;

  StockInItem({
    required this.product,
    required this.quantity,
    required this.costPrice,
    this.vatType = 0,
    this.receivedQuantity = 0.0,
  })  : qtyCtrl = TextEditingController(
            text: quantity > 0
                ? quantity
                    .toString()
                    .replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "")
                : ""),
        costCtrl = TextEditingController(
            text: costPrice
                .toStringAsFixed(4)
                .replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), ""));

  double get total => quantity * costPrice;

  void dispose() {
    qtyCtrl.dispose();
    costCtrl.dispose();
  }
}
