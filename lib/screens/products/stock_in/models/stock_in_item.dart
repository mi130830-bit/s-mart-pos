import '../../../../models/product.dart';

class StockInItem {
  Product product; // ✅ Mutable for delayed ID update
  double quantity;
  double receivedQuantity; // ✅ New field
  double costPrice;
  int vatType;

  StockInItem({
    required this.product,
    required this.quantity,
    required this.costPrice,
    this.vatType = 0,
    this.receivedQuantity = 0.0,
  });

  double get total => quantity * costPrice;
}
